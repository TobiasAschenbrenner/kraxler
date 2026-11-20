import { Router } from "express";
import { z } from "zod";

import type { AuthTokenVerifier } from "../../auth/auth-token.js";
import { ApiError } from "../../errors/api-error.js";
import { createRequireAuthentication } from "../../middleware/require-authentication.js";
import { UserProfileModel } from "./profile.model.js";
import type { AvatarStorage, StoredAvatar } from "./avatar-storage.js";

const avatarSchema = z.string().max(65_536).refine((value) => {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return false;
  const image = Buffer.from(value, "base64");
  return image.length <= 49_152 && image.length >= 4
    && image.toString("base64") === value
    && image[0] === 0xff && image[1] === 0xd8 && image[2] === 0xff
    && image.at(-2) === 0xff && image.at(-1) === 0xd9;
}, "Use a JPEG avatar smaller than 48 KB.");

const profileSchema = z.object({
  displayName: z.string().trim().min(1).max(80),
  avatarBase64: avatarSchema.nullable(),
  usesDefaultAvatar: z.boolean(),
}).strict().refine(
  ({ avatarBase64, usesDefaultAvatar }) => avatarBase64 === null || !usesDefaultAvatar,
  "A custom photo cannot also use the default avatar.",
);

export const createProfileRouter = (verifyAuthToken: AuthTokenVerifier, avatars: AvatarStorage): Router => {
  const router = Router();
  router.use("/me/profile", createRequireAuthentication(verifyAuthToken));

  router.get("/me/profile", async (_request, response) => {
    const profile = await UserProfileModel.findOne({
      userId: response.locals.authenticatedUserId,
    }).lean().exec();
    response.json({ data: {
      displayName: profile?.displayName ?? null,
      avatarBase64: profile?.avatarBase64 ?? null,
      avatarUrl: profile?.avatarUrl ?? null,
      usesDefaultAvatar: profile?.usesDefaultAvatar ?? false,
    } });
  });

  router.put("/me/profile", async (request, response) => {
    const parsed = profileSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new ApiError(400, "invalid_profile", "Use a name up to 80 characters and a JPEG photo smaller than 48 KB.");
    }
    const userId = response.locals.authenticatedUserId as string;
    const current = await UserProfileModel.findOne({ userId }).lean().exec();
    let uploaded: StoredAvatar | undefined;
    const removeUnused = async (publicId: string): Promise<void> => {
      try { await avatars.remove(publicId); }
      catch { request.log?.warn({ event: "avatar_cleanup_failed", publicId }, "Avatar cleanup failed."); }
    };
    if (parsed.data.avatarBase64 !== null) {
      uploaded = await avatars.upload(Buffer.from(parsed.data.avatarBase64, "base64"));
    }
    const clearPhoto = parsed.data.usesDefaultAvatar;
    let profile;
    try {
      profile = await UserProfileModel.findOneAndUpdate(
        current
          ? { _id: current._id, __v: current.__v ?? { $exists: false } }
          : { userId, __v: { $exists: false } },
        { $set: {
          userId,
          displayName: parsed.data.displayName,
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
    response.json({ data: {
      displayName: profile.displayName,
      avatarBase64: profile.avatarBase64,
      avatarUrl: profile.avatarUrl,
      usesDefaultAvatar: profile.usesDefaultAvatar,
    } });
  });
  return router;
};
