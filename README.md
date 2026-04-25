# Base Coat

Base Coat is a shared repository for GitHub Copilot customizations that teams can reuse across repositories.

It provides four customization types:

- Instructions for coding standards and guardrails
- Skills for repeatable workflows
- Prompts for quick task entry points
- Agents for longer multi-step flows

The files in this repository are authored as actual customization assets, with descriptive frontmatter so teams can copy them directly into their repos and refine them instead of rewriting from scratch.

## Governance

Base Coat operates under a lightweight enterprise governance framework that applies to all contributions and all agent definitions in this repository.

Key rules:

- **Issue-first**: All changes must be backed by a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a pull request; self-approval is permitted.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`

Full reference: [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md) · Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)

> ℹ️ `docs/GOVERNANCE.md` and `CONTRIBUTING.md` are introduced in the companion PR `feature/43-governance-docs` and will be available once that PR merges.

## Repository Layout

```text
basecoat/
├── .github/workflows/
├── CHANGELOG.md
├── INVENTORY.md
├── README.md
├── docs/
├── examples/
├── scripts/
├── version.json
├── sync.ps1
├── sync.sh
├── instructions/
├── skills/
├── prompts/
└── agents/
```

## What Is Included

- [instructions/backend.instructions.md](/c:/git/basecoat/instructions/backend.instructions.md): baseline backend engineering guidance
- [instructions/frontend.instructions.md](/c:/git/basecoat/instructions/frontend.instructions.md): UI and frontend guardrails
- [instructions/testing.instructions.md](/c:/git/basecoat/instructions/testing.instructions.md): expectations for tests and validation
- [instructions/security.instructions.md](/c:/git/basecoat/instructions/security.instructions.md): baseline secure coding and secret-handling practices
- [instructions/reliability.instructions.md](/c:/git/basecoat/instructions/reliability.instructions.md): failure handling and operability guardrails
- [instructions/documentation.instructions.md](/c:/git/basecoat/instructions/documentation.instructions.md): documentation and change-note expectations
- [instructions/azure.instructions.md](/c:/git/basecoat/instructions/azure.instructions.md): Azure coding, auth, and service-integration guidance
- [instructions/terraform.instructions.md](/c:/git/basecoat/instructions/terraform.instructions.md): Terraform guidance for Azure-oriented IaC changes
- [instructions/bicep.instructions.md](/c:/git/basecoat/instructions/bicep.instructions.md): Bicep authoring guidance and validation practices
- [instructions/naming.instructions.md](/c:/git/basecoat/instructions/naming.instructions.md): naming conventions across repos, code, and infrastructure
- [instructions/mcp.instructions.md](/c:/git/basecoat/instructions/mcp.instructions.md): MCP server and tool governance, safety, and enforcement guidance
- [skills/manual-test-strategy/SKILL.md](/c:/git/basecoat/skills/manual-test-strategy/SKILL.md): workflow for defining manual scope, producing charters, checklists, and automation handoff artifacts
- [skills/performance-profiling/SKILL.md](/c:/git/basecoat/skills/performance-profiling/SKILL.md): workflow for profiling slow paths
- [skills/code-review/SKILL.md](/c:/git/basecoat/skills/code-review/SKILL.md): review-first workflow focused on risk detection
- [skills/refactoring/SKILL.md](/c:/git/basecoat/skills/refactoring/SKILL.md): workflow for safe structural cleanup
- [skills/create-skill/SKILL.md](/c:/git/basecoat/skills/create-skill/SKILL.md): starter workflow for creating new reusable skills
- [skills/create-instruction/SKILL.md](/c:/git/basecoat/skills/create-instruction/SKILL.md): starter workflow for creating new instruction files
- [prompts/architect.prompt.md](/c:/git/basecoat/prompts/architect.prompt.md): architecture planning starter
- [prompts/code-review.prompt.md](/c:/git/basecoat/prompts/code-review.prompt.md): code review starter
- [prompts/bugfix.prompt.md](/c:/git/basecoat/prompts/bugfix.prompt.md): root-cause bugfix starter
- [agents/manual-test-strategy.agent.md](/c:/git/basecoat/agents/manual-test-strategy.agent.md): produce a complete manual test strategy with rubric, charter, checklist, defect template, and automation backlog
- [agents/exploratory-charter.agent.md](/c:/git/basecoat/agents/exploratory-charter.agent.md): generate time-boxed exploratory sessions with evidence capture and GitHub Issue filing
- [agents/strategy-to-automation.agent.md](/c:/git/basecoat/agents/strategy-to-automation.agent.md): convert manual paths into tiered automation candidates with a GitHub Issue filed for every one
- [agents/code-review.agent.md](/c:/git/basecoat/agents/code-review.agent.md): multi-step review agent definition draft
- [agents/new-customization.agent.md](/c:/git/basecoat/agents/new-customization.agent.md): workflow for creating the right customization primitive
- [agents/rollout-basecoat.agent.md](/c:/git/basecoat/agents/rollout-basecoat.agent.md): workflow for onboarding a repo to a pinned Base Coat release
- [docs/enterprise-rollout.md](/c:/git/basecoat/docs/enterprise-rollout.md): release, governance, and safe rollout guidance
- [docs/documentation-heading-scaffolds.md](/c:/git/basecoat/docs/documentation-heading-scaffolds.md): reusable heading templates for README, runbooks, ADRs, and change notes
- [docs/prd-and-spec-guidance.md](/c:/git/basecoat/docs/prd-and-spec-guidance.md): guidance and templates for product requirements docs and technical specs
- [docs/repo-template-standard.md](/c:/git/basecoat/docs/repo-template-standard.md): standard for enforcing Base Coat in new repository templates
- [examples/iac/README.md](/c:/git/basecoat/examples/iac/README.md): sample Azure IaC layouts for Bicep and Terraform
- [examples/workflows/bootstrap-from-release.yml](/c:/git/basecoat/examples/workflows/bootstrap-from-release.yml): consumer workflow that installs a pinned release
- [examples/repo-template/README.md](/c:/git/basecoat/examples/repo-template/README.md): sample repository template with lock-based bootstrap and enforcement
- [.github/workflows/validate-repo-template-sample.yml](/c:/git/basecoat/.github/workflows/validate-repo-template-sample.yml): CI validation for the sample repository template assets
- [examples/repo-template/README.md](/c:/git/basecoat/examples/repo-template/README.md): sample repository template with lock-based bootstrap and enforcement workflows

## Adoption Options

### Option 1: Pull With a Sync Script

Use this when teams want a lightweight, on-demand way to copy the shared standards into a repository.

For enterprise rollout, prefer a pinned tag or release artifact instead of `main`.

Linux and macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.ps1 | iex
```

