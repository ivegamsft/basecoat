"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const approval = require("../.github/base-coat/scripts/approval-contract.cjs");
const handoff = require("../.github/base-coat/scripts/spec-handoff.cjs");

const OWNER = "octo";
const REPO = "basecoat";
const HEAD = "a".repeat(40);
const MERGE = "b".repeat(40);
const SPEC = "docs/spec/synthesized/issue-7-handoff.spec.md";
const PRD = "docs/prd/synthesized/issue-7-handoff.prd.md";
const doc = (status = "reviewed", extra = "") => `---\nissue: 7\nstatus: ${status}\n---\n\n# Doc\n${extra}`;

function fixture(change = () => {}) {
  const repoRef = { id: 1, full_name: `${OWNER}/${REPO}`, default_branch: "main" };
  const f = {
    issue: { number: 7, state: "open", assignees: [], labels: ["enhancement", "priority:medium", "approved"],
      body: `Delivery intent: implementation\n\n- Spec: https://github.com/${OWNER}/${REPO}/blob/${MERGE}/${SPEC}\n` },
    comment: { id: 99, body: `/approve-spec 12 ${HEAD}`, user: { login: "maintainer", type: "User" },
      created_at: "2026-10-10T00:00:00Z", updated_at: "2026-10-10T00:00:00Z",
      html_url: "https://github.com/octo/basecoat/issues/7#issuecomment-99",
      issue_url: `https://api.github.com/repos/${OWNER}/${REPO}/issues/7` },
    permission: "write",
    events: [{ event: "unlabeled", label: { name: "needs-info" }, created_at: "2026-10-09T00:00:00Z" }],
    lastEditedAt: "2026-10-09T12:00:00Z",
    comments: [],
    pr: { number: 12, merged: true, merged_at: "2026-10-09T18:00:00Z", merge_commit_sha: MERGE, head: { sha: HEAD, repo: repoRef },
      base: { ref: "main", repo: repoRef }, body: "Source issues: #7\n" },
    files: [{ filename: SPEC, status: "added" }, { filename: PRD, status: "added" }],
    blobs: { [`${MERGE}:${SPEC}`]: ["s1", doc("reviewed", `\n- PRD: \`${PRD}\`\n`)], [`${MERGE}:${PRD}`]: ["p1", doc()] },
    writes: 0, assign: () => { f.issue.assignees = [{ login: "copilot-swe-agent[bot]" }]; }
  };
  for (const path of [SPEC, PRD]) f.blobs[`main:${path}`] = f.blobs[`${MERGE}:${path}`];
  change(f);
  const notFound = () => Object.assign(new Error("Not Found"), { status: 404 });
  const github = {
    paginate: async (method, params) => (await method(params)).data,
    graphql: async query => {
      if (query.includes("suggestedActors")) return { repository: { suggestedActors: { nodes: [{ login: "copilot-swe-agent", id: "B1" }] } } };
      if (f.lastEditedAt instanceof Error) throw f.lastEditedAt;
      return { repository: { issue: { lastEditedAt: f.lastEditedAt } } };
    },
    request: async () => { f.writes += 1; return f.assign(); },
    rest: {
      issues: {
        getComment: async ({ comment_id }) => ({ data: (f.comment?.id === comment_id ? f.comment : f.comments.find(item => item.id === comment_id)) || (() => { throw notFound(); })() }),
        get: async ({ issue_number }) => ({ data: issue_number === 7 ? f.issue : f.deps?.[issue_number] || { state: "open" } }),
        listComments: async () => ({ data: f.comments }),
        createComment: async ({ body }) => ({ data: f.comments[f.comments.push({ id: 1000 + f.comments.length, body,
          user: { login: "github-actions[bot]", type: "Bot" }, created_at: "2026-10-12T00:00:00Z" }) - 1] }),
        updateComment: async ({ comment_id, body }) => ({ data: Object.assign(f.comments.find(item => item.id === comment_id), { body }) }),
        listEvents: async () => ({ data: f.events }),
        addAssignees: async () => { f.writes += 1; }
      },
      repos: {
        getCollaboratorPermissionLevel: async ({ username }) => ({ data: { permission: username === "drive-by" ? "read" : f.permission } }),
        getContent: async ({ path, ref }) => { const blob = f.blobs[`${ref}:${path}`]; if (!blob) throw notFound(); if (blob instanceof Error) throw blob;
          return { data: { type: "file", sha: blob[0], content: Buffer.from(blob[1]).toString("base64") } }; }
      },
      pulls: { get: async () => ({ data: f.pr }), listFiles: async () => ({ data: f.files }) }
    }
  };
  return { f, github, run: () => handoff.resolveSpecHandoff({
    github, owner: OWNER, repo: REPO, issueNumber: 7, commentId: 99, approval }) };
}

