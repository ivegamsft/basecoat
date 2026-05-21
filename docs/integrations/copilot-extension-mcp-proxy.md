# Copilot Extension MCP Proxy Contract

This document defines the integration contract for the extension proxy routes added
for issue [#1129](https://github.com/IBuySpy-Shared/basecoat/issues/1129).

The extension service proxies read-only calls to the deployed BaseCoat MCP server
(`mcp/basecoat-metrics`) using MCP `tools/call` requests over HTTP.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `EXTENSION_MCP_ENDPOINT` | `http://localhost:8080` | MCP HTTP endpoint used by proxy routes |
| `EXTENSION_MCP_TIMEOUT_MS` | `5000` | Upstream timeout budget per MCP tool call |
| `PORT` | `3000` | Extension service listen port |

## Routes

### `POST /api/extension/search`

Searches skills and/or agents through MCP search tools.

Request:

```json
{
  "query": "security",
  "type": "all",
  "limit": 10
}
```

- `query` (required): keyword string
- `type` (optional): `all` (default), `skill`, or `agent`
- `limit` (optional): integer `1..50` (default `10`)

Tool mapping:
- `type=skill` → `search-skills`
- `type=agent` → `search-agents`
- `type=all` → both tools, combined response

### `GET /api/extension/metrics`

Returns metrics data through MCP metrics tools.

Query parameters:
- `view` (optional): `latest` (default), `history`, `alerts`, `repo`
- `repo` (required for `view=repo`)
- `weeks` (optional, `view=history`): integer `1..52`, default `4`
- `trendWeeks` (optional, `view=repo`): integer `1..12`, default `4`
- `severity` (optional, `view=alerts`): `all` (default), `warning`, `info`

Tool mapping:
- `view=latest` → `get-latest-metrics`
- `view=history` → `get-history`
- `view=alerts` → `get-alerts`
- `view=repo` → `get-repo-metrics`

### `POST /api/extension/details`

Loads full asset content from MCP.

Request:

```json
{
  "path": "skills/azure-ai/SKILL.md"
}
```

- `path` (required): repo-relative asset path
- Tool mapping: `get-asset-details`

## Timeout and Error Mapping Policy

| Condition | HTTP status | Error code |
|---|---:|---|
| Invalid request payload/parameters | `400` | `invalid_request` |
| Unknown extension route | `404` | `not_found` |
| MCP tool reports missing resource | `404` | `not_found` |
| Upstream timeout (`AbortError`) | `504` | `upstream_timeout` |
| Upstream unavailable/network failure | `502` | `upstream_unavailable` |
| Upstream HTTP `429` or `503` | `503` | `upstream_error` |
| Other upstream non-2xx HTTP | `502` | `upstream_error` |
| Invalid upstream response shape/format | `502` | `upstream_bad_response` |
| Unhandled server fault | `500` | `internal_error` |

All errors return JSON:

```json
{
  "error": "upstream_timeout",
  "message": "MCP upstream timed out after 5000ms."
}
```
