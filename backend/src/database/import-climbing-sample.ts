import "dotenv/config";

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Types } from "mongoose";

import { AreaModel, type Area, type AreaType } from "../modules/areas/area.model.js";
import { gradeRankFor } from "../modules/routes/grade.js";
import { RouteModel, type ClimbingRoute, type RouteTopo } from "../modules/routes/route.model.js";
import { connectToDatabase, disconnectFromDatabase } from "./mongo.js";

// Without --apply it validates the file and does not connect to MongoDB.
type SampleArea = Omit<Area, "parentAreaId"> & {
  _id: string;
  parentAreaId?: string;
};
type SampleRoute = Omit<ClimbingRoute, "areaId"> & {
  _id: string;
  areaId: string;
};
export interface Dataset {
  formatVersion: number;
  areas: SampleArea[];
  routes: SampleRoute[];
}

interface TopoMediaManifest {
  formatVersion: number;
  topos: {
    id: string;
    url: string | null;
    cloudinaryPublicId?: string | null;
    pixelWidth: number;
    pixelHeight: number;
    routeNumberMappings: { routeId: string; number: string }[];
  }[];
}

const objectIdPattern = /^[a-f\d]{24}$/i;
const assert = (condition: unknown, message: string): void => {
  if (!condition) throw new Error(message);
};