test("directive grammar is exact and distinct from /approve", () => {
  assert.deepEqual(handoff.parseSpecDirective(`  /approve-spec 12 ${HEAD.toUpperCase()}\n`), { prNumber: 12, headSha: HEAD });
  for (const body of ["/approve", `> /approve-spec 12 ${HEAD}`, `/approve-spec 12 ${HEAD}\nthanks`,
    `/approve-spec 0 ${HEAD}`, `/approve-spec 12 ${HEAD.slice(1)}`, `/approve-spec  12 ${HEAD}`, `/approve-spec #12 ${HEAD}`]) {
    assert.equal(handoff.parseSpecDirective(body), null, body);
  }
  assert.equal(approval.isExactIssueApproval(`/approve-spec 12 ${HEAD}`), false);
});

test("delivery intent requires exactly one implementation field", () => {
  assert.deepEqual(["Delivery intent: Implementation", "nothing", "Delivery intent: implementation\nDelivery intent: implementation",
    "Delivery intent:", "Delivery intent: logging-only"].map(handoff.deliveryIntent), ["implementation", "missing", "duplicate", "malformed", "logging-only"]);
});

test("valid merged binding is handoff-pending, read-only and stable across reruns", async () => {
  const { f, run } = fixture();
  const [first, second] = [await run(), await run()];
  assert.deepEqual([first.state, first.writesEnabled, f.writes], ["handoff-pending", false, 0]);
  assert.match(first.identity, /^[0-9a-f]{64}$/);
  assert.equal(second.identity, first.identity);
  assert.deepEqual([first.evidence.specBlob, first.evidence.prdBlob, first.evidence.mergeCommit], ["s1", "p1", MERGE]);
});

test("observed agent assignee is reported as assigned, not a second handoff", async () => {
  const { f, run } = fixture(x => { x.issue.assignees = [{ login: "copilot-swe-agent[bot]" }]; });
  assert.deepEqual([(await run()).state, f.writes], ["assigned", 0]);
});

