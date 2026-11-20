import type { Types } from "mongoose";

import type { Area } from "./area.model.js";

export const serializeArea = (area: Pick<Area, "name" | "type" | "location"> & { _id: Types.ObjectId }) => ({
  id: area._id.toString(),
  name: area.name,
  type: area.type,
  location: area.location,
});
