import { ApiError } from "../../errors/api-error.js";
import type { AvatarStorage, StoredAvatar } from "./avatar-storage.js";
import { UserProfileModel, type UserProfile } from "./profile.model.js";
import type { ProfileUpdate } from "./profile.validation.js";

type ProfileFields = Pick<UserProfile, "displayName" | "avatarBase64" | "avatarUrl" | "usesDefaultAvatar">;

const serializeProfile = (profile: ProfileFields | null) => ({
  displayName: profile?.displayName ?? null,
  avatarBase64: profile?.avatarBase64 ?? null,
  avatarUrl: profile?.avatarUrl ?? null,
  usesDefaultAvatar: profile?.usesDefaultAvatar ?? false,
});

export const getUserProfile = async (userId: string) =>
  serializeProfile(await UserProfileModel.findOne({ userId }).lean().exec());

export const updateUserProfile = async (
  userId: string,
  update: ProfileUpdate,
  avatars: AvatarStorage,
  onCleanupFailure: (publicId: string) => void,
) => {
  const current = await UserProfileModel.findOne({ userId }).lean().exec();
  let uploaded: StoredAvatar | undefined;
  const removeUnused = async (publicId: string): Promise<void> => {
    try { await avatars.remove(publicId); }
    catch { onCleanupFailure(publicId); }
  };
  if (update.avatarBase64 !== null) {
    uploaded = await avatars.upload(Buffer.from(update.avatarBase64, "base64"));
  }
  const clearPhoto = update.usesDefaultAvatar;
  let profile;
  try {
    profile = await UserProfileModel.findOneAndUpdate(
      current
        ? { _id: current._id, __v: current.__v ?? { $exists: false } }
        : { userId, __v: { $exists: false } },
      { $set: {
        userId,
        displayName: update.displayName,
        usesDefaultAvatar: clearPhoto,
        avatarBase64: uploaded || clearPhoto ? null : current?.avatarBase64 ?? null,
        avatarUrl: uploaded?.url ?? (clearPhoto ? null : current?.avatarUrl ?? null),
        avatarPublicId: uploaded?.publicId ?? (clearPhoto ? null : current?.avatarPublicId ?? null),
        __v: (current?.__v ?? 0) + 1,
      } },
      { upsert: current === null, returnDocument: "after", runValidators: true },
    ).lean().exec();
    if (!profile) throw new ApiError(409, "profile_changed", "Profile changed. Try again.");
  } catch (error) {
    if (uploaded) await removeUnused(uploaded.publicId);
    if (error && typeof error === "object" && "code" in error && error.code === 11000) {
      throw new ApiError(409, "profile_changed", "Profile changed. Try again.");
    }
    throw error;
  }
  if (current?.avatarPublicId && current.avatarPublicId !== profile.avatarPublicId) {
    await removeUnused(current.avatarPublicId);
  }
  return serializeProfile(profile);
};
