import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";

import { environment } from "./config/environment.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";
import { areaRouter } from "./modules/areas/area.routes.js";
import { healthRouter } from "./modules/health/health.routes.js";
import { routeRouter } from "./modules/routes/route.routes.js";

export const app = express();

app.disable("x-powered-by");
app.use(helmet());

if (environment.nodeEnv !== "test") {
  app.use(pinoHttp());
}

app.use(express.json({ limit: "100kb" }));
app.use(healthRouter);
app.use("/api/v1", areaRouter);
app.use("/api/v1", routeRouter);

app.use(notFoundHandler);
app.use(errorHandler);
