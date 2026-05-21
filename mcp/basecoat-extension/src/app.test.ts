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

// GitHub OAuth tests
test("GET /api/github/oauth/request returns authUrl and state", async () => {
  const originalClientId = process.env.BASECOAT_EXTENSION_CLIENT_ID;
  const originalBaseUrl = process.env.BASECOAT_EXTENSION_BASE_URL;

  try {
    process.env.BASECOAT_EXTENSION_CLIENT_ID = "test-client-id";
    process.env.BASECOAT_EXTENSION_BASE_URL = "http://localhost:3000";

    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/github/oauth/request`);
      assert.equal(response.status, 200);

      const body = (await response.json()) as {
        authUrl: string;
        state: string;
      };

      // Basic sanity checks
      assert.ok(body);
      assert.ok(body.authUrl);
      assert.ok(body.state);
      assert.ok(typeof body.authUrl === "string");
      assert.ok(typeof body.state === "string");
    });
  } finally {
    if (originalClientId) {
      process.env.BASECOAT_EXTENSION_CLIENT_ID = originalClientId;
    } else {
      delete process.env.BASECOAT_EXTENSION_CLIENT_ID;
    }

    if (originalBaseUrl) {
      process.env.BASECOAT_EXTENSION_BASE_URL = originalBaseUrl;
    } else {
      delete process.env.BASECOAT_EXTENSION_BASE_URL;
    }
  }
});

test("GET /api/github/oauth/request returns 500 when client_id missing", async () => {
  const originalClientId = process.env.BASECOAT_EXTENSION_CLIENT_ID;

  try {
    delete process.env.BASECOAT_EXTENSION_CLIENT_ID;

    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/github/oauth/request`);
      assert.equal(response.status, 500);

      const body = (await response.json()) as {
        error: string;
        detail: string;
      };

      assert.equal(body.error, "server_error");
      assert.match(body.detail, /not configured/i);
    });
  } finally {
    if (originalClientId) {
      process.env.BASECOAT_EXTENSION_CLIENT_ID = originalClientId;
    }
  }
});

test("GET /api/github/oauth/callback with valid state returns 200", async () => {
  const originalClientId = process.env.BASECOAT_EXTENSION_CLIENT_ID;

  try {
    process.env.BASECOAT_EXTENSION_CLIENT_ID = "test-client-id";

    await withServer(async (baseUrl) => {
      // First, generate a valid state
      const requestResponse = await fetch(`${baseUrl}/api/github/oauth/request`);
      const requestBody = (await requestResponse.json()) as { state: string };
      const validState = requestBody.state;

      // Then use that state in the callback
      const response = await fetch(
        `${baseUrl}/api/github/oauth/callback?code=test-code&state=${encodeURIComponent(validState)}`
      );
      assert.equal(response.status, 200);

      const body = (await response.json()) as {
        status: string;
        message: string;
        code: string;
        state: string;
      };

      assert.equal(body.status, "authorized");
      assert.ok(body.message.includes("OAuth callback received"));
      assert.equal(body.code, "test-code");
      assert.equal(body.state, validState);
    });
  } finally {
    if (originalClientId) {
      process.env.BASECOAT_EXTENSION_CLIENT_ID = originalClientId;
    } else {
      delete process.env.BASECOAT_EXTENSION_CLIENT_ID;
    }
  }
});

test("GET /api/github/oauth/callback with invalid state returns 403", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(
      `${baseUrl}/api/github/oauth/callback?code=test-code&state=invalid-state-that-was-never-generated`
    );
    assert.equal(response.status, 403);

    const body = (await response.json()) as {
      error: string;
      detail: string;
    };

    assert.equal(body.error, "invalid_state");
    assert.match(body.detail, /invalid or expired/i);
  });
});

test("GET /api/github/oauth/callback validates state is consumed after use", async () => {
  const originalClientId = process.env.BASECOAT_EXTENSION_CLIENT_ID;

  try {
    process.env.BASECOAT_EXTENSION_CLIENT_ID = "test-client-id";

    await withServer(async (baseUrl) => {
      // Generate a valid state
      const requestResponse = await fetch(`${baseUrl}/api/github/oauth/request`);
      const requestBody = (await requestResponse.json()) as { state: string };
      const validState = requestBody.state;

      // First callback with valid state should succeed
      const response1 = await fetch(
        `${baseUrl}/api/github/oauth/callback?code=test-code&state=${encodeURIComponent(validState)}`
      );
      assert.equal(response1.status, 200);

      // Second callback with same state should fail (state already consumed)
      const response2 = await fetch(
        `${baseUrl}/api/github/oauth/callback?code=test-code-2&state=${encodeURIComponent(validState)}`
      );
      assert.equal(response2.status, 403);

      const body = (await response2.json()) as {
        error: string;
        detail: string;
      };

      assert.equal(body.error, "invalid_state");
    });
  } finally {
    if (originalClientId) {
      process.env.BASECOAT_EXTENSION_CLIENT_ID = originalClientId;
    } else {
      delete process.env.BASECOAT_EXTENSION_CLIENT_ID;
    }
  }
});

