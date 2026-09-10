# Remediation Packet — `<finding title>`

Issue-ready packet for a single finding. One packet per finding; do not bundle
unrelated changes into one packet.

## Problem

`<What is being paid for that produces no value. One paragraph.>`

## Measurement

| Field | Value |
|---|---|
| Check | `<number and name>` |
| Workflow | `.github/workflows/<file>` |
| Measured value | `<number>` |
| Command | `<command that produced it>` |
| Sample window | `<window>` |
| Confidence | high / low (under 10 pull requests) |

## Proposed change

`<The specific, minimal edit. Show the exact YAML or frontmatter keys involved.>`

```yaml
# before

# after
```

## Estimated reduction

~N% of current agent spend, derived as
`runs_avoided_per_month x tier_weight(model)`. Show the arithmetic.

## Safety interlock

- [ ] Verified this workflow does **not** publish a required status check
- [ ] Verified no ruleset requires it
- [ ] If it does: this packet is blocked until the requirement is removed

A gated required check never reports and hangs every pull request.

## Residual risk

<What coverage is reduced, and what still covers it — for example independent
code scanning or secret scanning. Write "none" only when genuinely none.>

## Validation after applying

- Recompile if the workflow is generated, then confirm runtime and distributed
  copies stay identical.
- Re-measure the same command after 7 days and compare against the value above.
- Confirm pull requests still reach a mergeable state.

## Out of scope

This packet changes cost only. It does not alter security posture, agent
output quality, or branch protection.
