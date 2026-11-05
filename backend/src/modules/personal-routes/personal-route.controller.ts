import type { RequestHandler } from "express";
import { isValidObjectId, Types } from "mongoose";
import { z } from "zod";

import { ApiError } from "../../errors/api-error.js";
import { AreaModel } from "../areas/area.model.js";
import { RouteModel } from "../routes/route.model.js";
import { serializeRoute } from "../routes/route.controller.js";
import { PersonalRouteModel } from "./personal-route.model.js";

const personalRouteStateSchema = z
  .object({
    isSaved: z.boolean(),
    isTicked: z.boolean(),
  })
  .strict();

const authenticatedUserId = (locals: Record<string, unknown>): string => {
  const userId = locals.authenticatedUserId;

  if (typeof userId !== "string" || userId.length === 0) {
    throw new ApiError(
      500,
      "missing_authenticated_user",
      "The authenticated user was not attached to the request.",
    );
  }

  return userId;
};

const routeObjectId = (routeId: unknown): Types.ObjectId => {
  if (typeof routeId !== "string" || !isValidObjectId(routeId)) {
    throw new ApiError(400, "invalid_route_id", "routeId must be a valid ID.");
  }

  return new Types.ObjectId(routeId);
};

const serializeState = (
  routeId: Types.ObjectId,
  isSaved: boolean,
  tickedAt?: Date,
) => ({
  routeId: routeId.toString(),
  isSaved,
  isTicked: tickedAt !== undefined,
  ...(tickedAt === undefined ? {} : { tickedAt: tickedAt.toISOString() }),
});

const climbingAreaNamesByRouteAreaId = async (
  routeAreaIds: Types.ObjectId[],
): Promise<Map<string, string>> => {
  const uniqueRouteAreaIds = [
    ...new Map(routeAreaIds.map((areaId) => [areaId.toString(), areaId])).values(),
  ];
  const areasById = new Map<
    string,
    {
      name: string;
      type: "region" | "climbingArea" | "sector";
      parentAreaId?: Types.ObjectId;
    }
  >();
  let pendingAreaIds = uniqueRouteAreaIds;

  while (pendingAreaIds.length > 0) {
    const areas = await AreaModel.find({ _id: { $in: pendingAreaIds } })
      .select({ name: 1, type: 1, parentAreaId: 1 })
      .lean()
      .exec();
    const nextParentIds = new Map<string, Types.ObjectId>();

    for (const area of areas) {
      const areaId = area._id.toString();
      areasById.set(areaId, area);

      if (area.parentAreaId !== undefined) {
        const parentId = area.parentAreaId.toString();

        if (!areasById.has(parentId)) {
          nextParentIds.set(parentId, area.parentAreaId);
        }
      }
    }

    pendingAreaIds = [...nextParentIds.values()];
  }

  return new Map(
    uniqueRouteAreaIds.flatMap((routeAreaId) => {
      const routeAreaIdString = routeAreaId.toString();
      const routeArea = areasById.get(routeAreaIdString);

      if (routeArea === undefined) {
        return [];
      }

      let currentArea = routeArea;
      const visitedAreaIds = new Set<string>();

      while (true) {
        if (currentArea.type === "climbingArea") {
          return [[routeAreaIdString, currentArea.name] as const];
        }

        if (currentArea.parentAreaId === undefined) {
          return [[routeAreaIdString, routeArea.name] as const];
        }

        const parentId = currentArea.parentAreaId.toString();

        if (visitedAreaIds.has(parentId)) {
          return [[routeAreaIdString, routeArea.name] as const];
        }

        visitedAreaIds.add(parentId);
        const parentArea = areasById.get(parentId);

        if (parentArea === undefined) {
          return [[routeAreaIdString, routeArea.name] as const];
        }

        currentArea = parentArea;
      }
    }),
  );
};

export const listPersonalRoutes: RequestHandler = async (
  _request,
  response,
  next,
) => {
  try {
    const userId = authenticatedUserId(response.locals);
    const personalRoutes = await PersonalRouteModel.find({ userId })
      .sort({ updatedAt: -1 })
      .lean()
      .exec();
    const routes = await RouteModel.find({
      _id: { $in: personalRoutes.map(({ routeId }) => routeId) },
    })
      .lean()
      .exec();
    const routesById = new Map(
      routes.map((route) => [route._id.toString(), route]),
    );
    const areaNamesById = await climbingAreaNamesByRouteAreaId(
      routes.map(({ areaId }) => areaId),
    );

    const data = personalRoutes.flatMap((personalRoute) => {
      const route = routesById.get(personalRoute.routeId.toString());

      if (route === undefined) {
        return [];
      }

      return [
        {
          route: serializeRoute(route),
          areaName: areaNamesById.get(route.areaId.toString()),
          ...serializeState(
            personalRoute.routeId,
            personalRoute.isSaved,
            personalRoute.tickedAt,
          ),
        },
      ];
    });

    response.json({ data, meta: { count: data.length } });
  } catch (error) {
    next(error);
  }
};

export const getPersonalRouteState: RequestHandler = async (
  request,
  response,
  next,
) => {
  try {
    const userId = authenticatedUserId(response.locals);
    const routeId = routeObjectId(request.params.routeId);
    const personalRoute = await PersonalRouteModel.findOne({ userId, routeId })
      .lean()
      .exec();

    response.json({
      data: serializeState(
        routeId,
        personalRoute?.isSaved ?? false,
        personalRoute?.tickedAt,
      ),
    });
  } catch (error) {
    next(error);
  }
};

export const putPersonalRouteState: RequestHandler = async (
  request,
  response,
  next,
) => {
  try {
    const userId = authenticatedUserId(response.locals);
    const routeId = routeObjectId(request.params.routeId);
    const parsedState = personalRouteStateSchema.safeParse(request.body);

    if (!parsedState.success) {
      next(
        new ApiError(
          400,
          "invalid_personal_route_state",
          "isSaved and isTicked must both be boolean values.",
        ),
      );
      return;
    }

    const routeExists = await RouteModel.exists({ _id: routeId });

    if (!routeExists) {
      next(
        new ApiError(
          404,
          "climbing_route_not_found",
          "The climbing route was not found.",
        ),
      );
      return;
    }

    const { isSaved, isTicked } = parsedState.data;

    if (!isSaved && !isTicked) {
      await PersonalRouteModel.deleteOne({ userId, routeId }).exec();
      response.json({ data: serializeState(routeId, false) });
      return;
    }

    const existing = await PersonalRouteModel.findOne({ userId, routeId })
      .select({ tickedAt: 1 })
      .lean()
      .exec();
    const tickedAt = isTicked ? (existing?.tickedAt ?? new Date()) : undefined;
    const update = {
      $set: {
        isSaved,
        ...(tickedAt === undefined ? {} : { tickedAt }),
      },
      ...(tickedAt === undefined ? { $unset: { tickedAt: 1 } } : {}),
    };

    await PersonalRouteModel.updateOne(
      { userId, routeId },
      update,
      { upsert: true },
    ).exec();

    response.json({ data: serializeState(routeId, isSaved, tickedAt) });
  } catch (error) {
    next(error);
  }
};
