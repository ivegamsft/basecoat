"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const root = path.resolve(__dirname, "..");
const approvalContract = require("../.github/base-coat/scripts/approval-contract.cjs");
const assignment = require("../scripts/agent-assignment.cjs");
const distributedAssignment = require("../.github/base-coat/scripts/agent-assignment.cjs");
const owner = "IBuySpy-Shared";
const repo = "basecoat";
const issueNumber = 3592;
const spec = "https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/approved.spec.md";
const start = new Date("2026-10-07T12:00:00.000Z");
const agentLogin = "copilot-swe-agent[bot]";

function fixture(options = {}) {
  const state = {
    issue: {
      number: issueNumber, state: "open", title: "Authorized delivery",
      body: `- Spec: ${options.spec || spec}`,
      labels: [{ name: "bug" }, { name: "priority:high" }, { name: "approved" }, { name: "copilot-agent" }],
      assignees: [...(options.assignees || [])],
      html_url: `https://github.com/${owner}/${repo}/issues/${issueNumber}`
    },
    comments: [], permission: options.permission || "maintain",
    timelineEvents: options.timelineEvents || [],
    executionPulls: options.executionPulls || {},
    dependency: { number: 99, state: options.dependencyState || "closed" },
    capability: options.capability === undefined
      ? [{ login: "copilot-swe-agent", id: "MDQ6Qm90" }] : options.capability,
    writes: 0, requestOrder: [], statusWrites: 0, readIssueCalls: 0,
    requestBehavior: options.requestBehavior || null,
    graphqlError: null, readBackError: null, statusWriteError: null
  };
  if (options.approval !== false) {
    const directive = {
      id: 501, body: "/approve", created_at: "2026-10-07T11:00:00.000Z",
      html_url: `https://github.com/${owner}/${repo}/issues/${issueNumber}#issuecomment-501`,
      issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`,
      user: { login: "maintainer", type: "User" }
    };
    state.comments.push(directive, {
      id: 9001, body: approvalContract.approvedScopeReceipt(issueNumber, directive, options.spec || spec),
      user: { login: "github-actions[bot]", type: "Bot" }
    });
  }
  const rest = {
    issues: {
      async get({ issue_number }) {
        if (issue_number === 99) return { data: state.dependency };
        state.readIssueCalls += 1;
        if (state.readBackError && state.readIssueCalls >= state.readBackError.after) {
          throw state.readBackError.error;
        }
        return { data: state.issue };
      },
      async listComments() {
        return { data: state.comments };
      },
      async listEventsForTimeline() {
        return { data: state.timelineEvents };
      },
      async getComment({ comment_id }) {
        const comment = state.comments.find(item => item.id === comment_id);
        if (!comment) throw Object.assign(new Error("Comment not found"), { status: 404 });
        return { data: comment };
      },
      async createComment({ issue_number, body }) {
        if (state.statusWriteError) throw state.statusWriteError;
        state.statusWrites += 1;
        const comment = {
          id: 700 + state.statusWrites, issue_number, body,
          user: { login: "github-actions[bot]", type: "Bot" },
          created_at: new Date().toISOString(), updated_at: new Date().toISOString()
        };
        state.comments.push(comment);
        return { data: comment };
      },
      async updateComment({ comment_id, body }) {
        if (state.statusWriteError) throw state.statusWriteError;
        state.statusWrites += 1;
        const comment = state.comments.find(item => item.id === comment_id);
        if (!comment) throw Object.assign(new Error("Comment not found"), { status: 404 });
        comment.body = body;
        comment.updated_at = new Date().toISOString();
        return { data: comment };
      }
    },
    repos: {
      async getCollaboratorPermissionLevel() {
        return { data: { permission: state.permission } };
      }
    },
    pulls: {
      async get({ pull_number }) {
        if (state.executionPulls[pull_number]) {
          return { data: state.executionPulls[pull_number] };
        }
        return { data: { number: 4, title: "Linked issue", body: `Closes #${issueNumber}` } };
      }
    }
  };
  const github = {
    rest,
    async paginate(method, args) {
      return (await method(args)).data;
    },
    async graphql() {
      if (state.graphqlError) throw state.graphqlError;
      return { repository: { suggestedActors: { nodes: state.capability } } };
    },
    async request(route, args) {
      state.writes += 1;
      state.requestOrder.push({
        route, retryCount: args.request?.retryCount,
        statusState: assignment.readStatusSyncForTest
          ? assignment.readStatusSyncForTest(state.comments) : null
      });
      if (state.requestBehavior) return state.requestBehavior(state, route, args);
      state.issue.assignees.push({ login: agentLogin, type: "Bot" });
      return { status: 201 };
    }
  };
  return { state, github };
}

