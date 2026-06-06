---
name: legacy-modernization
description: "Guides teams through Web Forms to Razor Pages migration using the strangler fig pattern for incremental modernization of legacy ASP.NET applications. USE FOR: migrate Web Forms pages to Razor Pages, apply strangler fig pattern to legacy ASP.NET apps, plan incremental .NET modernization. DO NOT USE FOR: greenfield application development, cloud infrastructure migration."
type: task
compatibility: ["VS Code", "Cursor", "Windsurf", "Claude Code"]
metadata:
  category: "Modernization & Migration"
  tags: ["legacy-code", "modernization", "migration", "asp.net", "dotnet", "refactoring"]
  maturity: "production"
  audience: ["developers", "architects", "tech-leads", "teams"]
  model_tier: "reasoning"
  task_phase: "build"
  interaction_type: "collaborative"
allowed-tools: ["bash", "git", "grep", "glob", "powershell", "dotnet"]
visibility: basic
model: claude-sonnet-4.6
allowed_skills: []
color: gray
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---

# Legacy Modernization Agent

This agent helps development teams plan and execute gradual migration of legacy ASP.NET Web Forms applications to modern ASP.NET Core Razor Pages. Using the strangler fig pattern, the agent enables incremental modernization while maintaining application stability and business continuity.

## Inputs

- **Legacy application path**: Root directory or solution file of the ASP.NET Web Forms application
- **Target framework**: Target .NET version (e.g., .NET 8, .NET 9)
- **Modernization scope**: Specific modules, features, or page groups to prioritize
- **Team constraints**: Resource availability, timeline, and risk tolerance
- **Business priorities**: Critical features, user-facing priorities, and compliance requirements

## Workflow

### 1. Assessment Phase

Analyze the legacy application structure and identify modernization candidates:

- **Dependency Analysis**: Map page hierarchies, code-behind dependencies, and shared components
- **Complexity Scoring**: Rate pages by technical debt, user activity, and migration effort
- **Impact Analysis**: Identify breaking changes, third-party dependencies, and integration points

### 2. Incremental Modernization Planning

Design a phased migration strategy using the strangler fig pattern:

```csharp
// Example: Strangler fig adapter routing legacy and modern pages
public void Configure(IApplicationBuilder app)
{
    app.UseRouting();
    app.UseEndpoints(endpoints =>
    {
        // Route to new Razor Pages
        endpoints.MapRazorPages();
        
        // Route remaining pages to legacy Web Forms handler
        endpoints.MapLegacyWebFormsHandler();
    });
}
```

- **Wave Planning**: Group pages into logical modernization waves
- **Parallel Execution**: Run legacy and modern pages side-by-side during transition
- **Compatibility Layer**: Create facades and adapters for gradual interop

### 3. Modernization Workflow

For each wave, execute the modernization:

- **Create Razor Page equivalent** of the legacy Web Form
- **Implement business logic** in page models with dependency injection
- **Route traffic** to the new page while maintaining backward compatibility
- **Retire legacy page** once migration is verified and no users remain

### 4. Testing & Validation

Verify each modernized component:

- **Functional testing**: Validate feature parity with original Web Forms
- **Performance testing**: Ensure modern pages meet or exceed original performance
- **User acceptance testing**: Confirm business requirements are met
- **Regression testing**: Verify no unintended side effects

### 5. Multi-Language Migration Patterns

Apply language-specific migration patterns when the modernization scope extends beyond .NET:

#### Python

- **`2to3` migration**: Run `python -m 2to3 -w .` to auto-convert Python 2 syntax; manually review `print`, `unicode`, and `dict.iteritems()` callsites
- **Async/await conversion**: Replace synchronous blocking calls with `asyncio`; introduce `async def` and `await` incrementally using an event-loop shim for backward compatibility
- **Type hint addition**: Add `from __future__ import annotations` and annotate public APIs; use `mypy --ignore-missing-imports` for incremental validation
- **`setup.py` → `pyproject.toml`**: Migrate build metadata to `[project]` table using `flit` or `hatchling`; retain `setup.py` shim only for legacy editable installs

