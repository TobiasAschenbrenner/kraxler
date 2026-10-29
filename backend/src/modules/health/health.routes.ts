import { Router } from "express";

export const healthRouter = Router();

healthRouter.get("/health", (_request, response) => {
  response.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
});

healthRouter.get("/ready", (_request, response) => {
  response.json({
    status: "ready",
    timestamp: new Date().toISOString(),
  });
});
