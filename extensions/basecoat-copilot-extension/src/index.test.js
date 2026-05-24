import { createServer } from "node:http";
import test from "node:test";
import assert from "node:assert/strict";
import { createRequestHandler } from "./index.js";

function buildMcpResponse(textPayload) {
  return {
    jsonrpc: "2.0",
    id: "1",
    result: {
      content: [
        {
          type: "text",
          text: typeof textPayload === "string" ? textPayload : JSON.stringify(textPayload)
        }
      ]
    }
  };
}

async function withServer(handler, runTest) {
  const server = createServer(handler);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  try {
    await runTest(baseUrl);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
  }
}

test("POST /api/extension/search returns combined search results", async () => {
  const calls = [];
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    fetchImpl: async (_url, init) => {
      const body = JSON.parse(init.body);
      calls.push(body.params.name);
      if (body.params.name === "search-skills") {
        return Response.json(buildMcpResponse({ count: 1, skills: [{ name: "azure-ai" }] }));
      }
      if (body.params.name === "search-agents") {
        return Response.json(buildMcpResponse({ count: 1, agents: [{ name: "api-designer" }] }));
      }
      throw new Error("unexpected tool");
    }
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/search`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ query: "api", type: "all", limit: 5 })
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.query, "api");
    assert.deepEqual(calls, ["search-skills", "search-agents"]);
    assert.equal(payload.results.skills.count, 1);
    assert.equal(payload.results.agents.count, 1);
  });
});

test("GET /api/extension/metrics uses get-latest-metrics by default", async () => {
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    fetchImpl: async (_url, init) => {
      const body = JSON.parse(init.body);
      assert.equal(body.params.name, "get-latest-metrics");
      return Response.json(buildMcpResponse({ organization: "IBuySpy-Shared" }));
    }
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/metrics`);
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.view, "latest");
    assert.equal(payload.result.organization, "IBuySpy-Shared");
  });
});

test("POST /api/extension/details proxies get-asset-details", async () => {
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    fetchImpl: async (_url, init) => {
      const body = JSON.parse(init.body);
      assert.equal(body.params.name, "get-asset-details");
      assert.equal(body.params.arguments.path, "agents/api-designer.agent.md");
      return Response.json(buildMcpResponse({ content: "# api-designer" }));
    }
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/details`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ path: "agents/api-designer.agent.md" })
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.path, "agents/api-designer.agent.md");
    assert.equal(payload.result.content, "# api-designer");
  });
});

test("POST /api/extension/search returns 400 for invalid payload", async () => {
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    fetchImpl: async () => {
      throw new Error("should not be called");
    }
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/search`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ type: "all" })
    });

    assert.equal(response.status, 400);
    const payload = await response.json();
    assert.equal(payload.error, "invalid_request");
  });
});

test("GET /api/extension/metrics returns 504 on upstream timeout", async () => {
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    timeoutMs: 25,
    fetchImpl: (_url, init) =>
      new Promise((_resolve, reject) => {
        init.signal.addEventListener("abort", () => {
          const error = new Error("aborted");
          error.name = "AbortError";
          reject(error);
        });
      })
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/metrics`);
    assert.equal(response.status, 504);
    const payload = await response.json();
    assert.equal(payload.error, "upstream_timeout");
  });
});

test("POST /api/extension/details returns mapped upstream HTTP error", async () => {
  const handler = createRequestHandler({
    endpoint: "http://mcp.test",
    fetchImpl: async () => new Response("service unavailable", { status: 503, statusText: "Service Unavailable" })
  });

  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/extension/details`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ path: "skills/azure-ai/SKILL.md" })
    });

    assert.equal(response.status, 503);
    const payload = await response.json();
    assert.equal(payload.error, "upstream_error");
  });
});