const blockedCases = {
  "deleted directive": [x => { x.comment = null; }, "authorization-invalid", "directive-deleted"],
  "bot directive": [x => { x.comment.user = { login: "github-actions[bot]", type: "Bot" }; }, "authorization-invalid", "directive-not-exact"],
  "edited directive": [x => { x.comment.updated_at = "2026-10-11T00:00:00Z"; }, "authorization-invalid", "directive-edited"],
  "unqualified actor": [x => { x.permission = "read"; }, "authorization-invalid", "directive-actor-unqualified"],
  "unresolved dependency": [x => { x.issue.body += "Blocked by #8\n"; }, "blocked", "source-contract-incomplete"],
  "logging-only intent": [x => { x.issue.body = x.issue.body.replace("implementation", "logging-only"); }, "blocked", "delivery-intent-not-implementation"],
  "missing intent": [x => { x.issue.body = x.issue.body.replace("Delivery intent: implementation", ""); }, "blocked", "delivery-intent-missing"],
  "label removed after directive": [x => { x.events.push({ event: "unlabeled", label: { name: "deferred" }, created_at: "2026-10-11T00:00:00Z" }); }, "authorization-invalid", "directive-stale"],
  "body edited after directive": [x => { x.lastEditedAt = "2026-10-11T00:00:00Z"; }, "authorization-invalid", "directive-stale"],
  "unknown chronology": [x => { x.lastEditedAt = new Error("boom"); }, "blocked", "chronology-unknown"],
  "multiple source issues": [x => { x.pr.body = "Source issues: #7, #8\n"; }, "authorization-invalid", "spec-pr-not-bound"],
  "hidden source line only": [x => { x.pr.body = "<!--\nSource issues: #7\n-->\n```text\n```still-code\nSource issues: #7\n"; }, "authorization-invalid", "spec-pr-not-bound"],
  "issue reopened after directive": [x => { x.events.push({ event: "reopened", created_at: "2026-10-11T00:00:00Z" }); }, "authorization-invalid", "directive-stale"],
  "dependency cleared after directive": [x => { x.issue.body += "Blocked by #8\n"; x.deps = { 8: { state: "closed", closed_at: "2026-10-11T00:00:00Z" } }; }, "authorization-invalid", "directive-stale"],
  "dependency clearance time unknown": [x => { x.issue.body += "Blocked by #8\n"; x.deps = { 8: { state: "closed" } }; }, "blocked", "chronology-unknown"],
  "dependency comment edited after directive": [x => { x.comments.push({ body: "Depends on #8", created_at: "2026-10-08T00:00:00Z", updated_at: "2026-10-11T00:00:00Z" }); x.deps = { 8: { state: "closed", closed_at: "2026-10-01T00:00:00Z" } }; }, "authorization-invalid", "directive-stale"],
  "directive before merge": [x => { x.pr.merged_at = "2026-10-10T06:00:00Z"; }, "authorization-invalid", "directive-before-merge"],
  "inaccessible spec blob": [x => { x.blobs[`${MERGE}:${SPEC}`] = new Error("forbidden"); }, "blocked", "evidence-unavailable"],
  "fork head": [x => { x.pr.head.repo = { id: 2 }; }, "authorization-invalid", "spec-pr-not-bound"],
  "changed head": [x => { x.pr.head.sha = "c".repeat(40); }, "authorization-invalid", "approved-head-mismatch"],
  "unmerged spec": [x => { x.pr.merged = false; }, "spec-draft", "spec-pr-not-merged"],
  "unpinned spec url": [x => { x.issue.body = x.issue.body.replace(`blob/${MERGE}`, "blob/main"); }, "blocked", "spec-url-not-bound"],
  "draft spec status": [x => { x.blobs[`${MERGE}:${SPEC}`] = ["s1", doc("draft", `\n- PRD: \`${PRD}\`\n`)]; }, "blocked", "spec-documents-not-ready"],
  "deleted prd": [x => { delete x.blobs[`${MERGE}:${PRD}`]; }, "blocked", "spec-documents-not-ready"],
  "spec changed on main": [x => { x.blobs[`main:${SPEC}`] = ["s2", "changed"]; }, "authorization-invalid", "spec-blob-changed"]
};
for (const label of handoff.HOLD_LABELS) {
  blockedCases[`hold label ${label}`] = [x => { x.issue.labels.push({ name: label.toUpperCase() }); }, "blocked", null];
}

for (const [name, [change, state, reason]] of Object.entries(blockedCases)) {
  test(`fails closed: ${name}`, async () => {
    const { f, run } = fixture(change);
    const result = await run();
    assert.deepEqual([result.state, result.reason, result.identity, f.writes], [state, reason ?? result.reason, null, 0]);
  });
}

