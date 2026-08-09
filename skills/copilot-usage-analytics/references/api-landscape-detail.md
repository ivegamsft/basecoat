# Copilot Usage API Landscape — Detail

## API Sources

| Source | Endpoint | Status | Notes |
|---|---|---|---|
| GitHub REST — Copilot Metrics | `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest` | ✅ Live | Returns NDJSON download link; DAU, CLI users, agent users. Old `/copilot/metrics` sunset 2026-04-02. Requires `admin:org` or `read:org` scope. |
| GitHub REST — Copilot Billing | `GET /orgs/{org}/copilot/billing` | ⚠️ Partial | Returns seat counts only; no per-model or per-session cost data |
| Power BI Copilot Usage dataset | Dataset `5c6c70ac-*` | ❌ Auth error | Requires separate AAD scope (`AADSTS9010010`); not available via standard MCP token |

## Metrics API Response Format

```json
{
  "download_links": ["<azure-blob-ndjson-url>"],
  "report_start_day": "2026-04-10",
  "report_end_day": "2026-05-07"
}
```

The download URL returns NDJSON (one JSON object per line) with per-user/per-model usage data
for the 28-day window.

## Model Routing Guidance

| Task Complexity | Recommended Model | Rationale |
|---|---|---|
| Simple lookup, label assignment, short summarization | `gpt-5.4-mini` / `gpt-5-mini` | Low reasoning demand; high token efficiency; omit `reasoning_effort` |
| Code generation, refactoring, structured output | `claude-sonnet-4.6` / `gpt-5.4` | Balanced quality-to-cost ratio |
| Architecture design, multi-file reasoning, threat modeling | `claude-sonnet-4.6` / `gpt-5.4` | High accuracy required; cost justified by complexity |
| Creative or exploratory research | `claude-opus-4.7` | Reserve for tasks where quality difference is measurable |
| Code-specific tasks (generation, review, migration) | `gpt-5.3-codex` | Specialized code model; optimized for code tasks |

Until GitHub exposes per-session usage data, session cost must be self-tracked using this
skill's estimation workflow.
