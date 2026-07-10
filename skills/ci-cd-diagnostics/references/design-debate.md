# CI/CD Diagnostics Skill Design Debate

## Question

Should this behavior be added to existing audit skills or introduced as a new
skill?

## Option A: extend `ci-audit`

### Pros

- Reuses an existing CI-focused skill and agent name.
- Fewer routing entries to maintain.

### Cons

- `ci-audit` is governance and policy-gap oriented.
- Existing output contract expects findings and remediation framing.
- Mixing governance review with data-only diagnostics increases misrouting.

## Option B: create `ci-cd-diagnostics` (selected)

### Pros

- Clean intent boundary: metrics-only diagnostic snapshot.
- Enforces strict output contract (`Metric | Value | Source`) and `BLOCKED`.
- Fits release-engineering telemetry workflows without governance coupling.

### Cons

- Adds one additional skill to maintain.
- Requires routing updates and eval coverage for a new intent label.

## Decision

Create a new skill: `ci-cd-diagnostics`.

## Design choices

1. Keep `SKILL.md` concise and push details into references.
2. Require source-command traceability for every metric row.
3. For unavailable metrics, require exact blocking reason and failing source.
4. Explicitly ban recommendations to preserve data-collection purity.

## Out-of-scope

- Automatic remediation playbooks.
- Queue policy optimization guidance.
- Root-cause analysis narratives.
