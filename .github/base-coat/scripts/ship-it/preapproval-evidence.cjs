"use strict";

const { createHash } = require("node:crypto");
const { spawnSync } = require("node:child_process");

const QUALIFIED_PERMISSIONS = new Set(["admin", "maintain", "write"]);
const RECEIPT_MARKER_PATTERN = /<!-- basecoat-preapproval-receipt:v1 ([A-Za-z0-9_-]+) -->/;

function isBotActor(user) {
  const login = String(user?.login || "");
  return user?.type === "Bot" || login.toLowerCase().endsWith("[bot]");
}

function isExactIssueApproval(body) {
  return /^\/approve$/i.test(String(body || "").trim());
}

function hasQualifiedPermission(permission) {
  return [permission?.permission, permission?.role_name]
    .some(level => QUALIFIED_PERMISSIONS.has(String(level || "").toLowerCase()));
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value).sort().map(key => [key, stableValue(value[key])])
    );
  }
  return value;
}

function stableJson(value) {
  return JSON.stringify(stableValue(value));
}

function sha256(value) {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function parseIntentContract(body) {
  const match = String(body || "").match(
    /(?:^|\r?\n)##\s+Intent Contract\s*\r?\n([\s\S]*?)(?=\r?\n##\s|$)/i
  );
  if (!match) throw new Error("Approved issue is missing its ## Intent Contract section.");

  const fields = {
    intent: "Intent",
    goal: "Goal",
    scope: "Scope",
    target_repo: "Repository",
    risk_band: "Risk band",
    profile: "Profile",
    spec_ref: "Spec reference"
  };
  const parsed = {};
  for (const [field, label] of Object.entries(fields)) {
    const values = Array.from(
      match[1].matchAll(new RegExp(`^\\s*-\\s*${label}\\s*:\\s*(.*?)\\s*$`, "gim")),
      value => value[1].trim().replace(/^`+(.+?)`+$/, "$1")
    );
    if (values.length !== 1 || !values[0] || values[0] === "_Not provided_") {
      throw new Error(`Approved issue must contain exactly one non-empty '${label}' contract field.`);
    }
    parsed[field] = values[0];
  }
  if (parsed.scope !== parsed.goal) {
    throw new Error("Approved issue Goal and Scope must match exactly.");
  }
  return parsed;
}

function parsePinnedSpec(reference, owner, repo) {
  let url;
  try {
    url = new URL(String(reference || ""));
  } catch {
    throw new Error("Approved scope must reference a commit-pinned repository spec.");
  }
  const parts = url.pathname.split("/").filter(Boolean);
  const specPath = parts.slice(4).join("/");
  if (
    url.protocol !== "https:" ||
    url.hostname.toLowerCase() !== "github.com" ||
    url.search ||
    url.hash ||
    parts.length < 7 ||
    `${parts[0]}/${parts[1]}`.toLowerCase() !== `${owner}/${repo}`.toLowerCase() ||
    parts[2] !== "blob" ||
    !/^[0-9a-f]{40}$/i.test(parts[3]) ||
    !specPath.startsWith("docs/spec/") ||
    !specPath.endsWith(".spec.md") ||
    parts.slice(4).some(part => part === "." || part === "..")
  ) {
    throw new Error("Approved scope must reference a commit-pinned spec in this repository.");
  }
  return { commit: parts[3].toLowerCase(), path: specPath };
}

function labelsContainApproved(labels) {
  return (labels || []).some(label =>
    String(typeof label === "string" ? label : label?.name || "").toLowerCase() === "approved"
  );
}

function isoTime(value, name) {
  const milliseconds = new Date(value || "").getTime();
  if (!Number.isFinite(milliseconds)) throw new Error(`${name} is missing or invalid.`);
  return new Date(milliseconds).toISOString();
}

function laterTime(left, right) {
  return new Date(left).getTime() >= new Date(right).getTime() ? left : right;
}

function receiptPayload(receipt) {
  const { receipt_hash: _receiptHash, ...payload } = receipt;
  return payload;
}

function sealReceipt(receipt) {
  const payload = receiptPayload(receipt);
  return { ...payload, receipt_hash: sha256(stableJson(payload)) };
}

function assertReceiptSeal(receipt) {
  if (!receipt || typeof receipt !== "object" || Array.isArray(receipt)) {
    throw new Error("Pre-approval receipt is malformed.");
  }
  if (receipt.receipt_hash !== sha256(stableJson(receiptPayload(receipt)))) {
    throw new Error("Pre-approval receipt hash does not match its recorded fields.");
  }
}

function encodeReceipt(receipt) {
  assertReceiptSeal(receipt);
  return Buffer.from(stableJson(receipt), "utf8").toString("base64url");
}

function decodeReceipt(value) {
  let receipt;
  try {
    receipt = JSON.parse(Buffer.from(String(value || ""), "base64url").toString("utf8"));
  } catch {
    throw new Error("Pre-approval receipt is not valid encoded JSON.");
  }
  assertReceiptSeal(receipt);
  return receipt;
}

function createOctokitApi(github) {
  return {
    async getIssue(owner, repo, issueNumber) {
      return (await github.rest.issues.get({ owner, repo, issue_number: issueNumber })).data;
    },
    async getIssueComment(owner, repo, commentId) {
      return (await github.rest.issues.getComment({ owner, repo, comment_id: commentId })).data;
    },
    async getPermission(owner, repo, login) {
      return (await github.rest.repos.getCollaboratorPermissionLevel({
        owner,
        repo,
        username: login
      })).data;
    },
    async getIssueBodyEditTime(owner, repo, issueNumber) {
      const result = await github.graphql(
        `query($owner: String!, $repo: String!, $number: Int!) {
          repository(owner: $owner, name: $repo) {
            issue(number: $number) { createdAt lastEditedAt }
          }
        }`,
        { owner, repo, number: issueNumber }
      );
      const issue = result?.repository?.issue;
      if (!issue) throw new Error("Unable to verify approved issue body edit history.");
      return { createdAt: issue.createdAt, lastEditedAt: issue.lastEditedAt };
    },
    async getSpec(owner, repo, specPath, commit) {
      return (await github.rest.repos.getContent({
        owner,
        repo,
        path: specPath,
        ref: commit
      })).data;
    },
    async getWorkflowRun(owner, repo, runId) {
      return (await github.rest.actions.getWorkflowRun({
        owner,
        repo,
        run_id: runId
      })).data;
    }
  };
}

function runGh(args, options = {}) {
  const result = spawnSync("gh", ["api", ...args], {
    encoding: "utf8",
    env: process.env,
    maxBuffer: 4 * 1024 * 1024
  });
  if (result.error) throw new Error(`Unable to run gh api: ${result.error.message}`);
  if (result.status !== 0) {
    throw new Error(`GitHub API request failed: ${String(result.stderr || "").trim()}`);
  }
  const output = String(result.stdout || "");
  if (options.includeHeaders) return output;
  try {
    return JSON.parse(output);
  } catch {
    throw new Error("GitHub API returned invalid JSON.");
  }
}

function createGhApi() {
  return {
    async getIssue(owner, repo, issueNumber) {
      return runGh([`repos/${owner}/${repo}/issues/${issueNumber}`]);
    },
    async getIssueComment(owner, repo, commentId) {
      return runGh([`repos/${owner}/${repo}/issues/comments/${commentId}`]);
    },
    async getPermission(owner, repo, login) {
      return runGh([`repos/${owner}/${repo}/collaborators/${encodeURIComponent(login)}/permission`]);
    },
    async getIssueBodyEditTime(owner, repo, issueNumber) {
      const query = `query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
          issue(number: $number) { createdAt lastEditedAt }
        }
      }`;
      const response = runGh([
        "graphql",
        "-f", `query=${query}`,
        "-F", `owner=${owner}`,
        "-F", `repo=${repo}`,
        "-F", `number=${issueNumber}`
      ]);
      const issue = response?.data?.repository?.issue;
      if (!issue) throw new Error("Unable to verify approved issue body edit history.");
      return { createdAt: issue.createdAt, lastEditedAt: issue.lastEditedAt };
    },
    async getSpec(owner, repo, specPath, commit) {
      const path = specPath.split("/").map(encodeURIComponent).join("/");
      return runGh([`repos/${owner}/${repo}/contents/${path}?ref=${commit}`]);
    },
    async getWorkflowRun(owner, repo, runId) {
      return runGh([`repos/${owner}/${repo}/actions/runs/${runId}`]);
    },
    async getRepository() {
      const result = spawnSync("gh", ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"], {
        encoding: "utf8",
        env: process.env,
        maxBuffer: 1024 * 1024
      });
      if (result.error || result.status !== 0) {
        throw new Error("Unable to resolve the current repository with gh repo view.");
      }
      return String(result.stdout || "").trim();
    },
    async getServerTime() {
      const headers = runGh(["--include", "/meta"], { includeHeaders: true });
      const match = headers.match(/(?:^|\r?\n)date:\s*([^\r\n]+)/i);
      if (!match) throw new Error("GitHub API did not return a server Date header.");
      return new Date(match[1]).toISOString();
    },
    async getViewerLogin() {
      return String(runGh(["user"]).login || "");
    }
  };
}

