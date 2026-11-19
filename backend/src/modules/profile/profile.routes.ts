import { Router } from "express";
import { z } from "zod";

import type { AuthTokenVerifier } from "../../auth/auth-token.js";
import { ApiError } from "../../errors/api-error.js";
import { createRequireAuthentication } from "../../middleware/require-authentication.js";
import { UserProfileModel } from "./profile.model.js";

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

export const createProfileRouter = (verifyAuthToken: AuthTokenVerifier): Router => {
  const router = Router();
  router.use("/me/profile", createRequireAuthentication(verifyAuthToken));

  router.get("/me/profile", async (_request, response) => {
    const profile = await UserProfileModel.findOne({
      userId: response.locals.authenticatedUserId,
    }).lean().exec();
    response.json({ data: {
      displayName: profile?.displayName ?? null,
      avatarBase64: profile?.avatarBase64 ?? null,
      usesDefaultAvatar: profile?.usesDefaultAvatar ?? false,
    } });
  });

  router.put("/me/profile", async (request, response) => {
    const parsed = profileSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new ApiError(400, "invalid_profile", "Use a name up to 80 characters and a JPEG photo smaller than 48 KB.");
    }
    const profile = await UserProfileModel.findOneAndUpdate(
      { userId: response.locals.authenticatedUserId },
      { $set: parsed.data },
      { upsert: true, returnDocument: "after", runValidators: true },
    ).lean().exec();
    response.json({ data: {
      displayName: profile!.displayName,
      avatarBase64: profile!.avatarBase64,
      usesDefaultAvatar: profile!.usesDefaultAvatar,
    } });
  });
  return router;
};