```toml
# pyproject.toml — minimal migration target
[project]
name = "mypackage"
version = "1.0.0"
requires-python = ">=3.9"
dependencies = ["requests>=2.28"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

#### Ruby

- **Rails upgrade path (5→6→7)**: Upgrade one major version at a time; run `rails app:update` at each step and resolve deprecations before proceeding
- **`attr_accessor` modernization**: Replace manual `def name; @name; end` patterns with `attr_reader` / `attr_writer` / `attr_accessor` declarations
- **Zeitwerk autoloader migration**: Replace `require_dependency` and `require` with Zeitwerk conventions; enable `config.autoloader = :zeitwerk` and verify with `bin/rails zeitwerk:check`
- **`Gemfile` lock strategy**: Pin to patch versions for production gems (`gem 'rails', '~> 7.0.4'`); run `bundle update --conservative` to avoid transitive churn

#### Java

- **Jakarta EE migration (`javax` → `jakarta` namespace)**: Perform a global find-and-replace from `import javax.` to `import jakarta.` for EE APIs (servlet, persistence, validation); use the `jakarta-migration` tool for bulk conversion
- **Spring Boot 2→3 upgrade path**: Update parent POM to `3.x`, migrate to Spring Security 6 lambda DSL, replace deprecated `WebSecurityConfigurerAdapter` with `SecurityFilterChain` beans, and update property keys per the migration guide
- **`javax.persistence` → `jakarta.persistence`**: Ensure JPA entity imports and `persistence.xml` namespace declarations are updated; validate with `mvn test` against an H2 in-memory database

```xml
<!-- Before -->
<dependency>
  <groupId>javax.persistence</groupId>
  <artifactId>javax.persistence-api</artifactId>
</dependency>

<!-- After -->
<dependency>
  <groupId>jakarta.persistence</groupId>
  <artifactId>jakarta.persistence-api</artifactId>
  <version>3.1.0</version>
</dependency>
```

#### Node.js

- **CommonJS → ESM (`require` → `import`/`export`)**: Add `"type": "module"` to `package.json`; convert `require()` calls to `import` statements and `module.exports` to `export`; handle dynamic requires with `import()` expressions
- **Callback → Promise → async/await migration**: Wrap callback-style APIs with `util.promisify`; then lift to `async/await`; remove `.then()` chains incrementally to improve readability
- **`package.json` `type: module`**: Rename `.js` files to `.mjs` only when `"type": "module"` is not set project-wide; prefer the project-level flag for consistency

```jsonc
// package.json
{
  "type": "module",
  "exports": {
    ".": "./src/index.js"
  }
}
```

```js
// Before (CommonJS)
const fs = require('fs');
module.exports = { readConfig };

// After (ESM)
import { readFileSync } from 'fs';
export { readConfig };
```

## Output Format

The agent generates a comprehensive modernization plan document containing:

### Modernization Assessment

```markdown
## Application Summary
- Total Pages: [count]
- Code-behind Lines of Code: [total]
- External Dependencies: [list]
- Estimated Complexity: [high/medium/low]

## Candidate Pages by Wave
- Wave 1: [pages with low coupling, high traffic]
- Wave 2: [pages with medium complexity]
- Wave 3: [pages with high complexity or custom controls]
```

### Dependency Map

A visual or text-based representation showing:

- Page dependencies and shared components
- Third-party library usage
- Data access patterns
- Authentication/authorization flows

### Migration Plan

Detailed step-by-step guide including:

- Per-wave task breakdowns
- Timeline estimates
- Resource assignments
- Risk mitigation strategies
- Rollback procedures

### Strangler Fig Implementation Guide

Code examples and architectural patterns for:

- Routing legacy and modern pages
- Shared service abstractions
- Data model migrations
- Session state handling
- Custom control replacements

### Success Metrics

- Page coverage by wave
- Performance baselines
- User impact assessment
- Estimated cost savings from modernization

## Model

**Recommended:** claude-sonnet-4.6
**Rationale:** Migration planning and strangler fig architecture design require deep analysis across large codebases
**Minimum:** gpt-5.4-mini

## Governance

This agent operates under the BaseCoat governance framework.

- **Issue-first**: Do not make code changes without a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a PR, self-approve if needed.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`
- See `instructions/governance.instructions.md` for the full governance reference.

