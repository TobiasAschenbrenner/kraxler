import { randomUUID } from "node:crypto";
import type { Writable } from "node:stream";
import { v2 as cloudinary, type UploadApiOptions } from "cloudinary";

import { readCloudinaryConfig, type CloudinaryConfig } from "../../config/cloudinary.js";
import { ApiError } from "../../errors/api-error.js";

export interface StoredAvatar {
  url: string;
  publicId: string;
}

export interface AvatarStorage {
  upload(image: Buffer): Promise<StoredAvatar>;
  remove(publicId: string): Promise<void>;
}

export interface CloudinaryTransport {
  uploadStream(options: UploadApiOptions, callback: (error?: unknown, result?: unknown) => void): Writable;
  remove(publicId: string, options: UploadApiOptions): Promise<unknown>;
}

const transport: CloudinaryTransport = {
  uploadStream: (options, callback) => cloudinary.uploader.upload_stream(options, callback),
  remove: (publicId, options) => cloudinary.uploader.destroy(publicId, options),
};
const unavailable = () => new ApiError(503, "avatar_storage_unavailable", "Couldn’t save photo. Try again.");

export const createAvatarStorage = (
  config: CloudinaryConfig | undefined = readCloudinaryConfig(),
  remote: CloudinaryTransport = transport,
): AvatarStorage => {
  const credentials: UploadApiOptions = config ? {
    cloud_name: config.cloudName, api_key: config.apiKey, api_secret: config.apiSecret,
    secure: true, timeout: 20_000,
  } : {};
  const requireOwnedId = (publicId: string): void => {
    if (!config) throw unavailable();
    const suffix = publicId.startsWith(`${config.avatarFolder}/`)
      ? publicId.slice(config.avatarFolder.length + 1) : "";
    if (!/^[a-f\d]{8}-[a-f\d]{4}-4[a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/.test(suffix)) {
      throw new Error("Refusing to remove an image outside Kraxler’s avatar folder.");
    }
  };
  return {
    async upload(image) {
      if (!config) throw unavailable();
      if (image.length < 4 || image.length > 49_152) {
        throw new ApiError(400, "invalid_avatar", "Use a JPEG photo smaller than 48 KB.");
      }
      const publicId = `${config.avatarFolder}/${randomUUID()}`;
      return new Promise<StoredAvatar>((resolve, reject) => {
        let settled = false;
        let stream: Writable | undefined;
        const deadline = setTimeout(() => {
          finish(unavailable());
          stream?.destroy();
        }, 20_000);
        function finish(error?: unknown, result?: unknown): void {
          if (settled) return;
          settled = true;
          clearTimeout(deadline);
          if (error || !result || typeof result !== "object") { reject(unavailable()); return; }
          const data = result as Record<string, unknown>;
          try {
            const url = new URL(String(data.secure_url));
            if (data.public_id !== publicId || data.resource_type !== "image" || data.type !== "upload"
                || data.format !== "jpg" || data.width !== 256 || data.height !== 256
                || url.origin !== "https://res.cloudinary.com" || url.username || url.password
                || url.search || url.hash || url.href.length > 2048
                || !url.pathname.startsWith(`/${config!.cloudName}/image/upload/`)
                || !url.pathname.endsWith(`/${publicId}.jpg`)) throw unavailable();
            resolve({ publicId, url: url.href });
          } catch { reject(unavailable()); }
        }
        try {
          stream = remote.uploadStream({
            ...credentials, public_id: publicId, asset_folder: config.avatarFolder,
            resource_type: "image", type: "upload", allowed_formats: ["jpg"],
            overwrite: false, use_filename: false,
            transformation: [{ width: 256, height: 256, crop: "fill", flags: "force_strip" }],
          }, finish);
          stream.once("error", finish);
          if (!settled) stream.end(image);
        } catch { finish(unavailable()); }
      });
    },
    async remove(publicId) {
      requireOwnedId(publicId);
      try {
        const result = await remote.remove(publicId, {
          ...credentials, resource_type: "image", type: "upload", invalidate: true,
        }) as { result?: string };
        if (!result || !["ok", "not found"].includes(result.result ?? "")) throw unavailable();
      } catch { throw unavailable(); }
    },
  };
};
