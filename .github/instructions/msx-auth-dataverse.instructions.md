---
description: "MSX Dataverse authentication, workflow context, and integration patterns"
applyTo: "agents/**/*,skills/**/*,mcp/**/*"
---

# MSX & Dataverse Integration

## Authentication & Context

MSX (Microsoft Sales Execution) Dataverse operates within corporate authentication:

- Authenticate with `msx-mcp-msx_login` before first use
- Token validity check: `msx-mcp-msx_auth_status`
- VPN connectivity required for Dataverse queries

## Common Workflows

### Opportunity Lookup

Use `msx-mcp-get_opportunity_details` with:
- Exact GUID lookup: `opportunity_id`
- Fuzzy name search: `name_search`

Returns: value, close date, sales stage, deal team, milestones, products.

### Territory Overview

Scope to ATU Group (e.g., `USA.EC.FSI.Banking`):

```
msx-mcp-get_territory_overview --atu_group <pattern>
```

Returns: accounts (TPID), pipeline by stage, MACC data.

### Deal Team Management

Find your assigned accounts/opportunities:

- `msx-mcp-get_account_team` — Your account roster
- `msx-mcp-get_my_deals` — Your opportunity pipeline
- `msx-mcp-get_my_milestones` — Your engagement milestones

### Search & Filtering

Search opportunities across org:

```
msx-mcp-search_opportunities --search_text "term" --sales_play "play" --status open
```

Supports filters: solution_area, sales_play, deal_type, min_value, status.

## Data Operations

### Write Operations

Requires explicit confirmation (MCP elicitation pattern):

```
msx-mcp-dataverse_write --operation patch --entity_set opportunities --id <guid> --data '{fields}'
```

Supported operations: `create`, `patch`, `execute_action`.

### Queries

Read-only OData queries:

```
msx-mcp-dataverse_query --entity_set <set> --filter "$filter" --select "$select"
```

**WARNING**: OptionSet fields (solution_area, sales_play) store integers; never use `contains()` on them
(silently returns zero results). Use `eq` with codes or filter client-side.

## Quota & Consumption

Track AI model token consumption by customer (TPID):

```
msx-mcp-quota_consumption --tpid <tpid> --months 6
```

Returns DAX query for Foundry Dash semantic model with per-model/subscription/region breakdown.