function statusFromComments(comments) {
  const matching = comments.find(comment =>
    comment.user?.login === "github-actions[bot]" &&
    String(comment.body || "").includes(assignment.MARKER)
  );
  return matching ? assignment.parseStateComment(matching) : null;
}

async function run(f, options = {}) {
  return assignment.runAssignmentWorker({
    github: f.github, owner, repo, issueNumber, approval: approvalContract, now: start, ...options
  });
}

function jobBlock(source, jobName) {
  const result = source.match(new RegExp(
    `^  ${jobName}:\\n([\\s\\S]*?)(?=^  [\\w-]+:|$(?![\\s\\S]))`, "m"
  ));
  assert.ok(result, `Missing workflow job ${jobName}`);
  return result[1];
}

function extractScript(source, jobName) {
  const match = jobBlock(source, jobName).match(
    /^          script: \|\n((?: {12}[^\n]*(?:\n|$)|[ \t]*\n)*)/m
  );
  assert.ok(match, `Missing extracted script in ${jobName}`);
  return match[1].split("\n").map(line => line.replace(/^ {12}/, "")).join("\n");
}

async function executeWorkflowScript(script, f, env = {}, clock = Date) {
  const outputs = {};
  const warnings = [];
  const core = {
    setOutput: (key, value) => { outputs[key] = value; },
    info() {}, warning(message) { warnings.push(message); }, setFailed(message) { throw new Error(message); },
    summary: {
      addHeading() { return this; }, addTable() { return this; },
      addRaw() { return this; }, async write() {}
    }
  };
  const process = { env: { GITHUB_WORKSPACE: root, ...env } };
  const context = { repo: { owner, repo } };
  await new AsyncFunction("github", "context", "core", "require", "process", "Date", script)(
    f.github, context, core, require, process, clock
  );
  if (warnings.length) outputs.warnings = warnings;
  return outputs;
}