Both scripts support overrides through environment variables:

- `BASECOAT_REPO`: source git URL
- `BASECOAT_REF`: branch or tag to sync
- `BASECOAT_TARGET_DIR`: target directory inside the consumer repo

Default target directory is `.github/base-coat`.

### Option 1A: Enterprise Bootstrap From A Pinned Release

Use this when Base Coat is the approved starting point for new repositories and changes must roll out safely.

Windows PowerShell:

```powershell
$tag = 'v0.3.0'
irm https://raw.githubusercontent.com/YOUR-ORG/basecoat/$tag/sync.ps1 | iex
```

macOS and Linux:

```bash
tag=v0.3.0
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/${tag}/sync.sh | bash
```

GitHub CLI:

```bash
gh release download v0.3.0 --repo YOUR-ORG/basecoat --pattern "base-coat-*"
```

For stricter environments, publish checksums with the release and require verification before install.

### Option 2: Git Submodule

Use this when teams want explicit version pinning and are comfortable managing submodules.

```bash
git submodule add https://github.com/YOUR-ORG/basecoat.git .github/base-coat
git submodule update --remote --merge
```

## Recommended Rollout

1. Validate every change in CI before packaging.
2. Publish versioned release artifacts and checksums.
3. Start new repositories from a pinned Base Coat release, not an unpinned branch.
4. Roll changes through approval rings before broad adoption.
5. Keep `INVENTORY.md` current so teams can discover what exists without reading every file.

## Release Management

- Use semantic tags such as `v0.1.0`, `v0.2.0`, `v1.0.0`.
- Keep [version.json](/c:/git/basecoat/version.json) aligned with the latest published tag.
- Record breaking changes in [CHANGELOG.md](/c:/git/basecoat/CHANGELOG.md).
- Use the packaging and validation scripts in [scripts](/c:/git/basecoat/scripts) and the GitHub Actions definitions in [.github/workflows](/c:/git/basecoat/.github/workflows).
- Run the scaffold test suite in [tests](/c:/git/basecoat/tests) before publishing releases.

## Enterprise Distribution

Base Coat can be distributed through three channels:

- Windows: versioned `.zip` release artifact plus `sync.ps1`
- macOS and Linux: versioned `.tar.gz` release artifact plus `sync.sh`
- CLI: GitHub CLI or an internal artifact mirror that downloads pinned release assets

The recommended enterprise model is:

1. Validate on every change.
2. Package on approved tags.
3. Publish checksums.
4. Mirror approved artifacts internally if internet egress is restricted.
5. Use example onboarding workflows from [examples/workflows](/c:/git/basecoat/examples/workflows).

## Commit Message Security

Base Coat supports hard enforcement so commit messages do not leak secrets or PII.

- Local enforcement: `commit-msg` hook in `.githooks/commit-msg`
- CI enforcement: commit message scan job in [.github/workflows/validate-basecoat.yml](/c:/git/basecoat/.github/workflows/validate-basecoat.yml)

Install hooks in a local repo:

Windows PowerShell:

```powershell
./scripts/install-git-hooks.ps1
```

macOS and Linux:

```bash
bash scripts/install-git-hooks.sh
```

Run commit-message scan manually:

```bash
bash scripts/scan-commit-messages.sh HEAD~20..HEAD
```

## PRD and Spec Gate

Base Coat includes PR governance for documentation quality:

- Workflow: [.github/workflows/prd-spec-gate.yml](/c:/git/basecoat/.github/workflows/prd-spec-gate.yml)
- PR template: [.github/PULL_REQUEST_TEMPLATE.md](/c:/git/basecoat/.github/PULL_REQUEST_TEMPLATE.md)

Gate behavior:

- High-change pull requests require both PRD and spec references.
- Risky-path pull requests require at least one PRD or spec reference.

## Test Suite

Run the repository smoke tests:

PowerShell:

```powershell
./tests/run-tests.ps1
```

Bash:

```bash
bash tests/run-tests.sh
```

## Next Additions

- Validation for customization file structure in CI
- More language- and stack-specific instruction files
- Additional skills with examples and templates
- Organization-specific prompts and agents
