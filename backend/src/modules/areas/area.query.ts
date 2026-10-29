import { z } from "zod";

export type BoundingBox = readonly [
  west: number,
  south: number,
  east: number,
  north: number,
];

const coordinateSchema = z
  .string()
  .trim()
  .min(1)
  .transform(Number)
  .pipe(z.number().finite());

const boundingBoxSchema = z
  .string()
  .transform((value) => value.split(","))
  .pipe(
    z.tuple([
      coordinateSchema,
      coordinateSchema,
      coordinateSchema,
      coordinateSchema,
    ]),
  )
  .superRefine(([west, south, east, north], context) => {
    if (
      west < -180 ||
      west > 180 ||
      east < -180 ||
      east > 180 ||
      south < -90 ||
      south > 90 ||
      north < -90 ||
      north > 90
    ) {
      context.addIssue({
        code: "custom",
        message: "bbox coordinates are outside the valid geographic range.",
      });
    }

    if (west >= east || south >= north) {
      context.addIssue({
        code: "custom",
        message: "bbox west/south values must be smaller than east/north.",
      });
    }
  });

const areaQuerySchema = z.object({
  bbox: boundingBoxSchema,
});

export const parseAreaQuery = (
  query: unknown,
): { success: true; boundingBox: BoundingBox } | { success: false } => {
  const result = areaQuerySchema.safeParse(query);

  if (!result.success) {
    return { success: false };
  }

  return { success: true, boundingBox: result.data.bbox };
};
