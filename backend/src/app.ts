import express from "express";
import helmet from "helmet";

import {
  type AuthTokenVerifier,
  verifyFirebaseAuthToken,
} from "./auth/auth-token.js";
import { environment } from "./config/environment.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";
import { createRequestLogger } from "./middleware/request-logger.js";
import { areaRouter } from "./modules/areas/area.routes.js";
import { healthRouter } from "./modules/health/health.routes.js";
import { createPersonalRouteRouter } from "./modules/personal-routes/personal-route.routes.js";
import { createProfileRouter } from "./modules/profile/profile.routes.js";
import { type AvatarStorage, createAvatarStorage } from "./modules/profile/avatar-storage.js";
import { routeRouter } from "./modules/routes/route.routes.js";
import { searchRouter } from "./modules/search/search.routes.js";

interface AppDependencies {
  verifyAuthToken: AuthTokenVerifier;
  avatarStorage?: AvatarStorage;
}

export const createApp = (
  dependencies: AppDependencies = {
    verifyAuthToken: verifyFirebaseAuthToken,
  },
) => {
  const expressApp = express();

  expressApp.disable("x-powered-by");
  expressApp.use(helmet());

  if (environment.nodeEnv !== "test") {
    expressApp.use(createRequestLogger());
  }

  expressApp.use(express.json({ limit: "100kb" }));
  expressApp.use(healthRouter);
  expressApp.use("/api/v1", areaRouter);
  expressApp.use("/api/v1", routeRouter);
  expressApp.use("/api/v1", searchRouter);
  expressApp.use("/api/v1", createProfileRouter(
    dependencies.verifyAuthToken, dependencies.avatarStorage ?? createAvatarStorage(),
  ));
  expressApp.use(
    "/api/v1",
    createPersonalRouteRouter(dependencies.verifyAuthToken),
  );

  expressApp.use(notFoundHandler);
  expressApp.use(errorHandler);

  return expressApp;
};

export const app = createApp();
