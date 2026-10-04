"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");
const preapproval = require("../.github/base-coat/scripts/ship-it/preapproval-evidence.cjs");
const preapprovalSource = fs.readFileSync(
  require.resolve("../.github/base-coat/scripts/ship-it/preapproval-evidence.cjs"),
  "utf8"
);

const owner = "IBuySpy-Shared";
const repo = "basecoat";
const sourceRepo = `${owner}/${repo}`;
const runId = "37170000000";
const runStartedAt = "2026-10-03T10:00:00.000Z";
const specCommit = "0123456789abcdef0123456789abcdef01234567";
const specRef =
  `https://github.com/${sourceRepo}/blob/${specCommit}/docs/spec/synthesized/preapproval.spec.md`;
const specContent = "# Approved contract\n\nA pinned specification fixture.\n";

function makeFixture(overrides = {}) {
  const state = { ...overrides };
  const issue = {
    number: 99,
    state: "open",
    url: `https://api.github.com/repos/${sourceRepo}/issues/99`,
    html_url: `https://github.com/${sourceRepo}/issues/99`,
    labels: [{ name: "approved" }],
    body: [
      "## Intent Contract",
      "",
      "- Intent: `ship-it`",
      "- Goal: Deliver the approved release",
      "- Scope: Deliver the approved release",
      `- Repository: ${sourceRepo}`,
      "- Risk band: `medium`",
      "- Profile: `team-dev`",
      `- Spec reference: ${specRef}`,
      "",
      "## Governance Checklist",
      ""
    ].join("\n"),
    ...overrides.issue
  };
  const comment = {
    id: 7001,
    issue_url: issue.url,
    html_url: `https://github.com/${sourceRepo}/issues/99#issuecomment-7001`,
    body: "/approve",
    user: { login: "maintainer", type: "User" },
    created_at: "2026-10-03T09:59:59.999Z",
    updated_at: "2026-10-03T09:59:59.999Z",
    ...overrides.comment
  };
  const permissions = new Map([
    ["maintainer", { permission: "write" }],
    ["runner", { permission: "write" }]
  ]);
  const editTimes = {
    createdAt: "2026-10-03T09:00:00.000Z",
    lastEditedAt: null,
    ...overrides.editTimes
  };
  const workflowRun = {
    id: Number(runId),
    created_at: runStartedAt,
    repository: { full_name: sourceRepo },
    actor: { login: "runner" },
    ...overrides.workflowRun
  };
  const api = {
    async getIssue(requestOwner, requestRepo, number) {
      assert.equal(`${requestOwner}/${requestRepo}`.toLowerCase(), sourceRepo.toLowerCase());
      assert.equal(number, issue.number);
      return issue;
    },
    async getIssueComment(requestOwner, requestRepo, number) {
      assert.equal(`${requestOwner}/${requestRepo}`.toLowerCase(), sourceRepo.toLowerCase());
      assert.equal(number, comment.id);
      if (state.missingComment) throw new Error("404 Not Found");
      return comment;
    },
    async getPermission(requestOwner, requestRepo, login) {
      assert.equal(`${requestOwner}/${requestRepo}`.toLowerCase(), sourceRepo.toLowerCase());
      if (overrides.permissionError) throw new Error("403 Forbidden");
      return permissions.get(login) || { permission: "read" };
    },
    async getIssueBodyEditTime() {
      if (overrides.editTimeError) throw new Error("GraphQL unavailable");
      return editTimes;
    },
    async getSpec(requestOwner, requestRepo, path, commit) {
      assert.equal(`${requestOwner}/${requestRepo}`.toLowerCase(), sourceRepo.toLowerCase());
      assert.equal(path, "docs/spec/synthesized/preapproval.spec.md");
      assert.equal(commit, specCommit);
      if (overrides.specError) throw new Error("404 Not Found");
      return {
        type: "file",
        content: Buffer.from(overrides.specContent || specContent).toString("base64")
      };
    },
    async getWorkflowRun(requestOwner, requestRepo, id) {
      assert.equal(`${requestOwner}/${requestRepo}`.toLowerCase(), sourceRepo.toLowerCase());
      assert.equal(String(id), runId);
      if (overrides.runError) throw new Error("404 Not Found");
      return workflowRun;
    }
  };
  const args = {
    api,
    sourceRepo,
    targetRepo: sourceRepo,
    sourceIssueNumber: 99,
    approvalCommentId: 7001,
    intent: "ship-it",
    goal: "Deliver the approved release",
    specRef,
    riskBand: "medium",
    profile: "team-dev",
    executionPrincipal: "runner",
    runId,
    runStartedAt,
    selectedPolicy: "team-dev/medium"
  };
  return { api, args, issue, comment, permissions, editTimes, workflowRun, state };
}

