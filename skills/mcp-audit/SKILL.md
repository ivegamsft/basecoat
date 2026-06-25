---
name: mcp-audit
compatibility: [github-copilot-cli]
description: "Audits MCP server implementations, tool definitions, and schema compliance. USE FOR: reviewing MCP server code quality, validating tool definitions, assessing schema compliance, identifying integration issues, evaluating error handling. DO NOT USE FOR: implementing MCP servers from scratch, designing tool specifications, writing client applications, general code review."
---
# MCP Audit Skill

Comprehensive auditing of Model Context Protocol (MCP) server implementations, tool definitions, schema compliance, and integration quality.

## USE FOR

- Reviewing MCP server implementations for code quality
- Validating tool definitions and schema compliance
- Assessing JSON schema correctness and completeness
- Identifying integration issues and compatibility problems
- Evaluating error handling and validation logic
- Reviewing tool naming, descriptions, and documentation
- Assessing parameter validation and type safety
- Analyzing response format consistency
- Identifying security issues in tool implementation
- Creating structured audit findings with remediation guidance

## DO NOT USE FOR

- Implementing MCP servers from scratch (use `mcp-development` skill)
- Designing tool specifications
- Writing MCP client applications
- General code review (use `code-review` skill)
- Backend development unrelated to MCP

## Audit Checklist

- **Server Implementation**: Code quality, error handling, performance
- **Tool Definitions**: Naming, descriptions, parameter correctness
- **Schema Compliance**: JSON schema validity, type correctness, requirements
- **Validation**: Input validation, type checking, constraint enforcement
- **Documentation**: Tool descriptions, parameter documentation, examples
- **Error Handling**: Error messages, status codes, failure scenarios
- **Performance**: Response time, resource usage, efficiency
- **Security**: Input sanitization, injection prevention, access control
- **Integration**: API compatibility, versioning, backwards compatibility
- **Testing**: Coverage, edge cases, failure modes

## Related Skills

- `mcp-development` — MCP server development and implementation
- `backend-audit` — Backend code quality assessment
- `api-audit` — API contract and error handling audit