const distanceMeters = (a: number[], b: number[]): number => {
  const radians = (degrees: number): number => degrees * Math.PI / 180;
  const latitude = radians(b[1]! - a[1]!);
  const longitude = radians(b[0]! - a[0]!);
  const h = Math.sin(latitude / 2) ** 2
    + Math.cos(radians(a[1]!)) * Math.cos(radians(b[1]!)) * Math.sin(longitude / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
};

export const attachTopoMedia = (data: Dataset, media: TopoMediaManifest): Dataset => {
  assert(media.formatVersion === 1 && Array.isArray(media.topos), "Invalid topo media manifest.");
  const routes = new Map(data.routes.map((route) => [route._id, route]));
  const topos = new Map<string, RouteTopo[]>();
  const mediaIds = new Set<string>();
  for (const item of media.topos) {
    assert(!mediaIds.has(item.id), `Duplicate topo: ${item.id}`);
    mediaIds.add(item.id);
    const mappedRoutes = new Set<string>();
    for (const mapping of item.routeNumberMappings) {
      assert(routes.has(mapping.routeId), `Topo ${item.id} references an unknown route.`);
      assert(!mappedRoutes.has(mapping.routeId), `Duplicate route mapping in topo ${item.id}.`);
      mappedRoutes.add(mapping.routeId);
      if (item.url === null) continue;
      assert(typeof item.url === "string" && item.url.length > 0, `Missing URL for topo ${item.id}.`);
      const topo: RouteTopo = {
        id: item.id, imageUrl: item.url, routeNumber: mapping.number,
        pixelWidth: item.pixelWidth, pixelHeight: item.pixelHeight,
        ...(item.cloudinaryPublicId ? { cloudinaryPublicId: item.cloudinaryPublicId } : {}),
      };
      topos.set(mapping.routeId, [...(topos.get(mapping.routeId) ?? []), topo]);
    }
  }
  return {
    ...data,
    routes: data.routes.map((route) => {
      const images = topos.get(route._id);
      return images ? { ...route, topos: images } : route;
    }),
  };
};

export const validateDataset = async (data: Dataset): Promise<void> => {
  assert(data.formatVersion === 1, "Unsupported sample format.");
  assert(Array.isArray(data.areas) && Array.isArray(data.routes), "Expected area and route arrays.");
  assert(data.areas.length > 0 && data.routes.length > 0, "Sample is empty.");
  const areaIds = new Set<string>();
  const routeIds = new Set<string>();
  const routeNames = new Set<string>();
  const areaNames = new Set<string>();
  for (const area of data.areas) {
    assert(objectIdPattern.test(area._id), `Invalid area ID: ${area._id}`);
    assert(!areaIds.has(area._id), `Duplicate area ID: ${area._id}`);
    areaIds.add(area._id);
    const key = JSON.stringify([area.parentAreaId ?? null, area.type, area.name]);
    assert(!areaNames.has(key), `Duplicate area: ${area.name}`);
    areaNames.add(key);
    await new AreaModel({
      ...area,
      _id: new Types.ObjectId(area._id),
      ...(area.parentAreaId ? { parentAreaId: new Types.ObjectId(area.parentAreaId) } : {}),
    }).validate();
  }
  const areasById = new Map(data.areas.map((area) => [area._id, area]));
  for (const area of data.areas) {
    if (area.parentAreaId) assert(areaIds.has(area.parentAreaId), `Missing parent for ${area.name}`);
    const visited = new Set<string>();
    let current: SampleArea | undefined = area;
    while (current) {
      assert(!visited.has(current._id), `Area hierarchy cycle at ${area.name}`);
      visited.add(current._id);
      current = current.parentAreaId ? areasById.get(current.parentAreaId) : undefined;
    }
  }
  for (const route of data.routes) {
    assert(objectIdPattern.test(route._id), `Invalid route ID: ${route._id}`);
    assert(!routeIds.has(route._id), `Duplicate route ID: ${route._id}`);
    routeIds.add(route._id);
    assert(areaIds.has(route.areaId), `Missing area for ${route.name}`);
    const key = JSON.stringify([route.areaId, route.name]);
    assert(!routeNames.has(key), `Duplicate route name within area: ${route.name}`);
    routeNames.add(key);
    assert(gradeRankFor(route.grade.system, route.grade.value) === route.grade.rank,
      `Unsupported grade or mismatched rank for ${route.name}`);
    const boulderGrade = route.grade.system === "fontainebleau" || route.grade.system === "vScale";
    assert((route.discipline === "bouldering") === boulderGrade,
      `Grade system conflicts with discipline for ${route.name}`);
    await new RouteModel({
      ...route,
      _id: new Types.ObjectId(route._id),
      areaId: new Types.ObjectId(route.areaId),
    }).validate();
  }
};

export const importConnectedDataset = async (data: Dataset) => {
  await validateDataset(data);
  const areaIdMap = new Map<string, Types.ObjectId>();
  const routeIdMap = new Map<string, string>();
    const pending = [...data.areas];
    while (pending.length > 0) {
      const index = pending.findIndex((area) => !area.parentAreaId || areaIdMap.has(area.parentAreaId));
      assert(index >= 0, "The sample hierarchy could not be resolved.");
      const area = pending.splice(index, 1)[0]!;
      const parentAreaId = area.parentAreaId ? areaIdMap.get(area.parentAreaId) : undefined;
      let query: Record<string, unknown> = {
        name: area.name, type: area.type as AreaType, parentAreaId: parentAreaId ?? null,
      };
      let matches = await AreaModel.find(query).limit(2).exec();
      assert(matches.length <= 1, `More than one matching area exists: ${area.name}`);
      // Existing seed crags such as Röthelfels and Cuvier already have region parents.
      // Reuse a unique nearby crag while preserving that existing parent.
      if (!parentAreaId && matches.length === 0) {
        const candidates = await AreaModel.find({ name: area.name, type: area.type }).limit(2).exec();
        assert(candidates.length <= 1, `Ambiguous existing area: ${area.name}. Resolve it before importing.`);
        const candidate = candidates[0];
        if (candidate) {
          assert(distanceMeters(candidate.location.coordinates, area.location.coordinates) <= 2500,
            `Existing ${area.name} is more than 2.5 km from the sample point. Review before merging.`);
          matches = candidates;
        }
      }
      if (matches[0]) query = { _id: matches[0]._id };
      const saved = await AreaModel.findOneAndUpdate(query, {
        $set: {
          name: area.name,
          type: area.type,
          location: area.location,
          ...(parentAreaId ? { parentAreaId } : {}),
        },
        $setOnInsert: { _id: new Types.ObjectId(area._id) },
      }, { upsert: true, returnDocument: "after", runValidators: true }).exec();
      assert(saved, `Could not save area: ${area.name}`);
      areaIdMap.set(area._id, saved!._id);
    }
    for (const route of data.routes) {
      const { _id, areaId: sampleAreaId, ...fields } = route;
      const areaId = areaIdMap.get(sampleAreaId)!;
      const { styles, ...knownFields } = fields;
      const saved = await RouteModel.findOneAndUpdate({ areaId, name: route.name }, {
        $set: { ...knownFields, areaId, ...(styles.length ? { styles } : {}) },
        $setOnInsert: { _id: new Types.ObjectId(_id), ...(!styles.length ? { styles: [] } : {}) },
      }, { upsert: true, returnDocument: "after", runValidators: true }).exec();
      assert(saved, `Could not save route: ${route.name}`);
      routeIdMap.set(_id, saved!._id.toString());
    }
    return {
      areaIds: Object.fromEntries([...areaIdMap].map(([sample, actual]) => [sample, actual.toString()])),
      routeIds: Object.fromEntries(routeIdMap),
    };
};

const run = async (): Promise<void> => {
  const args = process.argv.slice(2);
  const option = (key: string): string | undefined => {
    const index = args.indexOf(key);
    if (index === -1) return undefined;
    const value = args[index + 1];
    assert(value && !value.startsWith("--"), `Provide a value for ${key}.`);
    return value;
  };
  const path = option("--data");
  assert(path, "Use --data /absolute/path/sample-data.json. Add --apply to import.");
  let data = JSON.parse(await readFile(resolve(path!), "utf8")) as Dataset;
  const mediaPath = option("--media");
  if (mediaPath) {
    const media = JSON.parse(await readFile(resolve(mediaPath), "utf8")) as TopoMediaManifest;
    data = attachTopoMedia(data, media);
    console.info(`Topos ready: ${media.topos.filter((topo) => topo.url !== null).length}/${media.topos.length}.`);
  }
  await validateDataset(data);
  console.info(`Validated ${data.areas.length} area documents and ${data.routes.length} routes.`);
  if (!args.includes("--apply")) {
    console.info("Validation complete. No database connection was made.");
    return;
  }
  const backupPath = option("--backup");
  assert(backupPath, "Use --backup /absolute/path/backup.json with --apply.");
  const { environment } = await import("../config/environment.js");
  await connectToDatabase(environment.mongoDbUri);
  try {
    const [areas, routes] = await Promise.all([AreaModel.find().lean().exec(), RouteModel.find().lean().exec()]);
    await mkdir(dirname(resolve(backupPath!)), { recursive: true });
    await writeFile(resolve(backupPath!), JSON.stringify({ createdAt: new Date().toISOString(), areas, routes }, null, 2), { flag: "wx", mode: 0o600 });
    const result = await importConnectedDataset(data);
    const idMapPath = option("--id-map");
    if (idMapPath) {
      await mkdir(dirname(resolve(idMapPath)), { recursive: true });
      await writeFile(resolve(idMapPath), JSON.stringify(result, null, 2) + "\n");
    } else {
      console.info(JSON.stringify(result, null, 2));
    }
    console.info(`Imported ${data.routes.length} sample routes. Existing unrelated records were retained.`);
  } finally {
    await disconnectFromDatabase();
  }
};

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  run().catch((error: unknown) => {
    console.error("Climbing import failed:", error instanceof Error ? error.message : "Unknown error");
    process.exitCode = 1;
  });
}
