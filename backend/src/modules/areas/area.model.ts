import { Schema, Types, model } from "mongoose";

import { geoJsonPointSchema, type GeoJsonPoint } from "../../database/schemas/geojson-point.js";

export const areaTypes = ["region", "climbingArea", "sector"] as const;

export type AreaType = (typeof areaTypes)[number];

export interface Area {
  name: string;
  type: AreaType;
  parentAreaId?: Types.ObjectId;
  location: GeoJsonPoint;
}

const areaSchema = new Schema<Area>(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    type: {
      type: String,
      enum: areaTypes,
      required: true,
    },
    parentAreaId: {
      type: Schema.Types.ObjectId,
      ref: "Area",
    },
    location: {
      type: geoJsonPointSchema,
      required: true,
    },
  },
  { timestamps: true },
);

areaSchema.index({ location: "2dsphere" });
areaSchema.index({ parentAreaId: 1 });

export const AreaModel = model<Area>("Area", areaSchema);
