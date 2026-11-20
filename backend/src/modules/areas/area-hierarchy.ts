import type { Types } from "mongoose";

import { AreaModel } from "./area.model.js";

export const climbingAreasByRouteAreaId = async (
  routeAreaIds: Types.ObjectId[],
): Promise<Map<string, { id: string; name: string }>> => {
  const uniqueRouteAreaIds = [
    ...new Map(routeAreaIds.map((areaId) => [areaId.toString(), areaId])).values(),
  ];
  const areasById = new Map<
    string,
    {
      _id: Types.ObjectId;
      name: string;
      type: "region" | "climbingArea" | "sector";
      parentAreaId?: Types.ObjectId;
    }
  >();
  let pendingAreaIds = uniqueRouteAreaIds;

  while (pendingAreaIds.length > 0) {
    const areas = await AreaModel.find({ _id: { $in: pendingAreaIds } })
      .select({ name: 1, type: 1, parentAreaId: 1 })
      .lean()
      .exec();
    const nextParentIds = new Map<string, Types.ObjectId>();

    for (const area of areas) {
      const areaId = area._id.toString();
      areasById.set(areaId, area);

      if (area.parentAreaId !== undefined) {
        const parentId = area.parentAreaId.toString();

        if (!areasById.has(parentId)) {
          nextParentIds.set(parentId, area.parentAreaId);
        }
      }
    }

    pendingAreaIds = [...nextParentIds.values()];
  }

  return new Map(
    uniqueRouteAreaIds.flatMap((routeAreaId) => {
      const routeAreaIdString = routeAreaId.toString();
      const routeArea = areasById.get(routeAreaIdString);

      if (routeArea === undefined) {
        return [];
      }

      let currentArea = routeArea;
      const visitedAreaIds = new Set<string>();

      while (true) {
        if (currentArea.type === "climbingArea") {
          return [[routeAreaIdString, { id: currentArea._id.toString(), name: currentArea.name }] as const];
        }

        if (currentArea.parentAreaId === undefined) {
          return [[routeAreaIdString, { id: routeAreaIdString, name: routeArea.name }] as const];
        }

        const parentId = currentArea.parentAreaId.toString();

        if (visitedAreaIds.has(parentId)) {
          return [[routeAreaIdString, { id: routeAreaIdString, name: routeArea.name }] as const];
        }

        visitedAreaIds.add(parentId);
        const parentArea = areasById.get(parentId);

        if (parentArea === undefined) {
          return [[routeAreaIdString, { id: routeAreaIdString, name: routeArea.name }] as const];
        }

        currentArea = parentArea;
      }
    }),
  );
};