async function main() {
  assert.equal(assignment, distributedAssignment, "Source and packaged assignment helpers must resolve to one adapter.");

  const readWorkflow = file => fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  const workerWorkflow = readWorkflow(path.join(root, ".github", "workflows", "agent-assignment-worker.yml"));
  const workerTemplate = readWorkflow(path.join(root, ".github", "base-coat", "workflows", "agent-assignment-worker.yml"));
  const helperSource = fs.readFileSync(path.join(root, ".github", "base-coat", "scripts", "agent-assignment.cjs"), "utf8");
  const approvalSource = fs.readFileSync(path.join(root, ".github", "base-coat", "scripts", "approval-contract.cjs"), "utf8");
  assert.equal(workerWorkflow, workerTemplate);
  for (const workflow of [workerWorkflow, workerTemplate]) {
    assert.match(workflow, /^permissions:\n  contents: read\n  issues: write\n  pull-requests: read\n/m,
      "The reusable worker must be permitted to read forwarded approval PRs and execution evidence.");
  }
  assert.match(workerWorkflow, /group: basecoat-agent-assignment-\$\{\{ github\.repository_id \}\}-\$\{\{ inputs\.issue_number \}\}/);
  assert.match(workerWorkflow, /cancel-in-progress:\s*false/);
  assert.match(helperSource, /request: \{ retryCount: 0 \}/);
  assert.match(workerWorkflow, /RECOVERY_WRITES_ENABLED: \$\{\{ vars\.BASECOAT_AGENT_ASSIGNMENT_RECOVERY_ENABLED \|\| 'false' \}\}/);
  assert.match(workerWorkflow, /APPROVED_SPEC_REF: \$\{\{ inputs\.approved_spec_ref \}\}/);
  assert.match(approvalSource, /basecoat-approved-scope:v1/);

  const forwardedApproval = fixture({ approval: false });
  const originalPrDirective = {
    id: 505, body: "/approve", created_at: "2026-10-07T11:00:00.000Z",
    issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/4`,
    html_url: `https://github.com/${owner}/${repo}/pull/4#issuecomment-505`,
    user: { login: "maintainer", type: "User" }
  };
  forwardedApproval.state.comments.push({
    id: 506, body: approvalContract.forwardReceipt(4, originalPrDirective, issueNumber),
    user: { login: "github-actions[bot]", type: "Bot" }
  }, {
    id: 507, body: approvalContract.approvedScopeReceipt(issueNumber, originalPrDirective, spec),
    user: { login: "github-actions[bot]", type: "Bot" }
  });
  forwardedApproval.github.rest.issues.getComment = async () => ({ data: originalPrDirective });
  let approvalPrReads = 0;
  forwardedApproval.github.rest.pulls.get = async () => {
    approvalPrReads += 1;
    return { data: { number: 4, body: `Closes #${issueNumber}` } };
  };
  assert.equal((await run(forwardedApproval)).state, "assigned");
  assert.ok(approvalPrReads >= 2, "Forwarded authority must reread its original PR before assignment.");
  assert.equal(forwardedApproval.state.writes, 1);

  const legacyApproval = fixture();
  legacyApproval.state.comments = legacyApproval.state.comments.filter(comment =>
    !String(comment.body || "").includes("basecoat-approved-scope:v1"));

  const workerScript = extractScript(workerWorkflow, "assignment");
  const legacyResult = await executeWorkflowScript(workerScript, legacyApproval, {
    ISSUE_NUMBER: String(issueNumber), RECOVERY: "true",
    RECOVERY_WRITES_ENABLED: "false", MAX_ASSIGNMENT_ATTEMPTS: "3"
  });
  const legacyState = await run(legacyApproval, {
    recovery: true, recoveryWritesEnabled: false
  });
  assert.equal(legacyState.state, "authorization-invalid");
  assert.equal(legacyState.lastFailureCategory, "authorization-scope-receipt-missing");
  assert.match(legacyState.ownerAction, /post a fresh qualified \/approve/i);
  assert.ok(legacyResult.warnings.some(message => /owner action:.*fresh qualified \/approve/i.test(message)));
  assert.equal(legacyApproval.state.writes, 0);
  assert.equal(legacyApproval.state.statusWrites, 0);
  const readonlyRecovery = fixture();
  await executeWorkflowScript(workerScript, readonlyRecovery, {
    ISSUE_NUMBER: String(issueNumber), RECOVERY: "true",
    RECOVERY_WRITES_ENABLED: "false", MAX_ASSIGNMENT_ATTEMPTS: "3"
  });
  const readonlyState = statusFromComments(readonlyRecovery.state.comments);
  assert.equal(readonlyState, null, "Disabled recovery must not persist a status comment.");
  assert.equal(readonlyRecovery.state.writes, 0);
  assert.equal(readonlyRecovery.state.statusWrites, 0);
  const readonlyResult = await run(readonlyRecovery, {
    recovery: true, recoveryWritesEnabled: false
  });
  assert.equal(readonlyResult.state, "pending");
  assert.equal(readonlyResult.attemptsConsumed, 0);
  assert.equal(readonlyResult.lastFailureCategory, "recovery-write-disabled");
  assert.equal(readonlyResult.executionState, "unobserved");
  assert.equal(readonlyResult.executionUrl, null);
  assert.equal(readonlyRecovery.state.statusWrites, 0,
    "Repeated disabled-recovery sweeps must remain read-only.");
  const unavailableRecovery = fixture({ capability: [] });
  const unavailableState = await run(unavailableRecovery, {
    recovery: true, recoveryWritesEnabled: false
  });
  assert.equal(unavailableState.lastFailureCategory, "capability-disabled",
    "Read-only recovery must discover permanent capability disablement before gating writes.");
  assert.equal(unavailableRecovery.state.writes, 0);
  assert.equal(unavailableRecovery.state.statusWrites, 0,
    "Disabled recovery must not persist permanent capability failure either.");
  const unauthorizedRecovery = fixture({ permission: "read" });
  const unauthorizedRecoveryState = await run(unauthorizedRecovery, {
    recovery: true, recoveryWritesEnabled: false
  });
  assert.equal(unauthorizedRecoveryState.state, "authorization-invalid");
  assert.equal(unauthorizedRecovery.state.writes, 0);
  assert.equal(unauthorizedRecovery.state.statusWrites, 0,
    "Disabled recovery must report invalid authority without writing status.");

  const normalApproval = fixture();
  await executeWorkflowScript(workerScript, normalApproval, {
    ISSUE_NUMBER: String(issueNumber), RECOVERY: "false",
    RECOVERY_WRITES_ENABLED: "false", MAX_ASSIGNMENT_ATTEMPTS: "3"
  });
  const successful = statusFromComments(normalApproval.state.comments);
  assert.equal(successful.state, "assigned");
  assert.equal(successful.attemptsConsumed, 1);
  assert.equal(successful.verifiedAssignee, agentLogin);
  assert.equal(successful.executionState, "unobserved");
  assert.equal(successful.executionUrl, null);
  for (const recoveryWritesEnabled of [false, true]) {
    const statusWritesBefore = normalApproval.state.statusWrites;
    const swept = await run(normalApproval, {
      now: new Date("2026-10-09T12:00:00.000Z"), recovery: true, recoveryWritesEnabled
    });
    assert.equal(swept.verifiedAt, successful.verifiedAt,
      "Repeated sweeps must preserve the first verification time, not postpone the SLA.");
    assert.equal(statusFromComments(normalApproval.state.comments).verifiedAt, successful.verifiedAt);
    assert.equal(normalApproval.state.writes, 1);
    if (!recoveryWritesEnabled) assert.equal(normalApproval.state.statusWrites, statusWritesBefore);
  }

  const execution = fixture({
    assignees: [{ login: agentLogin, type: "Bot" }],
    timelineEvents: [{
      event: "cross-referenced",
      source: { issue: { number: 777, pull_request: {}, user: { login: agentLogin } } }
    }],
    executionPulls: {
      777: {
        number: 777, user: { login: agentLogin },
        html_url: `https://github.com/${owner}/${repo}/pull/777`
      }
    }
  });
  const executionState = await run(execution);
  assert.equal(executionState.executionState, "observed");
  assert.equal(executionState.executionUrl, `https://github.com/${owner}/${repo}/pull/777`);


  const untrustedExecution = fixture({
    assignees: [{ login: agentLogin, type: "Bot" }],
    timelineEvents: [{
      event: "cross-referenced",
      source: { issue: { number: 778, pull_request: {}, user: { login: "maintainer" } } }
    }],
    executionPulls: {
      778: {
        number: 778, user: { login: "maintainer" },
        html_url: `https://github.com/${owner}/${repo}/pull/778`
      }
    }
  });
  const untrustedExecutionState = await run(untrustedExecution);
  assert.equal(untrustedExecutionState.executionState, "unobserved",
    "Execution links authored by users other than the coding agent must not be trusted.");
  assert.equal(untrustedExecutionState.executionUrl, null);

  const failedExecutionLookup = fixture({ assignees: [{ login: agentLogin }] });
  failedExecutionLookup.github.rest.issues.listEventsForTimeline = async () => {
    throw Object.assign(new Error("Execution read denied"), { status: 403 });
  };
  const lookupState = await run(failedExecutionLookup);
  assert.equal(lookupState.state, "assigned");
  assert.equal(lookupState.executionState, "unobserved");
  assert.equal(lookupState.executionUrl, null);
  assert.equal(failedExecutionLookup.state.writes, 0);

  const staleScope = fixture();
  staleScope.state.issue.body =
    "- Spec: https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/changed.spec.md";
  await assert.rejects(run(staleScope), /immutable scope captured by approval/);
  assert.equal(statusFromComments(staleScope.state.comments), null,
    "A first worker run must not create state for a spec changed after the approval step.");
  assert.equal(staleScope.state.writes, 0);

  const unscopedState = fixture();
  unscopedState.state.comments = unscopedState.state.comments.filter(comment =>
    !String(comment.body || "").includes("basecoat-approved-scope:v1")
  );
  const unscopedResult = await run(unscopedState);
  assert.equal(unscopedResult.state, "authorization-invalid");
  assert.equal(unscopedResult.lastFailureCategory, "authorization-scope-receipt-missing");
  assert.match(unscopedResult.ownerAction, /post a fresh qualified \/approve/i);
  const unscopedStatus = statusFromComments(unscopedState.state.comments);
  assert.equal(unscopedStatus.state, "authorization-invalid");
  assert.equal(unscopedStatus.epoch, null,
    "Legacy state must remain unbound to an assignment epoch until fresh approval.");
  assert.equal(unscopedState.state.writes, 0,
    "A legacy approval without scope evidence must not create an assignment.");

  const approval = fixture();
  const assigned = await run(approval);
  assert.equal(assigned.state, "assigned");
  assert.equal(assigned.attemptsConsumed, 1);
  assert.match(statusFromComments(approval.state.comments).originalApprovalUrl, /issuecomment-501/);
  const assignedComment = approval.state.comments.find(comment => comment.body.includes(assignment.MARKER)).body;
  assert.match(assignedComment, /\[@copilot-swe-agent\[bot\]\]\(https:\/\/github\.com\/copilot-swe-agent\)/);
  assert.match(assignedComment,
    /Execution: unobserved; unobserved/);
  assert.deepEqual(approval.state.requestOrder.map(call => call.retryCount), [0]);
  assert.ok(approval.state.requestOrder.length === 1);

  const humanPinned = fixture({ assignees: [{ login: "maintainer", type: "User" }] });
  await run(humanPinned);
  assert.deepEqual(humanPinned.state.issue.assignees.map(person => person.login).sort(),
    ["copilot-swe-agent[bot]", "maintainer"]);

  const responseLost = fixture({
    requestBehavior(state) {
      state.issue.assignees.push({ login: agentLogin, type: "Bot" });
      throw Object.assign(new Error("socket closed after request"), { code: "ECONNRESET" });
    }
  });
  const observedLostResponse = await run(responseLost);
  assert.equal(observedLostResponse.state, "assigned");
  assert.equal(responseLost.state.writes, 1);

  const notPersisted = fixture({ requestBehavior() { return { status: 201 }; } });
  const missingReadback = await run(notPersisted);
  assert.equal(missingReadback.state, "retryable");
  assert.equal(missingReadback.attemptsConsumed, 1);
  assert.equal(missingReadback.nextRetryAt, "2026-10-07T12:00:30.000Z");

  const unavailable = fixture();
  unavailable.state.dependency = { number: 99, state: "open" };
  unavailable.state.issue.body += "\nDepends on #99";
  const dependencyBlocked = await run(unavailable);
  assert.equal(dependencyBlocked.state, "blocked");
  assert.equal(dependencyBlocked.lastFailureCategory, "dependency-unresolved");
  assert.equal(unavailable.state.writes, 0);

  const invalidSpec = fixture({ spec: "TBD" });
  await assert.rejects(run(invalidSpec), /immutable scope captured by approval/);
  assert.equal(invalidSpec.state.writes, 0);
  assert.equal(statusFromComments(invalidSpec.state.comments), null);

  const revoked = fixture({ permission: "read" });
  const authorityRejected = await run(revoked);
  assert.equal(authorityRejected.state, "authorization-invalid");
  assert.equal(authorityRejected.lastFailureCategory, "authorization-missing");
  assert.equal(revoked.state.writes, 0);
  revoked.state.permission = "maintain";
  const permissionRevokedDuringPreflight = fixture();
  permissionRevokedDuringPreflight.github.graphql = async () => {
    permissionRevokedDuringPreflight.state.permission = "read";
    return { repository: { suggestedActors: { nodes: permissionRevokedDuringPreflight.state.capability } } };
  };
  const latePermission = await run(permissionRevokedDuringPreflight);
  assert.equal(latePermission.state, "authorization-invalid");
  assert.equal(permissionRevokedDuringPreflight.state.writes, 0);

  const specChangedDuringPreflight = fixture();
  specChangedDuringPreflight.github.graphql = async () => {
    specChangedDuringPreflight.state.issue.body =
      "- Spec: https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/changed.spec.md";
    return { repository: { suggestedActors: { nodes: specChangedDuringPreflight.state.capability } } };
  };
  const lateSpecChange = await run(specChangedDuringPreflight);
  assert.equal(lateSpecChange.state, "blocked");
  assert.equal(lateSpecChange.lastFailureCategory, "authorization-scope-changed-needs-fresh-approval");
  assert.equal(specChangedDuringPreflight.state.writes, 0);

  const dependencyChangedDuringPreflight = fixture();
  dependencyChangedDuringPreflight.github.graphql = async () => {
    dependencyChangedDuringPreflight.state.issue.body += "\nDepends on #99";
    dependencyChangedDuringPreflight.state.dependency.state = "open";
    return { repository: { suggestedActors: { nodes: dependencyChangedDuringPreflight.state.capability } } };
  };
  const lateDependency = await run(dependencyChangedDuringPreflight);
  assert.equal(lateDependency.state, "blocked");
  assert.equal(lateDependency.lastFailureCategory, "dependency-unresolved");
  assert.equal(dependencyChangedDuringPreflight.state.writes, 0);

  const restoredWithoutApproval = await run(revoked, { now: new Date("2026-10-07T12:05:00.000Z") });
  assert.equal(restoredWithoutApproval.state, "authorization-invalid");
  assert.equal(restoredWithoutApproval.lastFailureCategory, "authorization-reapproval-required");
  assert.equal(revoked.state.writes, 0, "Restored permissions alone must not renew prior authorization.");
  revoked.state.comments.push({
    id: 503, body: "/approve", created_at: "2026-10-07T12:10:00.000Z",
    html_url: `https://github.com/${owner}/${repo}/issues/${issueNumber}#issuecomment-503`,
    issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`,
    user: { login: "maintainer", type: "User" }
  });
  revoked.state.comments.push({
    id: 9002, body: approvalContract.approvedScopeReceipt(issueNumber, revoked.state.comments.at(-1), spec),
    user: { login: "github-actions[bot]", type: "Bot" }
  });
  const explicitRenewal = await run(revoked, { now: new Date("2026-10-07T12:10:00.000Z") });
  assert.equal(explicitRenewal.state, "assigned");
  assert.equal(explicitRenewal.attemptsConsumed, 1);

  const staleOrigin = fixture({ approval: false });
  staleOrigin.state.comments.push({
    id: 504,
    body: `<!-- basecoat-approval-forward:v1 pr:4 comment:999 issue:${issueNumber} -->\nOriginal qualified directive: "/approve"`,
    user: { login: "github-actions[bot]", type: "Bot" },
    created_at: "2026-10-07T11:30:00.000Z"
  });
  const stale = await run(staleOrigin);
  assert.equal(stale.state, "authorization-invalid");
  assert.equal(staleOrigin.state.writes, 0, "A missing forwarded origin (404) must not authorize assignment.");

  const statusWriteFailure = fixture();
  statusWriteFailure.state.statusWriteError = Object.assign(new Error("comment write denied"), { status: 403 });
  await assert.rejects(run(statusWriteFailure), /comment write denied/);
  assert.equal(statusWriteFailure.state.writes, 0, "Attempt persistence failure must stop before the assignment request.");

  const noCapability = fixture({ capability: [] });
  const disabled = await run(noCapability);
  assert.equal(disabled.state, "blocked");
  assert.equal(disabled.lastFailureCategory, "capability-disabled");
  assert.equal(noCapability.state.writes, 0);

  for (const status of [403, 404, 422]) {
    const rejected = fixture({
      requestBehavior() { throw Object.assign(new Error("Assignment rejected"), { status }); }
    });
    rejected.state.readBackError = {
      after: 4, error: Object.assign(new Error("Readback unavailable"), { status: 503 })
    };
    const rejectedState = await run(rejected);
    assert.equal(rejectedState.state, "blocked",
      "Failed readback must not turn permanent assignment rejection into retryable.");
    assert.equal(rejectedState.nextRetryAt, null);
    assert.equal(rejectedState.attemptsConsumed, 1);
    await run(rejected, { now: new Date("2026-10-09T12:00:00.000Z") });
    assert.equal(rejected.state.writes, 1);
  }
  const transientAssignmentPermanentReadback = fixture({
    requestBehavior() {
      throw Object.assign(new Error("temporary assignment failure"), { status: 503 });
    }
  });
  transientAssignmentPermanentReadback.state.readBackError = {
    after: 4, error: Object.assign(new Error("assignee read denied"), { status: 403 })
  };
  const permanentReadbackFailure = await run(transientAssignmentPermanentReadback);
  assert.equal(permanentReadbackFailure.state, "blocked");
  assert.equal(permanentReadbackFailure.lastFailureCategory, "preflight-permission-denied");
  assert.match(permanentReadbackFailure.ownerAction, /restore access/i);
  assert.equal(transientAssignmentPermanentReadback.state.writes, 1);

  const removedAgent = fixture();
  await run(removedAgent);
  removedAgent.state.issue.assignees = [];
  const removedState = await run(removedAgent, {
    recovery: true, recoveryWritesEnabled: true, now: new Date("2026-10-09T12:00:00.000Z")
  });
  assert.equal(removedState.state, "blocked");
  assert.equal(removedState.lastFailureCategory, "human-assignee-conflict");
  assert.equal(removedAgent.state.writes, 1, "Human unassignment must not trigger automatic repair.");

  const spoofedState = fixture();
  spoofedState.state.comments.push({
    id: 700, user: { login: "maintainer" },
    body: `${assignment.MARKER}\nmalformed user-owned state`
  });
  assert.equal((await run(spoofedState)).state, "assigned",
    "User marker comments cannot supply trusted assignment state.");
  const malformedOwnedState = fixture();
  malformedOwnedState.state.comments.push({
    id: 700, user: { login: "github-actions[bot]" },
    body: `${assignment.MARKER}\nmalformed owned state`
  });
  await assert.rejects(run(malformedOwnedState), /no valid state payload/);
  assert.equal(malformedOwnedState.state.writes, 0);

  const transientPreflight = fixture();
  transientPreflight.state.dependency = Object.assign(new Error("GitHub unavailable"), { status: 503 });
  transientPreflight.state.issue.body += "\nDepends on #99";
  transientPreflight.github.rest.issues.get = async ({ issue_number }) => {
    if (issue_number === 99) throw transientPreflight.state.dependency;
    return { data: transientPreflight.state.issue };
  };
  const readFailure = await run(transientPreflight);
  assert.equal(readFailure.state, "retryable");
  assert.equal(readFailure.attemptsConsumed, 0);
  assert.equal(readFailure.nextRetryAt, "2026-10-07T12:00:30.000Z");
  assert.equal(transientPreflight.state.writes, 0);

  const throttled = fixture({
    requestBehavior() {
      throw Object.assign(new Error("API throttled"), {
        status: 429, response: { headers: { "retry-after": "120" } }
      });
    }
  });
  const throttleState = await run(throttled);
  assert.equal(throttleState.nextRetryAt, "2026-10-07T12:02:00.000Z");
  const notDue = await run(throttled, { now: new Date("2026-10-07T12:01:59.000Z") });
  assert.equal(notDue.attemptsConsumed, 1);
  assert.equal(throttled.state.writes, 1, "A longer Retry-After must defer rather than retry at the cap.");

  const exactBackoff = fixture({
    requestBehavior() { throw Object.assign(new Error("server failed"), { status: 503 }); }
  });
  let retry = await run(exactBackoff);
  assert.equal(retry.nextRetryAt, "2026-10-07T12:00:30.000Z");
  retry = await run(exactBackoff, { now: new Date(retry.nextRetryAt) });
  assert.equal(retry.nextRetryAt, "2026-10-07T12:01:15.000Z");
  retry = await run(exactBackoff, { now: new Date(retry.nextRetryAt) });
  assert.equal(retry.state, "blocked");
  assert.equal(retry.attemptsConsumed, 3);
  assert.equal(retry.blockReason, "attempt-budget-exhausted");
  assert.equal(retry.nextRetryAt, null);
  assert.equal(retry.lastFailureCategory, "api-server-error");

  const exhausted = fixture({
    requestBehavior() { throw Object.assign(new Error("server failed"), { status: 503 }); }
  });
  let exhaustedState;
  let at = start;
  for (let index = 0; index < 550; index += 1) {
    exhaustedState = await run(exhausted, { now: at });
    at = exhaustedState.nextRetryAt
      ? new Date(exhaustedState.nextRetryAt)
      : new Date(at.getTime() + 60_000);
  }
  assert.equal(exhaustedState.state, "blocked");
  assert.equal(exhaustedState.attemptsConsumed, 3);
  assert.equal(exhausted.state.writes, 3, "550 sweeps must exhaust once and never exceed the finite request budget.");

  const cancelled = fixture();
  const cancelAfterPersist = {
    get aborted() {
      return statusFromComments(cancelled.state.comments)?.attemptsConsumed === 1;
    }
  };
  await assert.rejects(run(cancelled, { signal: cancelAfterPersist }), { name: "AbortError" });
  const cancelledState = statusFromComments(cancelled.state.comments);
  assert.equal(cancelledState.attemptsConsumed, 1);
  assert.equal(cancelledState.nextRetryAt, "2026-10-07T12:00:30.000Z");
  assert.equal(cancelled.state.writes, 0);
  const stillDeferred = await run(cancelled, { now: start });
  assert.equal(stillDeferred.attemptsConsumed, 1);
  assert.equal(cancelled.state.writes, 0);
  const resumed = await run(cancelled, { now: new Date(cancelledState.nextRetryAt) });
  assert.equal(resumed.state, "assigned");
  assert.equal(resumed.attemptsConsumed, 2);
  assert.equal(cancelled.state.writes, 1);

  const humanConflict = fixture({ assignees: [{ login: "maintainer", type: "User" }] });
  humanConflict.state.requestBehavior = () => {
    throw Object.assign(new Error("temporary"), { status: 503 });
  };
  let conflictRetry = await run(humanConflict);
  assert.equal(conflictRetry.state, "retryable");
  humanConflict.state.issue.assignees.push({ login: "triage-human", type: "User" });
  const conflict = await run(humanConflict, { now: new Date(conflictRetry.nextRetryAt) });
  assert.equal(conflict.state, "blocked");
  assert.equal(conflict.lastFailureCategory, "human-assignee-conflict");
  assert.equal(humanConflict.state.writes, 1);

  const newAuthorization = fixture({
    requestBehavior() { throw Object.assign(new Error("temporary"), { status: 503 }); }
  });
  let priorEpoch = await run(newAuthorization);
  priorEpoch = await run(newAuthorization, { now: new Date(priorEpoch.nextRetryAt) });
  priorEpoch = await run(newAuthorization, { now: new Date(priorEpoch.nextRetryAt) });
  assert.equal(priorEpoch.state, "blocked");
  newAuthorization.state.issue.body = "- Spec: https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/new.spec.md";
  newAuthorization.state.comments.push({
    id: 502, body: "/approve", created_at: "2026-10-07T12:10:00.000Z",
    html_url: `https://github.com/${owner}/${repo}/issues/${issueNumber}#issuecomment-502`,
    issue_url: `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`,
    user: { login: "maintainer", type: "User" }
  });
  newAuthorization.state.comments.push({
    id: 9002, body: approvalContract.approvedScopeReceipt(issueNumber, newAuthorization.state.comments.at(-1),
      "https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/new.spec.md"),
    user: { login: "github-actions[bot]", type: "Bot" }
  });
  newAuthorization.state.requestBehavior = null;
  const newEpoch = await run(newAuthorization, { now: new Date("2026-10-07T12:10:00.000Z") });
  assert.equal(newEpoch.state, "assigned");
  assert.equal(newEpoch.attemptsConsumed, 1);
  assert.equal(newEpoch.previousEpochs.length, 1);

  console.log("Agent assignment adapter, workflow extraction, and bounded recovery tests passed.");
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
