import type { RequestHandler } from "express";

import { ApiError } from "../../errors/api-error.js";
import { AreaModel } from "../areas/area.model.js";
import { RouteModel } from "../routes/route.model.js";
import { serializeRoute } from "../routes/route.controller.js";
import { parseSearchQuery } from "./search.query.js";

const resultLimit = 10;

const escapeRegularExpression = (value: string): string =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export const searchClimbingContent: RequestHandler = async (
  request,
  response,
  next,
) => {
  const query = parseSearchQuery(request.query);

  if (!query.success) {
    next(
      new ApiError(
        400,
        "invalid_search_query",
        "q must contain between 2 and 80 characters.",
      ),
    );
    return;
  }

  const name = {
    $regex: escapeRegularExpression(query.searchTerm),
    $options: "i",
  };

  try {
    const [areas, routes] = await Promise.all([
      AreaModel.find({ name })
        .select({ name: 1, type: 1, location: 1 })
        .sort({ name: 1 })
        .limit(resultLimit)
        .lean()
        .exec(),
      RouteModel.find({ name })
        .sort({ name: 1 })
        .limit(resultLimit)
        .lean()
        .exec(),
    ]);

    response.json({
      data: {
        areas: areas.map((area) => ({
          id: area._id.toString(),
          name: area.name,
          type: area.type,
          location: area.location,
        })),
        routes: routes.map(serializeRoute),
      },
      meta: {
        areaCount: areas.length,
        routeCount: routes.length,
      },
    });
  } catch (error) {
    next(error);
  }
};
