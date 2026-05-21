import express from "express";
import { SpanStatusCode } from "@opentelemetry/api";
import { copilotRuntime } from "./copilot-runtime.js";
import { WriteToolService, WriteToolName } from "./write-tools.js";
import { logger } from "./logger.js";
import { extensionTracer } from "./observability.js";
import { createRateLimiter, resolveRateLimitOptionsFromEnv } from "./rate-limit.js";

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
  const rateLimit = resolveRateLimitOptionsFromEnv();

  app.use(express.json());
  app.use((request, response, next) => {
    const startedAtMs = Date.now();
    response.on("finish", () => {
      logger.info("http_request", {
        method: request.method,
        path: request.path,
        statusCode: response.statusCode,
        durationMs: Date.now() - startedAtMs,
      });
    });
    next();
  });
  app.use("/api/copilot", createRateLimiter(rateLimit));

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "basecoat-extension",
      timestamp: new Date().toISOString(),
      rateLimit,
    });
  });

  app.get("/api/copilot/ping", async (req, res) => {
    const span = extensionTracer.startSpan("copilot.ping");
    const startedAtMs = Date.now();
    try {
      const result = await runtime.ping();
      span.setStatus({ code: SpanStatusCode.OK });
      logger.info("tool_invocation", {
        tool: "copilot.ping",
        status: "ok",
        durationMs: Date.now() - startedAtMs,
        userId: req.header("x-github-user-id") ?? "unknown",
      });
      res.status(200).json({ status: "ok", copilot: result });
    } catch (error) {
      const detail = error instanceof Error ? error.message : "Unknown error";
      span.recordException(error instanceof Error ? error : new Error(detail));
      span.setStatus({ code: SpanStatusCode.ERROR, message: detail });
      logger.error("tool_invocation", {
        tool: "copilot.ping",
        status: "error",
        error: detail,
        durationMs: Date.now() - startedAtMs,
        userId: req.header("x-github-user-id") ?? "unknown",
      });
      res.status(503).json({
        status: "degraded",
        error: "Copilot runtime unavailable",
        detail,
      });
    } finally {
      span.end();
    }
  });

  app.post("/api/copilot/chat", (req, res) => {
    logger.warn("intent_misroute", {
      route: "/api/copilot/chat",
      reason: "chat_not_implemented",
      userId: req.header("x-github-user-id") ?? "unknown",
    });
    res.status(501).json({
      error: "Not implemented",
      detail: "Chat/session wiring will be added in follow-up issues.",
    });
  });

  app.post("/api/copilot/tools/:toolName", async (req, res) => {
    const toolName = parseToolName(req.params.toolName);
    if (!toolName) {
      logger.warn("tool_invocation", {
        tool: req.params.toolName,
        status: "unknown_tool",
      });
      res.status(404).json({
        status: "error",
        error: "unknown_tool",
        detail: `Unsupported tool '${req.params.toolName}'.`,
      });
      return;
    }

    const result = await writeTools.execute(toolName, req.body);
    logger.info("tool_invocation", {
      tool: `copilot.${toolName}`,
      status: result.status,
      errorCode: result.errorCode ?? null,
      userId: req.header("x-github-user-id") ?? "unknown",
    });

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

