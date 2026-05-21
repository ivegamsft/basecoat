import { createApp } from "./app.js";
import { copilotRuntime } from "./copilot-runtime.js";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const app = createApp();
const server = app.listen(port, () => {
  console.log(`basecoat-extension listening on port ${port}`);
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
