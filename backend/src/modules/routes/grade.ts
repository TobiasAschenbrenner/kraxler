export const gradeSystems = [
  "uiaa",
  "french",
  "fontainebleau",
  "vScale",
] as const;

export type GradeSystem = (typeof gradeSystems)[number];

const gradeScales: Record<GradeSystem, readonly string[]> = {
  uiaa: [
    "1",
    "2",
    "2+",
    "3-",
    "3",
    "3+",
    "4-",
    "4",
    "4+",
    "5-",
    "5",
    "5+",
    "6-",
    "6",
    "6+",
    "7-",
    "7",
    "7+",
    "8-",
    "8",
    "8+",
    "9-",
    "9",
    "9+",
    "10-",
    "10",
    "10+",
    "11-",
    "11",
    "11+",
    "12-",
    "12",
  ],
  french: [
    "1",
    "2",
    "3",
    "4a",
    "4b",
    "4c",
    "5a",
    "5b",
    "5c",
    "6a",
    "6a+",
    "6b",
    "6b+",
    "6c",
    "6c+",
    "7a",
    "7a+",
    "7b",
    "7b+",
    "7c",
    "7c+",
    "8a",
    "8a+",
    "8b",
    "8b+",
    "8c",
    "8c+",
    "9a",
    "9a+",
    "9b",
    "9b+",
    "9c",
    "9c+",
  ],
  fontainebleau: [
    "1A",
    "1B",
    "1C",
    "2A",
    "2B",
    "2C",
    "3A",
    "3B",
    "3C",
    "4A",
    "4A+",
    "4B",
    "4B+",
    "4C",
    "4C+",
    "5A",
    "5A+",
    "5B",
    "5B+",
    "5C",
    "5C+",
    "6A",
    "6A+",
    "6B",
    "6B+",
    "6C",
    "6C+",
    "7A",
    "7A+",
    "7B",
    "7B+",
    "7C",
    "7C+",
    "8A",
    "8A+",
    "8B",
    "8B+",
    "8C",
    "8C+",
    "9A",
  ],
  vScale: [
    "VB",
    "V0-",
    "V0",
    "V0+",
    "V1",
    "V2",
    "V3",
    "V4",
    "V5",
    "V6",
    "V7",
    "V8",
    "V9",
    "V10",
    "V11",
    "V12",
    "V13",
    "V14",
    "V15",
    "V16",
    "V17",
  ],
};

const normalizeGradeValue = (system: GradeSystem, value: string): string => {
  const trimmedValue = value.trim();

  if (system === "french") {
    return trimmedValue.toLowerCase();
  }

  if (system === "fontainebleau" || system === "vScale") {
    return trimmedValue.toUpperCase();
  }

  return trimmedValue;
};

export const gradeRankFor = (
  system: GradeSystem,
  value: string,
): number | undefined => {
  const normalizedValue = normalizeGradeValue(system, value);
  const index = gradeScales[system].indexOf(normalizedValue);

  return index === -1 ? undefined : index + 1;
};
