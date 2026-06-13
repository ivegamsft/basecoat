# Build Master State Machine

## Lane states

| State | Meaning | Entry trigger | Exit trigger |
|---|---|---|---|
| `healthy` | Lane is merging normally | initialization or successful recovery | confirmed post-merge failure |
| `degraded` | Lane has active incident but may continue with limits | first confirmed failure | threshold breach (`paused`) or successful fix (`healthy`) |
| `paused` | Lane is blocked for safety | policy threshold reached or high-risk signal | fix PR verified and policy checks pass |
| `recovering` | Lane is in verification after fix | fix PR merged and checks running | all required checks green (`healthy`) or regression (`paused`) |

## Global states

| State | Meaning |
|---|---|
| `normal` | no lane-level active incidents |
| `incident-contained` | one or more lanes impacted, healthy lanes still merging |
| `global-hold` | merges paused globally due to cross-lane/high-risk incident |

## Transition rules

1. Merge decisions are lane-local unless cross-lane blast-radius policy is triggered.
2. A paused lane cannot resume without verification on target branch.
3. `global-hold` requires explicit owner acknowledgment to release.
4. Any Tier 3 incident may force `global-hold` regardless of lane count.

