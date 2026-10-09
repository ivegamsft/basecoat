---
issue: 3660
title: "fix(intake): prevent synthesized Markdown heading-spacing regressions"
status: proposal
author: ibuyspy
created: 2026-10-08
labels: ["bug", "priority:high", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: fix(intake): prevent synthesized Markdown heading-spacing regressions

## Problem Statement

## Description

fix(intake): prevent synthesized Markdown heading-spacing regressions

## Intake Contract

### RCA

## Why This Matters

Synthesis must fail explicitly on invalid artifacts instead of publishing a
draft that cannot pass required checks. Source placeholders remain separate
design blockers rather than implicit approval.

## Scope

Repair copied Markdown formatting and compile the complete embedded
github-script body; extend publication validation to both artifacts under
the same pinned repository Markdown configuration as PR CI.

## Design Contract

Normalize CRLF to LF and ensure blank lines around ATX headings outside
fenced code blocks. Preserve fenced content, fence type/length, indentation,
inline code and already-valid Markdown. Source extraction must understand
the current Description/Intake Contract format and legacy headings without
mistaking quoted commands or copied approval text for authority.

Do not truncate inside a fence or section boundary. Preserve bare URLs
according to the repository's configured Markdown rules; generated reference
URLs use the existing angle-bracket form. Titles/frontmatter must remain
valid with quotes, colons and untrusted input.

Compile every embedded script before hosted execution; YAML validation alone
cannot detect duplicate JavaScript lexical declarations. Test the complete
published script body, not just regex presence of a helper.

## Publication and Failure Contract

Generate both files in a bounded validation workspace using trusted tools
from the default-branch revision. Lint before branch/PR publication; failures
report source issue, stage and safe diagnostics and produce no success claim.
Never run source-provided commands as validation.

On a retry, reuse the identified synthesis branch and inspect existing
artifacts/PR state before mutation. Preserve user edits; stale base or
conflicting artifact identity blocks rather than overwrites. Existing intake
preflight must bind file/line counts to the current diff before PR creation.
An orphaned branch is a recoverable non-success state, not delivery proof.

## Test Matrix

| Fixture | Required result |
| --- | --- |
| Compact Description / Intake Contract / RCA headings | Both artifacts pass MD022 |
| Already valid headings | Content stays unchanged |
| CRLF source | Equivalent normalized output |
| Backtick, tilde and longer outer fences | Fenced headings stay code |
| Truncated fallback and incomplete fence | Preserve boundary or reject explicitly |
| Bare URLs, quoted titles, colon-containing text | Same pinned Markdown/frontmatter rules as PR CI |
| Duplicate embedded `const` declaration | Full-script compilation fails before dispatch |
| Lint failure in either artifact | No PR publication; explicit failed stage |
| Missing scope/acceptance | Draft proposal remains incomplete, never approved |
| Changed main, retry and existing user edits | Exact-base preflight or named conflict |

## Rollout and Verification

Land the minimal parse/heading hotfix #3691 through required checks and native
queue. Its current local compilation/normalization fixtures cover only the
corresponding rows; do not claim the entire matrix is implemented.
Prepublication artifact linting and robust source/fallback handling require
their own verified implementation evidence under #3660.

Use a controlled existing synthesized issue for hosted execution so a test
does not open unsolicited work. Bind proof to workflow SHA and resulting
artifact identities, not merely a green no-op run. Preserve solo-dev
autonomy through XL and genuine XXL approval.

## Risks, Observability and Rollback

Over-normalization can corrupt code or change source meaning; fence and
idempotence fixtures prevent that. Untrusted issue text is data only.
Record generation/validation/publication stages and explicit blocker reasons
without credentials or raw secret-bearing input. Retry cannot expand scope.
Revert the producer change if content preservation regresses; retain source
and generated artifacts for diagnosis, without claiming stale checks pass.

## Acceptance Criteria

- [ ] Implementation matches the scope defined above.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3660-fixintake-prevent-synthesized-markdown-heading-spacing-regre.prd.md`
- Refs #3660
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3660>
