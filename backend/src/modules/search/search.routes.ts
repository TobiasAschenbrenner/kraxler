import { Router } from "express";

import { searchClimbingContent } from "./search.controller.js";

export const searchRouter = Router();

searchRouter.get("/search", searchClimbingContent);
