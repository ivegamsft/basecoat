"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const source = fs.readFileSync(
  path.join(__dirname, "..", ".github", "workflows", "pr-conflict-routing.yml"), "utf8"
).replace(/\r\n/g, "\n");
const match = source.match(/^          script: \|\n((?: {12}[^\n]*(?:\n|$)|[ \t]*\n)*)/m);
assert.ok(match, "Production conflict routing script must be extracted.");
const script = match[1].split("\n").map(line => line.replace(/^ {12}/, "")).join("\n");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const execute = new AsyncFunction("github", "context", "core", "setTimeout", script);
const head = "a".repeat(40);

function fixture(options = {}) {
  const pr = {
    number: 42, draft: false, labels: [], mergeable: false, mergeable_state: "dirty",
    head: { sha: head }, base: { ref: "main" }, ...options.pr
  };
  const state = { pr, comments: [], calls: [], messages: [], delays: [], reads: 0 };
  const record = (name, args) => state.calls.push({ name, args });
  const github = {
    rest: {
      pulls: {
        async list(args) {
          record("list", args);
          if (options.listError) throw options.listError;
          return { data: [state.pr] };
        },
        async get(args) {
          record("get", args);
          state.reads += 1;
          return { data: options.refreshed || state.pr };
        }
      },
      issues: {
        async listComments(args) {
          record("listComments", args);
          return { data: state.comments };
        },
        async addLabels(args) {
          record("addLabels", args);
          if (!state.pr.labels.some(label => label.name === args.labels[0])) {
            state.pr.labels.push({ name: args.labels[0] });
          }
        },
        async createLabel(args) { record("createLabel", args); },
        async removeLabel(args) {
          record("removeLabel", args);
          state.pr.labels = state.pr.labels.filter(label => label.name !== args.name);
        },
        async createComment(args) {
          record("createComment", args);
          if (options.commentError) throw options.commentError;
          state.comments.push({ body: args.body });
        }
      }
    },
    async paginate(method, args) {
      return (await method(args)).data;
    }
  };
  return {
    state,
    async run() {
      await execute(
        github, { repo: { owner: "IBuySpy-Shared", repo: "basecoat" } },
        { info: message => state.messages.push(message) },
        (callback, milliseconds) => { state.delays.push(milliseconds); callback(); }
      );
    }
  };
}

const calls = (f, name) => f.state.calls.filter(call => call.name === name);

test("dirty PR routes exact head with shared procedure and no bypass", async () => {
  const f = fixture();
  await f.run();
  assert.equal(calls(f, "createComment").length, 1);
  assert.equal(calls(f, "addLabels").length, 1);
  const body = f.state.comments[0].body;
  assert.ok(body.includes(`<!-- pr-conflict-routing:v1 head=${head} -->`));
  assert.ok(body.includes("`main` (mergeable_state=dirty)"));
  for (const text of [
    "skills/merge-conflict-mediator/SKILL.md", "merge-coordinator", "isolated worktree",
    "take the base version", "pwsh scripts/generate-asset-manifest.ps1",
    "Preserve the PR intent", "do not drop base changes or bypass required checks",
    "attributed commit", "XXL approval and no-merge holds are unaffected"
  ]) assert.ok(body.includes(text), `Missing recovery instruction: ${text}`);
  assert.equal(f.state.messages.length, 1);
});

for (const [name, pr] of [
  ["draft", { draft: true }],
  ["XXL", { labels: [{ name: "size:XXL" }] }],
  ["no-merge", { labels: [{ name: "no-merge" }] }]
]) {
  test(`${name} PR never receives recovery writes or instruction`, async () => {
    const f = fixture({ pr });
    await f.run();
    assert.deepEqual(f.state.calls.map(call => call.name), ["list"]);
    assert.equal(f.state.messages.length, 0);
  });
}

test("same-head replay does not duplicate notification", async () => {
  const f = fixture();
  await f.run();
  await f.run();
  assert.equal(calls(f, "createComment").length, 1);
  assert.equal(calls(f, "addLabels").length, 1);
  assert.equal(f.state.messages.length, 1);
});

test("new conflicted head gets a distinct notification", async () => {
  const f = fixture();
  await f.run();
  f.state.pr.head = { sha: "b".repeat(40) };
  await f.run();
  assert.equal(calls(f, "createComment").length, 2);
  assert.ok(f.state.comments[1].body.includes(`head=${"b".repeat(40)}`));
});

test("unknown mergeability polls only three times without routing", async () => {
  const f = fixture({ pr: { mergeable: null, mergeable_state: "unknown" } });
  await f.run();
  assert.equal(f.state.reads, 3);
  assert.deepEqual(f.state.delays, [3000, 3000, 3000]);
  assert.equal(calls(f, "createComment").length, 0);
  assert.equal(calls(f, "addLabels").length, 0);
});

test("polling uses refreshed head when mergeability resolves", async () => {
  const options = { pr: { mergeable: null, mergeable_state: "unknown" } };
  const f = fixture(options);
  const refreshedHead = "c".repeat(40);
  options.refreshed = {
    ...f.state.pr, mergeable: false, mergeable_state: "dirty", head: { sha: refreshedHead }
  };
  await f.run();
  assert.equal(calls(f, "createComment").length, 1);
  assert.equal(f.state.reads, 1);
  assert.deepEqual(f.state.delays, [3000]);
  assert.ok(f.state.comments[0].body.includes(`head=${refreshedHead}`));
});

test("mergeable PR removes obsolete conflict label without notification", async () => {
  const f = fixture({
    pr: { mergeable: true, mergeable_state: "clean", labels: [{ name: "needs-conflict-fix" }] }
  });
  await f.run();
  assert.equal(calls(f, "removeLabel").length, 1);
  assert.equal(calls(f, "createComment").length, 0);
});

test("list failure propagates without writes", async () => {
  const error = Object.assign(new Error("PR enumeration denied"), { status: 403 });
  const f = fixture({ listError: error });
  await assert.rejects(f.run(), error);
  assert.deepEqual(f.state.calls.map(call => call.name), ["list"]);
});

test("notification failure never emits routed success; retry can recover", async () => {
  const options = { commentError: Object.assign(new Error("Comment denied"), { status: 403 }) };
  const f = fixture(options);
  await assert.rejects(f.run(), options.commentError);
  assert.equal(f.state.comments.length, 0);
  assert.equal(f.state.messages.length, 0);
  options.commentError = null;
  await f.run();
  assert.equal(f.state.comments.length, 1);
  assert.equal(f.state.messages.length, 1);
});
