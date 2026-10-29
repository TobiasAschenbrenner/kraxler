import type { RequestHandler } from "express";

import { ApiError } from "../../errors/api-error.js";
import { AreaModel } from "./area.model.js";
import { parseAreaQuery } from "./area.query.js";

export const listAreasInBoundingBox: RequestHandler = async (
  request,
  response,
  next,
) => {
  const query = parseAreaQuery(request.query);

  if (!query.success) {
    next(
      new ApiError(
        400,
        "invalid_bounding_box",
        "bbox must contain valid west,south,east,north coordinates.",
      ),
    );
    return;
  }

  const [west, south, east, north] = query.boundingBox;

  try {
    const areas = await AreaModel.find({
      location: {
        $geoWithin: {
          $geometry: {
            type: "Polygon",
            coordinates: [
              [
                [west, south],
                [east, south],
                [east, north],
                [west, north],
                [west, south],
              ],
            ],
          },
        },
      },
    })
      .select({ name: 1, type: 1, location: 1 })
      .sort({ name: 1 })
      .lean()
      .exec();

    response.json({
      data: areas.map((area) => ({
        id: area._id.toString(),
        name: area.name,
        type: area.type,
        location: area.location,
      })),
      meta: {
        count: areas.length,
      },
    });
  } catch (error) {
    next(error);
  }
};