const assignment = require("../.github/base-coat/scripts/agent-assignment.cjs");
const NOW = new Date("2026-10-12T00:00:00Z");
const later = minutes => new Date(NOW.getTime() + minutes * 60000);
const canaryFor = (record, extra = {}) => JSON.stringify({ issue: record.issueNumber, directiveId: record.directiveId,
  ...Object.fromEntries(["specPr", "approvedHead", "mergeCommit", "specBlob", "prdBlob"].map(key => [key, record.evidence[key]])), ...extra });

async function runWorker(ctx, mode, canary, now = NOW, maxAttempts = 3) {
  const adapter = handoff.handoffApproval({ github: ctx.github, owner: OWNER, repo: REPO, issueNumber: 7, commentId: 99, approval, mode, canary });
  const state = await assignment.runAssignmentWorker({ github: ctx.github, owner: OWNER, repo: REPO, issueNumber: 7, approval: adapter, now, maxAttempts });
  if (adapter.record) await adapter.findLatestApproval().catch(() => null).then(() => handoff.writeHandoffRecord({ github: ctx.github, owner: OWNER, repo: REPO, record: adapter.record, gate: adapter.gate }));
  return state;
}

test("write gate defaults read-only and only the exact canary tuple can write", async () => {
  const record = await fixture().run();
  const canary = canaryFor(record);
  assert.equal(handoff.handoffWriteGate({ record }).reason, "read-only-mode");
  assert.equal(handoff.handoffWriteGate({ mode: "canary", record }).reason, "canary-unconfigured");
  assert.equal(handoff.handoffWriteGate({ mode: "enabled", canary, record }).reason, "mode-invalid");
  assert.deepEqual(handoff.handoffWriteGate({ mode: "canary", canary, record }), { allowed: true, reason: "canary-match" });
  for (const extra of [{ issue: 8 }, { directiveId: 100 }, { specBlob: "s2" }, { approvedHead: "c".repeat(40) }])
    assert.equal(handoff.handoffWriteGate({ mode: "canary", canary: canaryFor(record, extra), record }).allowed, false);
  assert.equal(handoff.handoffWriteGate({ mode: "general", canary: canaryFor(record, { issue: 8 }), record }).reason, "canary-unverified");
  assert.equal(handoff.handoffWriteGate({ mode: "canary", canary, record: { ...record, state: "blocked" } }).reason, "handoff-not-ready");
});

test("read-only mode never reaches the assignment request nor burns the directive", async () => {
  const ctx = fixture();
  const state = await runWorker(ctx, "read-only", "");
  assert.equal(ctx.f.writes, 0);
  assert.equal(state.attemptsConsumed, 0);
  assert.equal((await handoff.readHandoffRecord({ github: ctx.github, owner: OWNER, repo: REPO, issueNumber: 7 })).record.gate, "read-only-mode");
  assert.deepEqual([state.state, state.authorizationInvalidAt], ["blocked", null]);
  assert.equal((await runWorker(ctx, "canary", canaryFor(await ctx.run()), later(5))).state, "assigned");
  assert.equal(ctx.f.writes, 1);
});

test("canary assigns once through the shared worker with stable epoch and read-back", async () => {
  const ctx = fixture();
  const canary = canaryFor(await ctx.run());
  const first = await runWorker(ctx, "canary", canary);
  const second = await runWorker(ctx, "canary", canary, later(60));
  assert.deepEqual([first.state, first.verifiedAssignee, first.attemptsConsumed, ctx.f.writes], ["assigned", "copilot-swe-agent[bot]", 1, 1]);
  assert.equal(second.epoch, first.epoch);
  assert.equal(ctx.f.writes, 1);
  assert.equal(await handoff.verifyCanary({ github: ctx.github, owner: OWNER, repo: REPO, canary }), true);
  assert.equal((await handoff.readHandoffRecord({ github: ctx.github, owner: OWNER, repo: REPO, issueNumber: 7 })).record.state, "assigned");
  const other = { ...(await ctx.run()), issueNumber: 8, directiveId: 5 };
  assert.equal((await handoff.checkWriteGate({ github: ctx.github, owner: OWNER, repo: REPO, record: other, mode: "canary", canary })).allowed, false);
  assert.deepEqual(await handoff.checkWriteGate({ github: ctx.github, owner: OWNER, repo: REPO, record: other, mode: "general", canary }),
    { allowed: true, reason: "general" });
});

