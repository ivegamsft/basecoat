# Repository Inventory

This is a point-in-time inventory of the versioned BaseCoat source tree. It
complements the generated [asset manifest](../../asset-manifest.json), which is
the authoritative file-level distribution inventory.

## Snapshot

Generated from the source tree on 2026-09-01.

| Asset type | Count | Source |
|---|---:|---|
| Agents | 130 | `agents/*.agent.md` |
| Skills | 134 | `skills/*/SKILL.md` |
| Instructions | 91 | `instructions/*.instructions.md` |
| Prompts | 6 | `prompts/*.prompt.md` |
| GitHub Actions workflows | 90 | `.github/workflows/*.yml` |
| Documentation pages | 416 | `docs/**/*.md` before this snapshot was added |
| Agent evaluation definitions | 229 | `agents/*.eval.yaml` |
| Skill evaluation definitions | 134 | `skills/**/eval.yaml` |

The docs homepage has the current distributable asset totals and is checked by
`scripts/validate-basecoat.ps1`. This page provides additional operational
counts that do not belong in the product overview.

## Model Assignment

Agent frontmatter currently resolves to four canonical models:

| Model | Assigned agents | Share |
|---|---:|---:|
| `claude-sonnet-4.6` | 79 | 60.8% |
| `gpt-5.3-codex` | 26 | 20.0% |
| `gpt-5.4-mini` | 23 | 17.7% |
| `gpt-5.4` | 2 | 1.5% |
| **Total** | **130** | **100.0%** |

The capability catalog records 28 published models, of which 26 support
Copilot CLI, 7 are CLI auto-selectable, and 15 support configurable reasoning.
Runtime entitlement is user- and organization-specific; the catalog is not an
allowlist.

Refresh assignment data with:

```powershell
pwsh -NoProfile -File scripts/generate-model-inventory.ps1
```

See [Model Inventory](model-inventory.md) and [Model Capability Framework](model-capabilities.md)
for the generated assignment list and capability details.

## Token Footprint

The validator estimates tokens as `round(word_count * 1.7)`. This is a sizing
heuristic for always-loaded entrypoints, not provider billing usage or runtime
context consumption.

| Asset type | Files | Words | Approximate tokens | Average tokens | At/above 630 tokens |
|---|---:|---:|---:|---:|---:|
| Agent entrypoints | 130 | 39,444 | 67,055 | 516 | 0 |
| Skill entrypoints | 134 | 31,128 | 52,918 | 395 | 0 |
| Instructions | 91 | 52,779 | 89,724 | 986 | 59 |
| Prompts | 6 | 2,185 | 3,714 | 619 | 2 |
| **Total** | **361** | **125,536** | **213,411** | **591** | **61** |

The validator's 630-token per-file warning applies only to agent and skill
entrypoints. The instruction and prompt values in the last column are raw
comparisons for visibility, not validator warnings or violations. Their
loading scopes also differ, so they are not equivalent to a single session
context size.

For session-level token economics and operating thresholds, see
[Token Optimization](../guides/token-optimization.md). Recalculate the table
after material asset changes with the same `-split '\s+'` word-count method
used by `scripts/validate-basecoat.ps1`.

## Refresh Expectations

1. Regenerate `model-map.json` and `model-inventory.md` whenever agent model
   frontmatter changes.
2. Update this snapshot when an asset count, workflow count, token budget, or
   capability-catalog count changes materially.
3. Regenerate `asset-manifest.json` when tracked distributable assets change.
