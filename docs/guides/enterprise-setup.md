# Enterprise Setup Guide

Step-by-step guide for deploying Base Coat across a GitHub Enterprise organization.

---

## Prerequisites

Before starting, ensure the following are in place:

| Requirement | Details |
|---|---|
| **GitHub Enterprise** | GitHub Enterprise Cloud or Server 3.8+ |
| **Copilot Enterprise license** | GitHub Copilot Enterprise enabled for your organization |
| **Repository access** | Ability to create or fork repositories in your GitHub org |
| **Admin permissions** | Organization admin or repository admin role for initial setup |
| **Git** | Git 2.30+ installed on developer machines |
| **PowerShell or Bash** | PowerShell 5.1+ (Windows) or Bash 4+ (macOS/Linux) for sync scripts |

---

## Installation

### Step 1 — Fork or Clone Base Coat

Fork the upstream Base Coat repository into your GitHub Enterprise organization:

```bash
# Option A: Fork via GitHub CLI
gh repo fork upstream-org/basecoat --org YOUR-ORG --clone

# Option B: Clone and push to your org
git clone https://github.com/upstream-org/basecoat.git
cd basecoat
git remote set-url origin https://github.com/YOUR-ORG/basecoat.git
git push -u origin main
```

### Step 2 — Configure the Source URL

Set the `BASECOAT_REPO` environment variable to point at your org's fork:

```bash
# macOS / Linux
export BASECOAT_REPO='https://github.com/YOUR-ORG/basecoat.git'

# Windows PowerShell
$env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
```

### Step 3 — Run the Sync Script in a Consumer Repository

