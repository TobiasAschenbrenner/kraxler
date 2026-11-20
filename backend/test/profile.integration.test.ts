import { MongoMemoryServer } from "mongodb-memory-server-core";
import request from "supertest";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

import { createApp } from "../src/app.js";
import { InvalidAuthTokenError } from "../src/auth/auth-token.js";
import { connectToDatabase, disconnectFromDatabase } from "../src/database/mongo.js";
import { UserProfileModel } from "../src/modules/profile/profile.model.js";
import { ApiError } from "../src/errors/api-error.js";

const uploadedPhoto = {
  url: "https://res.cloudinary.com/kraxler/image/upload/v1/kraxler/test/avatars/photo.jpg",
  publicId: "kraxler/test/avatars/photo",
};
const avatars = { upload: vi.fn(), remove: vi.fn() };

const app = createApp({ verifyAuthToken: async (token) => {
  if (token === "alice" || token === "bob") return { userId: token };
  throw new InvalidAuthTokenError();
}, avatarStorage: avatars });
let database: MongoMemoryServer;
const profile = { displayName: "Tobias", avatarBase64: null, usesDefaultAvatar: false };
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xd9]).toString("base64");
beforeEach(() => {
  avatars.upload.mockReset().mockResolvedValue(uploadedPhoto);
  avatars.remove.mockReset().mockResolvedValue(undefined);
});

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
    expect(response.body.data).toEqual({ displayName: null, avatarBase64: null, avatarUrl: null, usesDefaultAvatar: false });
  });

  it("saves the name and avatar preference and isolates each account", async () => {
    const updated = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, displayName: "  Tobias  ", usesDefaultAvatar: true });
    expect(updated.status).toBe(200);
    expect(updated.body.data).toEqual({ ...profile, avatarUrl: null, usesDefaultAvatar: true });
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
    { ...profile, avatarUrl: "https://example.com/avatar.jpg" },
    { ...profile, avatarPublicId: "another-user/photo" },
    { ...profile, avatarBase64: "<svg>not an image</svg>" },
    { ...profile, avatarBase64: Buffer.alloc(49_153).toString("base64") },
  ])("rejects invalid or unsupported profile updates", async (body) => {
    const response = await request(app).put("/api/v1/me/profile")
      .auth("alice", { type: "bearer" }).send(body);
    expect(response.status).toBe(400);
    expect(await UserProfileModel.countDocuments()).toBe(0);
  });

  it("uploads custom photos to Cloudinary and stores only their references", async () => {
    const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, avatarBase64: jpeg });
    expect(response.status).toBe(200);
    expect(avatars.upload).toHaveBeenCalledWith(Buffer.from(jpeg, "base64"));
    expect(response.body.data.avatarUrl).toBe(uploadedPhoto.url);
    expect(response.body.data.avatarBase64).toBeNull();
    expect(response.body.data.avatarPublicId).toBeUndefined();
    const stored = await UserProfileModel.findOne({ userId: "alice" }).lean();
    expect(stored?.avatarUrl).toBe(uploadedPhoto.url);
    expect(stored?.avatarPublicId).toBe(uploadedPhoto.publicId);
    expect(stored?.avatarBase64).toBeNull();
    const bob = await request(app).get("/api/v1/me/profile").auth("bob", { type: "bearer" });
    expect(bob.body.data.avatarUrl).toBeNull();
  });

  it("keeps the existing Cloudinary photo when only the name changes", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile, avatarUrl: uploadedPhoto.url, avatarPublicId: uploadedPhoto.publicId });
    const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, displayName: "Alice" });
    expect(response.status).toBe(200);
    expect(response.body.data.avatarUrl).toBe(uploadedPhoto.url);
    expect(avatars.upload).not.toHaveBeenCalled();
    expect(avatars.remove).not.toHaveBeenCalled();
  });

  it("replaces photos and deletes the previous Cloudinary asset", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile, avatarUrl: "https://res.cloudinary.com/kraxler/old.jpg", avatarPublicId: "kraxler/test/avatars/old" });
    const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, avatarBase64: jpeg });
    expect(response.status).toBe(200);
    expect(response.body.data.avatarUrl).toBe(uploadedPhoto.url);
    expect(avatars.remove).toHaveBeenCalledExactlyOnceWith("kraxler/test/avatars/old");
  });

  it("removes the Cloudinary photo when the default avatar is selected", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile, avatarUrl: uploadedPhoto.url, avatarPublicId: uploadedPhoto.publicId });
    const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, usesDefaultAvatar: true });
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({ ...profile, avatarUrl: null, usesDefaultAvatar: true });
    expect((await UserProfileModel.findOne({ userId: "alice" }).lean())?.avatarPublicId).toBeNull();
    expect(avatars.remove).toHaveBeenCalledExactlyOnceWith(uploadedPhoto.publicId);
  });

  it("keeps the current photo and name if an upload fails", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile, avatarUrl: uploadedPhoto.url, avatarPublicId: uploadedPhoto.publicId });
    avatars.upload.mockRejectedValueOnce(new ApiError(503, "avatar_storage_unavailable", "Couldn’t save photo. Try again."));
    const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, displayName: "Changed", avatarBase64: jpeg });
    expect(response.status).toBe(503);
    const stored = await UserProfileModel.findOne({ userId: "alice" }).lean();
    expect(stored?.displayName).toBe("Tobias");
    expect(stored?.avatarUrl).toBe(uploadedPhoto.url);
    expect(avatars.remove).not.toHaveBeenCalled();
  });

  it("cleans up an uploaded image if the database write fails", async () => {
    const write = vi.spyOn(UserProfileModel, "findOneAndUpdate").mockImplementationOnce(() => { throw new Error("Database unavailable"); });
    try {
      const response = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
        .send({ ...profile, avatarBase64: jpeg });
      expect(response.status).toBe(500);
      expect(avatars.remove).toHaveBeenCalledExactlyOnceWith(uploadedPhoto.publicId);
      expect(await UserProfileModel.countDocuments()).toBe(0);
    } finally { write.mockRestore(); }
  });

  it("keeps legacy photos readable and migrates them when saved", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile, avatarBase64: jpeg });
    const before = await request(app).get("/api/v1/me/profile").auth("alice", { type: "bearer" });
    expect(before.body.data.avatarBase64).toBe(jpeg);
    const migrated = await request(app).put("/api/v1/me/profile").auth("alice", { type: "bearer" })
      .send({ ...profile, avatarBase64: jpeg });
    expect(migrated.status).toBe(200);
    expect(migrated.body.data.avatarBase64).toBeNull();
    expect(migrated.body.data.avatarUrl).toBe(uploadedPhoto.url);
  });

  it("rejects a concurrent replacement and cleans up its unused upload", async () => {
    await UserProfileModel.create({ userId: "alice", ...profile });
    let release: () => void = () => {};
    const bothUploaded = new Promise<void>((resolve) => { release = resolve; });
    let count = 0;
    avatars.upload.mockImplementation(async () => {
      const id = ++count;
      if (count === 2) release();
      await bothUploaded;
      return { url: `${uploadedPhoto.url}?test=${id}`, publicId: `photo-${id}` };
    });
    const results = await Promise.all(["First", "Second"].map((displayName) => request(app)
      .put("/api/v1/me/profile").auth("alice", { type: "bearer" }).send({ ...profile, displayName, avatarBase64: jpeg })));
    expect(results.map((result) => result.status).sort()).toEqual([200, 409]);
    const stored = await UserProfileModel.findOne({ userId: "alice" }).lean();
    expect(avatars.remove).toHaveBeenCalledTimes(1);
    expect(avatars.remove.mock.calls[0]![0]).not.toBe(stored?.avatarPublicId);
  });
});
