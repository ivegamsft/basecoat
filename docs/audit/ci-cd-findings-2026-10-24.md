# CI/CD Audit: Blockers, Slowdowns, and Remediation Plan

**Date:** 2026-10-24
**Tracking issue:** [#3923](https://github.com/IBuySpy-Shared/basecoat/issues/3923)
**Previous audit:** [ci-cd-findings-2026-06-14.md](ci-cd-findings-2026-06-14.md)

## Scope and evidence

- The last 300 workflow runs, covering about 8 hours on 2026-10-24.
- Job and step timings and the logs of failed runs.
- The 12 merge-queue (`merge_group`) entries from 2026-10-14 to 2026-10-24.
- The live `main` ruleset, compared with
  `.github/governance/rulesets/main-merge-queue.json`.
- The source of the workflows and validation scripts on the critical path.

## Summary

The pipeline is correct but slow. A PR clears its required checks in about
15 minutes. It then spends 18 to 25 minutes in a merge-queue entry. The queue
builds and merges one entry at a time, which caps throughput at about 2.5 to 3
PRs per hour. Most of the time is spent validating the same commit more than
once and running the test suites one after another. Two automation failures
(a retired model pin and stuck Dependabot jobs) block agent and dependency
work outright.

## Findings

### Blockers

| ID | Finding | Evidence | Issue |
|---|---|---|---|
| B1 | Three agentic workflows pin a retired model, `gpt-5-mini`. They have failed on every run since 2026-10-24 04:39 UTC. | Run 40069352675: `'gpt-5-mini' did not resolve against catalog`. Pins are in `code-review-agent.md:27`, `issue-triage.md:16`, and `release-impact-advisor.md:22`. | [#3914](https://github.com/IBuySpy-Shared/basecoat/issues/3914) |
| B2 | Dependabot npm update jobs have been queued since 10:54 UTC. Every earlier run since 2026-10-21 was cancelled. | Output of `gh run list --workflow "Dependabot Updates"`. | [#3915](https://github.com/IBuySpy-Shared/basecoat/issues/3915) |
| B3 | The merge queue is serialized (`max_entries_to_build=1`, `max_entries_to_merge=1`). PRs wait behind each other. | #3852 started 12 seconds after #3903 finished. None of the 12 entries overlapped. | [#3918](https://github.com/IBuySpy-Shared/basecoat/issues/3918) |
| B4 | The auto-merge executor treats draft PRs, an expected waiting state, as failures. Pending required checks already report `pending` without failing the run (`pr-auto-merge-executor.yml:1808-1816,1964-1984`). | 21 failed and 15 cancelled (separately counted) out of 103 executor runs in about 8 hours. | [#3919](https://github.com/IBuySpy-Shared/basecoat/issues/3919) |

### Slowdowns on the critical path

| Job | Typical time | Cause | Issue |
|---|---|---|---|
| `Validate BaseCoat` (merge group) | 18-25 min | The full suite runs again in the queue | [#3916](https://github.com/IBuySpy-Shared/basecoat/issues/3916), [#3917](https://github.com/IBuySpy-Shared/basecoat/issues/3917) |
| `validate-windows` | ~14 min | `scripts/run-windows-validation-lane.ps1:19-28` runs `validate-basecoat.ps1` both normally and with `-Strict`, plus the full suite | [#3916](https://github.com/IBuySpy-Shared/basecoat/issues/3916) |
| CI `test` (Linux) | ~14.5 min | `tests/run-tests.ps1:1069` runs about 111 suites one after another; the same suite also runs on Windows | [#3917](https://github.com/IBuySpy-Shared/basecoat/issues/3917) |
| Package Base Coat | ~16 min | `package-basecoat.yml:64-70` re-runs `validate-basecoat.yml` on a commit the queue already validated | [#3916](https://github.com/IBuySpy-Shared/basecoat/issues/3916) |
| Docs-only PRs | ~35-40 min total | No change classification, so docs-only changes run the full validation | [#3920](https://github.com/IBuySpy-Shared/basecoat/issues/3920) |
| Checkout and actionlint setup | 35-50 s and ~40 s each | Full-history checkouts (`fetch-depth: 0`) where history isn't needed; actionlint is set up four times in one job | [#3921](https://github.com/IBuySpy-Shared/basecoat/issues/3921) |

### Waste

- **Merge-group runs keep going after a PR leaves the queue.** #3880 was
  removed manually at 04:49 and 06:25 UTC. Its `Validate BaseCoat` runs still
  ran until 05:05 and 06:45. This is tracked in #3918.
- **The gh-aw security analyst used up its daily AI-credit budget**
  ([#3875](https://github.com/IBuySpy-Shared/basecoat/issues/3875)).

## Constraints

- **Required check names stay the same.** `lint-and-validate`, `test`,
  `validate-windows`, and the other required checks must keep reporting under
  those names. That way, sharding and de-duplication don't touch the rulesets
  or the policy-pack digests.
- **The serialized queue was a deliberate choice.** The release-label gate
  rejects merge groups that contain more than one commit (see
  [merge-queue-enforcement.md](../operations/merge-queue-enforcement.md)). The
  gate must be able to validate multi-entry groups before the queue can build
  in parallel.
- **Docs-only skips need care.** `paths-ignore` would leave required checks
  pending forever. Docs-only fast paths must short-circuit inside jobs instead.

## Remediation plan

| Phase | Goal | Issues | Exit criteria |
|---|---|---|---|
| 0 - Unblock | Restore broken automation | #3914, #3915 | Agentic workflows pass; one Dependabot PR completes end to end |
| 1 - Latency | Shorten the critical path | #3916, then #3917 | `test` and `validate-windows` take 6 minutes or less; a queue entry takes 8 minutes or less |
| 2 - Throughput and noise | Raise queue capacity, cut red noise | #3919, then #3918 after re-measuring | Executor failure rate under 5%; merge-group runs cancelled when a PR leaves the queue |
| 3 - Polish | Remove remaining waste | #3920, #3921 | A docs-only PR clears in 10 minutes or less |

**Expected outcome:** time to merge drops from about 35-40 minutes to about
10-12 minutes per PR. Even before Phase 2, shorter queue entries raise
throughput to about 7 PRs per hour.

**Ordering:** Phase 1 comes before Phase 2. Faster CI benefits every PR and
every queue entry. Queue concurrency needs gate changes and may not be needed
once queue entries take less than 8 minutes. Re-measure before changing the
ruleset.

## Re-measurement

After each phase, repeat the baseline measurement:

```powershell
gh run list -R IBuySpy-Shared/basecoat --event merge_group -L 60 `
  --json workflowName,createdAt,updatedAt,conclusion
gh api repos/IBuySpy-Shared/basecoat/rules/branches/main `
  --jq '.[] | select(.type=="merge_queue") | .parameters'
```