test("lost assignment response is re-read before any second request", async () => {
  let calls = 0;
  const ctx = fixture(x => { x.assign = () => { calls += 1; x.issue.assignees = [{ login: "copilot-swe-agent[bot]" }];
    if (calls === 1) throw Object.assign(new Error("lost"), { status: 502 }); }; });
  const canary = canaryFor(await ctx.run());
  assert.equal((await runWorker(ctx, "canary", canary)).state, "assigned");
  assert.equal((await runWorker(ctx, "canary", canary, later(5))).state, "assigned");
  assert.equal(ctx.f.writes, 1);
});

test("exhausted budget blocks the canary and cannot verify general writes", async () => {
  const ctx = fixture(x => { x.assign = () => { throw Object.assign(new Error("down"), { status: 503 }); }; });
  const canary = canaryFor(await ctx.run());
  let state;
  for (const minutes of [0, 5, 10, 15]) state = await runWorker(ctx, "canary", canary, later(minutes), 2);
  assert.deepEqual([state.state, state.blockReason, ctx.f.writes], ["blocked", "attempt-budget-exhausted", 2]);
  assert.equal(await handoff.verifyCanary({ github: ctx.github, owner: OWNER, repo: REPO, canary }), false);
});

test("merge discovery records readiness only for docs-only spec merges and binds directives to the merged PR number", async () => {
  const ctx = fixture();
  const pr = { ...ctx.f.pr, number: 12 };
  const ready = await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr, approval });
  assert.deepEqual([ready.state, ready.identity, ctx.f.writes], ["awaiting-directive", null, 0]);
  assert.match(ready.ownerAction, /`\/approve-spec 12 <approved-head-sha>`/);
  ctx.f.comments.push({ ...ctx.f.comment, id: 98, user: { login: "github-actions[bot]", type: "Bot" } }, { ...ctx.f.comment, id: 97, user: { login: "drive-by", type: "User" } });
  assert.equal((await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr, approval })).state, "awaiting-directive");
  ctx.f.comments.push(ctx.f.comment);
  assert.equal((await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr, approval })).state, "handoff-pending");
  const reused = await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr: { ...pr, number: 13 }, approval });
  assert.equal(reused.state, "awaiting-directive");
  for (const bad of [{ merged: false }, { merge_commit_sha: null }, { head: { ...pr.head, repo: { id: 999 } } }, { base: { ...pr.base, ref: "release" } }])
    assert.equal(await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr: { ...pr, ...bad }, approval }), null);
  ctx.f.files = [{ filename: SPEC, status: "removed" }];
  assert.equal(await handoff.discoverMergedSpec({ github: ctx.github, owner: OWNER, repo: REPO, pr, approval }), null);

  const implementation = fixture(x => { x.files.push({ filename: "scripts/implementation.cjs", status: "modified" }); });
  assert.equal(await handoff.discoverMergedSpec({ github: implementation.github, owner: OWNER, repo: REPO,
    pr: { ...implementation.f.pr, number: 12 }, approval }), null);

  for (const intent of ["Delivery intent: implementation\n",
    "Delivery intent: implementation\nDelivery intent: implementation\n"]) {
    const docsOnlyImplementation = fixture(x => { x.pr.body += intent; });
    const implementationPr = { ...docsOnlyImplementation.f.pr, number: 12 };
    assert.equal(handoff.routeIssue({ eventName: "pull_request", payload: { pull_request: implementationPr },
      owner: OWNER, repo: REPO, approval }), null);
    assert.equal(await handoff.discoverMergedSpec({ github: docsOnlyImplementation.github, owner: OWNER, repo: REPO,
      pr: implementationPr, approval }), null);
  }

  const implementationRename = fixture(x => {
    x.files = [{ filename: SPEC, previous_filename: "scripts/implementation.cjs", status: "renamed" },
      { filename: PRD, status: "added" }];
  });
  assert.equal(await handoff.discoverMergedSpec({ github: implementationRename.github, owner: OWNER, repo: REPO,
    pr: { ...implementationRename.f.pr, number: 12 }, approval }), null);

  const docsOnlyRename = fixture(x => {
    x.files = [{ filename: SPEC, previous_filename: "docs/spec/old-handoff.spec.md", status: "renamed" },
      { filename: PRD, status: "added" }];
  });
  assert.equal((await handoff.discoverMergedSpec({ github: docsOnlyRename.github, owner: OWNER, repo: REPO,
    pr: { ...docsOnlyRename.f.pr, number: 12 }, approval })).state, "awaiting-directive");
});

