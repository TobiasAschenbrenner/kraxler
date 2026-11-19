import { MongoMemoryServer } from "mongodb-memory-server-core";
import request from "supertest";
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";
import { InvalidAuthTokenError } from "../src/auth/auth-token.js";
import { connectToDatabase, disconnectFromDatabase } from "../src/database/mongo.js";
import { UserProfileModel } from "../src/modules/profile/profile.model.js";

const app = createApp({ verifyAuthToken: async (token) => {
  if (token === "alice" || token === "bob") return { userId: token };
  throw new InvalidAuthTokenError();
} });
let database: MongoMemoryServer;
const profile = { displayName: "Tobias", avatarBase64: null, usesDefaultAvatar: false };

beforeAll(async () => {
  database = await MongoMemoryServer.create({ binary: { version: "8.2.6" } });
  await connectToDatabase(database.getUri());
  await UserProfileModel.syncIndexes();
});
afterEach(async () => { await UserProfileModel.deleteMany({}); });
afterAll(async () => { await disconnectFromDatabase(); await database.stop(); });

describe("user profiles", () => {
  it("requires authentication", async () => {
    expect((await request(app).get("/api/v1/me/profile")).status).toBe(401);
    expect((await request(app).put("/api/v1/me/profile").send(profile)).status).toBe(401);
  });

  it("falls back to the identity-provider profile before an override is saved", async () => {
    const response = await request(app).get("/api/v1/me/profile").auth("alice", { type: "bearer" });
    expect(response.body.data).toEqual({ displayName: null, avatarBase64: null, usesDefaultAvatar: false });
  });

  it("saves the name and avatar preference and isolates each account", async () => {
    const updated = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, displayName: "  Tobias  ", usesDefaultAvatar: true });
    expect(updated.status).toBe(200);
    expect(updated.body.data).toEqual({ ...profile, usesDefaultAvatar: true });
    const alice = await request(app).get("/api/v1/me/profile").auth("alice", { type: "bearer" });
    const bob = await request(app).get("/api/v1/me/profile").auth("bob", { type: "bearer" });
    expect(alice.body.data.displayName).toBe("Tobias");
    expect(bob.body.data.displayName).toBeNull();
    expect(alice.body.data.userId).toBeUndefined();
  });

  it.each([
    { ...profile, displayName: " " },
    { ...profile, displayName: "x".repeat(81) },
    { ...profile, email: "changed@example.com" },
    { ...profile, userId: "bob" },
    { ...profile, avatarBase64: "<svg>not an image</svg>" },
    { ...profile, avatarBase64: Buffer.alloc(49_153).toString("base64") },
  ])("rejects invalid or unsupported profile updates", async (body) => {
    const response = await request(app).put("/api/v1/me/profile")
      .auth("alice", { type: "bearer" }).send(body);
    expect(response.status).toBe(400);
    expect(await UserProfileModel.countDocuments()).toBe(0);
  });
});
