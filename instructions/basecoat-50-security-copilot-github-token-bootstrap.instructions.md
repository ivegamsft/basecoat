---
description: "Use only when gh-aw needs a PAT fallback because organization-backed inference is unavailable or expanded API access is required. Enforces least-privilege, non-echo token handling."
applyTo: "**/scripts/bootstrap-copilot-github-token.ps1,docs/operations/GITHUB_SECRETS.md"
---

# COPILOT_GITHUB_TOKEN Bootstrap Rules

Apply this instruction when implementing or updating repository bootstrap logic for
`COPILOT_GITHUB_TOKEN`.

## Requirements

- When using the PAT fallback, configure `COPILOT_GITHUB_TOKEN` as a
  **repository secret** (not a variable). Do not configure it for
  organization-backed `copilot-requests: write` workflows.
- Use `gh secret set` to automate setup; do not require manual UI copy-paste only.
- Never print the PAT value to console or logs.
- Accept secure input (`SecureString`, stdin, or equivalent) and clear plaintext memory.
- Validate `gh auth status` before attempting secret writes.

## Token Strategy

- Prefer `permissions: copilot-requests: write` for repositories with
  organization-backed Copilot billing. This uses the short-lived GitHub Actions
  token and requires no inference PAT.
- `COPILOT_GITHUB_TOKEN` is the fallback for gh-aw engine authentication when
  organization-backed inference is unavailable and should use the minimum
  scopes needed for that path.
- Prefer a **separate PAT** for `GH_AW_GITHUB_TOKEN` and
  `GH_AW_GITHUB_MCP_SERVER_TOKEN`.
- Reusing one PAT across all secrets is allowed only when explicitly requested.

## Script UX Expectations

- Support `-Repo owner/name` with origin autodetection fallback.
- Support non-interactive mode for automation (`-Silent` + explicit token input).
- Return explicit errors when token is missing or `gh` is unauthenticated.
- Print the follow-up verification command:

```powershell
gh secret list --repo <owner/repo>
```

## Anti-Patterns

```powershell
# WRONG: token echoed
Write-Host "PAT: $token"

# WRONG: only manual instructions, no automation path
Write-Host "Go set COPILOT_GITHUB_TOKEN in Settings"
```
