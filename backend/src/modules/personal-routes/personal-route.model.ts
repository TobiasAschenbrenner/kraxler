import { Schema, Types, model } from "mongoose";

export interface PersonalRoute {
  userId: string;
  routeId: Types.ObjectId;
  isSaved: boolean;
  tickedAt?: Date;
}

const personalRouteSchema = new Schema<PersonalRoute>(
  {
    userId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 128,
    },
    routeId: {
      type: Schema.Types.ObjectId,
      ref: "Route",
      required: true,
    },
    isSaved: {
      type: Boolean,
      required: true,
      default: false,
    },
    tickedAt: Date,
  },
  { timestamps: true },
);

personalRouteSchema.index({ userId: 1, routeId: 1 }, { unique: true });
personalRouteSchema.index({ userId: 1, updatedAt: -1 });

export const PersonalRouteModel = model<PersonalRoute>(
  "PersonalRoute",
  personalRouteSchema,
);
