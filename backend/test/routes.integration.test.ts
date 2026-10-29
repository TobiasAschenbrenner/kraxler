import { MongoMemoryServer } from "mongodb-memory-server-core";
import { Types } from "mongoose";
import request from "supertest";
import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
} from "vitest";

import { app } from "../src/app.js";
import {
  connectToDatabase,
  disconnectFromDatabase,
} from "../src/database/mongo.js";
import { AreaModel } from "../src/modules/areas/area.model.js";
import { gradeRankFor, type GradeSystem } from "../src/modules/routes/grade.js";
import { RouteModel } from "../src/modules/routes/route.model.js";

let mongoServer: MongoMemoryServer;
let areaId: Types.ObjectId;

const requiredGradeRank = (system: GradeSystem, value: string): number => {
  const rank = gradeRankFor(system, value);

  if (rank === undefined) {
    throw new Error(`Missing test grade ${system}:${value}.`);
  }

  return rank;
};

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create({
    binary: {
      version: "8.2.6",
    },
  });

  await connectToDatabase(mongoServer.getUri());
  await Promise.all([AreaModel.syncIndexes(), RouteModel.syncIndexes()]);
});

beforeEach(async () => {
  const area = await AreaModel.create({
    name: "Main sector",
    type: "sector",
    location: { type: "Point", coordinates: [11.24633, 49.74745] },
  });

  areaId = area._id;
});

afterEach(async () => {
  await Promise.all([RouteModel.deleteMany({}), AreaModel.deleteMany({})]);
});

afterAll(async () => {
  await disconnectFromDatabase();
  await mongoServer.stop();
});

describe("GET /api/v1/areas/:areaId/routes", () => {
  it("filters routes by discipline, grade, style, length, and pitches", async () => {
    await RouteModel.create([
      {
        name: "Sonntagsspaziergang",
        areaId,
        location: { type: "Point", coordinates: [11.24633, 49.74745] },
        discipline: "sport",
        grade: {
          system: "uiaa",
          value: "6+",
          rank: requiredGradeRank("uiaa", "6+"),
        },
        styles: ["vertical", "crack"],
        lengthMeters: 20,
        pitches: 1,
      },
      {
        name: "Lebe deinen Traum",
        areaId,
        location: { type: "Point", coordinates: [11.24633, 49.74745] },
        discipline: "sport",
        grade: {
          system: "uiaa",
          value: "7+",
          rank: requiredGradeRank("uiaa", "7+"),
        },
        styles: ["overhang", "crack"],
        lengthMeters: 25,
        pitches: 1,
      },
      {
        name: "Traditional test route",
        areaId,
        location: { type: "Point", coordinates: [11.24633, 49.74745] },
        discipline: "trad",
        grade: {
          system: "uiaa",
          value: "5+",
          rank: requiredGradeRank("uiaa", "5+"),
        },
        styles: ["crack"],
        lengthMeters: 18,
        pitches: 1,
      },
    ]);

    const response = await request(app)
      .get(`/api/v1/areas/${areaId.toString()}/routes`)
      .query({
        discipline: "sport",
        gradeSystem: "uiaa",
        gradeMin: "6",
        gradeMax: "7",
        style: "crack",
        lengthMin: "15",
        lengthMax: "22",
        pitchesMin: "1",
        pitchesMax: "1",
      });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      data: [
        {
          id: expect.any(String),
          areaId: areaId.toString(),
          name: "Sonntagsspaziergang",
          location: {
            type: "Point",
            coordinates: [11.24633, 49.74745],
          },
          discipline: "sport",
          grade: {
            system: "uiaa",
            value: "6+",
            rank: requiredGradeRank("uiaa", "6+"),
          },
          styles: ["vertical", "crack"],
          lengthMeters: 20,
          pitches: 1,
        },
      ],
      meta: { count: 1 },
    });
  });

  it("rejects grade values without a grading system", async () => {
    const response = await request(app)
      .get(`/api/v1/areas/${areaId.toString()}/routes`)
      .query({ gradeMin: "6a" });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_route_filters");
  });

  it("rejects an invalid area ID", async () => {
    const response = await request(app).get(
      "/api/v1/areas/not-an-id/routes",
    );

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_area_id");
  });

  it("reports a missing area", async () => {
    const response = await request(app).get(
      `/api/v1/areas/${new Types.ObjectId().toString()}/routes`,
    );

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe("area_not_found");
  });
});

describe("GET /api/v1/routes/:routeId", () => {
  it("returns the complete route details", async () => {
    const route = await RouteModel.create({
      name: "Lebe deinen Traum",
      areaId,
      location: { type: "Point", coordinates: [11.24633, 49.74745] },
      discipline: "sport",
      grade: {
        system: "uiaa",
        value: "7+",
        rank: requiredGradeRank("uiaa", "7+"),
      },
      styles: ["vertical", "overhang", "crack"],
      lengthMeters: 25,
      pitches: 1,
      description: "Varied wall climbing with cracks and an overhanging section.",
    });

    const response = await request(app).get(
      `/api/v1/routes/${route._id.toString()}`,
    );

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      data: {
        id: route._id.toString(),
        areaId: areaId.toString(),
        name: "Lebe deinen Traum",
        location: {
          type: "Point",
          coordinates: [11.24633, 49.74745],
        },
        discipline: "sport",
        grade: {
          system: "uiaa",
          value: "7+",
          rank: requiredGradeRank("uiaa", "7+"),
        },
        styles: ["vertical", "overhang", "crack"],
        lengthMeters: 25,
        pitches: 1,
        description:
          "Varied wall climbing with cracks and an overhanging section.",
      },
    });
  });

  it("reports a missing route", async () => {
    const response = await request(app).get(
      `/api/v1/routes/${new Types.ObjectId().toString()}`,
    );

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe("climbing_route_not_found");
  });
});
