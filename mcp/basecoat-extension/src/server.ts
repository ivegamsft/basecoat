import { createApp } from "./app.js";
import { copilotRuntime } from "./copilot-runtime.js";
import { logger } from "./logger.js";
import { initializeObservability } from "./observability.js";
import { validateConfig } from "./config.js";

// Validate configuration before starting
const config = validateConfig();

initializeObservability();
const app = createApp();
const server = app.listen(config.port, () => {
  logger.info("server_started", { port: config.port });
});

const shutdown = async () => {
  await copilotRuntime.stop();
  server.close(() => process.exit(0));
};

process.on("SIGINT", () => {
  void shutdown();
});

process.on("SIGTERM", () => {
  void shutdown();
});
