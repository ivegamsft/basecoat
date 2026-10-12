"use strict";

const { createHash } = require("node:crypto");
const { isBotActor, hasQualifiedPermission } = require("./ship-it/preapproval-evidence.cjs");
const { isAgentAssignee } = require("./agent-assignment.cjs");

const HOLD_LABELS = ["blocked", "deferred", "delivery-hold", "needs-info", "duplicate", "invalid", "wontfix"];
const READY_STATUSES = new Set(["reviewed", "implementation-ready"]);

function parseSpecDirective(body) {
  const match = String(body ?? "").trim().match(/^\/approve-spec ([1-9]\d{0,9}) ([0-9a-f]{40})$/i);
  return match ? { prNumber: Number(match[1]), headSha: match[2].toLowerCase() } : null;
}

function deliveryIntent(visibleBody) {
  const values = Array.from(String(visibleBody || "").matchAll(/^[ \t]*Delivery intent:[ \t]*(.*?)[ \t]*$/gm), match => match[1].toLowerCase());
  if (values.length !== 1) return values.length ? "duplicate" : "missing";
  return values[0] || "malformed";
}

function parseSpecUrl(value, owner, repo) {
  const match = String(value || "").match(/^https:\/\/github\.com\/([^/]+)\/([^/]+)\/blob\/([0-9a-f]{40})\/(docs\/spec\/[\w./-]+\.spec\.md)$/);
  if (!match || match[1].toLowerCase() !== owner.toLowerCase() ||
      match[2].toLowerCase() !== repo.toLowerCase() || match[4].split("/").includes("..")) return null;
  return { commit: match[3], path: match[4] };
}

