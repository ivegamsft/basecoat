---
name: mcp-development
compatibility: [github-copilot-cli]
description: "Use when building or extending MCP servers, defining tool schemas, or choosing stdio, SSE, or Streamable HTTP transports. USE FOR: scaffold MCP server, define MCP tool contract, configure MCP transport, review MCP server security, integrate MCP server with client. DO NOT USE FOR: generic REST API design, non-MCP frontend styling."
---
# MCP Development Skill

Design, scaffold, and implement MCP (Model Context Protocol) servers, tool definitions, and transport configurations.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `mcp-server-template.md` | MCP server scaffold with initialization, lifecycle hooks, and tool registration |
| `tool-definition-template.md` | Tool definition with JSON Schema input, handler structure, and error handling |
| `transport-config-template.md` | Transport protocol configuration for stdio, SSE, and Streamable HTTP |

## Agent Pairing

Use with `mcp-developer` agent. For MCP servers exposing API backends pair with `backend-dev`; for deployment and CI/CD pair with `devops-engineer`.
