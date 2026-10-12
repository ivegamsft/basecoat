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
    writes: 0
  };
  for (const path of [SPEC, PRD]) f.blobs[`main:${path}`] = f.blobs[`${MERGE}:${path}`];
  change(f);
  const notFound = () => Object.assign(new Error("Not Found"), { status: 404 });
  const github = {
    paginate: async (method, params) => (await method(params)).data,
    graphql: async () => { if (f.lastEditedAt instanceof Error) throw f.lastEditedAt; return { repository: { issue: { lastEditedAt: f.lastEditedAt } } }; },
    rest: {
      issues: {
        getComment: async () => { if (!f.comment) throw notFound(); return { data: f.comment }; },
        get: async ({ issue_number }) => ({ data: issue_number === 7 ? f.issue : f.deps?.[issue_number] || { state: "open" } }),
        listComments: async () => ({ data: f.comments }),
        listEvents: async () => ({ data: f.events }),
        addAssignees: async () => { f.writes += 1; }
      },
      repos: {
        getCollaboratorPermissionLevel: async () => ({ data: { permission: f.permission } }),
        getContent: async ({ path, ref }) => { const blob = f.blobs[`${ref}:${path}`]; if (!blob) throw notFound(); if (blob instanceof Error) throw blob;
          return { data: { type: "file", sha: blob[0], content: Buffer.from(blob[1]).toString("base64") } }; }
      },
      pulls: { get: async () => ({ data: f.pr }), listFiles: async () => ({ data: f.files }) }
    }
  };
  return { f, run: () => handoff.resolveSpecHandoff({
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

test("a directive posted after dependency clearance proceeds", async () => {
  assert.equal((await fixture(x => { x.issue.body += "Blocked by #8\n"; x.deps = { 8: { state: "closed", closed_at: "2026-10-09T00:00:00Z" } }; }).run()).state, "handoff-pending");
});