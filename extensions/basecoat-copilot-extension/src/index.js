import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

const DEFAULT_PORT = Number(process.env.PORT ?? "3000");
const DEFAULT_TIMEOUT_MS = Number(process.env.EXTENSION_MCP_TIMEOUT_MS ?? "5000");
const DEFAULT_MCP_ENDPOINT = process.env.EXTENSION_MCP_ENDPOINT ?? "http://localhost:8080";

class HttpError extends Error {
  constructor(statusCode, errorCode, message) {
    super(message);
    this.statusCode = statusCode;
    this.errorCode = errorCode;
  }
}

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(payload));
}

async function readJsonBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
  }

  const raw = Buffer.concat(chunks).toString("utf8").trim();
  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    throw new HttpError(400, "invalid_request", "Request body must be valid JSON.");
  }
}

function parseQuery(urlValue) {
  return new URL(urlValue, "http://localhost");
}

async function invokeMcpTool({
  toolName,
  args,
  fetchImpl,
  timeoutMs,
  endpoint
}) {
  const abortController = new AbortController();
  const timer = setTimeout(() => abortController.abort(), timeoutMs);

  try {
    const response = await fetchImpl(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: randomUUID(),
        method: "tools/call",
        params: {
          name: toolName,
          arguments: args
        }
      }),
      signal: abortController.signal
    });

    if (!response.ok) {
      const statusCode = response.status === 429 || response.status === 503 ? 503 : 502;
      throw new HttpError(
        statusCode,
        "upstream_error",
        `MCP upstream request failed: ${response.status} ${response.statusText}`
      );
    }

    let payload;
    try {
      payload = await response.json();
    } catch {
      throw new HttpError(502, "upstream_bad_response", "MCP upstream returned non-JSON response.");
    }

    if (payload?.error) {
      const message = payload.error.message ?? "MCP tool call failed.";
      const normalized = String(message).toLowerCase();
      if (normalized.includes("not found")) {
        throw new HttpError(404, "not_found", message);
      }
      if (payload.error.code === -32602) {
        throw new HttpError(400, "invalid_request", message);
      }
      throw new HttpError(502, "upstream_error", message);
    }

    const textResult = payload?.result?.content?.find((item) => item?.type === "text")?.text;
    if (typeof textResult !== "string") {
      throw new HttpError(
        502,
        "upstream_bad_response",
        "MCP upstream response did not include text content."
      );
    }

    try {
      return JSON.parse(textResult);
    } catch {
      return {
        value: textResult
      };
    }
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error?.name === "AbortError") {
      throw new HttpError(504, "upstream_timeout", `MCP upstream timed out after ${timeoutMs}ms.`);
    }
    throw new HttpError(502, "upstream_unavailable", `Failed to reach MCP upstream: ${error.message}`);
  } finally {
    clearTimeout(timer);
  }
}

function parseInteger(rawValue, fallback, { min, max }) {
  if (rawValue === undefined || rawValue === null || rawValue === "") {
    return fallback;
  }
  const parsed = Number.parseInt(String(rawValue), 10);
  if (Number.isNaN(parsed) || parsed < min || parsed > max) {
    throw new HttpError(
      400,
      "invalid_request",
      `Expected integer between ${min} and ${max}, received '${rawValue}'.`
    );
  }
  return parsed;
}

