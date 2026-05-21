import express from "express";
import { copilotRuntime } from "./copilot-runtime.js";
import { WriteToolService, WriteToolName } from "./write-tools.js";

type AppOptions = {
  writeTools?: WriteToolService;
  runtime?: {
    ping(): Promise<unknown>;
  };
};

function parseToolName(value: string): WriteToolName | null {
  if (value === "scaffold" || value === "validate" || value === "create-pr") {
    return value;
  }

  return null;
}

export function createApp(options: AppOptions = {}) {
  const app = express();
  const writeTools = options.writeTools ?? new WriteToolService();
  const runtime = options.runtime ?? copilotRuntime;

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
      const result = await runtime.ping();
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

  app.post("/api/copilot/tools/:toolName", async (req, res) => {
    const toolName = parseToolName(req.params.toolName);
    if (!toolName) {
      res.status(404).json({
        status: "error",
        error: "unknown_tool",
        detail: `Unsupported tool '${req.params.toolName}'.`,
      });
      return;
    }

    const result = await writeTools.execute(toolName, req.body);

    if (result.status === "error") {
      const status = result.errorCode === "unknown_tool" ? 404 : 400;
      res.status(status).json(result);
      return;
    }

    if (result.status === "blocked") {
      res.status(503).json(result);
      return;
    }

    res.status(200).json(result);
  });

  app.use((error: unknown, _req: express.Request, res: express.Response, next: express.NextFunction) => {
    if (error instanceof SyntaxError && "body" in error) {
      res.status(400).json({
        status: "error",
        error: "invalid_json",
        detail: "Request body must be valid JSON.",
      });
      return;
    }

    next(error);
  });

  return app;
}
