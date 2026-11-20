import { z } from "zod";

const avatarSchema = z.string().max(65_536).refine((value) => {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return false;
  const image = Buffer.from(value, "base64");
  return image.length <= 49_152 && image.length >= 4
    && image.toString("base64") === value
    && image[0] === 0xff && image[1] === 0xd8 && image[2] === 0xff
    && image.at(-2) === 0xff && image.at(-1) === 0xd9;
}, "Use a JPEG avatar smaller than 48 KB.");

export const profileSchema = z.object({
  displayName: z.string().trim().min(1).max(80),
  avatarBase64: avatarSchema.nullable(),
  usesDefaultAvatar: z.boolean(),
}).strict().refine(
  ({ avatarBase64, usesDefaultAvatar }) => avatarBase64 === null || !usesDefaultAvatar,
  "A custom photo cannot also use the default avatar.",
);

export type ProfileUpdate = z.infer<typeof profileSchema>;
