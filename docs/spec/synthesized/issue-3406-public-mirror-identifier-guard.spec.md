---
issue: 3406
title: "Fail closed on internal identifiers in the public mirror"
status: in-review
author: ibuyspy
created: 2026-10-03
updated: 2026-10-03
labels: ["documentation", "security", "priority:high", "sprint:2026-W40"]
---

# Technical Specification: Public Mirror Identifier Guard

## Context

The production publish workflow removes internal-only files, rewrites selected
repository references, and fails if internal organization identifiers remain.
PR #3436 added a PR-validation job that simulates those publication
transformations and runs the same fail-closed check before release. That
addresses the shift-left requirement in #3406, but the current pattern omits
the `@ibuyspy` account identifier, and `docs/getting-started.md` still relies
on rewriting the internal source repository name in a distributed workflow
example.

## Scope

- Extend the forbidden-identifier check in PR validation and production
  publication to include case-insensitive `@ibuyspy` matches.
- Keep the exact legal copyright attribution in `LICENSE` as the only
  allowlisted match.
- Replace the internal repository name in the distributed getting-started
  workflow example with explicit `OWNER/REPOSITORY` placeholders and explain
  that consumers must substitute their source repository.
- Update the production workflow's trusted SHA-256 binding in both policy-pack
  copies.
- Add regression coverage for the handle check and the neutral example.

## Out of Scope

- Replacing the existing PR #3436 public-payload simulation or duplicating its
  sanitization logic.
- Removing source repository identifiers from internal-only files or
  intentional source-specific implementation code.
- Changing the release workflow, production repository, or publication
  credentials.
- Running a public code search before a new version has been published.

## Architecture Overview

The PR-validation job continues to construct the same simulated public payload
as the production workflow: it removes internal-only paths, applies documented
neutralization, then rejects remaining forbidden identifiers. The production
workflow retains its independent final guard immediately before the push.

Both guards use the same case-insensitive expression for `IBuySpy-Shared`,
`IBuySpy-Dev`, and `@ibuyspy`. Only the exact existing `LICENSE` copyright line
is excluded from failure results. User-facing examples that need a repository
reference use placeholders in source, rather than relying on the production
rewrite to make them appear neutral.

## Data Model and Storage Changes

No schema changes. The existing production workflow digest is updated in both
the source and distributed policy-pack files.

## API and Interface Contracts

- PR validation must fail before a release is tagged when the simulated public
  payload contains any forbidden identifier outside the exact legal
  attribution.
- Production publication must fail before pushing if the sanitized payload
  contains any forbidden identifier outside that attribution.
- Failure output must include matching file and line details.
- The getting-started callable-workflow example must use `OWNER/REPOSITORY`
  consistently for both the reusable workflow reference and `source_repo`.

## Security and Privacy Considerations

The guard is fail-closed: an unexpected internal organization or account
identifier blocks publication rather than being silently rewritten. Matching
is case-insensitive. The legal attribution exception remains exact and
path-specific; it must not broaden to other files, lines, or identifier forms.
No credentials, permissions, or external services are added.

## Reliability and Failure Modes

- If either workflow omits the handle from its expression, PR validation may
  pass while production rejects or leaks a handle; tests must assert both
  workflows retain the same identifier pattern.
- If the copyright exception is broadened, real leaks could be suppressed;
  tests must continue to require exactly one legal match in the fixture.
- If examples retain hard-coded source repository names, publishing can mask
  that defect through rewriting; the docs regression test must inspect the
  source document itself.
- A failed guard must stop its job before publication proceeds.

## Performance and Capacity Considerations

Negligible. The added alternative is evaluated by the existing repository
content scan.

## Implementation Plan

1. Replace the two hard-coded repository names in the getting-started example
   with `OWNER/REPOSITORY` and document the substitution.
2. Extend both the PR-validation and production guard expressions with
   `@ibuyspy`.
3. Extend publication regression tests to verify the shared pattern, require
   neutral source documentation, prove an account-handle fixture fails, and
   verify the updated trusted workflow digest.
4. Run the focused publication tests, solo-dev profile contract test, full test
   suite, and repository validation.

## Testing Strategy

- The publish-payload fixture with no forbidden identifiers passes and retains
  only the exact allowed `LICENSE` match.
- A fixture containing `@IBuySpy` fails the production sanitizer guard,
  proving case-insensitive matching and fail-closed behavior.
- Tests assert that both the PR-validation and production workflow use the
  complete identifier pattern.
- Tests assert that `docs/getting-started.md` uses neutral placeholders rather
  than `IBuySpy-Shared/basecoat`.
- Run `pwsh tests\publish-to-production-dispatch-tag-tests.ps1`,
  `pwsh tests\release-note-publication-tests.ps1`,
  `pwsh tests\run-tests.ps1`, and `pwsh scripts\validate-basecoat.ps1`.

## Rollout, Migration, and Rollback Plan

No migration is required. The PR checks run before merge and release; the
production guard remains a final independent barrier. After the next
successful publication, search the public mirror for `IBuySpy-Shared`,
`IBuySpy-Dev`, and `@ibuyspy` and record the result against #3406. If a
false-positive blocks a release, review the exact match and make a narrowly
scoped source or legal-attribution correction; do not weaken the guard.

## Observability and Operational Readiness

Both jobs emit matching file and line details in their failure output, and
existing required checks surface the PR-validation result. After publication,
the public code-search verification is an operational follow-up; it does not
replace either automated gate.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Different regexes in PR and release workflows drift | Assert both workflow expressions in the same regression test |
| Account handles in public content cause a new false positive | Review reported path and line; keep the policy fail-closed |
| Source documentation depends on publish-time rewriting | Assert placeholders in the source document itself |
| Public search is not available until after a release | Keep automated pre-release checks and record the post-publish search as follow-up |

## Open Questions

None. PR #3436 already supplies the public-payload simulation; this change
closes the uncovered account-handle and source-example gaps without duplicating
that gate.

## References

- Issue: [#3406](https://github.com/IBuySpy-Shared/basecoat/issues/3406)
- Existing PR-validation gate: [#3436](https://github.com/IBuySpy-Shared/basecoat/pull/3436)
- Related release incident: [#3403](https://github.com/IBuySpy-Shared/basecoat/issues/3403)
