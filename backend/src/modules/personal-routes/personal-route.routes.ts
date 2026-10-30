import { Router } from "express";

import type { AuthTokenVerifier } from "../../auth/auth-token.js";
import { createRequireAuthentication } from "../../middleware/require-authentication.js";
import {
  getPersonalRouteState,
  listPersonalRoutes,
  putPersonalRouteState,
} from "./personal-route.controller.js";

export const createPersonalRouteRouter = (
  verifyAuthToken: AuthTokenVerifier,
): Router => {
  const router = Router();
  router.use(createRequireAuthentication(verifyAuthToken));
  router.get("/me/routes", listPersonalRoutes);
  router.get("/me/routes/:routeId", getPersonalRouteState);
  router.put("/me/routes/:routeId", putPersonalRouteState);
  return router;
};
