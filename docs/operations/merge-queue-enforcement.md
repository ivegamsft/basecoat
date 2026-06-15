# Merge Queue and Required Checks Enforcement — Sprint 36

> **Part of:** Sprint 36 Execution Plan · Issue #1548 · BaseCoat Enterprise Governance Framework

---

## Overview

This document defines the merge queue enforcement policy for **basecoat** and companion repositories. The merge queue provides a modern alternative to traditional branch protection by:

- **Reducing merge conflicts:** Tests run against the exact merge state
- **Enabling automation:** CI can safely merge PRs without manual coordination
- **Enforcing required checks:** All status checks must pass before queuing
- **Preventing race conditions:** Sequential merge processing prevents simultaneous conflicts

---

## Configuration

### Enable Merge Queue on `main`

GitHub Merge Queues are configured via Repository Rulesets API. This is the recommended approach for enterprise repositories.

**Prerequisites:**
- GitHub Advanced Security (Enterprise or Pro plan)
- Write access to repository settings
- Enable merge queue in repository settings:
  - Settings → Branch protection rules OR
  - Settings → Rulesets (new UI)

**JSON Ruleset Configuration:**

```json
{
  "name": "main-merge-queue-enforcement",
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
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false
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
      "type": "merge_queue",
      "parameters": {
        "check_response_timeout_minutes": 60,
        "grouping_strategy": "headCommit",
        "max_entries_to_build": 5,
        "max_entries_to_merge": 1,
        "merge_method": "squash",
        "min_entries_to_merge": 1,
        "min_entries_to_merge_wait_minutes": 5
      }
    }
  ],
  "bypass_actors": []
}
```

**CLI Deployment:**

```bash
#!/bin/bash
set -euo pipefail

OWNER="IBuySpy-Shared"
REPO="basecoat"

# Create merge queue ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/${OWNER}/${REPO}/rulesets" \
  --input merge-queue-ruleset.json

echo "Merge queue enforcement ruleset created successfully."
```

---

## Required Status Checks

The following checks **must pass** before a PR can enter the merge queue:

| Check Name | Workflow | Purpose |
|-----------|----------|---------|
| `validate-commit-messages` | `validate-basecoat.yml` | Enforce conventional commit format |
| `validate-unix` | `validate-basecoat.yml` | Bash/Unix-style linting and validation |
| `validate-windows` | `validate-basecoat.yml` | PowerShell/Windows validation suite |

**Additional recommended checks (org-specific):**

| Check Name | Workflow | Purpose |
|-----------|----------|---------|
| `prd-spec-gate` | `prd-spec-gate.yml` | PRD spec compliance (if applicable) |
| `code-review-agent` | `code-review-agent.md` | Security & code quality analysis |

---

## Merge Queue Behavior

### Parameters Explained

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `grouping_strategy` | `headCommit` | Group multiple PRs by their most recent commit; prevents redundant CI runs |
| `check_response_timeout_minutes` | `60` | Allow up to 1 hour for status checks to complete |
| `max_entries_to_build` | `5` | Build up to 5 PRs concurrently for efficiency |
| `max_entries_to_merge` | `1` | Merge one PR at a time to preserve linear history |
| `merge_method` | `squash` | Squash commits for cleaner main branch |
| `min_entries_to_merge_wait_minutes` | `5` | Wait up to 5 minutes to batch merges for efficiency |
| `min_entries_to_merge` | `1` | Merge immediately if queue has 1+ ready PR |

### Merge Queue Workflow

```
PR submitted → Status checks run → PR enters merge queue
                                   ↓
                          Check grouping strategy
                                   ↓
                    Build merge candidate (PR + main)
                                   ↓
                         All checks pass?
                            ├─ YES → Squash merge to main
                            └─ NO  → Remove from queue, notify author
```

---

## Developer Experience

### For PR Authors

1. **Automatic merging:** Once approved and in merge queue, the PR will merge automatically (no manual action needed)
2. **Queue status:** GitHub shows merge queue position on the PR
3. **Failure handling:** If checks fail in the queue, the PR is removed and you get a notification
4. **Re-queue:** Push new commits to retry; the PR re-enters the queue automatically

### For Maintainers

1. **Monitor queue health:** Use GitHub's Merge Queue dashboard in repository settings
2. **Manual intervention:** Can remove PRs from queue via UI if needed
3. **Bypass (admins only):** Can skip queue for emergency merges (discouraged)

---

## Acceptance Criteria

- [x] Merge queue configuration documented (this file)
- [x] JSON ruleset template provided for deployment
- [x] Required checks clearly specified
- [x] Merge queue parameters explained with rationale
- [x] CLI deployment script included
- [ ] Deploy ruleset to main branch (manual step via GitHub UI or API)
- [ ] Enable merge queue on `release/*` branches (optional, future PR)
- [ ] Publish deployment guide to team wiki

---

## Next Steps

1. **Review ruleset configuration** with security team
2. **Deploy to staging branch** (e.g., `release/*`) for testing
3. **Monitor merge queue metrics** (throughput, check pass rate, avg queue length)
4. **Adjust parameters** based on metrics (typically after 2 weeks)
5. **Deploy to main** once stable

---

## Related Documentation

- **Branch Protection:** `docs/operations/security/branch-protection.md`
- **Governance Contract:** `docs/reference/governance-contract.md`
- **CI/CD Workflows:** `.github/workflows/validate-basecoat.yml`
- **GitHub Merge Queues API:** [GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-merge-queue)

---

**Owner:** BaseCoat Platform Team  
**Last Updated:** 2026-06-14  
**Next Review:** 2026-07-14 (Sprint 37)
