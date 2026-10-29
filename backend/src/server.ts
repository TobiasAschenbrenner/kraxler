import { app } from "./app.js";
import { environment } from "./config/environment.js";

const server = app.listen(environment.port, () => {
  console.info(`Kraxler API listening on port ${environment.port}.`);
});

const shutDown = (signal: NodeJS.Signals): void => {
  console.info(`${signal} received. Closing the HTTP server.`);

  server.close((error) => {
    if (error) {
      console.error("The HTTP server could not close cleanly.", error);
      process.exitCode = 1;
      return;
    }

    process.exitCode = 0;
  });
};

process.on("SIGINT", shutDown);
process.on("SIGTERM", shutDown);
