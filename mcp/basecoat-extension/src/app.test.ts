import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { AddressInfo } from "node:net";
import { mkdir, readFile, rm } from "node:fs/promises";
import path from "node:path";
import { createApp } from "./app.js";
import { WriteToolService } from "./write-tools.js";

const testWorkRoot = path.resolve(process.cwd(), ".test-work");

async function withServer(run: (baseUrl: string) => Promise<void>) {
  const app = createApp({
    writeTools: new WriteToolService(testWorkRoot),
  });
  const server = app.listen(0);

  try {
    const address = server.address() as AddressInfo;
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

before(async () => {
  await rm(testWorkRoot, { recursive: true, force: true });
  await mkdir(testWorkRoot, { recursive: true });
});

test("GET /health returns ok payload", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`);
    assert.equal(response.status, 200);

    const body = (await response.json()) as {
      status: string;
      service: string;
      timestamp: string;
      rateLimit: { maxRequests: number; windowMs: number };
    };

    assert.equal(body.status, "ok");
    assert.equal(body.service, "basecoat-extension");
    assert.ok(Date.parse(body.timestamp));
    assert.ok(body.rateLimit.maxRequests > 0);
  });
});

test("POST /api/copilot/tools/scaffold returns confirmation preview", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/copilot/tools/scaffold`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        assetType: "skill",
        name: "Cloud Cost Optimizer",
        description: "Skill for cost recommendations",
      }),
    });

    assert.equal(response.status, 200);
    const body = (await response.json()) as {
      status: string;
      confirmationToken: string;
      preview: { files: Array<{ path: string; content: string }> };
    };

    assert.equal(body.status, "needs_confirmation");
    assert.ok(body.confirmationToken.length > 0);
    assert.equal(body.preview.files[0].path, "skills/cloud-cost-optimizer/SKILL.md");
    assert.ok(body.preview.files[0].content.includes("## Purpose"));
  });
});

test("POST /api/copilot/tools/scaffold confirm writes file", async () => {
  await withServer(async (baseUrl) => {
    const previewResponse = await fetch(`${baseUrl}/api/copilot/tools/scaffold`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        assetType: "agent",
        name: "test writer",
        description: "Scaffolded agent for test writer",
      }),
    });
    const previewBody = (await previewResponse.json()) as {
      confirmationToken: string;
    };

    const confirmResponse = await fetch(`${baseUrl}/api/copilot/tools/scaffold`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        assetType: "agent",
        name: "test writer",
        description: "Scaffolded agent for test writer",
        confirm: true,
        confirmationToken: previewBody.confirmationToken,
      }),
    });

    assert.equal(confirmResponse.status, 200);
    const confirmBody = (await confirmResponse.json()) as {
      status: string;
      result: { filesCreated: string[] };
    };
    assert.equal(confirmBody.status, "success");
    assert.equal(confirmBody.result.filesCreated[0], "agents/test-writer.agent.md");

    const fileContent = await readFile(path.resolve(testWorkRoot, "agents/test-writer.agent.md"), "utf-8");
    assert.ok(fileContent.includes("## Overview"));
  });
});

test("POST /api/copilot/tools/scaffold rejects invalid confirmation token", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/copilot/tools/scaffold`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        assetType: "prompt",
        name: "status update",
        confirm: true,
        confirmationToken: "bad-token",
      }),
    });

    assert.equal(response.status, 400);
    const body = (await response.json()) as {
      errorCode: string;
      message: string;
    };
    assert.equal(body.errorCode, "confirmation_mismatch");
    assert.match(body.message, /Invalid or stale/);
  });
});

test("POST /api/copilot/tools/validate returns confirmation payload", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/copilot/tools/validate`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        scope: "structure",
      }),
    });

    assert.equal(response.status, 200);
    const body = (await response.json()) as {
      status: string;
      preview: { scope: string; commands: Array<{ command: string; args: string[] }> };
    };
    assert.equal(body.status, "needs_confirmation");
    assert.equal(body.preview.scope, "structure");
    assert.equal(body.preview.commands.length, 1);
  });
});

test("POST /api/copilot/tools/create-pr reports external dependency blocker", async () => {
  await withServer(async (baseUrl) => {
    const previewResponse = await fetch(`${baseUrl}/api/copilot/tools/create-pr`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        title: "test title",
        body: "test body",
        headBranch: "feat/test-branch",
        baseBranch: "main",
        draft: false,
      }),
    });
    const previewBody = (await previewResponse.json()) as {
      confirmationToken: string;
    };

    const response = await fetch(`${baseUrl}/api/copilot/tools/create-pr`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        title: "test title",
        body: "test body",
        headBranch: "feat/test-branch",
        baseBranch: "main",
        draft: false,
        confirm: true,
        confirmationToken: previewBody.confirmationToken,
      }),
    });

    assert.equal(response.status, 503);
    const body = (await response.json()) as {
      status: string;
      errorCode: string;
      message: string;
    };
    assert.equal(body.status, "blocked");
    assert.equal(body.errorCode, "blocked_external_dependency");
    assert.match(body.message, /issue #1073/i);
  });
});

test("rate limiting enforces request cap for copilot routes", async () => {
  const originalMax = process.env.RATE_LIMIT_MAX_REQUESTS;
  const originalWindow = process.env.RATE_LIMIT_WINDOW_MS;
  process.env.RATE_LIMIT_MAX_REQUESTS = "1";
  process.env.RATE_LIMIT_WINDOW_MS = "60000";

  try {
    await withServer(async (baseUrl) => {
      const firstResponse = await fetch(`${baseUrl}/api/copilot/chat`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-github-user-id": "test-user" },
        body: JSON.stringify({}),
      });
      assert.equal(firstResponse.status, 501);

      const secondResponse = await fetch(`${baseUrl}/api/copilot/chat`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-github-user-id": "test-user" },
        body: JSON.stringify({}),
      });
      assert.equal(secondResponse.status, 429);
    });
  } finally {
    if (originalMax === undefined) {
      delete process.env.RATE_LIMIT_MAX_REQUESTS;
    } else {
      process.env.RATE_LIMIT_MAX_REQUESTS = originalMax;
    }

    if (originalWindow === undefined) {
      delete process.env.RATE_LIMIT_WINDOW_MS;
    } else {
      process.env.RATE_LIMIT_WINDOW_MS = originalWindow;
    }
  }
});

after(async () => {
  await rm(testWorkRoot, { recursive: true, force: true });
});