test("GET /api/github/oauth/callback with missing params returns 400", async () => {
  await withServer(async (baseUrl) => {
    // Missing state
    const response1 = await fetch(`${baseUrl}/api/github/oauth/callback?code=test-code`);
    assert.equal(response1.status, 400);

    const body1 = (await response1.json()) as {
      error: string;
      detail: string;
    };

    assert.equal(body1.error, "invalid_request");

    // Missing code
    const response2 = await fetch(`${baseUrl}/api/github/oauth/callback?state=test-state`);
    assert.equal(response2.status, 400);

    const body2 = (await response2.json()) as {
      error: string;
      detail: string;
    };

    assert.equal(body2.error, "invalid_request");
  });
});

test("POST /api/github/webhook with valid signature returns 202", async () => {
  const { createHmac } = await import("crypto");
  const originalSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;

  try {
    const webhookSecret = "test-webhook-secret-key";
    process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = webhookSecret;

    await withServer(async (baseUrl) => {
      const payload = JSON.stringify({ action: "opened", repository: { name: "test-repo" } });
      const signature =
        "sha256=" +
        createHmac("sha256", webhookSecret).update(payload).digest("hex");

      const response = await fetch(`${baseUrl}/api/github/webhook`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-hub-signature-256": signature,
          "x-github-event": "pull_request",
        },
        body: payload,
      });

      assert.equal(response.status, 202);

      const body = (await response.json()) as {
        status: string;
        message: string;
      };

      assert.equal(body.status, "accepted");
      assert.ok(body.message.includes("Webhook received"));
    });
  } finally {
    if (originalSecret) {
      process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = originalSecret;
    } else {
      delete process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;
    }
  }
});

test("POST /api/github/webhook with invalid signature returns 403", async () => {
  const originalSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;

  try {
    process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = "correct-secret";

    await withServer(async (baseUrl) => {
      const payload = JSON.stringify({ action: "opened", repository: { name: "test-repo" } });
      const incorrectSignature = "sha256=0000000000000000000000000000000000000000000000000000000000000000";

      const response = await fetch(`${baseUrl}/api/github/webhook`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-hub-signature-256": incorrectSignature,
          "x-github-event": "pull_request",
        },
        body: payload,
      });

      assert.equal(response.status, 403);

      const body = (await response.json()) as {
        error: string;
        detail: string;
      };

      assert.equal(body.error, "forbidden");
      assert.match(body.detail, /signature validation failed/i);
    });
  } finally {
    if (originalSecret) {
      process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = originalSecret;
    } else {
      delete process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;
    }
  }
});

test("POST /api/github/webhook with missing signature returns 403", async () => {
  const originalSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;

  try {
    process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = "test-secret";

    await withServer(async (baseUrl) => {
      const payload = JSON.stringify({ action: "opened", repository: { name: "test-repo" } });

      const response = await fetch(`${baseUrl}/api/github/webhook`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-github-event": "pull_request",
        },
        body: payload,
      });

      assert.equal(response.status, 403);

      const body = (await response.json()) as {
        error: string;
        detail: string;
      };

      assert.equal(body.error, "forbidden");
    });
  } finally {
    if (originalSecret) {
      process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = originalSecret;
    } else {
      delete process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;
    }
  }
});

test("POST /api/github/webhook with malformed signature returns 403", async () => {
  const originalSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;

  try {
    process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = "test-secret";

    await withServer(async (baseUrl) => {
      const payload = JSON.stringify({ action: "opened", repository: { name: "test-repo" } });

      const response = await fetch(`${baseUrl}/api/github/webhook`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-hub-signature-256": "invalid-format",
          "x-github-event": "pull_request",
        },
        body: payload,
      });

      assert.equal(response.status, 403);

      const body = (await response.json()) as {
        error: string;
        detail: string;
      };

      assert.equal(body.error, "forbidden");
    });
  } finally {
    if (originalSecret) {
      process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET = originalSecret;
    } else {
      delete process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;
    }
  }
});

test("GET /api/github/setup with installation_id returns 200", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/github/setup?installation_id=12345`);
    assert.equal(response.status, 200);

    const body = (await response.json()) as {
      status: string;
      message: string;
      installationId: string;
    };

    assert.equal(body.status, "setup_received");
    assert.ok(body.message.includes("setup initiated"));
    assert.equal(body.installationId, "12345");
  });
});

test("GET /api/github/setup with missing installation_id returns 200 with unknown", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/github/setup`);
    assert.equal(response.status, 200);

    const body = (await response.json()) as {
      status: string;
      message: string;
      installationId: string;
    };

    assert.equal(body.status, "setup_received");
    assert.equal(body.installationId, "unknown");
  });
});

after(async () => {
  await rm(testWorkRoot, { recursive: true, force: true });
});