function frontMatter(text) {
  const block = String(text || "").match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/)?.[1] || "";
  return Object.fromEntries(Array.from(block.matchAll(/^([a-z_]+):[ \t]*["']?(.*?)["']?[ \t]*$/gim),
    match => [match[1].toLowerCase(), match[2]]));
}

async function readBlob(github, owner, repo, path, ref) {
  const { data } = await github.rest.repos.getContent({ owner, repo, path, ref }).catch(error => {
    if (error.status === 404) return { data: null };
    throw error;
  });
  return !data || Array.isArray(data) || data.type !== "file" ? null :
    { sha: data.sha, text: Buffer.from(data.content || "", "base64").toString("utf8") };
}

async function resolveSpecHandoff(args) {
  const record = { issueNumber: Number(args.issueNumber), directiveId: Number(args.commentId) || null,
    state: "blocked", reason: null, ownerAction: null, writesEnabled: false, identity: null, evidence: {} };
  const finish = (state, reason, ownerAction) => Object.assign(record, { state, reason, ownerAction });
  try {
    return await resolveInto(args, record, finish);
  } catch {
    return finish("blocked", "evidence-unavailable", "GitHub evidence could not be read; rerun once it is accessible.");
  }
}

async function resolveInto({ github, owner, repo, issueNumber, commentId, approval }, record, finish) {
  const comment = await github.rest.issues.getComment({ owner, repo, comment_id: Number(commentId) })
    .then(response => response.data, error => { if (error.status === 404) return null; throw error; });
  if (!comment) return finish("authorization-invalid", "directive-deleted", "Post a fresh qualified /approve-spec directive.");
  const directive = parseSpecDirective(comment.body);
  const issueUrl = `${github.request?.endpoint?.DEFAULTS?.baseUrl || "https://api.github.com"}/repos/${owner}/${repo}/issues/${issueNumber}`;
  if (!directive || isBotActor(comment.user) || !comment.user?.login ||
      String(comment.issue_url || "").toLowerCase() !== issueUrl.toLowerCase()) {
    return finish("authorization-invalid", "directive-not-exact", "Post an exact /approve-spec <pr> <head-sha> comment on the source issue.");
  }
  if (comment.updated_at && comment.updated_at !== comment.created_at)
    return finish("authorization-invalid", "directive-edited", "Edited directives do not qualify; post a fresh /approve-spec comment.");
  const { data: permission } = await github.rest.repos.getCollaboratorPermissionLevel({ owner, repo, username: comment.user.login });
  if (!hasQualifiedPermission(permission))
    return finish("authorization-invalid", "directive-actor-unqualified", "A write, maintain, or admin collaborator must post the directive.");
  Object.assign(record.evidence, { directiveUrl: comment.html_url, actor: comment.user.login,
    specPr: directive.prNumber, approvedHead: directive.headSha });
  const contract = await approval.validateIssue({ github, owner, repo, issueNumber });
  if (contract.missing.length) return finish("blocked", "source-contract-incomplete", contract.missing.join("; "));
  const labels = (contract.issue.labels || []).map(label => String(typeof label === "string" ? label : label.name || "").toLowerCase());
  const holds = HOLD_LABELS.filter(label => labels.includes(label));
  if (holds.length) return finish("blocked", "source-hold", `Clear hold labels: ${holds.join(", ")}; then post a fresh directive.`);
  const intent = deliveryIntent(approval.visibleSpecText(contract.issue.body));
  if (intent !== "implementation") {
    return finish("blocked", `delivery-intent-${intent === "missing" || intent === "duplicate" ? intent : "not-implementation"}`,
      "Set exactly one `Delivery intent: implementation` line, then post a fresh directive.");
  }
  const directiveTime = Date.parse(comment.created_at || "");
  let chronology;
  try {
    const events = await github.paginate(github.rest.issues.listEvents, { owner, repo, issue_number: issueNumber, per_page: 100 });
    const { repository } = await github.graphql(
      "query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){lastEditedAt}}}",
      { owner, repo, number: Number(issueNumber) });
    chronology = [repository.issue.lastEditedAt, ...events.filter(event =>
      ["closed", "reopened"].includes(event.event) || ["labeled", "unlabeled"].includes(event.event) &&
      HOLD_LABELS.includes(String(event.label?.name || "").toLowerCase())).map(event => event.created_at)]
      .filter(Boolean).map(Date.parse);
    chronology.push(...contract.comments.filter(item => /^[ \t]*(?:Blocked by|Depends on)[ \t]/im.test(item.body || ""))
      .map(item => Date.parse(item.updated_at || item.created_at || "")));
    const resolutions = (contract.dependencyResolutions || []).map(item => Date.parse(item.resolvedAt || ""));
    if (resolutions.some(time => !Number.isFinite(time))) throw new Error("Dependency resolution time is unknown.");
    chronology.push(...resolutions);
  } catch {
    return finish("blocked", "chronology-unknown", "Edit, label or dependency history could not be read; rerun once GitHub evidence is accessible.");
  }
  if (!Number.isFinite(directiveTime) || chronology.some(time => !Number.isFinite(time) || time >= directiveTime))
    return finish("authorization-invalid", "directive-stale", "The source changed or a dependency cleared after the directive; post a fresh qualified directive.");
  const { data: pr } = await github.rest.pulls.get({ owner, repo, pull_number: directive.prNumber });
  const sources = Array.from(approval.visibleSpecText(pr.body).matchAll(/^Source issues:[ \t]*(.*?)[ \t]*$/gm), match => match[1]);
  if (pr.head?.repo?.id !== pr.base?.repo?.id || pr.base?.repo?.full_name?.toLowerCase() !== `${owner}/${repo}`.toLowerCase() ||
      pr.base?.ref !== pr.base?.repo?.default_branch || sources.length !== 1 ||
      !new RegExp(`^#?${Number(issueNumber)}$`).test(sources[0])) {
    return finish("authorization-invalid", "spec-pr-not-bound", "The spec PR must be same-repository, target the default branch, and declare exactly this source issue.");
  }
  if (String(pr.head?.sha || "").toLowerCase() !== directive.headSha)
    return finish("authorization-invalid", "approved-head-mismatch", "The spec PR head changed after approval; review it and post a fresh directive.");
  if (!pr.merged || !pr.merge_commit_sha) return finish("spec-draft", "spec-pr-not-merged", "Merge the approved spec PR before handoff.");
  if (!(Date.parse(pr.merged_at || "") < directiveTime))
    return finish("authorization-invalid", "directive-before-merge", "Post a fresh /approve-spec directive after the spec PR merges.");
  const specRef = parseSpecUrl(contract.specRef, owner, repo);
  const files = await github.paginate(github.rest.pulls.listFiles, { owner, repo, pull_number: pr.number, per_page: 100 });
  if (!specRef || !files.some(file => file.filename === specRef.path && file.status !== "removed"))
    return finish("blocked", "spec-url-not-bound", "Set the issue Spec URL to a commit-pinned blob URL of the spec file merged by this PR.");
  const spec = await readBlob(github, owner, repo, specRef.path, pr.merge_commit_sha);
  const prdPaths = Array.from(approval.visibleSpecText(spec?.text).matchAll(
    /^[ \t]*-[ \t]*PRD:[ \t]*`(docs\/prd\/[\w./-]+\.prd\.md)`[ \t]*$/gm), match => match[1]);
  const prdPath = prdPaths.length === 1 && !prdPaths[0].split("/").includes("..") ? prdPaths[0] : null;
  const prd = prdPath ? await readBlob(github, owner, repo, prdPath, pr.merge_commit_sha) : null;
  const ready = doc => Number(frontMatter(doc?.text).issue) === Number(issueNumber) && READY_STATUSES.has(String(frontMatter(doc?.text).status).toLowerCase());
  if (!ready(spec) || !ready(prd)) {
    return finish("blocked", "spec-documents-not-ready", "The merged spec and its single declared PRD must exist, name this issue, and be reviewed or implementation-ready.");
  }
  const pinned = await readBlob(github, owner, repo, specRef.path, specRef.commit);
  const currentSpec = await readBlob(github, owner, repo, specRef.path, pr.base.repo.default_branch);
  const currentPrd = await readBlob(github, owner, repo, prdPath, pr.base.repo.default_branch);
  if (pinned?.sha !== spec.sha || currentSpec?.sha !== spec.sha || currentPrd?.sha !== prd.sha)
    return finish("authorization-invalid", "spec-blob-changed", "The spec or PRD changed after merge; review it and post a fresh directive.");
  Object.assign(record.evidence, { mergeCommit: pr.merge_commit_sha, specPath: specRef.path, specBlob: spec.sha,
    prdPath, prdBlob: prd.sha, specUrl: contract.specRef });
  record.identity = createHash("sha256").update([pr.base.repo.id, issueNumber, comment.id, pr.number,
    directive.headSha, pr.merge_commit_sha, prd.sha, spec.sha].join("\n")).digest("hex");
  if ((contract.issue.assignees || []).some(isAgentAssignee))
    return finish("assigned", "agent-assignee-observed", "Assignment already observed; execution evidence is tracked separately.");
  return finish("handoff-pending", "writes-disabled",
    "Read-only discovery: assignment writes stay disabled until the trusted canary is configured.");
}

module.exports = { HOLD_LABELS, parseSpecDirective, deliveryIntent, parseSpecUrl, resolveSpecHandoff };
