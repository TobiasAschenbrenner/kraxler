import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";

import { environment } from "./config/environment.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";
import { healthRouter } from "./modules/health/health.routes.js";

export const app = express();

app.disable("x-powered-by");
app.use(helmet());

if (environment.nodeEnv !== "test") {
  app.use(pinoHttp());
}

app.use(express.json({ limit: "100kb" }));
app.use(healthRouter);

app.use(notFoundHandler);
app.use(errorHandler);
