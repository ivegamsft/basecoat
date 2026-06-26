# BaseCoat MCP and Metrics Data Flow

This diagram breaks the read paths into the two flows that matter most in day-to-day
use: catalog asset access in `basecoat-mcp`, and metrics retrieval in
`basecoat-metrics`.

- Source files: `mcp/index.js`, `mcp/basecoat-metrics/src/index.ts`

## 1. Asset catalog read path

```mermaid
flowchart TD
    A["MCP client request<br/>basecoat_inventory / basecoat_search_assets / basecoat_read_asset"] --> B["basecoat-mcp"]
    B --> C{"Which tool?"}

    C -->|inventory| D["buildInventory()<br/>read version.json<br/>walk approved top-level groups"]
    C -->|search| E["buildInventory()<br/>substring match on packaged paths"]
    C -->|read| F["normalizeRelativePath()<br/>reject traversal and disallowed roots"]

    D --> G["Return version + packaged asset list"]
    E --> H["Return matching repo-relative asset paths"]
    F --> I["readTextFile()<br/>read allowlisted file only"]
    I --> J["Return file contents to client"]
```

## 2. Metrics fetch path

```mermaid
flowchart TD
    K["MCP client request<br/>get-latest-metrics / get-history / get-alerts / get-repo-metrics"] --> L["basecoat-metrics"]
    L --> M["fetchMetrics(file)"]
    M --> N{"METRICS_DIR set and file exists?"}

    N -->|Yes| O["Read local JSON file<br/>latest.json / history.json / alerts.json"]
    N -->|No| P["Fetch from GitHub Pages<br/>METRICS_BASE_URL/<file>"]

    O --> Q["Parse JSON"]
    P --> Q
    Q --> R{"Tool-specific shaping"}

    R -->|latest| S["Optional repo filter"]
    R -->|history| T["Slice last N weeks<br/>optional repo filter"]
    R -->|alerts| U["Optional severity filter"]
    R -->|repo metrics| V["Join latest snapshot with history trend window"]

    S --> W["Return JSON payload"]
    T --> W
    U --> W
    V --> W
```

## 3. Notes

1. The catalog path stays inside the repo and relies on path normalization plus an
   allowlist of top-level directories and files before any read occurs.
2. The metrics path is read-only in both modes. The only runtime switch is whether
   the JSON source is local (`METRICS_DIR`) or remote (`METRICS_BASE_URL`).
3. `basecoat-metrics` also exposes optional repo asset discovery tools when
   `REPO_DIR` is configured, but those are a supplemental read path and do not
   replace the primary `basecoat-mcp` catalog flow.
