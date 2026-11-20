import { Writable } from "node:stream";
import { describe, expect, it, vi } from "vitest";

import { readCloudinaryConfig } from "../src/config/cloudinary.js";
import { createAvatarStorage, type CloudinaryTransport } from "../src/modules/profile/avatar-storage.js";

const config = { cloudName: "kraxler-test", apiKey: "12345", apiSecret: "test-only-secret", avatarFolder: "kraxler/test/avatars" };
const image = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

describe("Cloudinary avatar storage", () => {
  it("accepts only complete server-side credentials", () => {
    expect(readCloudinaryConfig({})).toBeUndefined();
    expect(() => readCloudinaryConfig({ CLOUDINARY_CLOUD_NAME: "kraxler" })).toThrow();
    expect(() => readCloudinaryConfig({ CLOUDINARY_CLOUD_NAME: "bad/name", CLOUDINARY_API_KEY: "123", CLOUDINARY_API_SECRET: "secret" })).toThrow();
  });

  it("uploads bounded JPEGs with random IDs, signed credentials and stripped metadata", async () => {
    const chunks: Buffer[] = [];
    const upload = vi.fn<CloudinaryTransport["uploadStream"]>((options, callback) => new Writable({
      write(chunk, _encoding, done) { chunks.push(Buffer.from(chunk)); done(); },
      final(done) {
        callback(undefined, {
          public_id: options.public_id, secure_url: `https://res.cloudinary.com/${config.cloudName}/image/upload/v123/${options.public_id}.jpg`,
          resource_type: "image", type: "upload", format: "jpg", width: 256, height: 256,
        });
        done();
      },
    }));
    const storage = createAvatarStorage(config, { uploadStream: upload, remove: vi.fn() });
    const stored = await storage.upload(image);
    expect(Buffer.concat(chunks)).toEqual(image);
    expect(stored.publicId).toMatch(/^kraxler\/test\/avatars\/[a-f\d-]{36}$/);
    expect(upload.mock.calls[0]![0]).toMatchObject({
      api_secret: config.apiSecret, allowed_formats: ["jpg"], overwrite: false,
      transformation: [{ width: 256, height: 256, crop: "fill", flags: "force_strip" }],
    });
    expect(stored.url).not.toContain(config.apiSecret);
  });

  it("rejects unexpectedly hosted images and masks Cloudinary errors", async () => {
    const storage = createAvatarStorage(config, {
      uploadStream: (_options, callback) => new Writable({ final(done) { callback(undefined, { secure_url: "https://example.com/photo.jpg" }); done(); } }),
      remove: vi.fn(),
    });
    await expect(storage.upload(image)).rejects.toMatchObject({ statusCode: 503, code: "avatar_storage_unavailable" });
    await expect(createAvatarStorage(config, {
      uploadStream: () => { throw new Error(config.apiSecret); }, remove: vi.fn(),
    }).upload(image)).rejects.not.toThrow(config.apiSecret);
  });

  it("only removes images from Kraxler’s avatar folder and invalidates the CDN copy", async () => {
    const remove = vi.fn().mockResolvedValue({ result: "ok" });
    const storage = createAvatarStorage(config, { uploadStream: vi.fn(), remove });
    const publicId = `${config.avatarFolder}/9870c770-5b5e-4671-b91b-284491b6d111`;
    await storage.remove(publicId);
    expect(remove).toHaveBeenCalledWith(publicId, expect.objectContaining({ invalidate: true, resource_type: "image" }));
    await expect(storage.remove("kraxler/topos/photo")).rejects.toThrow();
    expect(remove).toHaveBeenCalledTimes(1);
  });
});
