---
name: project-onboarding
description: "Single-invocation new repo setup with BaseCoat integration. Creates repo, syncs governance framework, configures templates, and logs initial sprint issue. USE FOR: set up a new repo with BaseCoat governance, sync instruction overlays to an existing project, bootstrap sprint issue tracking. DO NOT USE FOR: onboarding individual developers, migrating existing codebases."
visibility: basic
model: claude-sonnet-4.6
compatibility: []
metadata:
  category: core
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Project Onboarding Agent

Single-invocation repo setup with BaseCoat integration. Safe to re-run on existing repos.

## Inputs

- `repo_name`, `repo_description`, `visibility` (default: `private`), `sprint_1_goal`, `github_org`, `basecoat_version` (default: `main`), `hook_profile` (`none|memory|guardrails|standard`, default: `standard`)

## Workflow

1. Validate prerequisites: confirm `gh` and `git` are available and authenticated.
2. Create or clone the repository (idempotent; skips creation if exists).
3. Scaffold root files if absent: `sync.ps1`, `sync.sh`, `setup.ps1`, `.gitignore`, `README.md`.
4. Sync BaseCoat governance into `.github/base-coat/` via `sync.ps1` at the pinned version.
5. Configure hook packs from the selected profile (`none|memory|guardrails|standard`), write `.github/basecoat-hook-profiles.json`, and provision `.github/hooks/` pack files.
6. Create `.github/ISSUE_TEMPLATE/` with `feature.yml` and `bug.yml` templates if absent.
7. Log the Sprint 1 goal as a GitHub issue with acceptance criteria.
8. Stage all scaffolded files, commit with conventional message, and push only for a brand-new repository; reruns on existing repositories should use a review branch so branch protection still applies.

## Output

Scaffolded repository with BaseCoat governance, root files, hook profile, `.github/basecoat-hook-profiles.json`, `.github/hooks/` pack files, issue templates, Sprint-1 issue, and README. Output report table with status of each item created.

## References

File templates (`.gitignore`, `README.md`, `setup.ps1`, issue YAML), hook profile rules, output report table, expected directory structure: [`agents/references/project-onboarding-detail.md`](references/project-onboarding-detail.md)
