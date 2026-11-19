import { Writable } from "node:stream";

import express from "express";
import request from "supertest";
import { describe, expect, it } from "vitest";

import { createRequestLogger } from "../src/middleware/request-logger.js";

describe("HTTP request logging", () => {
  it("keeps request diagnostics without recording credentials or cookies", async () => {
    const chunks: string[] = [];
    const destination = new Writable({
      write(chunk: Buffer, _encoding, callback) {
        chunks.push(chunk.toString());
        callback();
      },
    });
    const app = express();
    app.use(createRequestLogger(destination));
    app.get("/health", (_request, response) => {
      response.setHeader("Set-Cookie", "session=response-cookie-fixture");
      response.json({ status: "ok" });
    });

    const response = await request(app)
      .get("/health")
      .set("Authorization", "Bearer token-fixture")
      .set("Cookie", "session=request-cookie-fixture");

    expect(response.status).toBe(200);
    const output = chunks.join("");
    expect(output).not.toContain("token-fixture");
    expect(output).not.toContain("request-cookie-fixture");
    expect(output).not.toContain("response-cookie-fixture");
    expect(JSON.parse(output)).toMatchObject({
      req: { method: "GET", url: "/health" },
      res: { statusCode: 200 },
      responseTime: expect.any(Number),
    });
  });
});
