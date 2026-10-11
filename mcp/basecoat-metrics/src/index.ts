#!/usr/bin/env node
/**
 * Base Coat Metrics MCP Server
 *
 * Exposes Base Coat adoption metrics to AI agents via the Model Context Protocol.
 * Reads from the live GitHub Pages endpoints or a local METRICS_DIR override.
 *
 * Tools:
 *   get-latest-metrics  — Current snapshot (all repos or one repo)
 *   get-history         — Historical snapshots (last N weeks)
 *   get-alerts          — Active degradation alerts
 *   get-repo-metrics    — Detailed metrics for a single repo
 */

import {
  McpServer,
  WebStandardStreamableHTTPServerTransport,
} from "@modelcontextprotocol/server";
import { StdioServerTransport } from "@modelcontextprotocol/server/stdio";
import { once } from "node:events";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const PAGES_BASE =
  process.env.METRICS_BASE_URL ??
  "https://ivegamsft.github.io/basecoat/metrics";

const METRICS_DIR = process.env.METRICS_DIR ?? null;
const MAX_REQUEST_BODY_BYTES = 1024 * 1024;

class RequestBodyTooLargeError extends Error {
  constructor() {
    super(`Request body exceeds ${MAX_REQUEST_BODY_BYTES} bytes.`);
    this.name = "RequestBodyTooLargeError";
  }
}

// ---------------------------------------------------------------------------
// Data fetching helpers
// ---------------------------------------------------------------------------

