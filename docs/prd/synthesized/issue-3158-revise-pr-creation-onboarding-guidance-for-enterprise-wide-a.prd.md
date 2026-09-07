---
issue: 3158
title: "Revise PR-creation onboarding guidance for enterprise-wide Actions toggle blast radius"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "docs", "priority:low", "onboarding-conductor", "needs-prd", "synthesize-spec"]
---

# PRD: Revise PR-creation onboarding guidance for enterprise-wide Actions toggle blast radius

## Problem Statement

The solo-dev PR-creation-permission guidance currently assumes the safest path is Enterprise policy delegation followed by repo-level opt-in for repos that install PR-creating workflows.

A GitHub Enterprise policy screen shows the relevant control as a global Enterprise checkbox: **Allow GitHub Actions to create and approve pull requests**. If enabling it at Enterprise scope effectively enables the capability everywhere unless each org overrides/restricts it, that blast radius is larger than the guidance implies and may be unacceptable for solo-dev/governed environments.

## Why This Matters

The setting is not scoped per workflow. It allows GitHub Actions to create pull requests and submit approving pull request reviews. In repos with permissive rulesets, including solo-dev's zero-review posture for routine PR sizes, broad Enterprise enablement can let unrelated or compromised workflows create/self-approve PRs.

## Scope

In scope:

- Revise solo-dev, downstream workflow, and repo-template onboarding guidance
  so it treats the Actions PR-creation/approval toggle as a high-blast-radius
  platform setting when controlled at Enterprise scope.
- Clarify that templates and workflow files ship downstream, but GitHub
  platform policy settings do not. Every downstream org/repo must explicitly
  decide whether PR-creating automation is allowed.
- Update bootstrap or setup warnings so they point users to org/enterprise
  policy review instead of implying a repository administrator can always fix
  the setting locally.
- Document safer alternatives when Enterprise-wide enablement is too broad:
  org-restricted policy where available, repo-level opt-in where available,
  scoped PAT fallback as a temporary exception, and a GitHub App or brokered
  token design as the preferred durable direction.
- Add validation coverage for the revised warning language and downstream
  onboarding caveat.

Out of scope:

- Enabling or disabling Enterprise, org, or repo Actions settings.
- Adding a new credential broker or GitHub App implementation in this PRD.
- Changing merge policy or branch protection requirements.

## Success Criteria

- [ ] BaseCoat docs no longer recommend Enterprise-wide enablement as the
  normal fix for a single repository's PR-creating workflow.
- [ ] Downstream/template guidance states that platform settings do not ship
  with the template and must be reviewed per consumer environment.
- [ ] Bootstrap guidance accurately distinguishes repo-local workflow files from
  enterprise/org/repo policy controls.
- [ ] The durable design path prefers scoped, auditable automation credentials
  over broad Enterprise-wide enablement when the capability is needed only in
  selected repositories.

## References

- Refs #3158
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3158>
