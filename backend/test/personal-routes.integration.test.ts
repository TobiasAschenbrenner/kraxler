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

import {
  InvalidAuthTokenError,
  type AuthTokenVerifier,
} from "../src/auth/auth-token.js";
import { createApp } from "../src/app.js";
import {
  connectToDatabase,
  disconnectFromDatabase,
} from "../src/database/mongo.js";
import { AreaModel } from "../src/modules/areas/area.model.js";
import { PersonalRouteModel } from "../src/modules/personal-routes/personal-route.model.js";
import { gradeRankFor } from "../src/modules/routes/grade.js";
import { RouteModel } from "../src/modules/routes/route.model.js";

let mongoServer: MongoMemoryServer;
let routeId: Types.ObjectId;

const verifyAuthToken: AuthTokenVerifier = async (token) => {
  if (token === "alice-token") {
    return { userId: "alice" };
  }

  if (token === "bob-token") {
    return { userId: "bob" };
  }

  throw new InvalidAuthTokenError();
};

const app = createApp({ verifyAuthToken });

const authenticated = (method: "get" | "put", path: string, token = "alice-token") =>
  request(app)[method](path).set("Authorization", `Bearer ${token}`);

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create({
    binary: { version: "8.2.6" },
  });

  await connectToDatabase(mongoServer.getUri());
  await Promise.all([
    AreaModel.syncIndexes(),
    RouteModel.syncIndexes(),
    PersonalRouteModel.syncIndexes(),
  ]);
});

beforeEach(async () => {
  const area = await AreaModel.create({
    name: "Bas Cuvier",
    type: "sector",
    location: { type: "Point", coordinates: [2.63823, 48.44704] },
  });
  const route = await RouteModel.create({
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

  routeId = route._id;
});

afterEach(async () => {
  await Promise.all([
    PersonalRouteModel.deleteMany({}),
    RouteModel.deleteMany({}),
    AreaModel.deleteMany({}),
  ]);
});

afterAll(async () => {
  await disconnectFromDatabase();
  await mongoServer.stop();
});

describe("personal routes authentication", () => {
  it("requires a bearer token", async () => {
    const response = await request(app).get("/api/v1/me/routes");

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("authentication_required");
  });

  it("rejects invalid tokens", async () => {
    const response = await authenticated(
      "get",
      "/api/v1/me/routes",
      "invalid-token",
    );

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("invalid_authentication_token");
  });
});

describe("PUT /api/v1/me/routes/:routeId", () => {
  it("stores saved and ticked independently while retaining the tick date", async () => {
    const firstResponse = await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: false, isTicked: true });

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.data).toEqual({
      routeId: routeId.toString(),
      isSaved: false,
      isTicked: true,
      tickedAt: expect.any(String),
    });

    const secondResponse = await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: true, isTicked: true });

    expect(secondResponse.status).toBe(200);
    expect(secondResponse.body.data.tickedAt).toBe(
      firstResponse.body.data.tickedAt,
    );
  });

  it("removes an empty personal route record", async () => {
    await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: true, isTicked: false });

    const response = await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: false, isTicked: false });

    expect(response.status).toBe(200);
    expect(await PersonalRouteModel.countDocuments()).toBe(0);
  });

  it("rejects incomplete state and missing routes", async () => {
    const invalidStateResponse = await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: true });
    const missingRouteResponse = await authenticated(
      "put",
      `/api/v1/me/routes/${new Types.ObjectId().toString()}`,
    ).send({ isSaved: true, isTicked: false });

    expect(invalidStateResponse.status).toBe(400);
    expect(invalidStateResponse.body.error.code).toBe(
      "invalid_personal_route_state",
    );
    expect(missingRouteResponse.status).toBe(404);
  });
});

describe("GET /api/v1/me/routes", () => {
  it("lists the current user's routes with their climbing details", async () => {
    await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: true, isTicked: true });

    const response = await authenticated("get", "/api/v1/me/routes");

    expect(response.status).toBe(200);
    expect(response.body.meta).toEqual({ count: 1 });
    expect(response.body.data[0]).toEqual({
      route: expect.objectContaining({
        id: routeId.toString(),
        name: "La Marie Rose",
      }),
      routeId: routeId.toString(),
      isSaved: true,
      isTicked: true,
      tickedAt: expect.any(String),
    });
  });

  it("keeps each user's library private", async () => {
    await authenticated(
      "put",
      `/api/v1/me/routes/${routeId.toString()}`,
    ).send({ isSaved: true, isTicked: false });

    const response = await authenticated(
      "get",
      "/api/v1/me/routes",
      "bob-token",
    );

    expect(response.status).toBe(200);
    expect(response.body.data).toEqual([]);
  });
});

describe("GET /api/v1/me/routes/:routeId", () => {
  it("returns a default state when the user has not saved or ticked a route", async () => {
    const response = await authenticated(
      "get",
      `/api/v1/me/routes/${routeId.toString()}`,
    );

    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({
      routeId: routeId.toString(),
      isSaved: false,
      isTicked: false,
    });
  });
});
