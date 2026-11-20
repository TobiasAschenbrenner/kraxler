import request from "supertest";
import { describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";

const app = createApp({ verifyAuthToken: async () => ({ userId: "test-user" }) });

describe("JSON request errors", () => {
  it("returns 400 for malformed JSON before calling the route", async () => {
    const response = await request(app).put("/api/v1/me/profile")
      .set("Content-Type", "application/json").send("{broken");
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe("invalid_json");
  });

  it("returns 413 for an oversized body without echoing its contents", async () => {
    const response = await request(app).put("/api/v1/me/profile")
      .send({ value: "private-payload".repeat(10_000) });
    expect(response.status).toBe(413);
    expect(response.body.error.code).toBe("request_too_large");
    expect(JSON.stringify(response.body)).not.toContain("private-payload");
  });
});
