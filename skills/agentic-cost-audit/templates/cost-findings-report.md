# Agentic Cost Audit — Findings Report

**Repository:** `OWNER/REPO`
**Audited:** YYYY-MM-DD
**Sample window:** `<N days / N pull requests>`
**Scope:** model and token waste only — read-only, no changes made

## Summary

| Metric | Value |
|---|---|
| Agentic workflows discovered | N |
| Frontier-tier agents in the PR path | N |
| Agent runs in window | N |
| Runs per pull request | N.N |
| Docs-only pull request ratio | N% |
| Estimated reduction available | ~N% of current agent spend |

One paragraph stating where the spend actually goes. Lead with the dominant
driver, not the longest list.

## Ranked findings

Ordered by estimated reduction, not by count.

| # | Check | Workflow | Evidence (measured) | Est. reduction | Risk |
|---|---|---|---|---|---|
| 1 | | | | ~N% | low/med/high |
| 2 | | | | ~N% | low/med/high |

## Finding detail

### F1 — `<title>`

- **Check:** number and name from `references/waste-signals.md`
- **Measurement:** `<the number, and the command that produced it>`
- **Sample:** `<window; mark low confidence under 10 pull requests>`
- **Estimated reduction:** ~N% of current agent spend
- **Remediation:** `<what to change; see the remediation packet>`
- **Residual risk:** `<what coverage is lost, or "none">`

Repeat per finding.

## Required-check interlock (check 10)

| Gating candidate | Publishes a required check? | Safe to gate? |
|---|---|---|
| | yes/no | yes / no — remove requirement first |

Any candidate marked **yes** must not be gated until the required-check
requirement is removed. Gating a required check hangs pull requests forever.

## Decisions required

Findings that trade cost against detection quality. These are **not**
recommendations; a human owner must choose.

### D1 — `<title>`

| Option | Est. saving | Risk |
|---|---|---|
| A. Status quo | baseline | none |
| B. `<option>` | ~N% | `<risk>` |

**Recommendation:** `<option, and the condition under which it holds>`

## Checks that returned no finding

| Check | Result |
|---|---|
| | pass / unknown (reason) |

Report **unknown** where a measurement was unavailable. Do not report an
unmeasured check as passing.

## Method and limitations

Commands used are listed in `references/measurement-commands.md`. State every
threshold applied and every assumption a reader might reasonably dispute.
