import { MongoMemoryServer } from "mongodb-memory-server-core";
import { Types } from "mongoose";
import request from "supertest";
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";

import { app } from "../src/app.js";
import { attachTopoMedia, importConnectedDataset, validateDataset, type Dataset } from "../src/database/import-climbing-sample.js";
import { connectToDatabase, disconnectFromDatabase } from "../src/database/mongo.js";
import { AreaModel } from "../src/modules/areas/area.model.js";
import { gradeRankFor } from "../src/modules/routes/grade.js";
import { RouteModel } from "../src/modules/routes/route.model.js";

let mongoServer: MongoMemoryServer;
beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create({ binary: { version: "8.2.6" } });
  await connectToDatabase(mongoServer.getUri());
  await Promise.all([AreaModel.syncIndexes(), RouteModel.syncIndexes()]);
});
afterEach(async () => { await Promise.all([AreaModel.deleteMany({}), RouteModel.deleteMany({})]); });
afterAll(async () => { await disconnectFromDatabase(); await mongoServer?.stop(); });

const sample = (): Dataset => {
  const areaId = new Types.ObjectId().toString();
  const sectorId = new Types.ObjectId().toString();
  return {
    formatVersion: 1,
    areas: [
      { _id: areaId, name: "Röthelfels", type: "climbingArea", location: { type: "Point", coordinates: [11.24633, 49.74745] } },
      { _id: sectorId, parentAreaId: areaId, name: "Main sector", type: "sector", location: { type: "Point", coordinates: [11.24633, 49.74745] } },
    ],
    routes: [{
      _id: new Types.ObjectId().toString(), areaId: sectorId, name: "Sonntagsspaziergang",
      location: { type: "Point", coordinates: [11.24633, 49.74745] },
      discipline: "sport", grade: { system: "uiaa", value: "6+", rank: gradeRankFor("uiaa", "6+")! },
      styles: [], lengthMeters: 20,
    }],
  };
};

describe("climbing sample import", () => {
  it("reuses seed IDs and region parents, preserves known styles and can run twice", async () => {
    const location = { type: "Point", coordinates: [11.24633, 49.74745] };
    const region = await AreaModel.create({ name: "Frankenjura", type: "region", location });
    const crag = await AreaModel.create({ name: "Röthelfels", type: "climbingArea", parentAreaId: region._id, location });
    const sector = await AreaModel.create({ name: "Main sector", type: "sector", parentAreaId: crag._id, location });
    const data = sample();
    const existing = await RouteModel.create({ ...data.routes[0], _id: new Types.ObjectId(), areaId: sector._id, styles: ["vertical"] });
    const first = await importConnectedDataset(data);
    const second = await importConnectedDataset(data);
    expect(first).toEqual(second);
    expect(first.areaIds[data.areas[0]!._id]).toBe(crag._id.toString());
    expect(first.routeIds[data.routes[0]!._id]).toBe(existing._id.toString());
    expect(await AreaModel.countDocuments()).toBe(3);
    expect(await RouteModel.countDocuments()).toBe(1);
    expect((await AreaModel.findById(crag._id))?.parentAreaId?.toString()).toBe(region._id.toString());
    expect((await RouteModel.findById(existing._id))?.styles).toEqual(["vertical"]);
  });

  it("saves a topo with its route number and exposes it through the route API", async () => {
    const data = sample();
    const enriched = attachTopoMedia(data, {
      formatVersion: 1,
      topos: [{ id: "topo-one", url: "https://res.cloudinary.com/demo/image/upload/topo.png", cloudinaryPublicId: "kraxler/topos/topo-one", pixelWidth: 427, pixelHeight: 320, routeNumberMappings: [{ routeId: data.routes[0]!._id, number: "15" }] }],
    });
    const result = await importConnectedDataset(enriched);
    const response = await request(app).get(`/api/v1/routes/${result.routeIds[data.routes[0]!._id]}`);
    expect(response.status).toBe(200);
    expect(response.body.data.topos).toEqual(enriched.routes[0]!.topos);
    expect(response.body.data.topos[0]).not.toHaveProperty("_id");
  });

  it("rejects dangling topo associations and unsafe URLs before importing", async () => {
    const data = sample();
    expect(() => attachTopoMedia(data, { formatVersion: 1, topos: [{ id: "bad", url: null, pixelWidth: 10, pixelHeight: 10, routeNumberMappings: [{ routeId: new Types.ObjectId().toString(), number: "1" }] }] })).toThrow("unknown route");
    data.routes[0]!.topos = [{ id: "bad", imageUrl: "javascript:alert(1)", routeNumber: "1", pixelWidth: 10, pixelHeight: 10 }];
    await expect(validateDataset(data)).rejects.toThrow("HTTPS URL");
  });
});
