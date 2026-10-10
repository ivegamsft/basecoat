"use strict";

const { createHash } = require("node:crypto");

const MARKER = "<!-- basecoat-agent-assignment:v1 -->";
const STATE_MARKER = "<!-- basecoat-agent-assignment-state:v1";
const DEFAULT_MAX_ATTEMPTS = 3;
const AGENT_LOGINS = new Set(["copilot-swe-agent", "copilot-swe-agent[bot]"]);

function isAgentAssignee(assignee) {
  return AGENT_LOGINS.has(String(assignee?.login || "").toLowerCase());
}

function parseStateComment(comment) {
  const text = String(comment?.body || "");
  if (!text.includes(MARKER)) return null;
  const match = text.match(/<!-- basecoat-agent-assignment-state:v1\s*\n([\s\S]*?)\n-->/);
  if (!match) throw new Error("Assignment status comment has no valid state payload.");
  let state;
  try {
    state = JSON.parse(match[1]);
  } catch (error) {
    throw new Error(`Assignment status payload is invalid: ${error.message}`);
  }
  if (!Number.isSafeInteger(state.issueNumber) || state.issueNumber < 1 ||
      !Number.isSafeInteger(state.attemptsConsumed) || state.attemptsConsumed < 0 ||
      !Number.isSafeInteger(state.maxAttempts) || state.maxAttempts < 1 ||
      !["pending", "retryable", "blocked", "assigned", "authorization-invalid"].includes(state.state)) {
    throw new Error("Assignment status payload violates its state schema.");
  }
  return state;
}

function isoAfter(seconds, now) {
  return new Date(now.getTime() + seconds * 1000).toISOString();
}

function retryAfterSeconds(error, now) {
  const headers = error?.response?.headers || {};
  const value = headers["retry-after"] || headers["Retry-After"];
  if (value === undefined || value === null || value === "") return 0;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds > 0) return Math.ceil(seconds);
  const timestamp = Date.parse(String(value));
  return Number.isFinite(timestamp) && timestamp > now.getTime()
    ? Math.ceil((timestamp - now.getTime()) / 1000)
    : 0;
}

function isTransient(error) {
  const status = Number(error?.status || error?.response?.status || 0);
  const message = String(error?.message || "");
  return status === 429 || (status === 403 &&
      (/rate limit/i.test(message) || retryAfterSeconds(error, new Date()) > 0)) ||
    status >= 500 || ["ECONNRESET", "ETIMEDOUT", "EAI_AGAIN", "ECONNREFUSED"]
      .includes(String(error?.code || ""));
}

function failureCategory(error, operation) {
  const status = Number(error?.status || error?.response?.status || 0);
  if (isTransient(error)) {
    if (status === 429 || status === 403) return "api-throttled";
    if (status >= 500) return "api-server-error";
    return "network-error";
  }
  if (operation === "capability") return "capability-query-failed";
  if (operation === "preflight") return status === 401 || status === 403
    ? "preflight-permission-denied" : "preflight-unavailable";
  if (status === 401 || status === 403) return "assignment-permission-denied";
  if (status === 404) return "assignment-operation-unsupported";
  if (status === 422) return "assignment-payload-rejected";
  return "assignment-request-failed";
}

