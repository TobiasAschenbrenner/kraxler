import { environment } from "./environment.js";

export interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
  avatarFolder: string;
}

export const readCloudinaryConfig = (
  values: NodeJS.ProcessEnv = process.env,
): CloudinaryConfig | undefined => {
  const cloudName = values.CLOUDINARY_CLOUD_NAME?.trim() ?? "";
  const apiKey = values.CLOUDINARY_API_KEY?.trim() ?? "";
  const apiSecret = values.CLOUDINARY_API_SECRET ?? "";
  if (!cloudName && !apiKey && !apiSecret) return undefined;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(cloudName)
      || !/^\d{1,64}$/.test(apiKey)
      || !/^[\x21-\x7e]{1,256}$/.test(apiSecret)) {
    throw new Error("Set valid CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET together.");
  }
  return { cloudName, apiKey, apiSecret, avatarFolder: `kraxler/${environment.nodeEnv}/avatars` };
};
