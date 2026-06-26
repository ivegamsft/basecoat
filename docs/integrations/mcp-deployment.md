# MCP Deployment

This document explains how to run Base Coat as a deployable MCP server.

## Purpose

The Base Coat MCP server exposes the packaged standards catalog through a read-only stdio server so AI clients can discover and retrieve approved Base Coat assets without granting write access.

## Architecture References

- [docs/diagrams/basecoat-mcp-topology-and-extension-surface.md](../diagrams/basecoat-mcp-topology-and-extension-surface.md) — component topology for the catalog server, metrics server, and extension HTTP surface
- [docs/diagrams/basecoat-mcp-and-metrics-data-flow.md](../diagrams/basecoat-mcp-and-metrics-data-flow.md) — asset inventory/read/search flow plus the metrics fetch path
- [docs/diagrams/mcp-metrics-build-and-deploy-flow.md](../diagrams/mcp-metrics-build-and-deploy-flow.md) — CI validation, GHCR publish, and Azure Container Apps deployment for the metrics service

## Included Package

- `mcp/package.json`
- `mcp/index.js`
- `mcp/Dockerfile`
- `mcp/README.md`

## Deployment Modes

### Local Node Runtime

1. Extract the published Base Coat release artifact.
2. Change into `mcp/`.
3. Run `npm install`.
4. Start the server with `npm start`.

### Container Runtime

1. Build the image from repository root:

```bash
docker build -f mcp/Dockerfile -t basecoat-mcp .
```

1. Run the container with stdio attached:

```bash
docker run --rm -i basecoat-mcp
```

## Usage Guidance

### Use `basecoat-mcp` for the read-only catalog

Choose the root `mcp/` package when the client needs packaged BaseCoat assets only:

- `basecoat_inventory` for the release inventory
- `basecoat_search_assets` for path discovery
- `basecoat_read_asset` for approved file reads

This server is stdio-only and intentionally limited to allowlisted repo content.

### Use `basecoat-metrics` for shared metrics access

Choose `mcp/basecoat-metrics/` when the client needs live or historical adoption data:

- **Local stdio** for VS Code or Copilot CLI development
- **Remote HTTP** for a shared deployed endpoint backed by Azure Container Apps
- `REPO_DIR` only when you also want the optional asset-discovery tools exposed by the metrics server

### Keep the extension surface separate

`mcp/basecoat-extension/` is an HTTP application for authenticated Copilot Extension
workflows. It is not the same runtime as the read-only catalog server and should be
used only when you need the extension-specific endpoints and guarded write-tool flow.

## Available Tools

- `basecoat_inventory`
- `basecoat_read_asset`
- `basecoat_search_assets`

## Security Notes

- The server is read-only.
- Asset access is restricted to approved Base Coat directories and top-level files.
- Secrets and credentials are not required for the default local deployment model.
- For production use, pin the container image digest or release artifact version.

## Validation

Run the package self-test:

```bash
cd mcp
npm install
npm run self-test
```
