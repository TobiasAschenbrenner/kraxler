import "dotenv/config";

import { Types } from "mongoose";

import { environment } from "../config/environment.js";
import { AreaModel, type AreaType } from "../modules/areas/area.model.js";
import {
  gradeRankFor,
  type GradeSystem,
} from "../modules/routes/grade.js";
import {
  RouteModel,
  type ClimbingStyle,
  type RouteDiscipline,
} from "../modules/routes/route.model.js";
import { connectToDatabase, disconnectFromDatabase } from "./mongo.js";

interface SeedArea {
  name: string;
  type: AreaType;
  coordinates: [longitude: number, latitude: number];
  parentAreaId?: Types.ObjectId;
}

interface SeedAreaIds {
  basCuvierId: Types.ObjectId;
  roethelfelsMainSectorId: Types.ObjectId;
}

interface SeedRoute {
  name: string;
  areaId: Types.ObjectId;
  coordinates: [longitude: number, latitude: number];
  discipline: RouteDiscipline;
  gradeSystem: GradeSystem;
  gradeValue: string;
  styles: ClimbingStyle[];
  lengthMeters?: number;
  pitches?: number;
  description?: string;
}

const upsertArea = async ({
  coordinates,
  name,
  parentAreaId,
  type,
}: SeedArea): Promise<Types.ObjectId> => {
  const area = await AreaModel.findOneAndUpdate(
    { name, type },
    {
      $set: {
        location: { type: "Point", coordinates },
        ...(parentAreaId === undefined ? {} : { parentAreaId }),
      },
      $setOnInsert: { name, type },
    },
    { returnDocument: "after", upsert: true },
  );

  return area._id;
};

const seedAreas = async (): Promise<SeedAreaIds> => {
  const frankenjuraId = await upsertArea({
    name: "Frankenjura",
    type: "region",
    coordinates: [11.245776, 49.747648],
  });

  const roethelfelsId = await upsertArea({
    name: "Röthelfels",
    type: "climbingArea",
    parentAreaId: frankenjuraId,
    coordinates: [11.245776, 49.747648],
  });

  const roethelfelsMainSectorId = await upsertArea({
    name: "Main sector",
    type: "sector",
    parentAreaId: roethelfelsId,
    coordinates: [11.245776, 49.747648],
  });

  const fontainebleauId = await upsertArea({
    name: "Fontainebleau",
    type: "region",
    coordinates: [2.638228, 48.447045],
  });

  const cuvierId = await upsertArea({
    name: "Cuvier",
    type: "climbingArea",
    parentAreaId: fontainebleauId,
    coordinates: [2.638228, 48.447045],
  });

  const basCuvierId = await upsertArea({
    name: "Bas Cuvier",
    type: "sector",
    parentAreaId: cuvierId,
    coordinates: [2.638228, 48.447045],
  });

  return { basCuvierId, roethelfelsMainSectorId };
};

const requiredGradeRank = (system: GradeSystem, value: string): number => {
  const rank = gradeRankFor(system, value);

  if (rank === undefined) {
    throw new Error(`Unsupported seed grade ${system}:${value}.`);
  }

  return rank;
};

const upsertRoute = async ({
  areaId,
  coordinates,
  description,
  discipline,
  gradeSystem,
  gradeValue,
  lengthMeters,
  name,
  pitches,
  styles,
}: SeedRoute): Promise<void> => {
  await RouteModel.findOneAndUpdate(
    { areaId, name },
    {
      $set: {
        areaId,
        name,
        location: { type: "Point", coordinates },
        discipline,
        grade: {
          system: gradeSystem,
          value: gradeValue,
          rank: requiredGradeRank(gradeSystem, gradeValue),
        },
        styles,
        ...(lengthMeters === undefined ? {} : { lengthMeters }),
        ...(pitches === undefined ? {} : { pitches }),
        ...(description === undefined ? {} : { description }),
      },
    },
    { upsert: true },
  );
};

const seedRoutes = async ({
  basCuvierId,
  roethelfelsMainSectorId,
}: SeedAreaIds): Promise<void> => {
  await Promise.all([
    upsertRoute({
      name: "Sonntagsspaziergang",
      areaId: roethelfelsMainSectorId,
      coordinates: [11.24633, 49.74745],
      discipline: "sport",
      gradeSystem: "uiaa",
      gradeValue: "6+",
      styles: ["vertical", "crack"],
      lengthMeters: 20,
      pitches: 1,
      description:
        "A sustained sport route with vertical climbing and a crack section.",
    }),
    upsertRoute({
      name: "Lebe deinen Traum",
      areaId: roethelfelsMainSectorId,
      coordinates: [11.24633, 49.74745],
      discipline: "sport",
      gradeSystem: "uiaa",
      gradeValue: "7+",
      styles: ["vertical", "overhang", "crack"],
      lengthMeters: 25,
      pitches: 1,
      description:
        "Varied wall climbing with cracks and an overhanging section.",
    }),
    upsertRoute({
      name: "La Marie Rose",
      areaId: basCuvierId,
      coordinates: [2.63823, 48.44704],
      discipline: "bouldering",
      gradeSystem: "fontainebleau",
      gradeValue: "6A",
      styles: ["overhang"],
      lengthMeters: 5,
      description:
        "A historic, slightly overhanging problem with polished holds and a sloping top-out.",
    }),
    upsertRoute({
      name: "La Dalle de Marbre / Lady Chatterley",
      areaId: basCuvierId,
      coordinates: [2.63823, 48.44704],
      discipline: "bouldering",
      gradeSystem: "fontainebleau",
      gradeValue: "6C+",
      styles: ["slab"],
    }),
    upsertRoute({
      name: "Scampi Fritti",
      areaId: basCuvierId,
      coordinates: [2.63823, 48.44704],
      discipline: "bouldering",
      gradeSystem: "fontainebleau",
      gradeValue: "6C",
      styles: [],
    }),
  ]);
};

const runSeed = async (): Promise<void> => {
  await connectToDatabase(environment.mongoDbUri);

  try {
    const areaIds = await seedAreas();
    await seedRoutes(areaIds);
    console.info("Kraxler development areas and routes seeded successfully.");
  } finally {
    await disconnectFromDatabase();
  }
};

runSeed().catch((error: unknown) => {
  console.error("The Kraxler development data could not be seeded.", error);
  process.exitCode = 1;
});
