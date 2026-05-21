---

name: github-security-posture
description: "Use when auditing GitHub organization or repository security settings with traffic-light scoring and remediation guidance. USE FOR: review branch protection and rulesets, check secret scanning and push protection, triage Dependabot or code scanning alerts, assess CODEOWNERS coverage, produce GitHub security posture report. DO NOT USE FOR: fixing application code vulnerabilities, cloud IAM auditing, incident response for active breaches."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Security & Compliance"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# GitHub Security Posture Skill

Audit GitHub organization and repository security settings with traffic-light scoring and
remediation guidance. Covers org configs, rulesets, secret scanning, push protection,
Dependabot alerts, branch protection, and CODEOWNERS.

## Reference Files

| File | Contents |
|------|----------|
| [`references/org-checks.md`](references/org-checks.md) | Org-level checks (O1–O4), org API quick reference, scoring rubric |
| [`references/repo-checks.md`](references/repo-checks.md) | Repo-level checks (R1–R8), repo API quick reference |

## Key Patterns

- Run `gh auth status` first — verify `repo` and `read:org` scopes are present
- Overall score: 🟢 all pass | 🟡 no fails, some warnings | 🔴 any fail
- Pair with `github-security-posture` agent (drives workflow) and `security-analyst` for deep analysis

## Templates

| Template | Purpose |
|---|---|
| `posture-report-template.md` | Traffic-light posture report with org checks, repo checks, scorecard, and remediation commands |
