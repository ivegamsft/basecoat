# Standards Mapping Reference

BaseCoat standards mappings are advisory planning aids and not compliance attestations.
They are not certifications or legal advice.

Use this reference with `skills/standards-mapping/SKILL.md` to crosswalk a
repository area, migration plan, component, agent, or skill bundle to supported
security and governance frameworks. The source of truth is
`docs/reference/governance/standards-mapping-taxonomy.json`; this Markdown file
documents how maintainers and downstream consumers should use it.

## Supported Framework Set

The initial taxonomy supports safe-to-cite identifiers or categories for:

| Framework ID | Framework | Citation mode |
|---|---|---|
| `owasp` | OWASP | Public identifiers and BaseCoat-owned summaries |
| `nist-csf` | NIST Cybersecurity Framework | Public function/category identifiers and BaseCoat-owned summaries |
| `microsoft-caf` | Microsoft Cloud Adoption Framework | Public methodology names and BaseCoat-owned summaries |
| `microsoft-waf` | Microsoft Azure Well-Architected Framework | Public pillar names and BaseCoat-owned summaries |
| `nist-ai-rmf` | NIST AI Risk Management Framework | Public function identifiers and BaseCoat-owned summaries |

Do not copy restricted framework text into BaseCoat reports. Cite public
identifiers, framework names, and BaseCoat-owned summaries only.

## Input Contract

Every mapping request must identify:

| Field | Required | Description |
|---|---|---|
| `componentName` | Yes | Human-readable component, repository area, migration plan, agent, or skill bundle name |
| `componentType` | Yes | Type such as `api`, `repository`, `azure`, `migration-plan`, `agent`, or `skill` |
| `repositoryPaths` | Yes | Paths that contain the implementation, plan, or customization assets being assessed |
| `frameworks` | No | Framework IDs to include; omit to use every supported framework |
| `cloudWorkloadContext` | No | Workload, subscription, platform, data sensitivity, or deployment context that affects applicability |

Unknown framework IDs must fail with an actionable diagnostic that lists the
supported framework IDs from the taxonomy.

## Output Contract

Each generated report must include:

| Field | Description |
|---|---|
| `taxonomyVersion` | Version or freshness date from the taxonomy |
| `selectedFrameworks` | Framework IDs included in the run |
| `summaryCounts` | Count of `covered`, `partial`, `gap`, and `not-applicable` outcomes |
| `warnings` | Stale taxonomy warnings, missing evidence warnings, or unsupported request details |
| `mappings` | Per-framework/category mapping rows |

Each mapping row must include:

| Field | Description |
|---|---|
| `framework` | Framework ID |
| `categoryId` | Taxonomy category or control identifier |
| `coverageStatus` | One of `covered`, `partial`, `gap`, or `not-applicable` |
| `evidencePaths` | BaseCoat or repository paths used as evidence |
| `evidenceSummary` | BaseCoat-owned summary of why the evidence applies |
| `caveat` | Advisory limitation, missing artifact, or applicability note |
| `nextAction` | Recommended review, skill, or issue follow-up |

## Coverage Semantics

| Status | Meaning |
|---|---|
| `covered` | A BaseCoat asset directly maps to the category for the component type and the requested evidence path exists |
| `partial` | Some supporting guidance exists, but the component lacks a required implementation, ownership, or review artifact |
| `gap` | No matching BaseCoat or repository evidence path was found |
| `not-applicable` | The category does not apply to the declared component type or workload context |

Missing evidence must be reported as `gap`; do not invent mappings.

## Freshness Rules

Taxonomy entries carry a `freshnessDate`. Entries older than
`freshnessReviewAfterDays` should warn, not fail, because standards and cloud
framework pages can change independently from BaseCoat. A stale warning means
the user should verify current public framework references before using the
report for planning.

## Recommended Review Pairing

Standards mapping points to existing BaseCoat review assets rather than replacing
them:

| Need | Follow-up asset |
|---|---|
| API threat modeling | `skills/api-security/SKILL.md` |
| Supply-chain posture | `skills/supply-chain-security/SKILL.md` |
| Repository controls | `skills/governance-audit/SKILL.md` |
| Azure policy posture | `skills/azure-policy-audit/SKILL.md` |
| Azure workload review | `skills/azure-waf-review/SKILL.md` |
| AI governance planning | `skills/agent-design/SKILL.md` and synthesized issue #3116 planning artifacts |

## Maintenance

1. Update `standards-mapping-taxonomy.json` when adding frameworks,
   categories, evidence assets, or freshness metadata.
2. Keep category summaries BaseCoat-owned and concise.
3. Add fixture coverage for every new framework and every new status outcome.
4. Preserve the advisory disclaimer in generated reports and downstream docs.

Refs #3114.
