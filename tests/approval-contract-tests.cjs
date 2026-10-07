"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const approval = require("../.github/base-coat/scripts/approval-contract.cjs");
const root = path.resolve(__dirname, "..");
process.env.GITHUB_WORKSPACE = root;
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const workflows = {};
for (const name of ["issue-approve.yml", "ship-it-intent-dispatch.yml"]) {
  const source = fs.readFileSync(path.join(root, ".github", "workflows", name), "utf8").replace(/\r\n/g, "\n");
  workflows[name] = source;
  let distributed = fs.readFileSync(path.join(root, ".github", "base-coat", "workflows", name), "utf8").replace(/\r\n/g, "\n");
  if (name === "ship-it-intent-dispatch.yml") {
    distributed = distributed.replace(
      "description: Repository in owner/repo format (defaults to this repository)\n        required: false",
      "description: Repository in owner/repo format\n        required: true\n        default: IBuySpy-Shared/basecoat"
    ).replace(".\\.github\\base-coat\\scripts\\ship-it\\dispatch-intent.ps1",
      ".\\scripts\\ship-it\\dispatch-intent.ps1");
  }
  assert.equal(source, distributed);
}
function workflowScripts(source, jobName, expectedCount) {
  const job = source.match(new RegExp(`^  ${jobName}:\\n([\\s\\S]*?)(?=^  [\\w-]+:|$(?![\\s\\S]))`, "m"));
  assert.ok(job, `Missing workflow job ${jobName}`);
  const extracted = Array.from(job[1].matchAll(
    /^          script: \|\n((?: {12}[^\n]*(?:\n|$)|[ \t]*\n)*)/gm
  ), match => match[1].split("\n").map(line => line.replace(/^ {12}/, "")).join("\n"));
  assert.equal(extracted.length, expectedCount, `Unexpected script layout in ${jobName}`);
  return extracted;
}
const issueWorkflow = workflows["issue-approve.yml"];
const approveScripts = workflowScripts(issueWorkflow, "approve", 3);
const scripts = {
  access: approveScripts[0],
  metadata: approveScripts[1],
  forward: workflowScripts(issueWorkflow, "route-pr-approve", 1)[0],
  reevaluate: workflowScripts(issueWorkflow, "reevaluate-linked-prs", 1)[0],
  delivery: workflowScripts(workflows["ship-it-intent-dispatch.yml"], "resolve-intent", 1)[0]
};
assert.match(scripts.access, /approval\.qualifiedDirective/);
assert.match(scripts.metadata, /approval\.validateIssue/);
const human = { login: "maintainer", type: "User" };
const spec = "https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/approved.spec.md";
const owner = "IBuySpy-Shared", repo = "basecoat";
function fixture() {
  const state = {
    issue: { number: 1, state: "open", title: "Feature", body: `- Spec: ${spec}`,
      labels: [{ name: "bug" }, { name: "priority:high" }], html_url: "https://github.com/IBuySpy-Shared/basecoat/issues/1" },
    pr: { number: 2, title: "Feature", body: "Closes #1" },
    permissions: { maintainer: { permission: "maintain" }, writer: { permission: "write" } },
    comments: { 1: [], 2: [] }, written: [], dispatched: [], statuses: [],
    dependency: { number: 3, state: "closed" },
    merged: true, dependencyRequests: []
  };
  for (const [issueNumber, id] of [[1, 11], [2, 22]]) {
    state.comments[issueNumber].push({ id, body: "/approve", user: human,
      issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`,
      html_url: `https://github.com/${owner}/${repo}/issues/${issueNumber}#issuecomment-${id}` });
  }
  const rest = {
    issues: {
      async get(args) {
        if (args.issue_number === 1) return { data: state.issue };
        state.dependencyRequests.push(args);
        return { data: state.dependency };
      },
      async getComment({ comment_id }) {
        const comment = Object.values(state.comments).flat().find(item => item.id === comment_id);
        if (!comment) throw Object.assign(new Error("Comment not found"), { status: 404 });
        return { data: comment };
      },
      async listComments({ issue_number }) { return { data: state.comments[issue_number] || [] }; },
      async createComment(args) {
        state.written.push(args);
        state.comments[args.issue_number].push({ id: 100 + state.written.length,
          body: args.body, user: { login: "github-actions[bot]", type: "Bot" } });
      },
      async addLabels() {}, async removeLabel() {}
    },
    repos: {
      async getCollaboratorPermissionLevel({ username }) {
        return { data: state.permissions[username] || { permission: "read" } };
      },
      async createCommitStatus(args) { state.statuses.push(args); }
    },
    pulls: {
      async get({ pull_number }) {
        return { data: pull_number === 2 ? state.pr : { merged: state.merged, state: "closed" } };
      },
      async list() { return { data: [{ ...state.pr, head: { sha: "a".repeat(40) } }] }; }
    },
    actions: {
      async listRepoWorkflows() {
        return { data: [{ id: 9, path: ".github/workflows/pr-auto-merge-executor.yml" }] };
      },
      async createWorkflowDispatch(args) { state.dispatched.push(args); }
    }
  };
  const github = { rest, paginate: async (fn, args) => (await fn(args)).data,
    graphql: async () => ({ repository: { suggestedActors: { nodes: [] } } }) };
  return { state, github };
}
async function run(script, f, route, body = "/spec-2-prod Deliver feature") {
  const outputs = {}, failures = [];
  const isPr = route === "forward";
  const comment = isPr ? f.state.comments[2][0] : f.state.comments[1][0];
  const context = { repo: { owner, repo }, actor: "writer", eventName: "issue_comment",
    payload: { issue: isPr ? { ...f.state.pr, pull_request: {} } : f.state.eventIssue || f.state.issue,
      comment: route === "delivery" ? { ...comment, body } : comment,
      repository: { default_branch: "main" } } };
  if (route === "manual") {
    context.eventName = "workflow_dispatch";
    context.payload.inputs = { intent: "spec-2-prod", goal: "Deliver feature",
      source_issue_number: "1", target_repo: `${owner}/${repo}`, dry_run: "true" };
  }
  const core = { setOutput: (key, value) => { outputs[key] = value; },
    setFailed: message => failures.push(message), info() {}, warning() {} };
  const value = await new AsyncFunction("github", "context", "core", "require", script)(
    f.github, context, core, require);
  return { outputs, failures, value };
}
async function approveRoute(f, route) {
  if (route === "forward") return run(scripts.forward, f, route);
  const access = await run(scripts.access, f, route);
  return access.value ? run(scripts.metadata, f, route) : access;
}
async function main() {
  for (const command of ["/approve", "/APPROVE", " \r\n /Approve \t\r\n"]) {
    for (const route of ["issue", "forward"]) {
      const f = fixture();
      f.state.comments[route === "issue" ? 1 : 2][0].body = command;
      const result = await approveRoute(f, route);
      assert.deepEqual(result.failures, [], `${route}: ${command}`);
      if (route === "issue") assert.equal(result.value, true);
      else {
        const receipt = f.state.written.find(item => item.body.startsWith("<!-- basecoat-approval-forward:"));
        assert.ok(receipt);
        assert.ok(receipt.body.includes(JSON.stringify(command)));
        assert.ok(receipt.body.includes("@maintainer"));
        f.state.comments[1] = f.state.comments[1].filter(item => item.id !== 11);
      }
      const delivered = await run(scripts.delivery, f, "delivery");
      assert.deepEqual(delivered.failures, []);
      assert.equal(delivered.outputs.should_run, "true");
      // An approved label is neither required nor sufficient authority.
      assert.ok(!f.state.issue.labels.some(label => label.name === "approved"));
    }
  }
  for (const reference of ["", "N/A", "<url>", "TBD", "docs/spec/feature.spec.md",
    "https://example.com/spec", "https://placeholder.company.com/spec",
    "https://localhost/spec", "https://service.invalid/spec", "https://host.test/spec",
    "https://host/spec todo", "https://", "https:///github.com/spec",
    "https://user:password@github.com/spec", "ftp://github.com/spec", `\n- Spec: ${spec}`]) {
    for (const route of ["issue", "forward", "delivery"]) {
      const f = fixture();
      f.state.issue.body = reference ? `- Spec: ${reference}` : "No spec";
      const result = route === "delivery" ? await run(scripts.delivery, f, route) :
        await approveRoute(f, route);
      assert.ok(result.failures.length || result.value === false ||
        f.state.written.some(item => item.body.includes("BLOCKED:")), `${route}: ${reference}`);
      assert.ok(!f.state.written.some(item => item.body.startsWith("<!-- basecoat-approval-forward:")));
      assert.notEqual(result.outputs.should_run, "true");
    }
  }
  for (const command of ["Please /approve", "> /approve", "`/approve`",
    "```\n/approve\n```", "/approve now", "/approve\n/approve", "/approve-extra"]) {
    for (const route of ["issue", "forward", "delivery"]) {
      const f = fixture();
      f.state.comments[route === "forward" ? 2 : 1][0].body = command;
      const result = route === "delivery" ? await run(scripts.delivery, f, route) :
        await approveRoute(f, route);
      assert.ok(result.failures.length, `${route}: ${command}`);
      assert.notEqual(result.outputs.should_run, "true");
    }
    for (const body of [`> - Spec: ${spec}`, `\`\`\`md\n- Spec: ${spec}\n\`\`\``,
      `~~~md\n- Spec: ${spec}\n~~~`, `<!--\n- Spec: ${spec}\n-->`]) {
      for (const route of ["issue", "forward", "delivery"]) {
        const f = fixture();
        f.state.issue.body = body;
        const result = route === "delivery" ? await run(scripts.delivery, f, route) :
          await approveRoute(f, route);
        assert.ok(result.failures.length || result.value === false ||
          f.state.written.some(item => item.body.includes("BLOCKED:")), `${route}: quoted spec`);
      }
    }
  }
  for (const permission of [{ permission: "read" }, { permission: "none" }]) {
    for (const route of ["issue", "forward", "delivery"]) {
      const f = fixture();
      f.state.permissions.maintainer = permission;
      const result = route === "delivery" ? await run(scripts.delivery, f, route) :
        await approveRoute(f, route);
      assert.ok(result.failures.length, `${route}: revoked permission`);
    }
  }
  for (const permission of [{ permission: "admin" }, { permission: "write" },
    { permission: "read", role_name: "maintain" }]) {
    const f = fixture();
    f.state.permissions.maintainer = permission;
    assert.equal((await approveRoute(f, "issue")).value, true);
  }
  for (const route of ["issue", "forward", "delivery"]) {
    const f = fixture();
    f.state.comments[route === "forward" ? 2 : 1][0].user =
      { login: "github-actions[bot]", type: "Bot" };
    f.state.permissions["github-actions[bot]"] = { permission: "admin" };
    const result = route === "delivery" ? await run(scripts.delivery, f, route) :
      await approveRoute(f, route);
    assert.ok(result.failures.length, `${route}: bots cannot approve`);
  }
  const staleEvent = fixture();
  staleEvent.state.eventIssue = { ...staleEvent.state.issue };
  staleEvent.state.issue.body = "- Spec: TBD";
  assert.equal((await approveRoute(staleEvent, "issue")).value, false);
  for (const route of ["issue", "forward", "delivery"]) {
    for (const dependency of ["Depends on #3", "Blocked by https://github.com/other/project/issues/3",
      "Depends on https://github.com/other/project/pull/3"]) {
      const f = fixture();
      f.state.issue.body += `\n${dependency}`;
      assert.deepEqual((await approval.validateIssue({ github: f.github, owner, repo, issueNumber: 1 })).missing, []);
      f.state.dependency.state = "open"; // Reopened since original approval.
      const result = route === "delivery" ? await run(scripts.delivery, f, route) :
        await approveRoute(f, route);
      assert.ok(result.failures.length || result.value === false ||
        f.state.written.some(item => item.body.includes("Unresolved dependencies")));
      if (dependency.includes("other/project")) assert.equal(f.state.dependencyRequests.at(-1).owner, "other");
    }
    const f = fixture();
    f.state.issue.body += "\nDepends on #3";
    f.state.dependency.pull_request = {};
    f.state.merged = false; // Closed but not merged.
    const result = route === "delivery" ? await run(scripts.delivery, f, route) : await approveRoute(f, route);
    assert.ok(result.failures.length || result.value === false ||
      f.state.written.some(item => item.body.includes("Unresolved dependencies")));
  }
  for (const mutation of ["revoked", "edited", "wrong-repo", "unlinked", "forged-bot", "bot-origin"]) {
    const f = fixture();
    await approveRoute(f, "forward");
    f.state.comments[1] = f.state.comments[1].filter(item => item.id !== 11);
    if (mutation === "revoked") f.state.permissions.maintainer = { permission: "read" };
    if (mutation === "edited") f.state.comments[2][0].body = "> /approve";
    if (mutation === "wrong-repo") f.state.comments[2][0].issue_url = "https://api.github.com/repos/other/project/issues/2";
    if (mutation === "unlinked") f.state.pr.body = "No closing issue";
    if (mutation === "forged-bot") f.state.comments[1][0].user = human;
    if (mutation === "bot-origin") f.state.comments[2][0].user = { login: "github-actions[bot]", type: "Bot" };
    assert.ok((await run(scripts.delivery, f, "delivery")).failures.length, mutation);
  }
  for (const replacement of ["none", "issue", "forward"]) {
    const f = fixture();
    await approveRoute(f, "forward");
    const issueDirective = f.state.comments[1].find(comment => comment.id === 11);
    f.state.comments[1] = f.state.comments[1].filter(comment => comment.id !== 11);
    f.state.comments[2] = []; // The first forwarded origin was deleted.
    if (replacement === "issue") f.state.comments[1].push(issueDirective);
    if (replacement === "forward") {
      const newOrigin = { ...issueDirective, id: 44,
        issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/2` };
      f.state.comments[2].push(newOrigin);
      f.state.comments[1].push({ id: 144, user: { login: "github-actions[bot]", type: "Bot" },
        body: approval.forwardReceipt(2, newOrigin, 1) });
    }
    const delivery = await run(scripts.delivery, f, "delivery");
    if (replacement === "none") {
      assert.ok(delivery.failures.length, "Deleted origin alone cannot authorize delivery");
      assert.notEqual(delivery.outputs.should_run, "true");
    } else {
      assert.deepEqual(delivery.failures, [], `Later ${replacement} approval must survive stale receipt`);
      assert.equal(delivery.outputs.should_run, "true");
      // The current PR directive is qualified; reevaluation searches the same stale receipt first.
      if (replacement === "issue") f.state.comments[2].push({
        ...issueDirective, id: 44, issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/2`
      });
      await run(scripts.reevaluate, f, "forward");
      assert.equal(f.state.dispatched.length, 1);
    }
  }
  for (const status of [401, 403, 429, 500]) {
    const f = fixture();
    f.github.rest.issues.getComment = async () => {
      throw Object.assign(new Error(`Comment lookup failed: ${status}`), { status });
    };
    await assert.rejects(run(scripts.delivery, f, "delivery"), error => error.status === status);
  }
  const permissionFailure = fixture();
  permissionFailure.github.rest.repos.getCollaboratorPermissionLevel = async ({ username }) => {
    if (username === "maintainer") throw Object.assign(new Error("Permission unavailable"), { status: 404 });
    return { data: { permission: "write" } };
  };
  await assert.rejects(run(scripts.delivery, permissionFailure, "delivery"), error => error.status === 404);
  const labelsOnly = fixture();
  labelsOnly.state.issue.labels.push({ name: "approved" });
  labelsOnly.state.comments[1] = [];
  assert.ok((await run(scripts.delivery, labelsOnly, "delivery")).failures.length);
  for (const body of ["/ship-it Deliver feature", "ship-it: Deliver feature",
    "/SPEC-2-PROD Deliver feature", "spec-2-prod: Deliver feature"]) {
    assert.equal((await run(scripts.delivery, fixture(), "delivery", body)).outputs.should_run, "true");
  }
  for (const body of ["> /spec-2-prod", "Please /spec-2-prod", "```\n/spec-2-prod\n```"]) {
    assert.notEqual((await run(scripts.delivery, fixture(), "delivery", body)).outputs.should_run, "true");
  }
  assert.equal((await run(scripts.delivery, fixture(), "manual")).outputs.should_run, "true");
  for (const route of ["delivery", "manual"]) {
    const f = fixture();
    f.state.permissions.writer = { permission: "read" };
    assert.ok((await run(scripts.delivery, f, route)).failures.length, `${route}: revoked initiator rights`);
  }
  const finalized = fixture();
  await run(scripts.reevaluate, finalized, "reevaluate");
  assert.equal(finalized.state.dispatched.length, 1);
  for (const mutation of ["quoted", "revoked", "spec", "dependency"]) {
    const f = fixture();
    f.state.issue.labels.push({ name: "approved" });
    if (mutation === "quoted") f.state.comments[1][0].body = "> /approve";
    if (mutation === "revoked") f.state.permissions.maintainer = { permission: "read" };
    if (mutation === "spec") f.state.issue.body = "- Spec: TBD";
    if (mutation === "dependency") {
      f.state.issue.body += "\nDepends on #3";
      f.state.dependency.state = "open";
    }
    await run(scripts.reevaluate, f, "reevaluate");
    assert.equal(f.state.dispatched.length, 0, `reevaluation: ${mutation}`);
  }
  console.log("Approval contract: shared helper and all workflow routes passed.");
}
main().catch(error => { console.error(error); process.exitCode = 1; });
