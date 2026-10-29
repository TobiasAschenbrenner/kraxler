import { Router } from "express";

import { listAreasInBoundingBox } from "./area.controller.js";

export const areaRouter = Router();

areaRouter.get("/areas", listAreasInBoundingBox);
