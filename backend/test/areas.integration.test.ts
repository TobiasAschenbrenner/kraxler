import { MongoMemoryServer } from "mongodb-memory-server-core";
import request from "supertest";
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";

import { app } from "../src/app.js";
import {
  connectToDatabase,
  disconnectFromDatabase,
} from "../src/database/mongo.js";
import { AreaModel } from "../src/modules/areas/area.model.js";

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create({
    binary: {
      version: "8.2.6",
    },
  });

  await connectToDatabase(mongoServer.getUri());
  await AreaModel.syncIndexes();
});

afterEach(async () => {
  await AreaModel.deleteMany({});
});

afterAll(async () => {
  await disconnectFromDatabase();
  await mongoServer.stop();
});

describe("GET /api/v1/areas", () => {
  it("returns only areas inside the requested map bounds", async () => {
    await AreaModel.create([
      {
        name: "Frankenjura",
        type: "climbingArea",
        location: { type: "Point", coordinates: [11.35, 49.75] },
      },
      {
        name: "Fontainebleau",
        type: "climbingArea",
        location: { type: "Point", coordinates: [2.66, 48.4] },
      },
      {
        name: "Yosemite Valley",
        type: "climbingArea",
        location: { type: "Point", coordinates: [-119.6, 37.74] },
      },
    ]);

    const response = await request(app)
      .get("/api/v1/areas")
      .query({ bbox: "5,47,15,55" });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      data: [
        {
          id: expect.any(String),
          name: "Frankenjura",
          type: "climbingArea",
          location: {
            type: "Point",
            coordinates: [11.35, 49.75],
          },
        },
      ],
      meta: {
        count: 1,
      },
    });
  });

  it("rejects a missing bounding box", async () => {
    const response = await request(app).get("/api/v1/areas");

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_bounding_box");
  });

  it("rejects an invalid bounding box", async () => {
    const response = await request(app)
      .get("/api/v1/areas")
      .query({ bbox: "15,55,5,47" });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_bounding_box");
  });
});

describe("GET /ready", () => {
  it("reports the connected database as ready", async () => {
    const response = await request(app).get("/ready");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      status: "ready",
      dependencies: {
        database: "up",
      },
    });
  });
});
