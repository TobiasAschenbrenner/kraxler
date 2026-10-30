import type { RequestHandler } from "express";
import { isValidObjectId, Types } from "mongoose";

import { ApiError } from "../../errors/api-error.js";
import { AreaModel } from "../areas/area.model.js";
import { RouteModel, type ClimbingRoute } from "./route.model.js";
import { parseRouteFilters, type RouteFilters } from "./route.query.js";

export const serializeRoute = (route: ClimbingRoute & { _id: Types.ObjectId }) => ({
  id: route._id.toString(),
  areaId: route.areaId.toString(),
  name: route.name,
  location: route.location,
  discipline: route.discipline,
  grade: {
    system: route.grade.system,
    value: route.grade.value,
    rank: route.grade.rank,
  },
  styles: route.styles,
  ...(route.lengthMeters === undefined
    ? {}
    : { lengthMeters: route.lengthMeters }),
  ...(route.pitches === undefined ? {} : { pitches: route.pitches }),
  ...(route.description === undefined
    ? {}
    : { description: route.description }),
});

const buildRouteFilter = (
  areaIds: Types.ObjectId[],
  filters: RouteFilters,
): Record<string, unknown> => {
  const mongoFilter: Record<string, unknown> = {
    areaId: { $in: areaIds },
  };

  if (filters.discipline !== undefined) {
    mongoFilter.discipline = filters.discipline;
  }

  if (filters.gradeSystem !== undefined) {
    mongoFilter["grade.system"] = filters.gradeSystem;
  }

  if (
    filters.gradeMinRank !== undefined ||
    filters.gradeMaxRank !== undefined
  ) {
    mongoFilter["grade.rank"] = {
      ...(filters.gradeMinRank === undefined
        ? {}
        : { $gte: filters.gradeMinRank }),
      ...(filters.gradeMaxRank === undefined
        ? {}
        : { $lte: filters.gradeMaxRank }),
    };
  }

  if (filters.styles !== undefined) {
    mongoFilter.styles = { $in: filters.styles };
  }

  if (filters.lengthMin !== undefined || filters.lengthMax !== undefined) {
    mongoFilter.lengthMeters = {
      ...(filters.lengthMin === undefined ? {} : { $gte: filters.lengthMin }),
      ...(filters.lengthMax === undefined ? {} : { $lte: filters.lengthMax }),
    };
  }

  if (filters.pitchesMin !== undefined || filters.pitchesMax !== undefined) {
    mongoFilter.pitches = {
      ...(filters.pitchesMin === undefined ? {} : { $gte: filters.pitchesMin }),
      ...(filters.pitchesMax === undefined ? {} : { $lte: filters.pitchesMax }),
    };
  }

  return mongoFilter;
};

const findAreaAndDescendantIds = async (
  rootAreaId: Types.ObjectId,
): Promise<Types.ObjectId[]> => {
  const areaIds = [rootAreaId];
  const visitedIds = new Set([rootAreaId.toString()]);
  let parentIds = [rootAreaId];

  while (parentIds.length > 0) {
    const children = await AreaModel.find({
      parentAreaId: { $in: parentIds },
    })
      .select({ _id: 1 })
      .lean()
      .exec();

    parentIds = children
      .map((child) => child._id)
      .filter((childId) => {
        const id = childId.toString();

        if (visitedIds.has(id)) {
          return false;
        }

        visitedIds.add(id);
        areaIds.push(childId);
        return true;
      });
  }

  return areaIds;
};

export const listRoutesForArea: RequestHandler = async (
  request,
  response,
  next,
) => {
  const { areaId } = request.params;

  if (typeof areaId !== "string" || !isValidObjectId(areaId)) {
    next(new ApiError(400, "invalid_area_id", "areaId must be a valid ID."));
    return;
  }

  const query = parseRouteFilters(request.query);

  if (!query.success) {
    next(
      new ApiError(
        400,
        "invalid_route_filters",
        "Route filters contain unsupported or conflicting values.",
      ),
    );
    return;
  }

  const objectId = new Types.ObjectId(areaId);

  try {
    const areaExists = await AreaModel.exists({ _id: objectId });

    if (!areaExists) {
      next(new ApiError(404, "area_not_found", "The climbing area was not found."));
      return;
    }

    const areaIds = await findAreaAndDescendantIds(objectId);
    const routes = await RouteModel.find(
      buildRouteFilter(areaIds, query.filters),
    )
      .sort({ "grade.rank": 1, name: 1 })
      .lean()
      .exec();

    response.json({
      data: routes.map(serializeRoute),
      meta: {
        count: routes.length,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const getRouteById: RequestHandler = async (
  request,
  response,
  next,
) => {
  const { routeId } = request.params;

  if (typeof routeId !== "string" || !isValidObjectId(routeId)) {
    next(new ApiError(400, "invalid_route_id", "routeId must be a valid ID."));
    return;
  }

  try {
    const route = await RouteModel.findById(routeId).lean().exec();

    if (!route) {
      next(
        new ApiError(
          404,
          "climbing_route_not_found",
          "The climbing route was not found.",
        ),
      );
      return;
    }

    response.json({ data: serializeRoute(route) });
  } catch (error) {
    next(error);
  }
};
