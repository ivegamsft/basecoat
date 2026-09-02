# Model Routing Defaults

Canonical cost-routing policy for BaseCoat sessions. Premium-tier models
(Opus and equivalents) are opt-in. Standard-tier, cache-friendly models
are the default for implementation, docs, and CI work.

Evidence: consumer repo-story spend where Opus sessions were ~60% of AIU
on work that did not need premium reasoning (issue #2978). Comparisons
across apps are directional only; the policy is justified by BaseCoat's
own guidance that Auto must not silently select Opus.

## Default tiers

| Work | Default family | Premium (Opus) |
|---|---|---|
| Implementation, docs, tests, CI triage | Standard (Sonnet / GPT-5.x class) | No |
| Mechanical scans, formatting, status loops | Mini / flash class | No |
| Background `task` / sub-agents | Mini or standard; never inherit parent premium | No |
| Architecture, security tradeoffs, deep RCA | Standard first | Opt-in after a written trigger |
| Regulated / reproducibility pin | `pinned_model` plus `pin_reason` | Only with pin_reason |

Do not pin a calendar version in this file. Use `model_policy.preferred_families`
on assets (ADR-002). Named examples in the playbook are illustrations.

## Premium opt-in

Use premium only when at least one trigger is true and recorded in the
session or PR:

- Ambiguous architecture with irreversible blast radius
- Security or safety reasoning the standard tier already failed
- Repeated standard-tier failures on the same defect

Say the trigger in one sentence before the upshift. Silent Auto-to-Opus
is a policy violation.

## Sub-agents

Fleet and `task` children default to a lighter model than the parent.
Passing the parent's premium model into a scan or test runner is the
failure mode this policy exists to stop.

## Session cost signal

At each phase boundary (`/compact`, PR open, merge wait):

1. Note selected model family and whether premium was used.
2. If usage data exists, record a one-line AIU or token rollup.
3. Warn when premium was used without a recorded trigger (soft ceiling).

Do not block the session on the warning. The next cycle should downshift.

## Related

- `docs/guides/cost-aware-prompting-playbook.md`
- `docs/guides/agent-tier-selection.md`
- `docs/architecture/decisions/adr-002-agent-model-shifting-and-cost-governance.md`
