# Legacy Modernization — Detail Reference

Full detail supporting `agents/basecoat-10-core-legacy-modernization.agent.md`.

## Strangler Fig Example (.NET)

```csharp
// Example: strangler fig via YARP reverse proxy — the legacy Web Forms app
// stays on .NET Framework/IIS as a separate process; this app only proxies to it.
public void Configure(IApplicationBuilder app)
{
    app.UseRouting();
    app.UseEndpoints(endpoints =>
    {
        // Route to new Razor Pages
        endpoints.MapRazorPages();

        // Reverse-proxy remaining paths to the legacy Web Forms app (requires
        // Yarp.ReverseProxy and a configured cluster/route for the legacy app)
        endpoints.MapReverseProxy();
    });
}
```

## Multi-Language Migration Patterns

Apply these language-specific patterns when the modernization scope extends beyond .NET.

### Python

- **`2to3` migration**: On Python ≤3.12, run the `2to3` executable (`2to3 -w .`) or `python -m lib2to3 -w .` to auto-convert Python 2 syntax (`2to3` is not an importable module, and the tool was removed entirely in 3.13+, so pin a ≤3.12 interpreter or use the standalone `2to3` PyPI package); manually review `print`, `unicode`, and `dict.iteritems()` callsites
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

### Ruby

- **Rails upgrade path (5→6→7)**: Upgrade one major version at a time; run `rails app:update` at each step and resolve deprecations before proceeding
- **`attr_accessor` modernization**: Replace manual `def name; @name; end` patterns with `attr_reader` / `attr_writer` / `attr_accessor` declarations
- **Zeitwerk autoloader migration**: Replace `require_dependency` and `require` with Zeitwerk conventions; enable `config.autoloader = :zeitwerk` and verify with `bin/rails zeitwerk:check`
- **`Gemfile` lock strategy**: Pin to patch versions for production gems (`gem 'rails', '~> 7.0.4'`); run `bundle update --conservative` to avoid transitive churn

### Java

- **Jakarta EE migration (`javax` → `jakarta` namespace)**: A blind global find-and-replace from `import javax.` to `import jakarta.` also rewrites Java SE packages (`javax.crypto`, `javax.net`, `javax.sql`, `javax.swing`, etc.) that never moved to Jakarta and would break the build. Restrict the replacement to the specific Jakarta EE API packages in use (servlet, persistence, validation, ...), or use a package-aware tool such as the Eclipse Transformer (`org.eclipse.transformer`) instead of an unscoped text replace
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

### Node.js

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
function readConfig(path) { return JSON.parse(fs.readFileSync(path, 'utf8')); }
module.exports = { readConfig };

// After (ESM)
import { readFileSync } from 'fs';
export function readConfig(path) { return JSON.parse(readFileSync(path, 'utf8')); }
```

## Output Format Detail

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
