import type { Writable } from "node:stream";

import { pinoHttp } from "pino-http";

export const createRequestLogger = (destination?: Writable) =>
  pinoHttp(
    {
      redact: {
        paths: [
          "req.headers.authorization",
          "req.headers.cookie",
          'res.headers["set-cookie"]',
        ],
        remove: true,
      },
    },
    destination,
  );