async function fetchMetrics(file: string): Promise<unknown> {
  if (METRICS_DIR) {
    const local = join(METRICS_DIR, file);
    if (existsSync(local)) {
      const raw = await readFile(local, "utf-8");
      return JSON.parse(raw);
    }
  }
  const url = `${PAGES_BASE}/${file}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

type MetricsSnapshot = {
  collected_at: string;
  organization: string;
  copilot: Record<string, unknown>;
  repos: Record<string, RepoMetrics>;
};

type RepoMetrics = {
  pull_requests: Record<string, unknown>;
  ci: Record<string, unknown>;
  issues: Record<string, unknown>;
  basecoat_coverage: Record<string, unknown>;
};

type Alert = {
  type: string;
  severity: string;
  message: string;
  repo?: string;
};

async function getLatest(): Promise<MetricsSnapshot> {
  return fetchMetrics("latest.json") as Promise<MetricsSnapshot>;
}

async function getHistory(): Promise<MetricsSnapshot[]> {
  return fetchMetrics("history.json") as Promise<MetricsSnapshot[]>;
}

async function getAlerts(): Promise<Alert[]> {
  return fetchMetrics("alerts.json") as Promise<Alert[]>;
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "basecoat-metrics",
  version: "1.0.0",
});

// ── Tool: get-latest-metrics ────────────────────────────────────────────────

server.registerTool(
  "get-latest-metrics",
  {
    description:
      "Returns the most recent Base Coat adoption metrics snapshot. " +
      "Includes Copilot usage, PR cycle times, CI success rates, issue resolution times, " +
      "and Base Coat coverage percentage for all monitored repositories. " +
      "Use repo parameter to narrow to a single repository. " +
      "Use for intents like 'latest', 'current', 'now', or 'refresh snapshot'. " +
      "Do not use for historical trends over multiple weeks or alert-only requests.",
    inputSchema: {
      repo: z
        .string()
        .optional()
        .describe(
          "Optional: filter to a single repo in 'org/repo' format. " +
            "Returns all repos if omitted."
        ),
    },
  },
  async ({ repo }) => {
    const latest = await getLatest();
    const result: Record<string, unknown> = {
      collected_at: latest.collected_at,
      organization: latest.organization,
      copilot: latest.copilot,
    };

    if (repo) {
      const found = latest.repos[repo];
      if (!found) {
        const available = Object.keys(latest.repos).join(", ");
        return {
          content: [
            {
              type: "text" as const,
              text: `Repository '${repo}' not found. Available: ${available}`,
            },
          ],
        };
      }
      result.repos = { [repo]: found };
    } else {
      result.repos = latest.repos;
    }

    return {
      content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
    };
  }
);

// ── Tool: get-history ───────────────────────────────────────────────────────

server.registerTool(
  "get-history",
  {
    description:
      "Returns historical adoption metrics snapshots collected weekly. " +
      "Use weeks parameter to control how many historical points to return (default 4, max 52). " +
      "Useful for trend analysis and spotting regressions over time. " +
      "Use for intents like 'history', 'trend', 'over time', 'week over week', or 'last N weeks'. " +
      "Do not use for single-point current snapshot refreshes.",
    inputSchema: {
      weeks: z
        .number()
        .int()
        .min(1)
        .max(52)
        .default(4)
        .describe("Number of historical weeks to return (1–52, default 4)."),
      repo: z
        .string()
        .optional()
        .describe(
          "Optional: filter repo metrics in each snapshot to a single 'org/repo'."
        ),
    },
  },
  async ({ weeks, repo }) => {
    const history = await getHistory();
    const slice = history.slice(-weeks);

    const result = slice.map((snap) => {
      const entry: Record<string, unknown> = {
        collected_at: snap.collected_at,
        organization: snap.organization,
      };
      if (repo) {
        entry.repos = snap.repos[repo]
          ? { [repo]: snap.repos[repo] }
          : {};
      } else {
        entry.repos = snap.repos;
      }
      return entry;
    });

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { points: result.length, history: result },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: get-alerts ────────────────────────────────────────────────────────

server.registerTool(
  "get-alerts",
  {
    description:
      "Returns active degradation alerts detected in the latest metrics run. " +
      "Alerts are generated when CI success rate drops >15%, PR cycle time increases >50%, " +
      "or Copilot acceptance rate drops >10%. An empty array means no regressions detected. " +
      "Use for intents mentioning alerts, warnings, incidents, degradations, or regressions. " +
      "Do not use for general snapshot refreshes or trend history.",
    inputSchema: {
      severity: z
        .enum(["warning", "info", "all"])
        .default("all")
        .describe("Filter by severity: 'warning', 'info', or 'all' (default)."),
    },
  },
  async ({ severity }) => {
    const alerts = await getAlerts();
    const filtered =
      severity === "all"
        ? alerts
        : alerts.filter((a) => a.severity === severity);

    const summary =
      filtered.length === 0
        ? "No active degradation alerts."
        : `${filtered.length} alert(s) detected.`;

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({ summary, alerts: filtered }, null, 2),
        },
      ],
    };
  }
);

// ── Tool: get-repo-metrics ──────────────────────────────────────────────────

server.registerTool(
  "get-repo-metrics",
  {
    description:
      "Returns detailed metrics for a single repository including PR velocity, " +
      "CI success rate, issue resolution time, and Base Coat asset coverage. " +
      "Also includes trend data from the last N weeks to show direction of change. " +
      "Use when the user targets one repository and wants both current metrics and trend context.",
    inputSchema: {
      repo: z
        .string()
        .describe("Repository in 'org/repo' format (e.g. 'ivegamsft/basecoat')."),
      trend_weeks: z
        .number()
        .int()
        .min(1)
        .max(12)
        .default(4)
        .describe("Number of historical weeks to include for trend analysis (default 4)."),
    },
  },
  async ({ repo, trend_weeks }) => {
    const [latest, history] = await Promise.all([getLatest(), getHistory()]);

    const current = latest.repos[repo];
    if (!current) {
      const available = Object.keys(latest.repos).join(", ");
      return {
        content: [
          {
            type: "text" as const,
            text: `Repository '${repo}' not found. Available: ${available}`,
          },
        ],
      };
    }

    const trend = history
      .slice(-trend_weeks)
      .map((snap) => ({
        collected_at: snap.collected_at,
        metrics: snap.repos[repo] ?? null,
      }))
      .filter((e) => e.metrics !== null);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              repo,
              as_of: latest.collected_at,
              current,
              trend,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---------------------------------------------------------------------------
// Asset discovery helpers (skills/, agents/)
// ---------------------------------------------------------------------------

const REPO_DIR = process.env.REPO_DIR ?? null;

type AssetFrontmatter = {
  name: string;
  description: string;
  type: "skill" | "agent";
  path: string;
};

function parseFrontmatter(content: string): Record<string, string> {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};
  const result: Record<string, string> = {};
  for (const line of match[1].split(/\r?\n/)) {
    const sep = line.indexOf(":");
    if (sep === -1) continue;
    const key = line.slice(0, sep).trim();
    const value = line.slice(sep + 1).trim().replace(/^["']|["']$/g, "");
    if (key && value) result[key] = value;
  }
  return result;
}

async function discoverAssets(): Promise<AssetFrontmatter[]> {
  if (!REPO_DIR) return [];

  const { readdir, readFile: rf } = await import("node:fs/promises");
  const { existsSync: exists } = await import("node:fs");
  const { join: j } = await import("node:path");

  const assets: AssetFrontmatter[] = [];

  // Skills
  const skillsDir = j(REPO_DIR, "skills");
  if (exists(skillsDir)) {
    for (const entry of await readdir(skillsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const skillMd = j(skillsDir, entry.name, "SKILL.md");
      if (!exists(skillMd)) continue;
      try {
        const content = await rf(skillMd, "utf-8");
        const fm = parseFrontmatter(content);
        assets.push({
          name: fm["name"] ?? entry.name,
          description: fm["description"] ?? "",
          type: "skill",
          path: `skills/${entry.name}/SKILL.md`,
        });
      } catch {
        // skip unreadable files
      }
    }
  }

  // Agents
  const agentsDir = j(REPO_DIR, "agents");
  if (exists(agentsDir)) {
    for (const entry of await readdir(agentsDir, { withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith(".agent.md")) continue;
      const agentMd = j(agentsDir, entry.name);
      try {
        const content = await rf(agentMd, "utf-8");
        const fm = parseFrontmatter(content);
        const name = entry.name.replace(/\.agent\.md$/, "");
        assets.push({
          name: fm["name"] ?? name,
          description: fm["description"] ?? "",
          type: "agent",
          path: `agents/${entry.name}`,
        });
      } catch {
        // skip unreadable files
      }
    }
  }

  return assets;
}

// ── Tool: search-skills ─────────────────────────────────────────────────────

server.registerTool(
  "search-skills",
  {
    description:
      "Search Base Coat skills by name or description keyword. " +
      "Returns matching skills with name, description, and relative path. " +
      "Requires the server to be started with REPO_DIR set to the repository root. " +
      "Use when the user asks to find/list skills. Do not use to read full file content.",
    inputSchema: {
      query: z
        .string()
        .describe("Keyword to search for in skill name or description (case-insensitive)."),
      limit: z
        .number()
        .int()
        .min(1)
        .max(50)
        .default(10)
        .describe("Maximum number of results to return (default 10)."),
    },
  },
  async ({ query, limit }) => {
    if (!REPO_DIR) {
      return {
        content: [
          {
            type: "text" as const,
            text: "REPO_DIR environment variable is not set. Set it to the repository root to enable asset search.",
          },
        ],
      };
    }

    const assets = await discoverAssets();
    const q = query.toLowerCase();
    const skills = assets
      .filter(
        (a) =>
          a.type === "skill" &&
          (a.name.toLowerCase().includes(q) || a.description.toLowerCase().includes(q))
      )
      .slice(0, limit);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { query, count: skills.length, skills: skills.map((s) => ({ name: s.name, description: s.description, path: s.path })) },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: search-agents ─────────────────────────────────────────────────────

server.registerTool(
  "search-agents",
  {
    description:
      "Search Base Coat agents by name or description keyword. " +
      "Returns matching agents with name, description, and relative path. " +
      "Requires the server to be started with REPO_DIR set to the repository root. " +
      "Use when the user asks to find/list agents. Do not use to read full file content.",
    inputSchema: {
      query: z
        .string()
        .describe("Keyword to search for in agent name or description (case-insensitive)."),
      limit: z
        .number()
        .int()
        .min(1)
        .max(50)
        .default(10)
        .describe("Maximum number of results to return (default 10)."),
    },
  },
  async ({ query, limit }) => {
    if (!REPO_DIR) {
      return {
        content: [
          {
            type: "text" as const,
            text: "REPO_DIR environment variable is not set. Set it to the repository root to enable asset search.",
          },
        ],
      };
    }

    const assets = await discoverAssets();
    const q = query.toLowerCase();
    const agents = assets
      .filter(
        (a) =>
          a.type === "agent" &&
          (a.name.toLowerCase().includes(q) || a.description.toLowerCase().includes(q))
      )
      .slice(0, limit);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { query, count: agents.length, agents: agents.map((a) => ({ name: a.name, description: a.description, path: a.path })) },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: get-asset-details ─────────────────────────────────────────────────

server.registerTool(
  "get-asset-details",
  {
    description:
      "Return the full content of a Base Coat skill (SKILL.md) or agent (.agent.md) file. " +
      "Use search-skills or search-agents first to discover the exact asset path. " +
      "Requires the server to be started with REPO_DIR set to the repository root. " +
      "Use when the user explicitly asks for complete/full file contents.",
    inputSchema: {
      path: z
        .string()
        .describe(
          "Relative path to the asset file from the repo root " +
            "(e.g. 'skills/cqrs-event-sourcing/SKILL.md' or 'agents/security-analyst.agent.md')."
        ),
    },
  },
  async ({ path: assetPath }) => {
    if (!REPO_DIR) {
      return {
        content: [
          {
            type: "text" as const,
            text: "REPO_DIR environment variable is not set. Set it to the repository root to enable asset details.",
          },
        ],
      };
    }

    const { readFile: rf } = await import("node:fs/promises");
    const { existsSync: exists } = await import("node:fs");
    const { join: j, resolve: res, normalize: norm } = await import("node:path");

    // Prevent path traversal
    const safeBase = res(REPO_DIR);
    const fullPath = res(j(REPO_DIR, norm(assetPath)));
    if (!fullPath.startsWith(safeBase)) {
      return {
        content: [{ type: "text" as const, text: "Invalid path: traversal not allowed." }],
      };
    }

    if (!exists(fullPath)) {
      return {
        content: [{ type: "text" as const, text: `Asset not found: ${assetPath}` }],
      };
    }

    try {
      const content = await rf(fullPath, "utf-8");
      return {
        content: [{ type: "text" as const, text: content }],
      };
    } catch (err) {
      return {
        content: [{ type: "text" as const, text: `Failed to read asset: ${String(err)}` }],
      };
    }
  }
);

// ---------------------------------------------------------------------------
// Start — stdio (local dev) or HTTP (deployed)
// ---------------------------------------------------------------------------

async function toWebRequest(req: IncomingMessage): Promise<Request> {
  const headers = new Headers();
  for (let index = 0; index < req.rawHeaders.length; index += 2) {
    headers.append(req.rawHeaders[index], req.rawHeaders[index + 1]);
  }

  const method = req.method ?? "GET";
  const chunks: Buffer[] = [];
  if (method !== "GET" && method !== "HEAD") {
    const contentLength = Number(req.headers["content-length"]);
    if (
      Number.isFinite(contentLength) &&
      contentLength > MAX_REQUEST_BODY_BYTES
    ) {
      throw new RequestBodyTooLargeError();
    }

    let bodyLength = 0;
    for await (const chunk of req) {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      bodyLength += buffer.length;
      if (bodyLength > MAX_REQUEST_BODY_BYTES) {
        throw new RequestBodyTooLargeError();
      }
      chunks.push(buffer);
    }
  }

  const host = req.headers.host ?? "localhost";
  const url = new URL(req.url ?? "/", `http://${host}`);
  const body = chunks.length > 0 ? Buffer.concat(chunks) : undefined;

  return new Request(url, {
    method,
    headers,
    body,
  });
}