function ownerActionFor(category) {
  const actions = {
    "capability-disabled": "Enable the Copilot coding agent for this repository, then issue a fresh qualified /approve if authorization scope changed.",
    "capability-query-failed": "Check repository Copilot capability availability and workflow permissions.",
    "assignment-permission-denied": "Restore the workflow's existing issue-assignment permission; do not reapprove by label.",
    "assignment-operation-unsupported": "Confirm this repository supports the documented Copilot assignment endpoint.",
    "assignment-payload-rejected": "Review the assignment payload and GitHub's accepted agent-assignment contract.",
    "dependency-unresolved": "Resolve the listed dependencies, then post a fresh qualified /approve.",
    "metadata-invalid": "Complete the issue metadata contract, then post a fresh qualified /approve.",
    "spec-invalid": "Restore one valid, non-placeholder Spec URL and post a fresh qualified /approve.",
    "authorization-missing": "Post a new exact /approve directive from a currently qualified human collaborator.",
    "authorization-revoked": "Restore qualified collaborator access and post a new exact /approve directive.",
    "authorization-reapproval-required": "Post a fresh exact /approve directive; restoring access does not renew prior authorization.",
    "authorization-scope-receipt-missing": "Review the current specification and post a fresh qualified /approve to capture its immutable scope.",
    "authorization-scope-changed": "Post a new exact /approve after reviewing the changed specification.",
    "attempt-budget-exhausted": "Inspect the recorded failures and explicitly approve a materially changed authorization before a new epoch.",
    "human-assignee-conflict": "Review the changed human assignee list; the worker preserved it and will not repair it automatically.",
    "recovery-write-disabled": "Recovery is in read-only rollout; enable it only after controlled authorized assignment verification.",
    "preflight-unavailable": "Retry after GitHub issue, dependency, and permission reads are healthy.",
    "preflight-permission-denied": "Restore access needed to revalidate current approval and dependencies.",
    "assignment-request-failed": "Inspect the GitHub assignment error category before a new qualified approval.",
    "api-throttled": "Wait until the persisted retry time and allow the next bounded reconciliation sweep.",
    "api-server-error": "Wait until the persisted retry time and allow the next bounded reconciliation sweep.",
    "network-error": "Wait until the persisted retry time and allow the next bounded reconciliation sweep.",
    "assignee-not-persisted": "Wait until the persisted retry time; verify GitHub's assignee state before another request."
  };
  return actions[category] || "Inspect the recorded status and restore the required authority or API availability.";
}

function serializeStatus(state) {
  const json = JSON.stringify(state);
  const approvalLink = state.originalApprovalUrl
    ? `[original approval](${state.originalApprovalUrl})` : "unknown (not verified)";
  const assigneeProfile = String(state.verifiedAssignee || "").replace(/\[bot\]$/i, "");
  const assigneeLink = state.verifiedAssignee
    ? `[@${state.verifiedAssignee}](https://github.com/${encodeURIComponent(assigneeProfile)})`
    : "not verified";
  const executionLink = state.executionUrl
    ? `[execution evidence](${state.executionUrl})` : "unobserved (no verified execution URL)";
  return [
    MARKER,
    `${STATE_MARKER}\n${json}\n-->`,
    "## Coding-agent assignment status",
    "",
    `- Issue: #${state.issueNumber}`,
    `- Original approval: ${approvalLink}`,
    `- State: \`${state.state}\``,
    `- Assignment epoch: \`${state.epoch || "unavailable"}\``,
    `- Attempts consumed: ${state.attemptsConsumed}/${state.maxAttempts}`,
    `- Next retry: ${state.nextRetryAt || "none scheduled"}`,
    `- Last failure category: \`${state.lastFailureCategory || "none"}\``,
    `- Block reason: \`${state.blockReason || "none"}\``,
    `- Owner action: ${state.ownerAction || "none"}`,
    `- Verified assignee: ${assigneeLink}`,
    `- Execution: ${state.executionState || "unobserved"}; ${executionLink}`,
    `- Verified at: ${state.verifiedAt || "not observed"}`
  ].join("\n");
}

async function readStatus({ github, owner, repo, issueNumber }) {
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner, repo, issue_number: issueNumber, per_page: 100
  });
  const matching = comments.filter(comment =>
    comment.user?.login === "github-actions[bot]" &&
    String(comment.body || "").includes(MARKER)
  );
  if (matching.length === 0) return null;
  matching.sort((a, b) => Date.parse(a.updated_at || a.created_at || 0) -
    Date.parse(b.updated_at || b.created_at || 0));
  return { comment: matching[matching.length - 1], state: parseStateComment(matching[matching.length - 1]) };
}

async function writeStatus({ github, owner, repo, issueNumber, state, current }) {
  const body = serializeStatus(state);
  if (current?.comment) {
    const { data: comment } = await github.rest.issues.updateComment({
      owner, repo, comment_id: current.comment.id, body
    });
    return { comment, state };
  } else {
    const { data: comment } = await github.rest.issues.createComment({
      owner, repo, issue_number: issueNumber, body
    });
    return { comment, state };
  }
}

function makeEpoch(issueNumber, evidence, specRef) {
  const identity = [
    issueNumber, evidence.id, evidence.user?.login?.toLowerCase(),
    evidence.issue_url, specRef
  ].join("\n");
  return createHash("sha256").update(identity).digest("hex");
}

