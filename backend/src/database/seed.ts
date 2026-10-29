import "dotenv/config";

import { Types } from "mongoose";

import { environment } from "../config/environment.js";
import { AreaModel, type AreaType } from "../modules/areas/area.model.js";
import { connectToDatabase, disconnectFromDatabase } from "./mongo.js";

interface SeedArea {
  name: string;
  type: AreaType;
  coordinates: [longitude: number, latitude: number];
  parentAreaId?: Types.ObjectId;
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

const seedAreas = async (): Promise<void> => {
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

  await upsertArea({
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

  await upsertArea({
    name: "Bas Cuvier",
    type: "sector",
    parentAreaId: cuvierId,
    coordinates: [2.638228, 48.447045],
  });
};

const runSeed = async (): Promise<void> => {
  await connectToDatabase(environment.mongoDbUri);

  try {
    await seedAreas();
    console.info("Kraxler development areas seeded successfully.");
  } finally {
    await disconnectFromDatabase();
  }
};

runSeed().catch((error: unknown) => {
  console.error("The Kraxler development data could not be seeded.", error);
  process.exitCode = 1;
});
