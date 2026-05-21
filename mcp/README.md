# Base Coat MCP Server

This package exposes the Base Coat repository as a stdio Model Context Protocol server.

## What It Does

- Lists packaged Base Coat assets
- Reads approved asset files by relative path
- Searches packaged asset paths

The server is read-only and only exposes approved top-level Base Coat content.

## Tools

- `basecoat_inventory`: list version and packaged assets
- `basecoat_read_asset`: read a specific Base Coat asset
- `basecoat_search_assets`: find matching asset paths

## Run Locally

```bash
cd mcp
npm install
npm start
```

## Self-Test

```bash
cd mcp
npm install
npm run self-test
```

## Docker

Build from the repository root:

```bash
docker build -f mcp/Dockerfile -t basecoat-mcp .
docker run --rm -i basecoat-mcp
```

## Example Client Config

See `examples/mcp/basecoat.mcp.json` for a sample MCP client entry.

## Copilot Extension Scaffold

The initial Copilot Extension runtime scaffold lives at `mcp/basecoat-extension/`.
It uses `@github/copilot-sdk` with an Express runtime skeleton and health endpoint.
