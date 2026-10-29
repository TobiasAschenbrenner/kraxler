import { Router } from "express";

import { getRouteById, listRoutesForArea } from "./route.controller.js";

export const routeRouter = Router();

routeRouter.get("/areas/:areaId/routes", listRoutesForArea);
routeRouter.get("/routes/:routeId", getRouteById);
