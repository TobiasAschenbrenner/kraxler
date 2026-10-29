import { z } from "zod";

const environmentSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3_000),
});

const result = environmentSchema.safeParse(process.env);

if (!result.success) {
  throw new Error(`Invalid environment configuration:\n${z.prettifyError(result.error)}`);
}

export const environment = {
  nodeEnv: result.data.NODE_ENV,
  port: result.data.PORT,
} as const;
