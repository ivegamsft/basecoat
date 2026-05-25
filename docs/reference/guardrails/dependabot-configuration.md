# Dependabot Configuration

> **Rule:** Enable Dependabot for all ecosystems in use. Group minor and patch updates together; keep major updates separate for explicit review.

## Ecosystems to Enable

Enable every package ecosystem present in the repository:

| Ecosystem | `package-ecosystem` value | Typical manifest |
|-----------|--------------------------|------------------|
| GitHub Actions | `github-actions` | `.github/workflows/*.yml` |
| npm | `npm` | `package.json` |
| pip | `pip` | `requirements.txt`, `pyproject.toml` |
| Docker | `docker` | `Dockerfile` |
| NuGet | `nuget` | `*.csproj`, `packages.config` |
| Go modules | `gomod` | `go.mod` |
| Terraform | `terraform` | `*.tf` |

## Update Schedule Recommendations

| Update type | Schedule | Rationale |
|-------------|----------|-----------|
| Security patches | `daily` | Minimize exposure window for known CVEs |
| Minor and patch | `weekly` | Balance freshness with review burden |
| Major versions | `monthly` | Require deliberate migration effort |

## Dependency Grouping Strategy

Group minor and patch updates to reduce PR noise. Keep major version bumps as individual PRs so breaking changes receive focused review.

```yaml
groups:
  minor-and-patch:
    patterns:
      - "*"
    update-types:
      - "minor"
      - "patch"
```

## Auto-Merge Rules

Auto-merge patch updates when all CI checks pass. Require human review for minor and major bumps:

- Patch updates: auto-merge after CI passes
- Minor updates: require one approval
- Major updates: require two approvals and a changelog review

Configure auto-merge via repository rulesets or a GitHub Actions workflow that approves and merges Dependabot PRs matching `semver-patch`.

## Dependency Canary Lane

Run a dedicated dependency canary lane for Dependabot PRs to catch breakage before merge.

- Trigger on Dependabot-authored PRs or PRs labeled `dependencies`.
- Scope canary jobs to changed lockfiles/package manifests when possible.
- Use install retry with exponential backoff for transient registry/network faults.
- Run canary tests with one containment retry:
  - First pass fails -> retry once after short wait.
  - Pass on retry -> mark as flaky candidate and track for follow-up.
  - Fail twice -> keep blocking; do not auto-quarantine.
- Preserve logs as artifacts so repeated flakes can be promoted to quarantine only with evidence and expiry ownership.

## Ignore Conditions and Version Constraints

Use `ignore` to suppress known-incompatible upgrades or packages pinned for compatibility:

```yaml
ignore:
  - dependency-name: "example-legacy-lib"
    versions: [">=3.0.0"]
```

Pin upper bounds only when a downstream dependency has a verified incompatibility. Document the reason in a comment above the ignore rule.

## Example `dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"

  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      npm-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
    ignore:
      # Pinned due to ESM-only breaking change in v5
      - dependency-name: "chalk"
        versions: [">=5.0.0"]

  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      pip-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      nuget-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
```

## Quick Reference

| Decision | Recommendation |
|----------|---------------|
| How many ecosystems? | All that exist in the repo |
| Grouping? | Minor + patch together, majors alone |
| Auto-merge? | Patch only, after CI passes |
| Ignore rules? | Only with documented incompatibility reason |
| Schedule? | Weekly default; daily for security-only updates |
