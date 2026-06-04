<!-- markdownlint-disable MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->

# BaseCoat Agent SDK

## Overview

The BaseCoat Agent SDK is a TypeScript/Node.js package that provides developers with tooling to build, validate, and test custom agentic workflows following BaseCoat patterns.

## Phase 1 Foundation

This is the Phase 1 implementation of the Consumer Agent SDK, providing core scaffolding, validation, and compilation utilities.

### Features

- **Agent Scaffolding** (`init` command) - Generate new agent templates
- **Schema Validation** (`validate` command) - Lint agents against BaseCoat schema
- **Compilation** (`compile` command) - Compile agents from source to lock files
- **Test Harness** (`test` command) - Run behavioral eval tests

## Installation

```bash
npm install @basecoat/agent-sdk
```

## Quick Start

### 1. Initialize a New Agent

```bash
npx basecoat-agent init my-agent --description "My custom agent" --author "Your Name"
```

Creates:
- `my-agent.agent.md` - Agent source file with YAML frontmatter
- `__tests__/my-agent.test.ts` - Test template

### 2. Validate Agent Structure

```bash
npx basecoat-agent validate my-agent.agent.md
```

Checks:
- Required frontmatter fields (name, description)
- Valid field formats (name must be kebab-case)
- Content body presence

### 3. Compile to Lock File

```bash
npx basecoat-agent compile my-agent.agent.md --output my-agent.lock.yml
```

Generates a `.lock.yml` compilation checkpoint (Phase 2 will add full GitHub Actions workflow generation).

### 4. Run Tests

```bash
npx basecoat-agent test __tests__
```

Executes test cases from JSON test files in the directory.

## Agent Structure

Agents are markdown files with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Automatic code review agent
author: Your Name
version: 0.1.0
triggers:
  - pull_request
instructions:
  - keep-it-simple
skills: []
mcp:
  - github-mcp-server
---

## Overview

Your agent implementation goes here.

## Behavior

- Responds to pull request events
- Uses GitHub MCP server tools
- Follows BaseCoat patterns
```

### Frontmatter Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Agent name (kebab-case) |
| description | string | Yes | Agent description (10+ chars) |
| author | string | No | Agent author |
| version | string | No | Semantic version |
| triggers | array | No | GitHub events (e.g., "pull_request", "issues") |
| instructions | array | No | BaseCoat instruction references |
| skills | array | No | BaseCoat skill references |
| mcp | array | No | MCP server names to bind |

## API Reference

### Core Functions

#### `initializeAgent(name, outputDir, options)`

Scaffold a new agent.

**Parameters:**
- `name` (string): Agent name in kebab-case
- `outputDir` (string): Output directory
- `options` (object, optional):
  - `description` (string): Agent description
  - `author` (string): Agent author

**Returns:** `{ success: boolean, message: string, agentPath?: string }`

#### `validateAgent(content)`

Validate agent content string.

**Parameters:**
- `content` (string): Agent markdown content

**Returns:** `ValidationResult` with errors and warnings

#### `compileAgent(options)`

Compile agent to lock file.

**Parameters:**
- `options.input` (string): Input agent file path
- `options.output` (string, optional): Output lock file path
- `options.validate` (boolean, default true): Validate before compiling
- `options.strict` (boolean, optional): Fail on warnings

**Returns:** `CompileResult`

#### `runTestHarness(testDir)`

Execute tests from directory.

**Parameters:**
- `testDir` (string): Test directory path

**Returns:** `TestResult` with pass/fail counts

## Test Cases

Create JSON test files (`.test.json`) with this structure:

```json
[
  {
    "name": "Agent responds to PR events",
    "description": "Test pull request trigger",
    "inputs": {
      "event": "pull_request",
      "action": "opened"
    },
    "expectedOutputs": {
      "triggered": true
    }
  }
]
```

## CLI Options

### Global Options

- `--verbose, -v` - Verbose output
- `--quiet, -q` - Suppress non-error output
- `--help, -h` - Show help
- `--version` - Show version

### Command Options

**init**
- `--description, -d` - Agent description
- `--author, -a` - Agent author

**validate**
- `--strict, -s` - Fail on warnings

**compile**
- `--validate` - Validate before compiling (default: true)
- `--strict` - Fail on warnings

**test**
- None currently

## Schema Validation

The SDK validates agents against a JSON Schema defined in `schema/agent-schema.json`. The schema enforces:

- Name format: lowercase, numbers, hyphens only
- Description length: minimum 10 characters
- Valid GitHub event triggers
- Required fields: name, description

## Exit Codes

- `0` - Success
- `1` - Validation/compilation failure or test failure

## Examples

### Scaffold and Validate

```bash
npx basecoat-agent init my-triage-agent --description "Issue triage automation"
npx basecoat-agent validate my-triage-agent.agent.md
```

### Batch Compile

```bash
npx basecoat-agent compile .
```

Compiles all `.agent.md` files in current directory.

### Strict Validation

```bash
npx basecoat-agent validate --strict
```

Fails on warnings, not just errors.

## Next Steps (Phase 2)

- Full `gh aw compile` integration for GitHub Actions workflows
- MCP server auto-discovery and registry management
- Behavioral eval harness with reference test cases
- Workflow signature/checksum verification

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT

<!-- markdownlint-enable MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->