From the root of any consumer repository:

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.ps1 | iex
```

This copies Base Coat assets into `.github/base-coat/` and also copies agents, instructions, and prompts to `.github/agents/`, `.github/instructions/`, and `.github/prompts/` — the paths that GitHub Copilot auto-discovers.

### Step 4 — Pin to a Release Tag

For production environments, always pin to a specific release:

```bash
export BASECOAT_REF='v1.0.0'
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/v1.0.0/sync.sh | bash
```

---

## Organization-Level Configuration

### Recommended Repository Settings

Apply these settings to your Base Coat fork:

1. **Branch protection on `main`**:
   - Require pull request reviews (1+ approvals)
   - Require status checks to pass (CI validation)
   - Restrict who can push to `main`
   - See [`docs/../operations/security/BRANCH_PROTECTION.md`](../operations/security/branch-protection.md)

2. **Secret scanning**: Enable GitHub secret scanning and push protection.
   See [`docs/../operations/security/SECRET_SCANNING.md`](../operations/security/secret-scanning.md)

3. **Copilot policy**: Enable Copilot for the organization and allow custom instructions from repositories.

4. **Template repositories**: Configure Base Coat as a template source for new repositories.
    See [`docs/repo-template-standard.md`](repo-template-standard.md)

5. **Copilot Space bootstrap**: Use `scripts/bootstrap-copilot-space.ps1` to create the org-owned `base-coat` Space and attach the curated BaseCoat docs.

### Copilot Space reference for consumer repos

Consumer repositories should reference the shared BaseCoat Copilot Space using:

- **Owner**: `YOUR-ORG`
- **Space name**: `base-coat`

Use this exact owner/name pair when invoking Copilot Space context retrieval from consumers.
Do not point consumers at repo-local or personal spaces for BaseCoat canonical guidance.

For onboarding posture selection, use the versioned profile contract in `docs/reference/onboarding-profile-contract.v1.md`.

### CI/CD Pipeline

Base Coat includes validation workflows. Ensure these run on your fork:

- **`validate-basecoat.yml`** — Validates file structure, naming conventions, and commit message security
- **`prd-spec-gate.yml`** — Intake gate: high-change PRs (`>=12` files or `>=500` churn) require both PRD+spec refs; risky-path-only PRs (`instructions/`, `skills/`, `agents/`, `scripts/`, `.github/workflows/`) get advisory warning when missing refs
- **`validate-repo-template-sample.yml`** — Validates sample repo template assets

For merge-queue runs (`merge_group`), the gate passes with a notice because PR body context is unavailable in the merge group payload.

### Distribution Channels

| Channel | Best For | Setup |
|---|---|---|
| Sync script | Most teams | Point `BASECOAT_REPO` at your fork |
| Release artifacts | Strict change control | Use `scripts/package-basecoat.ps1` or `.sh` to build, publish via GitHub Releases |
| Git submodule | Explicit version pinning | `git submodule add` pointing at your fork |
| Artifact mirror | Air-gapped environments | Download release assets, host on internal artifact server |

### Onboarding profile contract

The profile contract in `docs/reference/onboarding-profile-contract.v1.md` is the canonical place to choose between `solo-dev`, `team-dev`, and `regulated-team` without editing each consumer repo by hand.

---

## Custom Agent Development

### Creating a New Agent

1. Use the `new-customization` agent or `agent-design` skill to scaffold:

   ```text
   @new-customization Create a new agent for database migration review
   ```

2. Or create manually following the naming convention `<name>.agent.md` in the `agents/` directory.

3. Agent files use YAML frontmatter for metadata:

   ```yaml
   ---
   name: my-custom-agent
   description: One-line description of what this agent does
   model: gpt-4o
   ---
   ```

4. Reference existing skills and instructions as needed. See [Inventory](../reference/inventory.md) for the full registry.

### Creating a New Skill

1. Create a directory under `skills/` with a `SKILL.md` workflow file.
2. Add template files (checklists, specs, scaffolds) alongside `SKILL.md`.
3. Use the `create-skill` skill for guided scaffolding.

### Creating a New Instruction File

1. Create `instructions/<scope>.instructions.md`.
2. Keep instructions focused on a single domain (e.g., security, testing, frontend).
3. Use the `create-instruction` skill for guided scaffolding.

### Governance for Custom Assets

All customizations follow the same governance model:

- **Issue-first**: Log a GitHub issue before creating or modifying any asset.
- **PR review**: All changes go through pull requests. Self-approval is permitted for low-risk changes.
- **Naming conventions**: Follow the patterns in [`instructions/basecoat-10-core-naming.instructions.md`](../../instructions/basecoat-10-core-naming.instructions.md).
- **Quality gates**: CI validates structure and naming on every PR.

See [`docs/reference/governance-contract.md`](../reference/governance-contract.md) and [`CONTRIBUTING.md`](../../CONTRIBUTING.md) for full details.

---

## Security Considerations

### Secrets and Credentials

- **Never commit secrets** to agent definitions, skill templates, or instruction files.
- Base Coat includes a `commit-msg` hook that scans for secrets. Install it:

  ```bash
  bash scripts/install-git-hooks.sh       # macOS / Linux
  ./scripts/install-git-hooks.ps1         # Windows
  ```

- CI also runs commit message scanning via `validate-basecoat.yml`.
- See guardrail: [`docs/../reference/guardrails/secrets-in-workflows.md`](../reference/guardrails/secrets-in-workflows.md)

### Agent Trust Boundaries

- Agents and skills execute in the context of the developer's Copilot session. They do not have independent access to systems.
- MCP integrations must follow the trust-boundary and tool-approval guardrails in [`tool-confirmation-policy.md`](../reference/guardrails/tool-confirmation-policy.md).
- Review [`docs/../reference/guardrails/oidc-federation.md`](../reference/guardrails/oidc-federation.md) before configuring any GitHub Actions to Azure authentication.

### Supply Chain Security

- Pin Base Coat to a release tag, not `main`, for production consumer repos.
- Publish checksums with every release for verification.
- Use branch protection to prevent unauthorized changes to the Base Coat fork.
- Enable Dependabot or similar tooling for any dependencies.

### Audit Trail

- All changes require a GitHub issue and PR, creating an audit trail.
- Commit message scanning prevents accidental secret leaks.
- Branch protection rules ensure no direct pushes to `main`.

---

## Maintenance and Updates

### Pulling Upstream Updates

If your org fork diverges from upstream, merge periodically:

```bash
cd basecoat
git remote add upstream https://github.com/upstream-org/basecoat.git
git fetch upstream
git checkout main
git merge upstream/main
# Resolve any conflicts, then push
git push origin main
```

### Updating Consumer Repositories

After updating your Base Coat fork, consumers re-sync by running the sync script again. The script is idempotent — it replaces the target directory contents entirely.

```bash
# Re-run in each consumer repo
export BASECOAT_REF='v1.1.0'
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/v1.1.0/sync.sh | bash
```

### Release Process

1. Validate all changes pass CI.
2. Update `version.json` with the new version and release date.
3. Update `CHANGELOG.md` with notable changes.
4. Tag the release: `git tag v1.1.0 && git push origin v1.1.0`.
5. Create a GitHub Release with packaged artifacts using `scripts/package-basecoat.ps1` or `.sh`.
6. Publish checksums alongside the release assets.

See [`docs/release-process.md`](../operations/release-process.md) for the full release workflow.

### Rollout Strategy

Use approval rings to manage risk:

| Ring | Scope | Timing |
|---|---|---|
| Ring 0 | Base Coat maintainers' own repos | Immediately on merge |
| Ring 1 | Early adopter teams (3–5 repos) | 1 week after Ring 0 |
| Ring 2 | Broader organization | 2 weeks after Ring 1 |
| Ring 3 | All repositories | After Ring 2 validation |

See [`docs/enterprise-rollout.md`](enterprise-rollout.md) for detailed rollout guidance.

---

## Troubleshooting

### Sync script fails with "permission denied"

- Ensure the repository URL in `BASECOAT_REPO` is accessible.
- For private repos, configure a GitHub PAT or SSH key.
- For Enterprise Server, ensure the correct hostname is used.

### Copilot doesn't pick up instructions or agents

- Verify instruction files exist at `.github/instructions/`, agents at `.github/agents/`, and prompts at `.github/prompts/`. These are the paths that GitHub Copilot auto-discovers — not `.github/base-coat/`.
- If those directories are missing, re-run the sync script. It copies from `.github/base-coat/` into the Copilot-discoverable paths automatically.
- Check that the `BASECOAT_TARGET_DIR` variable was not overridden to a non-standard path.
- Ensure the Copilot organization policy allows custom instructions from repositories.

### CI validation fails on PR

- Run the validation script locally to see detailed errors:

  ```bash
  bash scripts/validate-basecoat.sh       # macOS / Linux
  ./scripts/validate-basecoat.ps1         # Windows
  ```

- Common causes: missing frontmatter, incorrect file naming, or files in wrong directories.

### Merge conflicts when syncing upstream

- The sync script replaces the entire target directory, so consumer-side conflicts are rare.
- For fork-level conflicts, use standard Git merge resolution.
- Consider rebasing your org-specific changes on top of upstream tags.

### Agents reference missing skills or instructions

- Run `CATALOG.md` validation to check all cross-references.
- Ensure the skill directory exists and contains a `SKILL.md` file.
- Check [Inventory](../reference/inventory.md) for the authoritative list of available assets.

### Release artifacts fail checksum verification

- Re-download the artifact and checksum file.
- Ensure you are comparing the correct release tag.
- Contact Base Coat maintainers if the issue persists.
