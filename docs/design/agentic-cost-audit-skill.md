# Spec: `agentic-cost-audit` skill

**Status**: Proposed
**Issue**: #3296
**Scope**: Cost and token waste only

## Problem

BaseCoat found ~60% waste in its own agentic PR review spend only because an
operator asked. Nothing detects it automatically, and downstream repos consuming
the template inherit the same ungated agent workflows with no way to measure the
damage.

The findings that motivated this (issue #3291) required reading agent frontmatter
and correlating it with PR history by hand:

- Two of three PR agents ran a frontier model; ~95% of spend
- 40% of merged PRs were markdown-only yet triggered all three agents
- 1.54 agent runs per PR from `synchronize` re-reviews
- Two agents held overlapping charters, paying twice for one answer

None of this is visible from any existing skill.

## Why existing skills do not cover it

| Skill | Covers | Why it misses this |
|---|---|---|
| `copilot-usage-analytics` | Copilot CLI session cost, model routing efficiency, usage APIs | Oriented at interactive session/API usage. Does not read `.github/workflows/*.md` agent definitions. |
| `ci-audit` | Branch protection, required checks, runners, security gates | Governance and compute posture. Has no concept of AI model selection or token spend. |

Agentic CI model spend falls in the gap between them.

## Scope

**In scope — cost and token waste only:**

- Model selection versus agent invocation frequency
- Trigger and path-filter gating that causes needless invocations
- Duplicate or overlapping agent charters
- Prompt/context size driving per-run token cost
- Redundant review layers

**Explicitly out of scope:**

- Security posture, branch protection, compliance (owned by `ci-audit`)
- Agent output quality or accuracy
- Compute/runner-minute cost unrelated to model spend
- Interactive CLI session cost (owned by `copilot-usage-analytics`)
- Any write operation

## Behavior

Read-only. Routed by `investigate:` or `audit:`. Never edits workflows; emits a
findings report plus optional issue-ready remediation packets.

### Signals

Discover agentic workflows (`engine:` in `.github/workflows/*.md`, or `.lock.yml`
with `gh-aw-metadata`), then evaluate:

| # | Check | Waste signal | Severity basis |
|---|---|---|---|
| 1 | Frontier model on high-frequency agent | `model:` is frontier-tier AND runs/day above threshold | frequency x model tier |
| 2 | Missing `paths-ignore` | PR-triggered agent with no path gating | docs-only PR ratio |
| 3 | Docs-only invocation waste | % of recent PRs that are docs-only but still triggered agents | direct waste % |
| 4 | `synchronize` re-review amplification | runs-per-PR meaningfully above 1.0 | multiplier x model tier |
| 5 | Overlapping charters | 2+ agents claiming the same concern in description/body | duplicated spend |
| 6 | Redundant review layers | native Copilot review enabled alongside custom review agents | duplicated spend |
| 7 | Missing `cancel-in-progress` | superseded runs not cancelled | wasted partial runs |
| 8 | Oversized agent prompt | agent body token count above budget | per-run token cost |
| 9 | Unbounded diff ingestion | no truncation guidance for large diffs | per-run token cost |
| 10 | Required-check + `paths-ignore` trap | gated agent is a required check | not cost — blocks merges; must flag before recommending #2 |

Check 10 is a safety interlock: recommending `paths-ignore` on a required check
would hang PRs. The audit must verify this before proposing gating.

### Method

1. **Inventory** agent definitions: model, triggers, path filters, concurrency,
   prompt size.
2. **Measure** from `gh run list`: runs per agent per day, duration, runs-per-PR.
3. **Classify** recent merged PRs by changed-file type to get the docs-only ratio.
4. **Cross-check** required status checks before proposing any gating.
5. **Rank** findings by estimated spend reduction, not by count.
6. **Report** with measurements, ranked remediations, and residual risk.

Every finding must carry a measurement. No unquantified recommendations.

### Output

Ranked findings table (check, evidence, estimated reduction, risk), a
remediation packet per finding, and an explicit **decisions-required** section
for anything trading cost against detection quality — for example downshifting a
security agent's model. The skill recommends; it never silently assumes that
tradeoff.

## Deliverables

```text
skills/agentic-cost-audit/
  SKILL.md
  eval.yaml
  references/
    waste-signals.md
    measurement-commands.md
  templates/
    cost-findings-report.md
    remediation-packet.md
```

`eval.yaml` is required by the CI gate (all 142 skills currently have one).

## Acceptance criteria

- [ ] Detects all four findings from #3291 when run against this repo at the
      pre-fix commit — this is the regression test for the skill
- [ ] Every finding includes a measurement and estimated reduction
- [ ] Flags required-check conflicts before recommending `paths-ignore`
- [ ] Performs zero writes
- [ ] Routes cleanly from `investigate:` and `audit:`
- [ ] Cross-references `copilot-usage-analytics` and `ci-audit` rather than
      duplicating them
- [ ] Runs against a downstream template consumer with no BaseCoat-specific
      assumptions

## Open questions

1. Extend `copilot-usage-analytics` instead of adding a skill? Its stated scope
   already claims model-routing audit, but its implementation is
   session/API-oriented. **Recommendation: separate skill, cross-linked**, since
   the input surface (workflow definitions) is entirely different.
2. Should thresholds (frontier-model runs/day, runs-per-PR) be configurable or
   fixed defaults?
3. Should this run on a schedule and open an issue on regression, or stay
   on-demand? Scheduled runs cost tokens themselves — a monthly cadence is
   likely the right tradeoff.
