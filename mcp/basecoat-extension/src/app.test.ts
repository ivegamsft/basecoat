import assert from "node:assert/strict";
import { test } from "node:test";
import { AddressInfo } from "node:net";
import { createApp } from "./app.js";

test("GET /health returns ok payload", async () => {
  const app = createApp();
  const server = app.listen(0);

  try {
    const address = server.address() as AddressInfo;
    const response = await fetch(`http://127.0.0.1:${address.port}/health`);
    assert.equal(response.status, 200);

    const body = (await response.json()) as {
      status: string;
      service: string;
      timestamp: string;
    };

    assert.equal(body.status, "ok");
    assert.equal(body.service, "basecoat-extension");
    assert.ok(Date.parse(body.timestamp));
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
});
