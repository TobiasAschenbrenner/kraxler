import type { RequestHandler } from "express";

import { ApiError } from "../../errors/api-error.js";
import type { AvatarStorage } from "./avatar-storage.js";
import { getUserProfile, updateUserProfile } from "./profile.service.js";
import { profileSchema } from "./profile.validation.js";

export const getProfile: RequestHandler = async (_request, response) => {
  response.json({ data: await getUserProfile(response.locals.authenticatedUserId as string) });
};

export const createUpdateProfile = (avatars: AvatarStorage): RequestHandler => async (request, response) => {
  const parsed = profileSchema.safeParse(request.body);
  if (!parsed.success) {
    throw new ApiError(400, "invalid_profile", "Use a name up to 80 characters and a JPEG photo smaller than 48 KB.");
  }
  const profile = await updateUserProfile(
    response.locals.authenticatedUserId as string, parsed.data, avatars,
    (publicId) => request.log?.warn({ event: "avatar_cleanup_failed", publicId }, "Avatar cleanup failed."),
  );
  response.json({ data: profile });
};
