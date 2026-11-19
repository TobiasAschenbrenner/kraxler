import { Schema, model } from "mongoose";

export interface UserProfile {
  userId: string;
  displayName: string;
  avatarBase64: string | null;
  usesDefaultAvatar: boolean;
}

const profileSchema = new Schema<UserProfile>(
  {
    userId: { type: String, required: true, maxlength: 128 },
    displayName: { type: String, required: true, trim: true, maxlength: 80 },
    avatarBase64: { type: String, default: null, maxlength: 65_536 },
    usesDefaultAvatar: { type: Boolean, default: false },
  },
  { timestamps: true },
);

profileSchema.index({ userId: 1 }, { unique: true });

export const UserProfileModel = model<UserProfile>("UserProfile", profileSchema);