async function getAuthenticatedViewer(api) {
  if (!api || typeof api.getViewerLogin !== "function") {
    throw new Error("Unable to resolve the authenticated GitHub CLI user.");
  }
  const login = String(await api.getViewerLogin() || "").trim();
  if (!login) throw new Error("Unable to resolve the authenticated GitHub CLI user.");
  return login;
}

async function getRevalidationPrincipal(api, receipt) {
  const actionsRunId = String(process.env.GITHUB_RUN_ID || "");
  const actionsRepository = String(process.env.GITHUB_REPOSITORY || "");
  if (
    process.env.GITHUB_ACTIONS === "true" &&
    /^[1-9]\d*$/.test(actionsRunId) &&
    actionsRepository.toLowerCase() === String(receipt.source_repo || "").toLowerCase()
  ) {
    return String(receipt.execution_principal || "");
  }
  return getAuthenticatedViewer(api);
}

async function resolvePreApproval({
  api,
  sourceRepo,
  targetRepo,
  sourceIssueNumber,
  approvalCommentId,
  intent,
  goal,
  specRef,
  riskBand,
  profile,
  executionPrincipal,
  runId = "",
  runStartedAt,
  selectedPolicy = ""
}) {
  if (!api) throw new Error("A live GitHub API client is required for pre-approval validation.");
  const sourceId = String(sourceIssueNumber || "");
  const commentId = String(approvalCommentId || "");
  if (!/^[1-9]\d*$/.test(sourceId) || !/^[1-9]\d*$/.test(commentId)) {
    throw new Error("Pre-approval requires positive integer source_issue_number and approval_comment_id values.");
  }
  if (!Number.isSafeInteger(Number(sourceId)) || !Number.isSafeInteger(Number(commentId))) {
    throw new Error("Pre-approval issue and comment IDs must be safe positive integers.");
  }
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(String(sourceRepo || "")) ||
      String(sourceRepo).toLowerCase() !== String(targetRepo || "").toLowerCase()) {
    throw new Error("Pre-approval is limited to a source issue in the same target repository.");
  }
  const [owner, repo] = String(sourceRepo).split("/");
  if (!["ship-it", "spec-2-prod"].includes(String(intent || ""))) {
    throw new Error("Pre-approval is supported only for explicit ship-it or spec-2-prod intent.");
  }
  const principal = String(executionPrincipal || "").trim();
  const principalPermission = principal
    ? await api.getPermission(owner, repo, principal)
    : null;
  if (!principal || !hasQualifiedPermission(principalPermission)) {
    throw new Error(`Execution principal @${principal || "unknown"} lacks current write, maintain, or admin permission.`);
  }

  const issueNumber = Number(sourceId);
  const commentNumber = Number(commentId);
  const issue = await api.getIssue(owner, repo, issueNumber);
  if (issue.pull_request || issue.state !== "open" || Number(issue.number) !== issueNumber) {
    throw new Error("Pre-approval source must be the specified open issue, not a pull request.");
  }
  if (!labelsContainApproved(issue.labels)) {
    throw new Error(`Pre-approval source issue #${issueNumber} is missing the live approved label.`);
  }
  const comment = await api.getIssueComment(owner, repo, commentNumber);
  if (
    Number(comment.id) !== commentNumber ||
    String(comment.issue_url || "").replace(/\/+$/, "").toLowerCase() !==
      String(issue.url || "").replace(/\/+$/, "").toLowerCase()
  ) {
    throw new Error("Approval comment does not belong to the specified source issue in this repository.");
  }
  if (isBotActor(comment.user)) {
    throw new Error("Approval comment author is a bot; automation cannot approve its own run.");
  }
  if (!isExactIssueApproval(comment.body)) {
    throw new Error("Approval comment must contain only the exact /approve command.");
  }
  const approver = String(comment.user?.login || "");
  if (!approver || !hasQualifiedPermission(await api.getPermission(owner, repo, approver))) {
    throw new Error(`Approval author @${approver || "unknown"} lacks current write, maintain, or admin permission.`);
  }

  const cutoff = isoTime(runStartedAt, "Initial run start time");
  const approvalCreatedAt = isoTime(comment.created_at, "Approval comment creation time");
  const approvalUpdatedAt = isoTime(comment.updated_at || comment.created_at, "Approval comment update time");
  const effectiveApprovalAt = laterTime(approvalCreatedAt, approvalUpdatedAt);
  if (new Date(effectiveApprovalAt).getTime() >= new Date(cutoff).getTime()) {
    throw new Error("Approval must be recorded and unchanged strictly before the initial run start.");
  }

  const contract = parseIntentContract(issue.body);
  const expected = {
    intent: String(intent),
    goal: String(goal || "").trim(),
    target_repo: String(targetRepo),
    risk_band: String(riskBand || ""),
    profile: String(profile || ""),
    spec_ref: String(specRef || "").trim()
  };
  for (const [field, value] of Object.entries(expected)) {
    const caseInsensitive = ["target_repo", "risk_band", "profile"].includes(field);
    if (!value || (caseInsensitive
      ? contract[field].toLowerCase() !== value.toLowerCase()
      : contract[field] !== value)) {
      throw new Error(`Dispatch input '${field}' does not exactly match the approved issue scope.`);
    }
  }
  const pinnedSpec = parsePinnedSpec(contract.spec_ref, owner, repo);
  if (expected.spec_ref !== contract.spec_ref) {
    throw new Error("Dispatch spec_ref does not exactly match the approved issue scope.");
  }
  const spec = await api.getSpec(owner, repo, pinnedSpec.path, pinnedSpec.commit);
  if (!spec || spec.type !== "file" || !spec.content) {
    throw new Error("Pinned approved spec could not be read from the source repository.");
  }
  const specContent = Buffer.from(String(spec.content).replace(/\s/g, ""), "base64").toString("utf8");
  if (!specContent.trim()) throw new Error("Pinned approved spec is empty or inaccessible.");

  const editTimes = await api.getIssueBodyEditTime(owner, repo, issueNumber);
  const bodyCreatedAt = isoTime(editTimes?.createdAt, "Approved issue creation time");
  const bodyLastEditedAt = isoTime(editTimes?.lastEditedAt || bodyCreatedAt, "Approved issue body edit time");
  if (new Date(bodyLastEditedAt).getTime() > new Date(effectiveApprovalAt).getTime()) {
    throw new Error("Approved issue scope was edited after the approval comment; a renewed approval is required.");
  }

  const policy = String(selectedPolicy || `${profile}/${riskBand}`);
  const receipt = {
    decision: "accepted",
    rejection_reason: null,
    source_repo: `${owner}/${repo}`,
    target_repo: String(targetRepo),
    source_issue_number: issueNumber,
    source_issue_url: issue.html_url,
    approval_comment_id: commentNumber,
    approval_comment_url: comment.html_url,
    approver_login: approver,
    approval_created_at: approvalCreatedAt,
    approval_updated_at: approvalUpdatedAt,
    effective_approval_at: effectiveApprovalAt,
    issue_body_created_at: bodyCreatedAt,
    issue_body_last_edited_at: bodyLastEditedAt,
    issue_body_sha256: sha256(String(issue.body || "")),
    approval_body_sha256: sha256(String(comment.body || "")),
    run_id: String(runId || ""),
    run_started_at: cutoff,
    execution_principal: principal,
    intent: expected.intent,
    goal: contract.goal,
    scope: contract.scope,
    risk_band: contract.risk_band,
    profile: contract.profile,
    spec_ref: contract.spec_ref,
    spec_commit: pinnedSpec.commit,
    spec_path: pinnedSpec.path,
    spec_content_sha256: sha256(specContent),
    selected_policy: policy
  };
  receipt.scope_sha256 = sha256(stableJson({
    intent: receipt.intent,
    goal: receipt.goal,
    scope: receipt.scope,
    target_repo: receipt.target_repo.toLowerCase(),
    risk_band: receipt.risk_band.toLowerCase(),
    profile: receipt.profile.toLowerCase(),
    spec_commit: receipt.spec_commit,
    spec_path: receipt.spec_path
  }));
  return sealReceipt(receipt);
}

