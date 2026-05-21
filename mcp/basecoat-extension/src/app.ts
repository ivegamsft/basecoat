import express from "express";
import { SpanStatusCode } from "@opentelemetry/api";
import { copilotRuntime } from "./copilot-runtime.js";
import { WriteToolService, WriteToolName } from "./write-tools.js";
import { logger } from "./logger.js";
import { extensionTracer } from "./observability.js";
import { createRateLimiter, resolveRateLimitOptionsFromEnv } from "./rate-limit.js";
import { gitHubOAuthManager } from "./github-oauth.js";

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

  // GitHub OAuth routes
  app.get("/api/github/oauth/request", (_req, res) => {
    const state = gitHubOAuthManager.generateState();
    const clientId = process.env.BASECOAT_EXTENSION_CLIENT_ID;

    if (!clientId) {
      logger.error("oauth_request_failed", {
        reason: "missing_client_id",
      });
      res.status(500).json({
        error: "server_error",
        detail: "GitHub OAuth not configured",
      });
      return;
    }

    const redirectUri = `${process.env.BASECOAT_EXTENSION_BASE_URL ?? "http://localhost:3000"}/api/github/oauth/callback`;
    const authUrl = `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${state}&scope=user:email`;

    logger.info("oauth_request", {
      statePrefix: state.slice(0, 8),
      redirect: redirectUri,
    });

    res.status(200).json({ authUrl, state });
  });

  app.get("/api/github/oauth/callback", (req, res) => {
    const { code, state } = req.query;

    if (!code || !state || typeof state !== "string") {
      logger.warn("oauth_callback_rejected", {
        reason: "missing_params",
      });
      res.status(400).json({
        error: "invalid_request",
        detail: "Missing code or state parameter",
      });
      return;
    }

    if (!gitHubOAuthManager.validateState(state)) {
      logger.warn("oauth_callback_rejected", {
        reason: "invalid_state",
        statePrefix: (state as string).slice(0, 8),
      });
      res.status(403).json({
        error: "invalid_state",
        detail: "State parameter is invalid or expired",
      });
      return;
    }

    logger.info("oauth_callback_accepted", {
      statePrefix: (state as string).slice(0, 8),
      code: (code as string).slice(0, 8),
    });

    // Exchange code for token (actual implementation requires GitHub API call)
    res.status(200).json({
      status: "authorized",
      message: "OAuth callback received. Token exchange will be performed by client.",
      code,
      state,
    });
  });

  app.post("/api/github/webhook", (req, res) => {
    const signature = req.header("x-hub-signature-256");
    const webhookSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;

    if (!signature || !webhookSecret) {
      logger.warn("webhook_rejected", {
        reason: "missing_signature_or_secret",
      });
      res.status(403).json({
        error: "forbidden",
        detail: "Webhook signature validation failed",
      });
      return;
    }

    const body = JSON.stringify(req.body);
    const isValid = gitHubOAuthManager.validateWebhookSignature(
      body,
      signature,
      webhookSecret
    );

    if (!isValid) {
      logger.warn("webhook_rejected", {
        reason: "signature_mismatch",
      });
      res.status(403).json({
        error: "forbidden",
        detail: "Webhook signature validation failed",
      });
      return;
    }

    const event = req.header("x-github-event");
    const bodyObj = req.body as Record<string, unknown>;
    logger.info("webhook_received", {
      event: String(event ?? "unknown"),
      action: String(bodyObj.action ?? "unknown"),
      repository: String((bodyObj.repository as Record<string, unknown>)?.name ?? "unknown"),
    });

    res.status(202).json({
      status: "accepted",
      message: "Webhook received and queued for processing",
    });
  });

  app.get("/api/github/setup", (req, res) => {
    const iid = req.query.installation_id;
    const installationId: string = Array.isArray(iid)
      ? String(iid[0] ?? "unknown")
      : String(iid ?? "unknown");

    logger.info("github_app_setup", {
      installationId,
    });

    res.status(200).json({
      status: "setup_received",
      message: "GitHub App setup initiated. Installation ID recorded.",
      installationId,
    });
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