test("routing admits only exact human directives and visible bound spec merges", () => {
  const pr = { ...fixture().f.pr, number: 12 };
  const route = (eventName, payload) => handoff.routeIssue({ eventName, payload, owner: OWNER, repo: REPO, approval });
  const comment = body => ({ issue: { number: 7 }, comment: { body, user: { login: "maintainer", type: "User" } } });
  assert.equal(route("issue_comment", comment(`/approve-spec 12 ${"a".repeat(40)}`)), 7);
  assert.equal(route("issue_comment", comment("Review, then post /approve-spec 12 <approved-head-sha>")), null);
  assert.equal(route("issue_comment", { ...comment(`/approve-spec 12 ${"a".repeat(40)}`), comment: { body: `/approve-spec 12 ${"a".repeat(40)}`, user: { login: "github-actions[bot]", type: "Bot" } } }), null);
  assert.equal(route("pull_request", { pull_request: { ...pr, body: "Source issues: #7\n<!--\nSource issues: #8\n-->\n" } }), 7);
  assert.equal(route("pull_request", { pull_request: { ...pr, base: { ...pr.base, ref: "release" } } }), null);
});

test("each run reconciles the newest qualified directive, skipping later noise", async () => {
  const ctx = fixture();
  const args = { github: ctx.github, owner: OWNER, repo: REPO, issueNumber: 7, approval };
  assert.equal(await handoff.latestQualifiedHandoff(args), null);
  ctx.f.comments.push(ctx.f.comment, { ...ctx.f.comment, id: 120, user: { login: "drive-by", type: "User" } },
    { ...ctx.f.comment, id: 121, updated_at: "2026-10-11T00:00:00Z" }, { ...ctx.f.comment, id: 122, user: { login: "github-actions[bot]", type: "Bot" } });
  const latest = await handoff.latestQualifiedHandoff(args);
  assert.deepEqual([latest.directiveId, latest.state], [99, "handoff-pending"]);
});

test("stale or older snapshots never regress an assigned record", async () => {
  const ctx = fixture();
  const args = { github: ctx.github, owner: OWNER, repo: REPO };
  const record = await ctx.run();
  await handoff.writeHandoffRecord({ ...args, record: { ...record, state: "assigned" } });
  await handoff.writeHandoffRecord({ ...args, record });
  await handoff.writeHandoffRecord({ ...args, record: { ...record, state: "awaiting-directive", identity: null, directiveId: null } });
  await handoff.writeHandoffRecord({ ...args, record: { ...record, directiveId: 50, state: "blocked" } });
  assert.equal((await handoff.readHandoffRecord({ ...args, issueNumber: 7 })).record.state, "assigned");
  await handoff.writeHandoffRecord({ ...args, record: { ...record, directiveId: 120, state: "authorization-invalid" } });
  assert.equal((await handoff.readHandoffRecord({ ...args, issueNumber: 7 })).record.state, "authorization-invalid");
  await handoff.writeHandoffRecord({ ...args, record: { ...record, state: "awaiting-directive", identity: null, directiveId: null } });
  assert.equal((await handoff.readHandoffRecord({ ...args, issueNumber: 7 })).record.directiveId, 120);
});

