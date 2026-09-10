# Waste Signals Reference

The ten checks evaluated by the `agentic-cost-audit` skill. Every check must
produce a measurement; a check that cannot be measured is reported as
**unknown**, never as a finding.

## Discovery

An agentic workflow is any of:

- `.github/workflows/*.md` containing an `engine:` key
- `.github/workflows/*.lock.yml` containing `gh-aw-metadata`
- a workflow invoking a model/agent action with a `model:` input

Record per workflow: model identifier, trigger events, `paths`/`paths-ignore`,
`concurrency`, prompt body size, and whether it publishes a status check.

## Model tiers

Tier the discovered `model:` value rather than hardcoding product names, which
change often:

| Tier | Characteristics | Relative cost weight |
|---|---|---|
| frontier | Flagship reasoning model, highest per-token price | 10 |
| standard | General-purpose mid-tier | 3 |
| economy | Small/fast/mini tier | 1 |

If a model identifier is unrecognized, report the tier as **unknown** and ask
rather than guessing. Never substitute a model automatically.

## Checks

| # | Check | Waste signal | Severity basis |
|---|---|---|---|
| 1 | Frontier model on high-frequency agent | `model:` is frontier tier and runs/day exceeds threshold | frequency x tier weight |
| 2 | Missing `paths-ignore` | PR-triggered agent with no path gating | docs-only PR ratio |
| 3 | Docs-only invocation waste | share of recent PRs that are docs-only yet triggered agents | direct waste percentage |
| 4 | `synchronize` amplification | runs-per-PR meaningfully above 1.0 | multiplier x tier weight |
| 5 | Overlapping charters | two or more agents claiming the same concern | duplicated spend |
| 6 | Redundant review layers | native Copilot Code Review enabled alongside custom review agents | duplicated spend |
| 7 | Missing `cancel-in-progress` | superseded runs not cancelled | wasted partial runs |
| 8 | Oversized agent prompt | agent body token count above budget | per-run token cost |
| 9 | Unbounded diff ingestion | no truncation guidance for large diffs | per-run token cost |
| 10 | Required-check + `paths-ignore` trap | a gate candidate is a required status check | **safety interlock** |

## Default thresholds

Thresholds are defaults, not policy. State the value used in the report so a
reader can disagree with it.

| Threshold | Default | Meaning |
|---|---|---|
| High-frequency agent | more than 2 runs/day averaged over the sample | check 1 trigger |
| Runs-per-PR | above 1.2 | check 4 trigger |
| Prompt budget | 630 approximate tokens | check 8 trigger |
| Sample window | 30 days or 100 PRs, whichever is smaller | all measurements |

Report the sample window with every measurement. A finding drawn from fewer
than 10 pull requests must be labelled **low confidence**.

## Check 10 is an interlock, not a finding

Check 10 does not save money — it prevents a recommendation from breaking the
repository. A required status check that is skipped by `paths-ignore` never
reports a conclusion, so the pull request waits forever on a check that will
never arrive.

Run check 10 **before** emitting any check 2 or check 4 remediation. If a
candidate agent publishes a required check, the remediation must first
propose removing the required-check requirement, or be withdrawn.

## Severity

Rank by estimated monthly spend reduction, not by finding count. A single
frontier-tier downshift usually outweighs several gating changes. When two
findings overlap — for example checks 2 and 3 describe the same waste — merge
them and count the saving once.

## Decisions required

Any finding that trades cost against detection quality is **not** a
recommendation. Route these to the report's decisions-required section with
options and residual risk, and let a human owner choose:

- downshifting a security-review agent's model tier
- dropping `synchronize` from a review agent that gates merges
- disabling a review layer that provides independent coverage
