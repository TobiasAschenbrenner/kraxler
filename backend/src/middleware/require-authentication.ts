import type { RequestHandler } from "express";

import {
  InvalidAuthTokenError,
  type AuthTokenVerifier,
} from "../auth/auth-token.js";
import { ApiError } from "../errors/api-error.js";

export const createRequireAuthentication = (
  verifyAuthToken: AuthTokenVerifier,
): RequestHandler =>
  async (request, response, next) => {
    const authorization = request.header("authorization");
    const [scheme, idToken, ...remainingParts] = authorization?.split(" ") ?? [];

    if (
      scheme?.toLowerCase() !== "bearer" ||
      idToken === undefined ||
      idToken.length === 0 ||
      remainingParts.length > 0
    ) {
      next(
        new ApiError(
          401,
          "authentication_required",
          "A Firebase ID token is required.",
        ),
      );
      return;
    }

    try {
      const authenticatedUser = await verifyAuthToken(idToken);
      response.locals.authenticatedUserId = authenticatedUser.userId;
      next();
    } catch (error) {
      if (error instanceof InvalidAuthTokenError) {
        next(new ApiError(401, "invalid_authentication_token", error.message));
        return;
      }

      next(error);
    }
  };