async function validateLiveReceipt({ api, receipt, currentExecutionPrincipal }) {
  assertReceiptSeal(receipt);
  if (typeof currentExecutionPrincipal !== "string" || currentExecutionPrincipal.trim() === "") {
    throw new Error("A current execution principal is required to validate live pre-approval evidence.");
  }
  const principal = currentExecutionPrincipal;
  if (principal !== receipt.execution_principal) {
    throw new Error("Pre-approval receipt execution principal does not match the current trusted principal.");
  }
  if (receipt.run_id) {
    const [owner, repo] = String(receipt.source_repo || "").split("/");
    const run = await api.getWorkflowRun(owner, repo, receipt.run_id);
    if (
      String(run.id) !== String(receipt.run_id) ||
      String(run.repository?.full_name || "").toLowerCase() !== String(receipt.source_repo).toLowerCase() ||
      isoTime(run.created_at, "Initial workflow run creation time") !== receipt.run_started_at ||
      String(run.actor?.login || "").toLowerCase() !== String(receipt.execution_principal).toLowerCase()
    ) {
      throw new Error("Pre-approval receipt does not match the immutable initial workflow run provenance.");
    }
  }
  const current = await resolvePreApproval({
    api,
    sourceRepo: receipt.source_repo,
    targetRepo: receipt.target_repo,
    sourceIssueNumber: receipt.source_issue_number,
    approvalCommentId: receipt.approval_comment_id,
    intent: receipt.intent,
    goal: receipt.goal,
    specRef: receipt.spec_ref,
    riskBand: receipt.risk_band,
    profile: receipt.profile,
    executionPrincipal: principal,
    runId: receipt.run_id,
    runStartedAt: receipt.run_started_at,
    selectedPolicy: receipt.selected_policy
  });
  if (stableJson(current) !== stableJson(receipt)) {
    throw new Error("Live approval evidence or its approved scope changed after dispatch.");
  }
  return current;
}

