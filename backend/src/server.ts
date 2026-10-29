import "dotenv/config";

import { app } from "./app.js";
import { environment } from "./config/environment.js";
import {
  connectToDatabase,
  disconnectFromDatabase,
} from "./database/mongo.js";

const startServer = async (): Promise<void> => {
  await connectToDatabase(environment.mongoDbUri);

  const server = app.listen(environment.port, () => {
    console.info(`Kraxler API listening on port ${environment.port}.`);
  });

  const shutDown = (signal: NodeJS.Signals): void => {
    console.info(`${signal} received. Closing the Kraxler API.`);

    server.close((error) => {
      void disconnectFromDatabase().finally(() => {
        if (error) {
          console.error("The HTTP server could not close cleanly.", error);
          process.exitCode = 1;
          return;
        }

        process.exitCode = 0;
      });
    });
  };

  process.on("SIGINT", shutDown);
  process.on("SIGTERM", shutDown);
};

startServer().catch((error: unknown) => {
  console.error("The Kraxler API could not start.", error);
  process.exitCode = 1;
});
