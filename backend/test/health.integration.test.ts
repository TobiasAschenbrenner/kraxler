import request from "supertest";
import { describe, expect, it } from "vitest";

import { app } from "../src/app.js";

describe("service status endpoints", () => {
  it("reports that the process is healthy", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      status: "ok",
    });
    expect(response.body.timestamp).toEqual(expect.any(String));
    expect(response.body.uptimeSeconds).toEqual(expect.any(Number));
  });

  it("reports that the service is ready", async () => {
    const response = await request(app).get("/ready");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      status: "ready",
    });
  });
});

describe("unknown routes", () => {
  it("returns the common API error format", async () => {
    const response = await request(app).get("/does-not-exist");

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      error: {
        code: "route_not_found",
        message: "No route exists for GET /does-not-exist.",
      },
    });
  });
});
