import assert from "node:assert/strict";
import { test } from "node:test";
import { GitHubOAuthManager } from "./github-oauth.js";
import { createHmac } from "crypto";

test("GitHubOAuthManager state generation and validation", () => {
  const manager = new GitHubOAuthManager();

  // Generate unique states
  const state1 = manager.generateState();
  const state2 = manager.generateState();

  assert.equal(state1.length, 64);
  assert.equal(state2.length, 64);
  assert.match(state1, /^[a-f0-9]+$/);
  assert.match(state2, /^[a-f0-9]+$/);
  assert.notEqual(state1, state2);

  // Valid fresh state validates successfully
  assert.equal(manager.validateState(state1), true);

  // Already consumed state fails validation
  assert.equal(manager.validateState(state1), false);

  // Unknown state fails validation
  const unknownState = "0".repeat(64);
  assert.equal(manager.validateState(unknownState), false);
});

test("GitHubOAuthManager webhook signature validation", () => {
  const manager = new GitHubOAuthManager();
  const secret = "test-webhook-secret";
  const payload = JSON.stringify({ action: "opened", repository: { name: "test-repo" } });

  // Valid signature passes
  const validSignature =
    "sha256=" + createHmac("sha256", secret).update(payload).digest("hex");
  assert.equal(manager.validateWebhookSignature(payload, validSignature, secret), true);

  // Invalid signature fails
  const invalidSignature = "sha256=0000000000000000000000000000000000000000000000000000000000000000";
  assert.equal(manager.validateWebhookSignature(payload, invalidSignature, secret), false);

  // Mismatched payload fails
  const differentPayload = JSON.stringify({ action: "closed", repository: { name: "different" } });
  assert.equal(
    manager.validateWebhookSignature(differentPayload, validSignature, secret),
    false
  );

  // Malformed signature fails
  assert.equal(manager.validateWebhookSignature(payload, "invalid-format", secret), false);

  // Empty signature fails
  assert.equal(manager.validateWebhookSignature(payload, "", secret), false);
});

test("GitHubOAuthManager stores and retrieves user tokens", () => {
  const manager = new GitHubOAuthManager();
  const state = manager.generateState();

  // Store user token
  manager.storeUserToken(state, "user123", "token-abc");

  // Token should be retrievable before validation
  let token = manager.getUserToken(state);
  assert.ok(token);

  // After validation, token entry is deleted
  manager.validateState(state);
  token = manager.getUserToken(state);
  assert.equal(token, null);
});

test("GitHubOAuthManager handles invalid state gracefully", () => {
  const manager = new GitHubOAuthManager();

  // Empty state fails
  assert.equal(manager.validateState(""), false);

  // Unknown state fails
  assert.equal(manager.validateState("unknown"), false);

  // Store token for unknown state doesn't throw
  manager.storeUserToken("unknown", "user", "token");
  assert.ok(true);

  // Get token for unknown state returns null
  assert.equal(manager.getUserToken("unknown"), null);
});
