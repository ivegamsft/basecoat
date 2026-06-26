# Main Branch Protection Policy

This document defines the required branch protection baseline for the `main` branch and enforcement procedures.

## Objective

Establish a consistent, auditable baseline for main branch protection that prevents accidental or unauthorized changes, requires code review, and ensures all changes pass required checks before merge.

## Baseline Controls

### 1. Required Pull Request Reviews

- **Minimum reviewers**: per active governance profile baseline (max required approvals across risk tiers in `.github/governance/policy-packs.json`; `solo-dev` = 0, `team-dev` = 1, `regulated-team` = 2)
- **Dismissal of stale reviews**: Enabled
- **Require code owner reviews**: Disabled (repo has no CODEOWNERS enforcement requirement)
- **Restrict who can dismiss reviews**: Admins only
- **Apply to admins**: Yes

### 2. Required Status Checks Before Merge

The following status checks **must pass** before a pull request can be merged to `main`:

| Check | Description | Purpose |
|-------|-------------|---------|
| `lint-and-validate` | Linting and repository validation | Catch lint errors and enforce repo standards |
| `test` | Test suite | Catch regressions and quality issues |
| `validate-commit-messages` | Commit message format validation | Enforce conventional commits |
| `validate-unix` | Unix-environment validation | Ensure cross-platform compatibility |
| `validate-windows` | Windows-environment validation | Ensure Windows compatibility |
| `release-label-gate` | Release label gate | Require release label for delivery tracking |

Additional checks may run and fail without blocking merge (advisory-only checks), but the
above six are required for all PRs to `main`.

### 3. Restricted Direct Pushes

- **Allow force pushes**: No
- **Allow deletions**: No
- **Require branches to be up to date before merging**: Yes
- **Require status checks to pass on up-to-date branches**: Yes

### 4. Bypass Rules

- **Admins can bypass protection**: Yes (with audit trail expected)
- **GitHub Apps bypass**: Not allowed
- **Automation bypass**: Not allowed (all automation must work within protection constraints)

## Enforcement

### Automated Enforcement

The `governance-enforce` workflow (triggered on main branch changes to this file or related governance docs) validates that:

1. This policy document exists and is current
2. Repository API confirms branch protection is active
3. All baseline controls are enforced via `gh api` or Terraform

### Manual Enforcement (Repository Settings)

To apply branch protection via GitHub UI:

1. Navigate to **Settings** > **Branches**
2. Click **Add rule** under **Branch protection rules**
3. Pattern: `main`
4. Enable:
   - ✓ Require a pull request before merging
   - ✓ Require approvals (0 for `solo-dev`, 1 for `team-dev`, 2 for `regulated-team` — see `.github/governance/policy-packs.json`)
   - ✓ Dismiss stale pull request approvals when new commits are pushed
   - ✓ Require status checks to pass before merging
   - ✓ Require branches to be up to date before merging
5. Search for and select required status checks:
   - `validate-basecoat`
   - `ci`
   - `docs`
6. Restrict who can push to matching branches:
   - [ ] No one (if all changes must go through PR)
   - Or [ ] Specify teams/individuals allowed to push directly
7. Disable:
   - ☐ Allow force pushes
   - ☐ Allow deletions

## Validation

### Audit Evidence

The `governance-audit` workflow queries the repository API to confirm:

```bash
gh api repos/{owner}/{repo}/branches/main/protection
```

Expected payload shape:

- `required_status_checks.strict === true`
- `required_status_checks.contexts` includes at least `lint-and-validate`, `test`, `validate-commit-messages`, `validate-unix`, `validate-windows`, `release-label-gate`
- `allow_force_pushes.enabled === false`
- `allow_deletions.enabled === false`
- `enforce_admins.enabled === true`

### Remediation

If validation fails:

1. **Missing protection rules**: Re-apply via Settings UI or run `branch-protection-enforce.yml` manually
2. **Incomplete status checks**: Update workflow triggers in `.github/workflows/*` to ensure all required checks run
3. **Admin bypass enabled**: Review and disable if not permitted by security policy

## References

- [GitHub Branch Protection API](https://docs.github.com/en/rest/branches/branch-protection)
- [Repository Settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/managing-a-branch-protection-rule)
- Governance Contract: `docs/reference/governance-contract.md`
- Governance Audit: `.github/workflows/governance-audit.yml`
