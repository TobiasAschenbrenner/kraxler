import { z } from "zod";

const searchQuerySchema = z.object({
  q: z.string().trim().min(2).max(80),
});

export const parseSearchQuery = (
  query: unknown,
): { success: true; searchTerm: string } | { success: false } => {
  const result = searchQuerySchema.safeParse(query);

  if (!result.success) {
    return { success: false };
  }

  return { success: true, searchTerm: result.data.q };
};