function extractReceipt(body) {
  const match = String(body || "").match(RECEIPT_MARKER_PATTERN);
  return match ? decodeReceipt(match[1]) : null;
}

function matchesReceiptScope(body, receipt) {
  const contract = parseIntentContract(body);
  return contract.intent === receipt.intent &&
    contract.goal === receipt.goal &&
    contract.scope === receipt.scope &&
    contract.target_repo.toLowerCase() === receipt.target_repo.toLowerCase() &&
    contract.risk_band.toLowerCase() === receipt.risk_band.toLowerCase() &&
    contract.profile.toLowerCase() === receipt.profile.toLowerCase() &&
    contract.spec_ref === receipt.spec_ref;
}

function expectedIntentRunHash(receipt) {
  const runKey = `${receipt.intent}|${receipt.target_repo}|${receipt.goal}|${receipt.profile}` +
    `|preapproval:${receipt.scope_sha256}`;
  return sha256(runKey.toLowerCase());
}

async function resolveInitialRunStart(api, owner, repo, runId) {
  if (runId) {
    const run = await api.getWorkflowRun(owner, repo, runId);
    return isoTime(run.created_at, "Initial workflow run creation time");
  }
  if (!api.getServerTime) {
    throw new Error("Local pre-approval requires a GitHub server-time resolver.");
  }
  return isoTime(await api.getServerTime(), "GitHub server time at local run initialization");
}

