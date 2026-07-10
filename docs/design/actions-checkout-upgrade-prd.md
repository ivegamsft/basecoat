# Product Requirements Document: GitHub Actions Checkout Action Upgrade

## Problem Statement

BaseCoat workflows depend on `actions/checkout` for repository checkout in CI/CD pipelines. As major versions are released, staying current ensures access to security patches, bug fixes, and new capabilities while reducing exposure to unsupported versions.

## Goals

1. Upgrade all BaseCoat workflow references from `actions/checkout@v4` to the latest stable major release.
2. Confirm that no workflow behavior changes result from the version bump.
3. Maintain consistency across all workflow files.

## Non-Goals

- Changing checkout configuration options or behavior.
- Modifying other GitHub Actions dependencies in this PR.
- Adding new workflow steps or jobs.

## User Personas and Use Cases

| Persona | Impact |
|---|---|
| CI maintainer | Workflows continue to function with a supported action version |
| Security reviewer | Reduces exposure to issues in older, unsupported action versions |

## Functional Requirements

1. All workflow files referencing `actions/checkout` must use the updated version SHA.
2. Workflow behavior (checkout depth, token, submodules, etc.) must remain unchanged.
3. All existing CI checks must continue to pass after the upgrade.

## Non-Functional Requirements

- Change must be automated via Dependabot to reduce manual error.
- Pin to the full commit SHA as required by BaseCoat workflow guardrails.

## Success Metrics

- All CI checks pass on the upgrade PR.
- No regressions reported in workflow behavior post-merge.

## Constraints and Assumptions

- `actions/checkout` is a direct production dependency used across all workflow files.
- Dependabot handles version discovery and SHA pinning.

## Risks and Open Questions

- Major version bumps may introduce breaking API changes; validate against known usage patterns before merging.

## Dependencies

- Dependabot configuration in `.github/dependabot.yml`

## Rollout and Adoption Plan

- Merge Dependabot PR after CI checks pass.
- Monitor workflow runs for 24 hours post-merge.

## References

- [actions/checkout releases](https://github.com/actions/checkout/releases)
- [actions/checkout CHANGELOG](https://github.com/actions/checkout/blob/main/CHANGELOG.md)
- BaseCoat workflow guardrails: `tests/workflow-guardrails-tests.ps1`
