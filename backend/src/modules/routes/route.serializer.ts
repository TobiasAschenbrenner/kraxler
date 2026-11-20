import type { Types } from "mongoose";

import type { ClimbingRoute } from "./route.model.js";

export const serializeRoute = (route: ClimbingRoute & { _id: Types.ObjectId }) => ({
  id: route._id.toString(),
  areaId: route.areaId.toString(),
  name: route.name,
  location: route.location,
  discipline: route.discipline,
  grade: {
    system: route.grade.system,
    value: route.grade.value,
    rank: route.grade.rank,
  },
  styles: route.styles,
  ...(route.lengthMeters === undefined
    ? {}
    : { lengthMeters: route.lengthMeters }),
  ...(route.pitches === undefined ? {} : { pitches: route.pitches }),
  ...(route.description === undefined
    ? {}
    : { description: route.description }),
  ...(!route.topos?.length ? {} : {
    topos: route.topos.map((topo) => ({
      id: topo.id,
      imageUrl: topo.imageUrl,
      ...(topo.cloudinaryPublicId ? { cloudinaryPublicId: topo.cloudinaryPublicId } : {}),
      routeNumber: topo.routeNumber,
      pixelWidth: topo.pixelWidth,
      pixelHeight: topo.pixelHeight,
    })),
  }),
});

