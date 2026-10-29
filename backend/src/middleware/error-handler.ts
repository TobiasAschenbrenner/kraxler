import type { ErrorRequestHandler, RequestHandler } from "express";

import { ApiError } from "../errors/api-error.js";

export const notFoundHandler: RequestHandler = (request, _response, next) => {
  next(
    new ApiError(
      404,
      "route_not_found",
      `No route exists for ${request.method} ${request.originalUrl}.`,
    ),
  );
};

export const errorHandler: ErrorRequestHandler = (
  error: unknown,
  _request,
  response,
  _next,
) => {
  if (error instanceof ApiError) {
    response.status(error.statusCode).json({
      error: {
        code: error.code,
        message: error.message,
      },
    });
    return;
  }

  response.status(500).json({
    error: {
      code: "internal_server_error",
      message: "An unexpected error occurred.",
    },
  });
};
