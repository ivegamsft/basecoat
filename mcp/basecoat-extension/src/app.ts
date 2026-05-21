import express from "express";
import { copilotRuntime } from "./copilot-runtime.js";

export function createApp() {
  const app = express();

  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "basecoat-extension",
      timestamp: new Date().toISOString(),
    });
  });

  app.get("/api/copilot/ping", async (_req, res) => {
    try {
      const result = await copilotRuntime.ping();
      res.status(200).json({ status: "ok", copilot: result });
    } catch (error) {
      const detail = error instanceof Error ? error.message : "Unknown error";
      res.status(503).json({
        status: "degraded",
        error: "Copilot runtime unavailable",
        detail,
      });
    }
  });

  app.post("/api/copilot/chat", (_req, res) => {
    res.status(501).json({
      error: "Not implemented",
      detail: "Chat/session wiring will be added in follow-up issues.",
    });
  });

  return app;
}