function configuredBudget(value) {
  if (value === undefined || value === "") return DEFAULT_MAX_ATTEMPTS;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 10) {
    throw new Error("MAX_ASSIGNMENT_ATTEMPTS must be an integer from 1 through 10.");
  }
  return parsed;
}

function newState(issueNumber, epoch, evidence, specRef, maxAttempts) {
  return {
    issueNumber, epoch, originalApprovalId: Number(evidence.id),
    originalApprovalActor: evidence.user.login,
    originalApprovalUrl: evidence.html_url,
    approvalCreatedAt: evidence.created_at || null,
    specRef, state: "pending", attemptsConsumed: 0, maxAttempts,
    nextRetryAt: null, lastFailureCategory: null, blockReason: null, ownerAction: null,
    verifiedAssignee: null, executionState: "unobserved", executionUrl: null,
    verifiedAt: null, authorizationInvalidAt: null,
    baselineHumanAssignees: [], previousEpochs: []
  };
}

function initializeEpoch({ issueNumber, evidence, specRef, previous, maxAttempts }) {
  const epoch = makeEpoch(issueNumber, evidence, specRef);
  if (!previous) return newState(issueNumber, epoch, evidence, specRef, maxAttempts);
  if (previous.epoch === epoch) {
    return previous.state === "authorization-invalid" ? null :
      { ...previous, maxAttempts: previous.maxAttempts };
  }
  const oldTime = Date.parse(previous.approvalCreatedAt || "");
  const newTime = Date.parse(evidence.created_at || "");
  const invalidAt = Date.parse(previous.authorizationInvalidAt || "");
  if (previous.state === "authorization-invalid" &&
      (!Number.isFinite(newTime) || !Number.isFinite(invalidAt) || newTime <= invalidAt)) {
    return null;
  }
  if (!previous.epoch && previous.attemptsConsumed === 0) {
    const state = newState(issueNumber, epoch, evidence, specRef, previous.maxAttempts);
    state.previousEpochs = [
      ...(Array.isArray(previous.previousEpochs) ? previous.previousEpochs : []),
      { epoch: previous.epoch, attemptsConsumed: previous.attemptsConsumed,
        maxAttempts: previous.maxAttempts, state: previous.state,
        lastFailureCategory: previous.lastFailureCategory }
    ].slice(-10);
    return state;
  }
  if (!Number.isFinite(newTime) || !Number.isFinite(oldTime) || newTime <= oldTime) {
    return null;
  }
  const state = newState(issueNumber, epoch, evidence, specRef, maxAttempts);
  state.previousEpochs = [
    ...(Array.isArray(previous.previousEpochs) ? previous.previousEpochs : []),
    { epoch: previous.epoch, attemptsConsumed: previous.attemptsConsumed,
      maxAttempts: previous.maxAttempts, state: previous.state }
  ].slice(-10);
  return state;
}

function isFreshAuthorizationEpoch(issueNumber, evidence, specRef, state) {
  if (!state || makeEpoch(issueNumber, evidence, specRef) === state.epoch) return false;
  const boundary = state.state === "authorization-invalid"
    ? state.authorizationInvalidAt : state.approvalCreatedAt;
  const boundaryTime = Date.parse(boundary || "");
  const approvalTime = Date.parse(evidence?.created_at || "");
  return Number.isFinite(boundaryTime) && Number.isFinite(approvalTime) &&
    approvalTime > boundaryTime;
}

function retryState(state, category, attemptNumber, error, now) {
  const exponential = Math.min(90, 30 * Math.pow(1.5, Math.max(0, attemptNumber - 1)));
  const delaySeconds = Math.max(exponential, retryAfterSeconds(error, now));
  state.state = state.attemptsConsumed >= state.maxAttempts ? "blocked" : "retryable";
  state.nextRetryAt = state.state === "retryable" ? isoAfter(delaySeconds, now) : null;
  state.lastFailureCategory = category;
  state.blockReason = state.state === "blocked" ? "attempt-budget-exhausted" : null;
  state.ownerAction = ownerActionFor(state.blockReason || category);
  return state;
}

function expectedHumanAssignees(assignees) {
  return (assignees || []).filter(assignee => !isAgentAssignee(assignee))
    .map(assignee => String(assignee.login || "").toLowerCase()).sort();
}

