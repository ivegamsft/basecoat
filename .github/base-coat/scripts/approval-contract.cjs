"use strict";

const { isBotActor, isExactIssueApproval, hasQualifiedPermission } =
  require("./ship-it/preapproval-evidence.cjs");

function isPlaceholderSpecUrl(value) {
  try {
    const candidate = String(value || "").trim();
    const url = new URL(candidate);
    const host = url.hostname.toLowerCase();
    return !/^https?:\/\/[^/?#\s<>`]+(?:[/?#][^\s<>`]*)?$/i.test(candidate) ||
      !["http:", "https:"].includes(url.protocol) || !host || Boolean(url.username || url.password) ||
      ["example.com", "example.org", "example.net", "localhost"].some(
        domain => host === domain || host.endsWith(`.${domain}`)
      ) || /\.(?:invalid|test|localhost)$/.test(host) ||
      /\b(?:placeholder|replace[-_ ]?me|todo|tbd)\b/i.test(candidate);
  } catch {
    return true;
  }
}

function closingIssueNumbers(text) {
  return new Set(Array.from(String(text || "").matchAll(
    /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)\b/gim
  ), match => Number(match[1])));
}

function visibleSpecText(body) {
  let fence = null;
  return String(body || "").replace(/<!--[\s\S]*?(?:-->|$)/g, "").split(/\r?\n/).map(line => {
    const marker = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (marker) {
      if (!fence) fence = marker[1];
      else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = null;
      return "";
    }
    return fence ? "" : line;
  }).join("\n");
}

async function qualifiedDirective({ github, owner, repo, commentId, issueNumber }) {
  let comment;
  try {
    ({ data: comment } = await github.rest.issues.getComment({
      owner, repo, comment_id: Number(commentId)
    }));
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
  const expectedUrl = `${github.request?.endpoint?.DEFAULTS?.baseUrl || "https://api.github.com"}/repos/${owner}/${repo}/issues/${issueNumber}`;
  if (Number(comment.id) !== Number(commentId) ||
      !isExactIssueApproval(comment.body) || isBotActor(comment.user) ||
      !comment.user?.login ||
      String(comment.issue_url || "").toLowerCase() !== expectedUrl.toLowerCase()) {
    return null;
  }
  const { data: permission } = await github.rest.repos.getCollaboratorPermissionLevel({
    owner, repo, username: comment.user.login
  });
  return hasQualifiedPermission(permission) ? comment : null;
}

async function validateIssue({ github, owner, repo, issueNumber }) {
  const { data: issue } = await github.rest.issues.get({ owner, repo, issue_number: issueNumber });
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner, repo, issue_number: issueNumber, per_page: 100
  });
  const labels = (issue.labels || []).map(label =>
    String(typeof label === "string" ? label : label.name || "").toLowerCase()
  );
  const missing = [];
  if (issue.pull_request || issue.state !== "open") missing.push("Source must be an open issue");
  if (!["bug", "enhancement", "documentation", "chore", "security", "question"]
    .some(label => labels.includes(label))) missing.push("Type label is required");
  if (!["critical", "high", "medium", "low"].some(level =>
    labels.includes(`priority:${level}`))) missing.push("Priority label is required");
  const blockers = ["duplicate", "invalid", "wontfix"].filter(label => labels.includes(label));
  if (blockers.length) missing.push(`Blocking label present: ${blockers.join(", ")}`);
  const specs = Array.from(visibleSpecText(issue.body).matchAll(
    /^[ \t]*-[ \t]*Spec:[ \t]*(.*?)[ \t]*$/gim
  ), match => match[1]);
  const specRef = specs.length === 1 && !isPlaceholderSpecUrl(specs[0]) ? specs[0] : "";
  if (!specRef) missing.push("Spec reference must be exactly one non-placeholder Spec URL");
  const dependencies = new Map();
  for (const text of [issue.body, ...comments.map(comment => comment.body)]) {
    for (const match of String(text || "").matchAll(
      /^[ \t]*(?:Blocked by|Depends on)[ \t]+(?:#(\d+)|https?:\/\/github\.com\/([^/\s]+)\/([^/\s]+)\/(?:issues|pull)\/(\d+))\b/gim
    )) {
      const dependency = { owner: match[2] || owner, repo: match[3] || repo,
        issue_number: Number(match[1] || match[4]) };
      dependencies.set(`${dependency.owner}/${dependency.repo}#${dependency.issue_number}`, dependency);
    }
  }
  for (const [reference, dependency] of dependencies) {
    const { data: linked } = await github.rest.issues.get(dependency);
    let resolved = linked.state === "closed";
    if (linked.pull_request) {
      const { data: linkedPr } = await github.rest.pulls.get({
        owner: dependency.owner, repo: dependency.repo, pull_number: dependency.issue_number
      });
      resolved = Boolean(linkedPr.merged);
    }
    if (!resolved) missing.push(`Unresolved dependencies: ${reference}`);
  }
  return { issue, comments, missing, specRef };
}

function forwardReceipt(prNumber, comment, issueNumber) {
  return [
    `<!-- basecoat-approval-forward:v1 pr:${prNumber} comment:${comment.id} issue:${issueNumber} -->`,
    `Original qualified directive: ${JSON.stringify(comment.body)}`,
    `Original actor: @${comment.user.login}`,
    `Original evidence: ${comment.html_url}`,
    "Authority remains the original human directive, revalidated at delivery."
  ].join("\n");
}

async function findApproval({ github, owner, repo, issueNumber, comments }) {
  for (const comment of comments) {
    if (isExactIssueApproval(comment.body) && !isBotActor(comment.user)) {
      const original = await qualifiedDirective({
        github, owner, repo, commentId: comment.id, issueNumber
      });
      if (original) return original;
    }
    if (comment.user?.login !== "github-actions[bot]" || comment.user?.type !== "Bot") continue;
    const receipt = String(comment.body || "").match(
      /^<!-- basecoat-approval-forward:v1 pr:(\d+) comment:(\d+) issue:(\d+) -->\r?\n/
    );
    if (!receipt || Number(receipt[3]) !== Number(issueNumber)) continue;
    const original = await qualifiedDirective({
      github, owner, repo, commentId: receipt[2], issueNumber: receipt[1]
    });
    if (!original) continue;
    const { data: pr } = await github.rest.pulls.get({
      owner, repo, pull_number: Number(receipt[1])
    });
    if (closingIssueNumbers(`${pr.title || ""}\n${pr.body || ""}`).has(Number(issueNumber))) {
      return original;
    }
  }
  return null;
}

module.exports = { isExactIssueApproval, hasQualifiedPermission, isPlaceholderSpecUrl,
  closingIssueNumbers, qualifiedDirective, validateIssue, forwardReceipt, findApproval };
