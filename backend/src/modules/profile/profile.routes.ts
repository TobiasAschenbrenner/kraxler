import { Router } from "express";

import type { AuthTokenVerifier } from "../../auth/auth-token.js";
import { createRequireAuthentication } from "../../middleware/require-authentication.js";
import type { AvatarStorage } from "./avatar-storage.js";
import { createUpdateProfile, getProfile } from "./profile.controller.js";

export const createProfileRouter = (verifyAuthToken: AuthTokenVerifier, avatars: AvatarStorage): Router => {
  const router = Router();
  router.use("/me/profile", createRequireAuthentication(verifyAuthToken));
  router.get("/me/profile", getProfile);
  router.put("/me/profile", createUpdateProfile(avatars));
  return router;
};
