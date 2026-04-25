# Branch Protection — Recommended Ruleset

> **Part of:** basecoat Enterprise Governance Framework · Issue #43 · Sprint 5 / v1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Enterprise Policy Note](#enterprise-policy-note)
3. [Recommended Settings (UI)](#recommended-settings-ui)
4. [JSON Ruleset Template](#json-ruleset-template)
5. [Applying the Ruleset via GitHub CLI](#applying-the-ruleset-via-github-cli)
6. [Rule-by-Rule Rationale](#rule-by-rule-rationale)
7. [Minimum Viable Protection (MVP)](#minimum-viable-protection-mvp)

---

## Overview

This document defines the recommended branch protection configuration for
repositories that adopt the **basecoat** template. It covers:

- **`main`** — production/default branch (strictest rules)
- **`release/*`** — release branches (strict)
- **Feature branches** — lighter touch, developer-friendly

The configuration is designed to be **enterprise-compatible**: rules that may
conflict with GitHub Enterprise managed policies are noted explicitly.

---

## Enterprise Policy Note

> ⚠️ **GitHub Enterprise organisation or enterprise policies may override or
> conflict with repository-level branch protection rules.**

Common enterprise overrides to be aware of:

| Enterprise policy | Effect on this ruleset |
|-------------------|------------------------|
| Required GHAS (Advanced Security) checks | May add additional required status checks beyond what is configured here |
| "Enforce admins" at org level | Cannot be disabled at repo level |
| "Allow force push" disabled at org level | `allow_force_pushes: false` is already aligned — no conflict |
| Required number of reviewers (org minimum) | Sets a floor; repo-level can only increase it |
| Signed commits required at org level | Already recommended here |
| Status check requirements | Enterprise may add; cannot remove at repo level |

**Action:** Before applying this ruleset, review your organisation's branch
protection policies in **Settings → Policies → Branch protection** (org level)
to understand what is already enforced.

---

## Recommended Settings (UI)

Navigate to: **Repository Settings → Branches → Add rule** (or edit existing rule).

### `main` branch

| Setting | Value | Notes |
|---------|-------|-------|
| Branch name pattern | `main` | Exact match |
| Require a pull request before merging | ✅ | No direct pushes to main |
| Required approvals | **1** (minimum) | Adjust to 2 for higher-risk repos |
| Dismiss stale reviews | ✅ | Re-review after new push |
| Require review from code owners | ✅ (if CODEOWNERS exists) | Enforce ownership boundaries |
| Require status checks to pass | ✅ | See status checks list below |
| Require branches to be up to date | ✅ | Prevents stale-branch merges |
| Require conversation resolution | ✅ | All review comments must be resolved |
| Require signed commits | ✅ | Verify author identity |
| Include administrators | ✅ | No admin bypass |
| Allow force pushes | ❌ | Never on main |
| Allow deletions | ❌ | Never delete main |
| Restrict who can push | ✅ (optional) | Limit to CI service accounts + leads |

#### Required status checks for `main`

These are the checks defined in basecoat workflows:

| Check name | Workflow | Notes |
|-----------|----------|-------|
| `validate-commit-messages` | `validate-basecoat.yml` | Commit message format |
| `validate-unix` | `validate-basecoat.yml` | Bash validation suite |
| `validate-windows` | `validate-basecoat.yml` | PowerShell validation suite |
| `gitleaks` | `secret-scan.yml` | ⚠️ Warn-only — **do NOT add as required check** |
| `prd-spec-gate` | `prd-spec-gate.yml` | PRD spec compliance |

> **Important:** Do **not** add the `gitleaks` / `Secret Scanning (warn only)`
> check as a required status check. It is intentionally warn-only and must
> never block merges. See [Secret Scanning design rationale](./SECRET_SCANNING.md#overview).

### `release/*` branches

Same as `main` with these differences:
- Required approvals: **2**
- Restrict who can push: CI release automation + release manager role only

### Feature branches (`feature/*`, `fix/*`, `chore/*`)

- No branch protection required (developer flexibility)
- Rely on pre-commit hooks for local enforcement
- CI runs on all PRs targeting `main`

---

## JSON Ruleset Template

GitHub's new **Repository Rulesets** API (recommended over legacy branch
protection rules for enterprise use) supports JSON import/export.

Save this as `branch-protection-ruleset.json` and import via CLI (see next section):

```json
{
  "name": "main-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "required_signatures"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "allowed_merge_methods": ["squash", "merge"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          {
            "context": "validate-commit-messages",
            "integration_id": null
          },
          {
            "context": "validate-unix",
            "integration_id": null
          },
          {
            "context": "validate-windows",
            "integration_id": null
          }
        ]
      }
    },
    {
      "type": "commit_message_pattern",
      "parameters": {
        "name": "Conventional Commits",
        "negate": false,
        "operator": "regex",
        "pattern": "^(feat|fix|docs|chore|refactor|test|ci|perf|style|build|revert)(\\(.+\\))?: .{1,100}"
      }
    }
  ],
  "bypass_actors": []
}
```

> **Note on `bypass_actors`:** Leave empty for maximum security. If CI/CD
> service accounts need merge rights without review (e.g. automated release
> bots), add them here with `"role_name": "OrganizationAdmin"` or a specific
> app ID. Enterprise policy may inject bypass actors automatically.

---

## Applying the Ruleset via GitHub CLI

```bash
# Authenticate
gh auth login

# Create the ruleset from JSON (GitHub Rulesets API)
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/{OWNER}/{REPO}/rulesets \
  --input branch-protection-ruleset.json

# List existing rulesets
gh api /repos/{OWNER}/{REPO}/rulesets

# Update existing ruleset (get ID from list first)
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/{OWNER}/{REPO}/rulesets/{RULESET_ID} \
  --input branch-protection-ruleset.json
```

### Legacy branch protection (classic)

If your organisation uses classic branch protection (not Rulesets):

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/{OWNER}/{REPO}/branches/main/protection \
  --field required_status_checks='{"strict":true,"contexts":["validate-commit-messages","validate-unix","validate-windows"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false
```

---

## Rule-by-Rule Rationale

| Rule | Why |
|------|-----|
| **No direct push to main** | All changes reviewed by ≥1 human; audit trail via PR |
| **Dismiss stale reviews** | Prevents approval laundering after post-review changes |
| **Up-to-date branch required** | Ensures CI ran against the actual merge state, not a stale base |
| **Conversation resolution** | Forces reviewers and authors to close feedback loops |
| **Signed commits** | Verifies author identity; prevents commit author spoofing |
| **No force push** | Preserves immutable history on main |
| **No deletion** | Prevents accidental or malicious main branch deletion |
| **Required linear history** | Cleaner git log; easier to bisect and revert |
| **Conventional commit pattern** | Enables automated changelog generation; enforces PR hygiene |
| **No `gitleaks` as required check** | Warn-only by design — see Secret Scanning rationale |

---

## Minimum Viable Protection (MVP)

For repos where full enforcement is not yet possible (e.g., solo developers,
prototype repos), enable at minimum:

1. ✅ Require PR before merging (no direct push to main)
2. ✅ At least 1 required status check (`validate-unix` or `validate-basecoat`)
3. ✅ No force pushes
4. ✅ No deletions
5. ✅ Local gitleaks pre-commit hook installed

---

> **Maintainer:** Branch protection policy owned by the security_analyst squad agent.
> Issues → [#43](https://github.com/ivegamsft/basecoat/issues/43)
