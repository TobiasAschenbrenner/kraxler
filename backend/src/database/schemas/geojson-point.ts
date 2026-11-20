import { Schema } from "mongoose";

export interface GeoJsonPoint {
  type: "Point";
  coordinates: [longitude: number, latitude: number];
}

export const geoJsonPointSchema = new Schema<GeoJsonPoint>(
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

