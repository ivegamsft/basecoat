---
issue: 3158
title: "Revise PR-creation onboarding guidance for enterprise-wide Actions toggle blast radius"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "docs", "priority:low", "onboarding-conductor", "needs-prd", "synthesize-spec"]
---

# Spec: Revise PR-creation onboarding guidance for enterprise-wide Actions toggle blast radius

## Problem Statement

The solo-dev PR-creation-permission guidance currently assumes the safest path is Enterprise policy delegation followed by repo-level opt-in for repos that install PR-creating workflows.

A GitHub Enterprise policy screen shows the relevant control as a global Enterprise checkbox: **Allow GitHub Actions to create and approve pull requests**. If enabling it at Enterprise scope effectively enables the capability everywhere unless each org overrides/restricts it, that blast radius is larger than the guidance implies and may be unacceptable for solo-dev/governed environments.

## Why This Matters

The setting is not scoped per workflow. It allows GitHub Actions to create pull requests and submit approving pull request reviews. In repos with permissive rulesets, including solo-dev's zero-review posture for routine PR sizes, broad Enterprise enablement can let unrelated or compromised workflows create/self-approve PRs.

## Scope

Implement a documentation and validation correction for PR-creating automation
onboarding.

1. Update `docs/guides/solo-dev-profile.md` to state that the Enterprise
   setting **Allow GitHub Actions to create and approve pull requests** may be
   Enterprise-global. The default recommendation must be to avoid enabling it
   broadly for one repository unless org-level restriction/override and audit
   controls are already planned.
2. Update downstream onboarding docs:
   - `docs/guides/workflows-getting-started.md`,
   - `docs/guides/downstream-workflows-setup.md`,
   - `docs/guides/repo-template-standard.md`,
   - `.github/template-repos/repo-template/sample-repo-template.md`.
3. Ensure downstream docs distinguish what ships from the template from what
   must be configured in GitHub:
   - workflow files and bootstrap guidance ship,
   - Enterprise/org/repo Actions settings do not ship,
   - secrets or GitHub App credentials do not ship.
4. Update `docs/operations/github-secrets.md` to keep `GH_AW_GITHUB_TOKEN`
   fallback-only and to point to scoped credential or GitHub App/brokered-token
   designs when platform policy cannot be narrowed safely.
5. Update `scripts/bootstrap.ps1` warning text so missing
   `can_approve_pull_request_reviews` does not imply repository admins can
   always enable the setting locally. It should direct the operator to review
   Enterprise, org, and repo policy scope.
6. Extend `tests/solo-dev-profile-tests.ps1` or adjacent documentation tests so
   the revised language is covered.

## Decision Guidance

Use this decision order when onboarding PR-creating workflows:

1. Prefer no PR-creating workflow when a read-only report or issue comment is
   sufficient.
2. If PR creation is required, prefer repo-level opt-in only when the platform
   actually supports it under the current Enterprise/org policy.
3. If repo-level opt-in is unavailable, prefer org-scoped restriction or
   override before considering Enterprise-wide enablement.
4. If Enterprise-wide enablement would affect unrelated repositories, do not
   enable it solely for BaseCoat or one downstream repo. Use a scoped credential
   fallback as a temporary exception or design a GitHub App/brokered-token path.
5. Treat any broad enablement as a governance decision that requires audit,
   rollback, and clear ownership.

## Documentation Requirements

The revised docs must consistently use the following distinctions:

- `GITHUB_TOKEN` permissions in workflow YAML are necessary but not sufficient
  for PR creation/approval.
- `can_approve_pull_request_reviews` is a platform policy capability, not a
  secret and not a setting that template files can carry downstream.
- `GH_AW_GITHUB_TOKEN` is an optional, manually-created fallback credential, not
  a system token.
- A downstream repository inherits files from the template, but the repository,
  org, or Enterprise owner must separately decide whether Actions may create or
  approve pull requests.

## Failure Handling

- Bootstrap should warn, not fail, when the setting cannot be inspected or is
  disabled. The warning must name the likely policy scopes and point to the
  docs for decision guidance.
- Docs must not promise that repository admins can fix the setting without
  enterprise or org owner involvement.
- If a downstream environment cannot safely enable the platform setting, the
  documented fallback must be explicit about credential scope, rotation, and the
  preference for replacing a PAT with a GitHub App or brokered token.

## Validation

Validation should include:

- documentation checks that the solo-dev and downstream guides mention the
  Enterprise blast-radius caveat,
- tests that the bootstrap warning points to policy-scope review,
- checks that the `GH_AW_GITHUB_TOKEN` docs describe fallback-only use,
- repository validation after documentation and script changes.

## Acceptance Criteria

- [ ] Solo-dev, downstream workflow, repo-template, and sample template docs all
  say the platform toggle does not ship downstream.
- [ ] Guidance warns against Enterprise-wide enablement solely for one repo
  unless org restriction/override and audit controls are part of the plan.
- [ ] Bootstrap warning text directs users to enterprise/org/repo policy review
  and avoids implying a repo admin can always fix the setting locally.
- [ ] `GH_AW_GITHUB_TOKEN` remains documented as fallback-only, with scoped PAT
  as temporary and GitHub App/brokered token as preferred durable direction.
- [ ] Tests cover the revised onboarding and bootstrap language.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3158-revise-pr-creation-onboarding-guidance-for-enterprise-wide-a.prd.md`
- Refs #3158
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3158>