async function readAssignees({ github, owner, repo, issueNumber }) {
  const { data: issue } = await github.rest.issues.get({ owner, repo, issue_number: issueNumber });
  return issue;
}

async function findExecutionEvidence({ github, owner, repo, issueNumber }) {
  if (!github.rest.issues.listEventsForTimeline) return null;
  const events = await github.paginate(github.rest.issues.listEventsForTimeline, {
    owner, repo, issue_number: issueNumber, per_page: 100
  });
  for (const event of [...events].reverse()) {
    const source = event.source?.issue;
    if (event.event !== "cross-referenced" || !source?.pull_request ||
        !isAgentAssignee(source.user) || !Number.isSafeInteger(Number(source.number))) continue;
    const { data: pull } = await github.rest.pulls.get({
      owner, repo, pull_number: Number(source.number)
    });
    if (!isAgentAssignee(pull.user) || !pull.html_url) continue;
    const url = new URL(pull.html_url);
    if (url.origin !== "https://github.com" ||
        url.pathname.toLowerCase() !== `/${owner}/${repo}/pull/${Number(source.number)}`.toLowerCase()) {
      continue;
    }
    return pull.html_url;
  }
  return null;
}

async function runAssignmentWorker({
  github, owner, repo, issueNumber, recovery = false,
  recoveryWritesEnabled = false, maxAttempts: requestedMaxAttempts,
  now = new Date(), approval, approvedSpecRef, signal
}) {
  const number = Number(issueNumber);
  if (!Number.isSafeInteger(number) || number < 1) throw new Error("issueNumber must be a positive integer.");
  const maxAttempts = configuredBudget(requestedMaxAttempts);
  const prior = await readStatus({ github, owner, repo, issueNumber: number });
  let current = prior;
  let state = prior?.state || null;
  const save = async () => {
    if (state.state === "blocked" && !state.blockReason) {
      state.blockReason = state.lastFailureCategory;
    }
    if (state.state !== "blocked") state.blockReason = null;
    if (recovery && !recoveryWritesEnabled) return;
    const written = await writeStatus({
      github, owner, repo, issueNumber: number, state, current
    });
    current = written;
  };
  if (!approval?.validateIssue || !approval?.findLatestApproval) {
    throw new Error("The trusted shared approval contract is required by the assignment worker.");
  }
  let validated;
  try {
    validated = await approval.validateIssue({ github, owner, repo, issueNumber: number });
  } catch (error) {
    const category = failureCategory(error, "preflight");
    if (!isTransient(error) && !Number(error?.status || error?.response?.status)) throw error;
    state ||= newState(number, null, { id: 0, user: { login: "unknown" } }, "", maxAttempts);
    state.state = isTransient(error) ? "retryable" : "blocked";
    state.lastFailureCategory = category;
    state.nextRetryAt = state.state === "retryable" ? isoAfter(30, now) : null;
    state.ownerAction = ownerActionFor(category);
    await save();
    return state;
  }
  let evidence;
  try {
    evidence = await approval.findLatestApproval({
      github, owner, repo, issueNumber: number, comments: validated.comments
    });
  } catch (error) {
    const category = failureCategory(error, "preflight");
    if (!isTransient(error) && !Number(error?.status || error?.response?.status)) throw error;
    state ||= newState(number, null, { id: 0, user: { login: "unknown" } }, "", maxAttempts);
    state.state = isTransient(error) ? "retryable" : "blocked";
    state.lastFailureCategory = category;
    state.nextRetryAt = state.state === "retryable" ? isoAfter(30, now) : null;
    state.ownerAction = ownerActionFor(category);
    await save();
    return state;
  }
  if (!evidence) {
    state ||= newState(number, null, { id: 0, user: { login: "unknown" } }, "", maxAttempts);
    state.state = "authorization-invalid";
    state.authorizationInvalidAt = now.toISOString();
    state.nextRetryAt = null;
    state.lastFailureCategory = "authorization-missing";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    await save();
    return state;
  }
  const metadataMissing = validated.missing.filter(item => !item.startsWith("Unresolved dependencies:"));
  const dependenciesMissing = validated.missing.some(item => item.startsWith("Unresolved dependencies:"));
  const specRef = validated.specRef;
  const persistedSpecRef = approval.findApprovedSpecRef?.({
    comments: validated.comments, evidence, issueNumber: number
  }) || null;
  const approvedRef = approvedSpecRef || persistedSpecRef;
  if (!approvedRef) {
    state ||= newState(number, null, evidence, specRef, maxAttempts);
    state.state = "authorization-invalid";
    state.authorizationInvalidAt ||= now.toISOString();
    state.nextRetryAt = null;
    state.lastFailureCategory = "authorization-scope-receipt-missing";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    await save();
    return state;
  }
  if ((persistedSpecRef && persistedSpecRef !== specRef) ||
      (approvedSpecRef && persistedSpecRef && approvedSpecRef !== persistedSpecRef)) {
    if (!state) {
      throw new Error("Current specification does not match the immutable scope captured by approval.");
    }
    state.state = "blocked";
    state.nextRetryAt = null;
    state.lastFailureCategory = "authorization-scope-changed-needs-fresh-approval";
    state.ownerAction = ownerActionFor("authorization-scope-changed");
    await save();
    return state;
  }
  if (!state && approvedRef !== specRef) {
    throw new Error("Initial assignment requires the exact specification scope captured by approval.");
  }
  if (state && Number(state.originalApprovalId) !== Number(evidence.id) &&
      approvedRef !== specRef) {
    state.state = "blocked";
    state.nextRetryAt = null;
    state.lastFailureCategory = "authorization-scope-changed-needs-fresh-approval";
    state.ownerAction = ownerActionFor("authorization-scope-changed");
    await save();
    return state;
  }
  const target = initializeEpoch({
    issueNumber: number, evidence, specRef, previous: state, maxAttempts
  });
  if (!target) {
    if (state.state === "authorization-invalid") {
      state.authorizationInvalidAt ||= now.toISOString();
      state.lastFailureCategory = "authorization-reapproval-required";
      state.ownerAction = ownerActionFor("authorization-reapproval-required");
      state.nextRetryAt = null;
      await save();
      return state;
    }
    state.state = "blocked";
    state.nextRetryAt = null;
    state.lastFailureCategory = "authorization-scope-changed-needs-fresh-approval";
    state.ownerAction = ownerActionFor("authorization-scope-changed");
    await save();
    return state;
  }
  state = target;
  if (validated.issue.pull_request || validated.issue.state !== "open") {
    state.state = "authorization-invalid";
    state.authorizationInvalidAt = now.toISOString();
    state.lastFailureCategory = "authorization-missing";
    state.ownerAction = ownerActionFor("authorization-missing");
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (!evidence.created_at || !evidence.id || !evidence.user?.login) {
    state.state = "authorization-invalid";
    state.authorizationInvalidAt = now.toISOString();
    state.lastFailureCategory = "authorization-missing";
    state.ownerAction = ownerActionFor("authorization-missing");
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (metadataMissing.length || dependenciesMissing) {
    const specInvalid = metadataMissing.some(item => /Spec reference/.test(item));
    state.state = specInvalid ? "authorization-invalid" : "blocked";
    if (state.state === "authorization-invalid") state.authorizationInvalidAt = now.toISOString();
    state.lastFailureCategory = specInvalid ? "spec-invalid" :
      dependenciesMissing ? "dependency-unresolved" : "metadata-invalid";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }

  let liveIssue;
  try {
    liveIssue = await readAssignees({ github, owner, repo, issueNumber: number });
  } catch (error) {
    const category = failureCategory(error, "preflight");
    if (!isTransient(error) && !Number(error?.status || error?.response?.status)) throw error;
    state.state = isTransient(error) ? "retryable" : "blocked";
    state.lastFailureCategory = category;
    state.nextRetryAt = state.state === "retryable" ? isoAfter(30, now) : null;
    state.ownerAction = ownerActionFor(category);
    await save();
    return state;
  }
  const agent = (liveIssue.assignees || []).find(isAgentAssignee);
  const captureExecutionEvidence = async () => {
    try {
      const executionUrl = await findExecutionEvidence({
        github, owner, repo, issueNumber: number
      });
      if (executionUrl) {
        state.executionState = "observed";
        state.executionUrl = executionUrl;
      }
    } catch {
      // Execution evidence is observational; failed discovery remains unobserved.
    }
  };
  if (state.attemptsConsumed > 0 &&
      JSON.stringify(expectedHumanAssignees(liveIssue.assignees)) !==
      JSON.stringify(state.baselineHumanAssignees)) {
    state.state = "blocked";
    state.verifiedAssignee = agent?.login || null;
    state.lastFailureCategory = "human-assignee-conflict";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (agent) {
    await captureExecutionEvidence();
    state.state = "assigned";
    state.verifiedAssignee = agent.login;
    state.verifiedAt ||= now.toISOString();
    state.nextRetryAt = null;
    state.lastFailureCategory = null;
    state.ownerAction = null;
    await save();
    return state;
  }

  if (state.state === "assigned") {
    state.state = "blocked";
    state.lastFailureCategory = "human-assignee-conflict";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (state.state === "blocked") return state;
  if (state.attemptsConsumed >= state.maxAttempts) {
    state.state = "blocked";
    state.blockReason = "attempt-budget-exhausted";
    state.ownerAction = ownerActionFor("attempt-budget-exhausted");
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (state.nextRetryAt && Date.parse(state.nextRetryAt) > now.getTime()) return state;
  let copilotActor;
  try {
    const { repository } = await github.graphql(
      `query($owner: String!, $repo: String!) {
        repository(owner: $owner, name: $repo) {
          suggestedActors(capabilities: [CAN_BE_ASSIGNED], first: 100) {
            nodes { login ... on Bot { id } }
          }
        }
      }`, { owner, repo }
    );
    copilotActor = repository?.suggestedActors?.nodes?.find(actor =>
      actor?.login === "copilot-swe-agent"
    );
  } catch (error) {
    const category = failureCategory(error, "capability");
    if (!isTransient(error)) {
      state.state = "blocked";
      state.lastFailureCategory = category;
      state.ownerAction = ownerActionFor(category);
      state.nextRetryAt = null;
      await save();
      return state;
    }
    retryState(state, category, Math.max(1, state.attemptsConsumed), error, now);
    await save();
    return state;
  }
  if (!copilotActor) {
    state.state = "blocked";
    state.lastFailureCategory = "capability-disabled";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }

  let finalContract;
  let finalEvidence;
  try {
    finalContract = await approval.validateIssue({ github, owner, repo, issueNumber: number });
    finalEvidence = await approval.findLatestApproval({
      github, owner, repo, issueNumber: number, comments: finalContract.comments
    });
  } catch (error) {
    const category = failureCategory(error, "preflight");
    if (!isTransient(error) && !Number(error?.status || error?.response?.status)) throw error;
    state.state = isTransient(error) ? "retryable" : "blocked";
    state.lastFailureCategory = category;
    state.nextRetryAt = state.state === "retryable" ? isoAfter(30, now) : null;
    state.ownerAction = ownerActionFor(category);
    await save();
    return state;
  }
  const finalIssueInvalid = finalContract.issue.state !== "open" || finalContract.issue.pull_request;
  const finalSpecInvalid = finalContract.missing.some(item => /Spec reference/.test(item));
  if (!finalEvidence || finalIssueInvalid || finalSpecInvalid || finalContract.missing.length) {
    state.state = !finalEvidence || finalIssueInvalid || finalSpecInvalid
      ? "authorization-invalid" : "blocked";
    if (state.state === "authorization-invalid") state.authorizationInvalidAt = now.toISOString();
    state.lastFailureCategory = !finalEvidence || finalIssueInvalid
      ? "authorization-missing" : finalSpecInvalid
        ? "spec-invalid" : finalContract.missing.some(item =>
          item.startsWith("Unresolved dependencies:"))
          ? "dependency-unresolved" : "metadata-invalid";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (makeEpoch(number, finalEvidence, finalContract.specRef) !== state.epoch) {
    state.state = "blocked";
    state.lastFailureCategory = "authorization-scope-changed-needs-fresh-approval";
    state.ownerAction = ownerActionFor("authorization-scope-changed");
    state.nextRetryAt = null;
    await save();
    return state;
  }
  liveIssue = finalContract.issue;
  const finalAgent = (liveIssue.assignees || []).find(isAgentAssignee);
  if (finalAgent) {
    state.state = "assigned";
    state.verifiedAssignee = finalAgent.login;
    state.verifiedAt ||= now.toISOString();
    state.lastFailureCategory = null;
    state.nextRetryAt = null;
    state.ownerAction = null;
    await save();
    return state;
  }
  if (state.attemptsConsumed > 0 &&
      JSON.stringify(expectedHumanAssignees(liveIssue.assignees)) !==
      JSON.stringify(state.baselineHumanAssignees)) {
    state.state = "blocked";
    state.lastFailureCategory = "human-assignee-conflict";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (state.attemptsConsumed === 0) {
    state.baselineHumanAssignees = expectedHumanAssignees(liveIssue.assignees);
  }
  if (recovery && !recoveryWritesEnabled) {
    state.state = "pending";
    state.lastFailureCategory ||= "recovery-write-disabled";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    return state;
  }
  state.attemptsConsumed += 1;
  state.state = "pending";
  state.lastFailureCategory = null;
  state.blockReason = null;
  state.nextRetryAt = isoAfter(30, now);
  state.ownerAction = "An assignment attempt is durably consumed; verify the live assignee before retry.";
  await save();
  if (signal?.aborted) {
    const error = new Error("Assignment worker cancelled after persisting attempt consumption.");
    error.name = "AbortError";
    throw error;
  }

  let requestError = null;
  try {
    await github.request("POST /repos/{owner}/{repo}/issues/{issue_number}/assignees", {
      owner, repo, issue_number: number,
      assignees: ["copilot-swe-agent[bot]"],
      agent_assignment: {
        target_repo: `${owner}/${repo}`, base_branch: "main",
        custom_instructions: `Implement the approved specification in issue #${number} using the repository's existing conventions. Open a ready-for-review implementation PR (not a draft) with \`Closes #${number}\` in its body. Required CI and the merge executor own merge eligibility; do not request a human review for XS through XL changes.`,
        custom_agent: "", model: ""
      },
      request: { retryCount: 0 }
    });
  } catch (error) {
    requestError = error;
  }

  let after;
  try {
    after = await readAssignees({ github, owner, repo, issueNumber: number });
  } catch (readError) {
    const category = !isTransient(readError)
      ? failureCategory(readError, "preflight")
      : requestError ? failureCategory(requestError, "assignment") : failureCategory(readError, "preflight");
    if (requestError && !isTransient(requestError)) {
      state.state = "blocked";
      state.nextRetryAt = null;
      state.lastFailureCategory = category;
      state.ownerAction = ownerActionFor(category);
      await save();
      return state;
    }
    if (!isTransient(readError)) {
      state.state = "blocked";
      state.nextRetryAt = null;
      state.lastFailureCategory = category;
      state.ownerAction = ownerActionFor(category);
      await save();
      return state;
    }
    retryState(state, category, state.attemptsConsumed, requestError || readError, now);
    await save();
    return state;
  }
  const assigned = (after.assignees || []).find(isAgentAssignee);
  if (JSON.stringify(expectedHumanAssignees(after.assignees)) !==
      JSON.stringify(state.baselineHumanAssignees)) {
    state.state = "blocked";
    state.verifiedAssignee = assigned?.login || null;
    state.lastFailureCategory = "human-assignee-conflict";
    state.ownerAction = ownerActionFor(state.lastFailureCategory);
    state.nextRetryAt = null;
    await save();
    return state;
  }
  if (assigned) {
    await captureExecutionEvidence();
    state.state = "assigned";
    state.verifiedAssignee = assigned.login;
    state.verifiedAt ||= now.toISOString();
    state.lastFailureCategory = null;
    state.nextRetryAt = null;
    state.ownerAction = null;
    await save();
    return state;
  }

  const category = requestError
    ? failureCategory(requestError, "assignment") : "assignee-not-persisted";
  if (requestError && !isTransient(requestError)) {
    state.state = "blocked";
    state.nextRetryAt = null;
    state.lastFailureCategory = category;
    state.ownerAction = ownerActionFor(category);
    await save();
    return state;
  }
  retryState(state, category, state.attemptsConsumed, requestError, now);
  await save();
  return state;
}

function isRetryDue(state, now = new Date()) {
  if (!state) return true;
  if (state.state !== "pending" && state.state !== "retryable") return false;
  return !state.nextRetryAt || Date.parse(state.nextRetryAt) <= now.getTime();
}

module.exports = {
  MARKER, STATE_MARKER, DEFAULT_MAX_ATTEMPTS, isAgentAssignee,
  parseStateComment, readStatus, writeStatus, runAssignmentWorker, isRetryDue,
  retryAfterSeconds, configuredBudget, makeEpoch, isFreshAuthorizationEpoch
};
