import { z } from "zod";

import { gradeRankFor, gradeSystems, type GradeSystem } from "./grade.js";
import {
  climbingStyles,
  routeDisciplines,
  type ClimbingStyle,
  type RouteDiscipline,
} from "./route.model.js";

export interface RouteFilters {
  discipline?: RouteDiscipline;
  gradeSystem?: GradeSystem;
  gradeMinRank?: number;
  gradeMaxRank?: number;
  styles?: ClimbingStyle[];
  lengthMin?: number;
  lengthMax?: number;
  pitchesMin?: number;
  pitchesMax?: number;
}

const optionalPositiveNumber = z.coerce.number().positive().optional();
const optionalPositiveInteger = z.coerce.number().int().positive().optional();

const routeQuerySchema = z.object({
  discipline: z.enum(routeDisciplines).optional(),
  gradeSystem: z.enum(gradeSystems).optional(),
  gradeMin: z.string().trim().min(1).optional(),
  gradeMax: z.string().trim().min(1).optional(),
  style: z
    .string()
    .transform((value) => value.split(",").map((style) => style.trim()))
    .pipe(z.array(z.enum(climbingStyles)).min(1))
    .optional(),
  lengthMin: optionalPositiveNumber,
  lengthMax: optionalPositiveNumber,
  pitchesMin: optionalPositiveInteger,
  pitchesMax: optionalPositiveInteger,
});

export const parseRouteFilters = (
  query: unknown,
): { success: true; filters: RouteFilters } | { success: false } => {
  const result = routeQuerySchema.safeParse(query);

  if (!result.success) {
    return { success: false };
  }

  const {
    discipline,
    gradeMax,
    gradeMin,
    gradeSystem,
    lengthMax,
    lengthMin,
    pitchesMax,
    pitchesMin,
    style,
  } = result.data;

  if (
    (lengthMin !== undefined &&
      lengthMax !== undefined &&
      lengthMin > lengthMax) ||
    (pitchesMin !== undefined &&
      pitchesMax !== undefined &&
      pitchesMin > pitchesMax)
  ) {
    return { success: false };
  }

  if ((gradeMin !== undefined || gradeMax !== undefined) && !gradeSystem) {
    return { success: false };
  }

  const gradeMinRank =
    gradeSystem !== undefined && gradeMin !== undefined
      ? gradeRankFor(gradeSystem, gradeMin)
      : undefined;
  const gradeMaxRank =
    gradeSystem !== undefined && gradeMax !== undefined
      ? gradeRankFor(gradeSystem, gradeMax)
      : undefined;

  if (
    (gradeMin !== undefined && gradeMinRank === undefined) ||
    (gradeMax !== undefined && gradeMaxRank === undefined) ||
    (gradeMinRank !== undefined &&
      gradeMaxRank !== undefined &&
      gradeMinRank > gradeMaxRank)
  ) {
    return { success: false };
  }

  return {
    success: true,
    filters: {
      ...(discipline === undefined ? {} : { discipline }),
      ...(gradeSystem === undefined ? {} : { gradeSystem }),
      ...(gradeMinRank === undefined ? {} : { gradeMinRank }),
      ...(gradeMaxRank === undefined ? {} : { gradeMaxRank }),
      ...(style === undefined ? {} : { styles: style }),
      ...(lengthMin === undefined ? {} : { lengthMin }),
      ...(lengthMax === undefined ? {} : { lengthMax }),
      ...(pitchesMin === undefined ? {} : { pitchesMin }),
      ...(pitchesMax === undefined ? {} : { pitchesMax }),
    },
  };
};
