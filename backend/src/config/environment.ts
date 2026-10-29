import { z } from "zod";

const environmentSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3_000),
  MONGODB_URI: z
    .string()
    .min(1)
    .default("mongodb://127.0.0.1:27017/kraxler"),
});

const result = environmentSchema.safeParse(process.env);

if (!result.success) {
  throw new Error(`Invalid environment configuration:\n${z.prettifyError(result.error)}`);
}

export const environment = {
  mongoDbUri: result.data.MONGODB_URI,
  nodeEnv: result.data.NODE_ENV,
  port: result.data.PORT,
} as const;