async function writeWebResponse(
  response: Response,
  res: ServerResponse
): Promise<void> {
  response.headers.forEach((value, name) => {
    res.setHeader(name, value);
  });
  res.writeHead(response.status);

  if (response.body === null) {
    res.end();
    return;
  }

  const reader = response.body.getReader();
  const cancelReader = (): void => {
    void reader.cancel().catch((error: unknown) => {
      const message = error instanceof Error ? error.message : String(error);
      process.stderr.write(`Failed to cancel HTTP response stream: ${message}\n`);
    });
  };
  res.once("close", cancelReader);

  try {
    while (!res.destroyed) {
      const { done, value } = await reader.read();
      if (done) {
        res.end();
        return;
      }
      if (!res.write(value)) {
        await once(res, "drain");
      }
    }
  } finally {
    res.off("close", cancelReader);
  }
}

async function startHttp(): Promise<void> {
  const port = parseInt(process.env.PORT ?? "8080", 10);

  // Stateless transport — each request is independent (no session affinity needed)
  const transport = new WebStandardStreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });

  await server.connect(transport);

  const httpServer = createServer(
    (req: IncomingMessage, res: ServerResponse) => {
      const handleRequest = async (): Promise<void> => {
        if (req.url === "/health") {
          res.writeHead(200, { "Content-Type": "text/plain" }).end("ok");
          return;
        }
        const request = await toWebRequest(req);
        const response = await transport.handleRequest(request);
        await writeWebResponse(response, res);
      };

      void handleRequest().catch((error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        process.stderr.write(`HTTP request failed: ${message}\n`);
        if (!res.headersSent) {
          const statusCode =
            error instanceof RequestBodyTooLargeError ? 413 : 500;
          const responseMessage =
            statusCode === 413 ? "Request body too large" : "Internal server error";
          res
            .writeHead(statusCode, { "Content-Type": "application/json" })
            .end(JSON.stringify({ error: responseMessage }));
        } else {
          res.destroy(error instanceof Error ? error : new Error(message));
        }
      });
    }
  );

  httpServer.listen(port, () => {
    process.stderr.write(`basecoat-metrics-mcp listening on port ${port}\n`);
  });
}

async function startStdio(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

async function main(): Promise<void> {
  if (process.env.MCP_TRANSPORT === "http" || process.env.NODE_ENV === "production") {
    await startHttp();
  } else {
    await startStdio();
  }
}

main().catch((err) => {
  console.error("basecoat-metrics-mcp failed to start:", err);
  process.exit(1);
});