test("unqualified directive noise never replaces the auditable record", async () => {
  const ctx = fixture(x => { x.permission = "read"; });
  const record = await ctx.run();
  assert.equal(await handoff.writeHandoffRecord({ github: ctx.github, owner: OWNER, repo: REPO, record }), null);
  assert.equal(ctx.f.comments.length, 0);
});

test("recovery recognizes only persisted spec directives", async () => {
  const ctx = fixture(x => { x.comments.push({ id: 5, body: "/approve" }); });
  const args = { github: ctx.github, owner: OWNER, repo: REPO };
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { originalApprovalId: 99 } }), 99);
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { originalApprovalId: 5 } }), null);
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { originalApprovalId: 404 } }), null);
  await handoff.writeHandoffRecord({ ...args, record: await ctx.run() });
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { issueNumber: 7, originalApprovalId: 404 } }), null);
  const directive = ctx.f.comment; ctx.f.comment = null;
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { issueNumber: 7, originalApprovalId: 99 } }), 99);
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { issueNumber: 7, originalApprovalId: 5 } }), null);
  await handoff.writeHandoffRecord({ ...args, record: await ctx.run(), gate: { reason: "canary-match" } });
  for (const originalApprovalId of [0, 5]) assert.equal(await handoff.priorSpecDirective({ ...args, status: { issueNumber: 7, originalApprovalId } }), 99);
  assert.equal(await handoff.priorSpecDirective({ ...args, status: { issueNumber: 7, originalApprovalId: 150 } }), null);
  ctx.f.comment = directive;
});

test("a directive posted after dependency clearance proceeds", async () => {
  assert.equal((await fixture(x => { x.issue.body += "Blocked by #8\n"; x.deps = { 8: { state: "closed", closed_at: "2026-10-09T00:00:00Z" } }; }).run()).state, "handoff-pending");
});

test("workflow wiring is read-only by default and reuses the shared worker", () => {
  const read = (...parts) => require("node:fs").readFileSync(require("node:path").join(__dirname, "..", ".github", ...parts), "utf8").replace(/\r\n/g, "\n");
  const [workflow, worker] = ["approved-spec-handoff.yml", "agent-assignment-worker.yml"].map(file => read("workflows", file));
  assert.equal(read("base-coat", "workflows", "approved-spec-handoff.yml"), workflow);
  assert.equal(read("base-coat", "workflows", "agent-assignment-worker.yml"), worker);
  assert.match(workflow, /contains\(github\.event\.comment\.body, '\/approve-spec'\)[\s\S]*pull_request\.base\.ref == github\.event\.repository\.default_branch[\s\S]*handoff\.routeIssue\([\s\S]*handoff\.latestQualifiedHandoff\(/);
  assert.match(workflow, /needs: route[\s\S]*group: basecoat-spec-handoff-\$\{\{ github\.repository_id \}\}-\$\{\{ needs\.route\.outputs\.issue \}\}/);
  assert.match(workflow, /BASECOAT_SPEC_HANDOFF_MODE \|\| 'read-only'/);
  assert.match(workflow, /if: needs\.resolve\.outputs\.dispatch == 'true'[\s\S]*uses: \.\/\.github\/workflows\/agent-assignment-worker\.yml/);
  assert.doesNotMatch(workflow, /issues\/\{issue_number\}\/assignees|addAssignees|variables/);
  assert.match(worker, /spec_handoff_comment_id:/);
  assert.match(worker, /group: basecoat-agent-assignment-\$\{\{ github\.repository_id \}\}-\$\{\{ inputs\.issue_number \}\}/);
  assert.match(worker, /handoff\.handoffApproval\([\s\S]*contract\.findLatestApproval\(\)\.catch[\s\S]*writeHandoffRecord/);
});
