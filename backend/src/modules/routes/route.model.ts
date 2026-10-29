import { Schema, Types, model } from "mongoose";

import type { GeoJsonPoint } from "../areas/area.model.js";
import { gradeSystems, type GradeSystem } from "./grade.js";

export const routeDisciplines = ["sport", "trad", "bouldering"] as const;
export const climbingStyles = [
  "slab",
  "vertical",
  "overhang",
  "roof",
  "crack",
  "chimney",
  "arete",
  "traverse",
] as const;

export type RouteDiscipline = (typeof routeDisciplines)[number];
export type ClimbingStyle = (typeof climbingStyles)[number];

export interface RouteGrade {
  system: GradeSystem;
  value: string;
  rank: number;
}

export interface ClimbingRoute {
  name: string;
  areaId: Types.ObjectId;
  location: GeoJsonPoint;
  discipline: RouteDiscipline;
  grade: RouteGrade;
  styles: ClimbingStyle[];
  lengthMeters?: number;
  pitches?: number;
  description?: string;
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

const gradeSchema = new Schema<RouteGrade>(
  {
    system: {
      type: String,
      enum: gradeSystems,
      required: true,
    },
    value: {
      type: String,
      required: true,
      trim: true,
      maxlength: 20,
    },
    rank: {
      type: Number,
      required: true,
      min: 1,
      max: 100,
    },
  },
  { _id: false },
);

const routeSchema = new Schema<ClimbingRoute>(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 160,
    },
    areaId: {
      type: Schema.Types.ObjectId,
      ref: "Area",
      required: true,
    },
    location: {
      type: pointSchema,
      required: true,
    },
    discipline: {
      type: String,
      enum: routeDisciplines,
      required: true,
    },
    grade: {
      type: gradeSchema,
      required: true,
    },
    styles: {
      type: [String],
      enum: climbingStyles,
      default: [],
    },
    lengthMeters: {
      type: Number,
      min: 0.1,
    },
    pitches: {
      type: Number,
      min: 1,
      validate: Number.isInteger,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 2_000,
    },
  },
  { timestamps: true },
);

routeSchema.index({ location: "2dsphere" });
routeSchema.index({ areaId: 1, "grade.rank": 1, name: 1 });
routeSchema.index({ areaId: 1, name: 1 }, { unique: true });

export const RouteModel = model<ClimbingRoute>("Route", routeSchema);