async function makeReceipt(fixture = makeFixture()) {
  return preapproval.resolvePreApproval(fixture.args);
}

test("accepts a prior exact approval with current role-name permission fallback", async () => {
  const fixture = makeFixture();
  fixture.permissions.set("maintainer", { permission: "read", role_name: "write" });
  fixture.permissions.set("runner", { permission: "read", role_name: "admin" });
  fixture.comment.body = " \n/APPROVE\r\n";

  const receipt = await makeReceipt(fixture);
  assert.equal(receipt.decision, "accepted");
  assert.equal(receipt.approver_login, "maintainer");
  assert.equal(receipt.execution_principal, "runner");
  assert.equal(receipt.run_started_at, runStartedAt);
  assert.equal(receipt.spec_commit, specCommit);
  assert.match(receipt.receipt_hash, /^[a-f0-9]{64}$/);
});

test("accepts each qualified current permission level for approver and executor", async t => {
  for (const permission of ["write", "maintain", "admin"]) {
    await t.test(permission, async () => {
      const fixture = makeFixture();
      fixture.permissions.set("maintainer", { permission });
      fixture.permissions.set("runner", { permission });
      assert.equal((await makeReceipt(fixture)).decision, "accepted");
    });
  }
});

test("uses the authenticated GitHub CLI viewer instead of caller-controlled identity inputs", async () => {
  assert.match(preapprovalSource, /const executionPrincipal = await getAuthenticatedViewer\(api\);/);
  assert.match(preapprovalSource, /const executionPrincipal = await getRevalidationPrincipal\(api, receipt\);/);
  assert.doesNotMatch(preapprovalSource, /BASECOAT_EXECUTION_PRINCIPAL|process\.env\.GITHUB_ACTOR/);
  const environmentKeys = [
    "BASECOAT_EXECUTION_PRINCIPAL",
    "GITHUB_ACTOR",
    "GITHUB_ACTIONS",
    "GITHUB_RUN_ID",
    "GITHUB_REPOSITORY"
  ];
  const originalEnvironment = new Map(
    environmentKeys.map(key => [key, process.env[key]])
  );
  process.env.BASECOAT_EXECUTION_PRINCIPAL = "maintainer";
  process.env.GITHUB_ACTOR = "maintainer";
  delete process.env.GITHUB_ACTIONS;
  delete process.env.GITHUB_RUN_ID;
  delete process.env.GITHUB_REPOSITORY;
  try {
    const api = { async getViewerLogin() { return "runner"; } };
    assert.equal(
      await preapproval.getAuthenticatedViewer(api),
      "runner"
    );
    assert.equal(
      await preapproval.getRevalidationPrincipal(api, {
        source_repo: sourceRepo,
        execution_principal: "another-user"
      }),
      "runner"
    );
    await assert.rejects(
      preapproval.getAuthenticatedViewer({ async getViewerLogin() { return ""; } }),
      /authenticated GitHub CLI user/
    );

    process.env.GITHUB_ACTIONS = "true";
    process.env.GITHUB_RUN_ID = runId;
    process.env.GITHUB_REPOSITORY = sourceRepo;
    assert.equal(
      await preapproval.getRevalidationPrincipal(api, {
        source_repo: sourceRepo,
        execution_principal: "initial-runner"
      }),
      "initial-runner"
    );
  } finally {
    for (const [key, value] of originalEnvironment) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test("rejects malformed, partial, or unsafe source identifiers", async () => {
  for (const [sourceIssueNumber, approvalCommentId] of [
    ["0", "7001"],
    ["99.1", "7001"],
    ["99", ""],
    ["", "7001"],
    ["9007199254740992", "7001"]
  ]) {
    const fixture = makeFixture();
    fixture.args.sourceIssueNumber = sourceIssueNumber;
    fixture.args.approvalCommentId = approvalCommentId;
    await assert.rejects(makeReceipt(fixture), /positive integer|safe positive integers/);
  }
});

test("accepts only a trimmed exact /approve command and rejects bot actors", async () => {
  for (const body of ["/approve now", "please /approve", "`/approve`", "```/approve```", "/approve extra"]) {
    const fixture = makeFixture();
    fixture.comment.body = body;
    await assert.rejects(makeReceipt(fixture), /exact \/approve/);
  }
  for (const user of [{ login: "agent[bot]", type: "User" }, { login: "copilot", type: "Bot" }]) {
    const fixture = makeFixture();
    fixture.comment.user = user;
    await assert.rejects(makeReceipt(fixture), /author is a bot/);
  }
});

test("rejects missing labels and insufficient or unavailable live permission", async () => {
  const noLabel = makeFixture();
  noLabel.issue.labels = [{ name: "enhancement" }];
  await assert.rejects(makeReceipt(noLabel), /missing the live approved label/);

  for (const level of ["read", "triage", "unknown"]) {
    const fixture = makeFixture();
    fixture.permissions.set("maintainer", { permission: level });
    await assert.rejects(makeReceipt(fixture), /Approval author .* lacks current/);
  }

  const apiFailure = makeFixture({ permissionError: true });
  await assert.rejects(makeReceipt(apiFailure), /403 Forbidden/);
});

test("requires approval created and last updated strictly before the run cutoff", async t => {
  for (const [name, time, succeeds] of [
    ["one millisecond before", "2026-10-03T09:59:59.999Z", true],
    ["equal to start", runStartedAt, false],
    ["one millisecond after", "2026-10-03T10:00:00.001Z", false]
  ]) {
    await t.test(name, async () => {
      const fixture = makeFixture({
        comment: {
          created_at: time,
          updated_at: time
        }
      });
      if (succeeds) assert.equal((await makeReceipt(fixture)).decision, "accepted");
      else await assert.rejects(makeReceipt(fixture), /strictly before the initial run start/);
    });
  }

  const editedIntoApproval = makeFixture({
    comment: {
      created_at: "2026-10-03T09:00:00.000Z",
      updated_at: runStartedAt
    }
  });
  await assert.rejects(makeReceipt(editedIntoApproval), /strictly before the initial run start/);
});

test("requires body scope unchanged through the qualified approval time", async t => {
  for (const [name, lastEditedAt, succeeds] of [
    ["equal to approval", "2026-10-03T09:59:59.999Z", true],
    ["one millisecond after approval", "2026-10-03T10:00:00.000Z", false]
  ]) {
    await t.test(name, async () => {
      const fixture = makeFixture({ editTimes: { lastEditedAt } });
      if (succeeds) assert.equal((await makeReceipt(fixture)).decision, "accepted");
      else await assert.rejects(makeReceipt(fixture), /edited after the approval/);
    });
  }
  const unknownEditHistory = makeFixture({ editTimeError: true });
  await assert.rejects(makeReceipt(unknownEditHistory), /GraphQL unavailable/);
});

test("rejects wrong repository, PR, issue/comment association, and closed evidence", async () => {
  const crossRepo = makeFixture();
  crossRepo.args.targetRepo = "another-owner/other-repo";
  await assert.rejects(makeReceipt(crossRepo), /same target repository/);

  for (const issue of [
    { ...makeFixture().issue, pull_request: { url: "https://github.com/pull/99" } },
    { ...makeFixture().issue, state: "closed" }
  ]) {
    const fixture = makeFixture({ issue });
    await assert.rejects(makeReceipt(fixture), /open issue, not a pull request/);
  }

  const wrongComment = makeFixture({ comment: { issue_url: "https://api.github.com/repos/other/repo/issues/99" } });
  await assert.rejects(makeReceipt(wrongComment), /does not belong to the specified source issue/);
});

test("requires supplied intent, goal, target, risk, profile, and pinned spec to match", async () => {
  const variants = [
    ["intent", "spec-2-prod"],
    ["goal", "A wider goal"],
    ["targetRepo", "IBuySpy-Shared/other"],
    ["riskBand", "high"],
    ["profile", "solo-dev"],
    ["specRef", "https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/x.spec.md"]
  ];
  for (const [field, value] of variants) {
    const fixture = makeFixture();
    fixture.args[field] = value;
    await assert.rejects(makeReceipt(fixture), /does not exactly match the approved issue scope|same target repository/);
  }
  const unsupportedIntent = makeFixture();
  unsupportedIntent.args.intent = "onboarding-conductor";
  await assert.rejects(makeReceipt(unsupportedIntent), /only for explicit ship-it or spec-2-prod/);
});

test("requires an accessible immutable same-repository spec", async () => {
  for (const spec of [
    "https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/x.spec.md",
    "https://example.com/IBuySpy-Shared/basecoat/blob/0123456789abcdef0123456789abcdef01234567/docs/spec/x.spec.md",
    "https://github.com/another-owner/repo/blob/0123456789abcdef0123456789abcdef01234567/docs/spec/x.spec.md",
    `https://github.com/${sourceRepo}/blob/${specCommit}/docs/prd/x.spec.md`
  ]) {
    const fixture = makeFixture();
    fixture.issue.body = fixture.issue.body.replace(specRef, spec);
    fixture.args.specRef = spec;
    await assert.rejects(makeReceipt(fixture), /commit-pinned spec/);
  }
  const inaccessible = makeFixture({ specError: true });
  await assert.rejects(makeReceipt(inaccessible), /404 Not Found/);
  const emptySpec = makeFixture({ specContent: " \n " });
  await assert.rejects(makeReceipt(emptySpec), /empty or inaccessible/);
});

test("revalidates live authority, scope, run provenance, and permission at later boundaries", async t => {
  const mutations = [
    ["approved label removed", fixture => { fixture.issue.labels = []; }],
    ["approval comment edited", fixture => { fixture.comment.body = "not approval"; }],
    ["approver loses write", fixture => { fixture.permissions.set("maintainer", { permission: "read" }); }],
    ["execution principal loses write", fixture => { fixture.permissions.set("runner", { permission: "read" }); }],
    ["scope edited", fixture => { fixture.issue.body += "\nEdited after approval."; fixture.editTimes.lastEditedAt = "2026-10-03T10:00:00.000Z"; }],
    ["pinned spec inaccessible", fixture => { fixture.api.getSpec = async () => { throw new Error("403 Forbidden"); }; }],
    ["initial run start changed", fixture => { fixture.workflowRun.created_at = "2026-10-03T10:00:00.001Z"; }],
    ["initial run actor changed", fixture => { fixture.workflowRun.actor.login = "other-user"; }],
    ["comment disappeared", fixture => { fixture.state.missingComment = true; }]
  ];
  for (const [name, mutate] of mutations) {
    await t.test(name, async () => {
      const fixture = makeFixture();
      const receipt = await makeReceipt(fixture);
      mutate(fixture);
      await assert.rejects(
        preapproval.validateLiveReceipt({
          api: fixture.api,
          receipt,
          currentExecutionPrincipal: receipt.execution_principal
        })
      );
    });
  }
});

test("rejects a changed execution principal and tampered receipt fields", async () => {
  const fixture = makeFixture();
  const receipt = await makeReceipt(fixture);
  for (const currentExecutionPrincipal of [undefined, null, "", "  "]) {
    await assert.rejects(
      preapproval.validateLiveReceipt({
        api: fixture.api,
        receipt,
        currentExecutionPrincipal
      }),
      /A current execution principal is required/
    );
  }
  await assert.rejects(
    preapproval.validateLiveReceipt({
      api: fixture.api,
      receipt,
      currentExecutionPrincipal: "other-user"
    }),
    /does not match the current trusted principal/
  );

  const tampered = { ...receipt, run_started_at: "2026-10-03T09:00:00.000Z" };
  assert.throws(() => preapproval.encodeReceipt(tampered), /hash does not match/);
  assert.throws(() => preapproval.decodeReceipt("not-a-receipt"), /valid encoded JSON/);
});

test("generated child issue receipt binds to the approved contract and dispatch run", async () => {
  const fixture = makeFixture();
  const receipt = await makeReceipt(fixture);
  const body = [
    "## Intent Contract",
    "",
    "- Intent: `ship-it`",
    "- Goal: Deliver the approved release",
    "- Scope: Deliver the approved release",
    `- Repository: ${sourceRepo}`,
    "- Risk band: `medium`",
    "- Profile: `team-dev`",
    `- Spec reference: ${specRef}`,
    "",
    `<!-- basecoat-intent-child:${preapproval.expectedIntentRunHash(receipt)}:sprint-1-plan-and-scope -->`,
    `<!-- basecoat-preapproval-receipt:v1 ${preapproval.encodeReceipt(receipt)} -->`
  ].join("\n");
  assert.equal(preapproval.matchesReceiptScope(body, receipt), true);
  assert.deepEqual(preapproval.extractReceipt(body), receipt);
  assert.match(preapproval.expectedIntentRunHash(receipt), /^[a-f0-9]{64}$/);
  assert.equal(preapproval.matchesReceiptScope(body.replace("medium", "high"), receipt), false);
});
