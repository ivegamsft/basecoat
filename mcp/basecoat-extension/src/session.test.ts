import assert from "node:assert/strict";
import { test } from "node:test";
import { SessionStore } from "./session.js";

test("generateStateParam creates valid state and session", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();

  assert.ok(state);
  assert.equal(typeof state, "string");
  assert.ok(state.length > 0);
  assert.equal(store.getSessionCount(), 1);
});

test("validateState returns session for valid state", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session = store.validateState(state);

  assert.ok(session);
  assert.equal(session.state, state);
  assert.ok(session.sessionId);
  assert.ok(session.expiresAt > Date.now());
  assert.ok(!session.userId);
  assert.ok(!session.token);
});

test("validateState rejects invalid state", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const session = store.validateState("invalid-state");

  assert.equal(session, null);
});

test("validateState rejects expired state", async () => {
  const store = new SessionStore({ ttlMs: 10 });
  store.stopCleanupInterval();

  const state = store.generateStateParam();

  await new Promise((resolve) => setTimeout(resolve, 20));

  const session = store.validateState(state);

  assert.equal(session, null);
});

test("storeUserSession associates token with session", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const userId = "user-123";
  const token = "github-token-abc";

  const session = store.storeUserSession(state, userId, token);

  assert.ok(session);
  assert.equal(session.userId, userId);
  assert.equal(session.token, token);
  assert.equal(session.state, state);
});

test("storeUserSession rejects expired state", async () => {
  const store = new SessionStore({ ttlMs: 10 });
  store.stopCleanupInterval();

  const state = store.generateStateParam();

  await new Promise((resolve) => setTimeout(resolve, 20));

  const session = store.storeUserSession(state, "user-123", "token-abc");

  assert.equal(session, null);
});

test("getSession retrieves valid session", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session1 = store.getSession(state);

  assert.ok(session1);
  assert.equal(session1.state, state);

  const session2 = store.getSession(state);

  assert.ok(session2);
  assert.equal(session2.state, state);
});

test("getSession returns null for invalid state", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const session = store.getSession("invalid-state");

  assert.equal(session, null);
});

test("getSessionById retrieves session by ID", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session1 = store.getSession(state);

  assert.ok(session1);

  const session2 = store.getSessionById(session1.sessionId);

  assert.ok(session2);
  assert.equal(session2.sessionId, session1.sessionId);
  assert.equal(session2.state, session1.state);
});

test("deleteSession removes session", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();

  assert.equal(store.getSessionCount(), 1);

  const deleted = store.deleteSession(state);

  assert.equal(deleted, true);
  assert.equal(store.getSessionCount(), 0);
  assert.equal(store.getSession(state), null);
});

test("deleteSession returns false for unknown state", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const deleted = store.deleteSession("unknown-state");

  assert.equal(deleted, false);
});

test("cleanup removes expired sessions", async () => {
  const store = new SessionStore({ ttlMs: 10 });
  store.stopCleanupInterval();

  const state1 = store.generateStateParam();
  const state2 = store.generateStateParam();

  assert.equal(store.getSessionCount(), 2);

  await new Promise((resolve) => setTimeout(resolve, 20));

  assert.equal(store.getSession(state1), null);
  assert.equal(store.getSession(state2), null);
  assert.equal(store.getSessionCount(), 0);
});

test("concurrent state generation creates unique sessions", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const states = new Set<string>();
  const sessionIds = new Set<string>();

  for (let i = 0; i < 100; i++) {
    const state = store.generateStateParam();
    const session = store.getSession(state);

    assert.ok(session);
    states.add(state);
    sessionIds.add(session.sessionId);
  }

  assert.equal(states.size, 100);
  assert.equal(sessionIds.size, 100);
  assert.equal(store.getSessionCount(), 100);
});

test("concurrent state validation handles racing requests", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const states = Array.from({ length: 10 }, () =>
    store.generateStateParam()
  );

  const validationResults = states.map((state) =>
    store.validateState(state)
  );

  assert.equal(validationResults.length, 10);
  validationResults.forEach((result) => {
    assert.ok(result);
  });

  const secondValidationResults = states.map((state) =>
    store.validateState(state)
  );

  assert.equal(secondValidationResults.length, 10);
  secondValidationResults.forEach((result) => {
    assert.equal(result, null);
  });
});

test("storeUserSession prevents overwriting valid data", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session1 = store.storeUserSession(state, "user-1", "token-1");

  assert.ok(session1);
  assert.equal(session1.userId, "user-1");
  assert.equal(session1.token, "token-1");

  const session2 = store.storeUserSession(state, "user-2", "token-2");

  assert.ok(session2);
  assert.equal(session2.userId, "user-2");
  assert.equal(session2.token, "token-2");
});

test("sessions expire after TTL", async () => {
  const store = new SessionStore({ ttlMs: 50 });
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session1 = store.getSession(state);

  assert.ok(session1);

  await new Promise((resolve) => setTimeout(resolve, 100));

  const session2 = store.getSession(state);

  assert.equal(session2, null);
});

test("validateState is consumed only once (CSRF pattern)", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state = store.generateStateParam();
  const session1 = store.validateState(state);

  assert.ok(session1);

  const session2 = store.validateState(state);

  assert.equal(session2, null);
});

test("multiple independent sessions coexist", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  const state1 = store.generateStateParam();
  const state2 = store.generateStateParam();
  const state3 = store.generateStateParam();

  const session1 = store.storeUserSession(state1, "user-1", "token-1");
  const session2 = store.storeUserSession(state2, "user-2", "token-2");

  assert.ok(session1);
  assert.ok(session2);

  assert.equal(session1.userId, "user-1");
  assert.equal(session2.userId, "user-2");

  assert.equal(store.getSessionCount(), 3);

  const retrieved1 = store.getSession(state1);
  const retrieved2 = store.getSession(state2);
  const retrieved3 = store.getSession(state3);

  assert.equal(retrieved1?.userId, "user-1");
  assert.equal(retrieved2?.userId, "user-2");
  assert.ok(!retrieved3?.userId);
});

test("getSessionCount reflects actual session count", () => {
  const store = new SessionStore();
  store.stopCleanupInterval();

  assert.equal(store.getSessionCount(), 0);

  store.generateStateParam();
  assert.equal(store.getSessionCount(), 1);

  store.generateStateParam();
  assert.equal(store.getSessionCount(), 2);

  const state = store.generateStateParam();
  assert.equal(store.getSessionCount(), 3);

  store.deleteSession(state);
  assert.equal(store.getSessionCount(), 2);
});
