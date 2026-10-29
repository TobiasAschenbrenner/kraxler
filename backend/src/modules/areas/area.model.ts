import { Schema, Types, model } from "mongoose";

export const areaTypes = ["region", "climbingArea", "sector"] as const;

export type AreaType = (typeof areaTypes)[number];

export interface GeoJsonPoint {
  type: "Point";
  coordinates: [longitude: number, latitude: number];
}

export interface Area {
  name: string;
  type: AreaType;
  parentAreaId?: Types.ObjectId;
  location: GeoJsonPoint;
}

const pointSchema = new Schema<GeoJsonPoint>(
  {
    type: {
      type: String,
      enum: ["Point"],
      required: true,
    },
    coordinates: {
      type: [Number],
      required: true,
      validate: {
        validator: (coordinates: number[]) => {
          const [longitude, latitude] = coordinates;

          return (
            coordinates.length === 2 &&
            longitude !== undefined &&
            latitude !== undefined &&
            Number.isFinite(longitude) &&
            Number.isFinite(latitude) &&
            longitude >= -180 &&
            longitude <= 180 &&
            latitude >= -90 &&
            latitude <= 90
          );
        },
        message: "Location must contain a valid longitude and latitude.",
      },
    },
  },
  { _id: false },
);

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
      type: pointSchema,
      required: true,
    },
  },
  { timestamps: true },
);

areaSchema.index({ location: "2dsphere" });
areaSchema.index({ parentAreaId: 1 });

export const AreaModel = model<Area>("Area", areaSchema);
