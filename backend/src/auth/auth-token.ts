import {
  applicationDefault,
  getApps,
  initializeApp,
  type App,
} from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import { ApiError } from "../errors/api-error.js";
import { environment } from "../config/environment.js";

export interface AuthenticatedUser {
  userId: string;
}

export type AuthTokenVerifier = (
  idToken: string,
) => Promise<AuthenticatedUser>;

export class InvalidAuthTokenError extends Error {
  public constructor() {
    super("The authentication token is invalid or expired.");
    this.name = "InvalidAuthTokenError";
  }
}

let firebaseApp: App | undefined;

const getFirebaseApp = (): App => {
  if (firebaseApp !== undefined) {
    return firebaseApp;
  }

  if (environment.firebaseProjectId === undefined) {
    throw new ApiError(
      503,
      "authentication_unavailable",
      "Authentication is not configured on this server.",
    );
  }

  firebaseApp =
    getApps()[0] ??
    initializeApp({
      credential: applicationDefault(),
      projectId: environment.firebaseProjectId,
    });

  return firebaseApp;
};

export const verifyFirebaseAuthToken: AuthTokenVerifier = async (idToken) => {
  try {
    const decodedToken = await getAuth(getFirebaseApp()).verifyIdToken(idToken);
    return { userId: decodedToken.uid };
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }

    const errorCode =
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      typeof error.code === "string"
        ? error.code
        : undefined;

    if (errorCode?.startsWith("auth/") === true) {
      throw new InvalidAuthTokenError();
    }

    throw new ApiError(
      503,
      "authentication_unavailable",
      "Authentication could not verify the current user.",
    );
  }
};
