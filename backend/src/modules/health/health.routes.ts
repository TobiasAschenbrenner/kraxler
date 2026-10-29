import { Router } from "express";

import { databaseIsReady } from "../../database/mongo.js";

export const healthRouter = Router();

healthRouter.get("/health", (_request, response) => {
  response.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
});

healthRouter.get("/ready", (_request, response) => {
  const ready = databaseIsReady();

  response.status(ready ? 200 : 503).json({
    status: ready ? "ready" : "not_ready",
    dependencies: {
      database: ready ? "up" : "down",
    },
    timestamp: new Date().toISOString(),
  });
});
