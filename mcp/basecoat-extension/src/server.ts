import { createApp } from "./app.js";
import { copilotRuntime } from "./copilot-runtime.js";
import { logger } from "./logger.js";
import { initializeObservability } from "./observability.js";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
initializeObservability();
const app = createApp();
const server = app.listen(port, () => {
  logger.info("server_started", { port });
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
