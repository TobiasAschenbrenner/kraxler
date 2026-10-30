import { MongoMemoryServer } from "mongodb-memory-server-core";
import request from "supertest";
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";

import { app } from "../src/app.js";
import {
  connectToDatabase,
  disconnectFromDatabase,
} from "../src/database/mongo.js";
import { AreaModel } from "../src/modules/areas/area.model.js";
import { gradeRankFor } from "../src/modules/routes/grade.js";
import { RouteModel } from "../src/modules/routes/route.model.js";

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create({
    binary: { version: "8.2.6" },
  });

  await connectToDatabase(mongoServer.getUri());
  await Promise.all([AreaModel.syncIndexes(), RouteModel.syncIndexes()]);
});

afterEach(async () => {
  await Promise.all([RouteModel.deleteMany({}), AreaModel.deleteMany({})]);
});

afterAll(async () => {
  await disconnectFromDatabase();
  await mongoServer.stop();
});

describe("GET /api/v1/search", () => {
  it("finds areas and routes by name without matching case", async () => {
    const area = await AreaModel.create({
      name: "Cuvier",
      type: "climbingArea",
      location: { type: "Point", coordinates: [2.63823, 48.44704] },
    });

    await RouteModel.create({
      name: "La Marie Rose",
      areaId: area._id,
      location: { type: "Point", coordinates: [2.63823, 48.44704] },
      discipline: "bouldering",
      grade: {
        system: "fontainebleau",
        value: "6A",
        rank: gradeRankFor("fontainebleau", "6A"),
      },
      styles: ["overhang"],
    });

    const response = await request(app).get("/api/v1/search").query({ q: "iE" });

    expect(response.status).toBe(200);
    expect(response.body.data.areas).toEqual([
      expect.objectContaining({ name: "Cuvier", type: "climbingArea" }),
    ]);
    expect(response.body.data.routes).toEqual([
      expect.objectContaining({
        name: "La Marie Rose",
        areaId: area._id.toString(),
      }),
    ]);
    expect(response.body.meta).toEqual({ areaCount: 1, routeCount: 1 });
  });

  it("treats regular-expression characters as ordinary search text", async () => {
    await AreaModel.create({
      name: "Sector A+",
      type: "sector",
      location: { type: "Point", coordinates: [11.2, 49.7] },
    });
    await AreaModel.create({
      name: "Sector AAA",
      type: "sector",
      location: { type: "Point", coordinates: [11.3, 49.8] },
    });

    const response = await request(app).get("/api/v1/search").query({ q: "A+" });

    expect(response.status).toBe(200);
    expect(
      response.body.data.areas.map((area: { name: string }) => area.name),
    ).toEqual(["Sector A+"]);
  });

  it("rejects search terms shorter than two characters", async () => {
    const response = await request(app).get("/api/v1/search").query({ q: "a" });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_search_query");
  });
});