export function createRequestHandler({
  fetchImpl = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  endpoint = DEFAULT_MCP_ENDPOINT
} = {}) {
  return async (req, res) => {
    try {
      if (req.url === "/healthz" && req.method === "GET") {
        sendJson(res, 200, {
          status: "ok",
          service: "basecoat-copilot-extension"
        });
        return;
      }

      if (req.url?.startsWith("/api/extension/search") && req.method === "POST") {
        const body = await readJsonBody(req);
        const query = typeof body.query === "string" ? body.query.trim() : "";
        const type = typeof body.type === "string" ? body.type : "all";
        const limit = parseInteger(body.limit, 10, { min: 1, max: 50 });

        if (!query) {
          throw new HttpError(400, "invalid_request", "Field 'query' is required.");
        }
        if (!["all", "skill", "agent"].includes(type)) {
          throw new HttpError(
            400,
            "invalid_request",
            "Field 'type' must be one of: all, skill, agent."
          );
        }

        if (type === "skill") {
          const skills = await invokeMcpTool({
            toolName: "search-skills",
            args: { query, limit },
            fetchImpl,
            timeoutMs,
            endpoint
          });
          sendJson(res, 200, {
            query,
            type,
            result: skills
          });
          return;
        }

        if (type === "agent") {
          const agents = await invokeMcpTool({
            toolName: "search-agents",
            args: { query, limit },
            fetchImpl,
            timeoutMs,
            endpoint
          });
          sendJson(res, 200, {
            query,
            type,
            result: agents
          });
          return;
        }

        const [skills, agents] = await Promise.all([
          invokeMcpTool({
            toolName: "search-skills",
            args: { query, limit },
            fetchImpl,
            timeoutMs,
            endpoint
          }),
          invokeMcpTool({
            toolName: "search-agents",
            args: { query, limit },
            fetchImpl,
            timeoutMs,
            endpoint
          })
        ]);

        sendJson(res, 200, {
          query,
          type,
          results: {
            skills,
            agents
          }
        });
        return;
      }

      if (req.url?.startsWith("/api/extension/metrics") && req.method === "GET") {
        const requestUrl = parseQuery(req.url);
        const view = requestUrl.searchParams.get("view") ?? "latest";
        const repo = requestUrl.searchParams.get("repo") ?? undefined;

        let toolName;
        let args;
        if (view === "latest") {
          toolName = "get-latest-metrics";
          args = repo ? { repo } : {};
        } else if (view === "history") {
          toolName = "get-history";
          args = {
            weeks: parseInteger(requestUrl.searchParams.get("weeks"), 4, {
              min: 1,
              max: 52
            }),
            ...(repo ? { repo } : {})
          };
        } else if (view === "alerts") {
          const severity = requestUrl.searchParams.get("severity") ?? "all";
          if (!["all", "warning", "info"].includes(severity)) {
            throw new HttpError(
              400,
              "invalid_request",
              "Query parameter 'severity' must be one of: all, warning, info."
            );
          }
          toolName = "get-alerts";
          args = { severity };
        } else if (view === "repo") {
          if (!repo) {
            throw new HttpError(
              400,
              "invalid_request",
              "Query parameter 'repo' is required when view=repo."
            );
          }
          toolName = "get-repo-metrics";
          args = {
            repo,
            trend_weeks: parseInteger(requestUrl.searchParams.get("trendWeeks"), 4, {
              min: 1,
              max: 12
            })
          };
        } else {
          throw new HttpError(
            400,
            "invalid_request",
            "Query parameter 'view' must be one of: latest, history, alerts, repo."
          );
        }

        const result = await invokeMcpTool({
          toolName,
          args,
          fetchImpl,
          timeoutMs,
          endpoint
        });
        sendJson(res, 200, {
          view,
          result
        });
        return;
      }

      if (req.url?.startsWith("/api/extension/details") && req.method === "POST") {
        const body = await readJsonBody(req);
        const assetPath = typeof body.path === "string" ? body.path.trim() : "";

        if (!assetPath) {
          throw new HttpError(400, "invalid_request", "Field 'path' is required.");
        }

        const result = await invokeMcpTool({
          toolName: "get-asset-details",
          args: { path: assetPath },
          fetchImpl,
          timeoutMs,
          endpoint
        });
        sendJson(res, 200, {
          path: assetPath,
          result
        });
        return;
      }

      if (req.url?.startsWith("/api/extension/")) {
        throw new HttpError(404, "not_found", "Unknown extension route.");
      }

      sendJson(res, 404, {
        error: "not_found"
      });
    } catch (error) {
      if (error instanceof HttpError) {
        sendJson(res, error.statusCode, {
          error: error.errorCode,
          message: error.message
        });
        return;
      }
      sendJson(res, 500, {
        error: "internal_error",
        message: "Unexpected server error."
      });
    }
  };
}

export function startServer(port = DEFAULT_PORT) {
  const server = createServer(createRequestHandler());
  server.listen(port, () => {
    console.log(`basecoat-copilot-extension listening on :${port}`);
  });
  return server;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startServer();
}