async function runCli() {
  const operation = process.argv[2];
  const api = createGhApi();
  if (operation === "resolve") {
    let request;
    try {
      request = JSON.parse(process.env.BASECOAT_PREAPPROVAL_REQUEST_JSON || "");
    } catch {
      throw new Error("Pre-approval request parameters are malformed.");
    }
    const [owner, repo] = String(request.targetRepo || "").split("/");
    if (!owner || !repo) throw new Error("Pre-approval target repository is invalid.");
    const currentRepo = process.env.GITHUB_REPOSITORY || await api.getRepository();
    if (String(currentRepo).toLowerCase() !== String(request.targetRepo).toLowerCase()) {
      throw new Error("Pre-approval is limited to the current repository; cross-repository approval is not supported.");
    }
    const runId = String(process.env.GITHUB_RUN_ID || "");
    const executionPrincipal = await getAuthenticatedViewer(api);
    const runStartedAt = await resolveInitialRunStart(api, owner, repo, runId);
    const receipt = await resolvePreApproval({
      api,
      ...request,
      sourceRepo: currentRepo,
      executionPrincipal,
      runId,
      runStartedAt
    });
    process.stdout.write(`${JSON.stringify(receipt)}\n`);
    return;
  }
  if (operation === "revalidate") {
    const receipt = decodeReceipt(process.env.BASECOAT_APPROVAL_RECEIPT_BASE64);
    const currentRepo = process.env.GITHUB_REPOSITORY || await api.getRepository();
    if (String(currentRepo).toLowerCase() !== String(receipt.source_repo).toLowerCase()) {
      throw new Error("Pre-approval is limited to the same current repository.");
    }
    const executionPrincipal = await getRevalidationPrincipal(api, receipt);
    const current = await validateLiveReceipt({ api, receipt, currentExecutionPrincipal: executionPrincipal });
    process.stdout.write(`${JSON.stringify(current)}\n`);
    return;
  }
  if (operation === "encode") {
    let receipt;
    try {
      receipt = JSON.parse(process.env.BASECOAT_PREAPPROVAL_RECEIPT_JSON || "");
    } catch {
      throw new Error("Pre-approval receipt JSON is malformed.");
    }
    process.stdout.write(`${encodeReceipt(receipt)}\n`);
    return;
  }
  throw new Error("Expected operation 'resolve', 'revalidate', or 'encode'.");
}

module.exports = {
  createGhApi,
  createOctokitApi,
  decodeReceipt,
  encodeReceipt,
  expectedIntentRunHash,
  extractReceipt,
  getAuthenticatedViewer,
  getRevalidationPrincipal,
  hasQualifiedPermission,
  isBotActor,
  isExactIssueApproval,
  matchesReceiptScope,
  parseIntentContract,
  parsePinnedSpec,
  resolveInitialRunStart,
  resolvePreApproval,
  validateLiveReceipt
};

if (require.main === module) {
  runCli().catch(error => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
