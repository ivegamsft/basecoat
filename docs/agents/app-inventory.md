# App Inventory and Discovery Guide

This guide explains how to use the App Inventory Agent and accompanying skill to systematically
scan legacy applications, map their dependencies, and produce the structured data needed to plan
and prioritize migration work.

## Why Inventory First

Ad-hoc migration attempts fail when teams underestimate what they are migrating. A complete
inventory provides:

- Accurate scope for sprint planning and cost estimation
- Evidence-based complexity scores that drive prioritization
- A dependency map that prevents surprise integration failures mid-migration
- Audit-ready records for compliance and governance reviews

## Scope of a Scan

A full inventory pass covers six areas:

| Area | What is captured |
|------|-----------------|
| Project structure | Solution/project files, build configuration, framework targets |
| NuGet / npm / other packages | Direct and transitive dependencies, versions, license |
| Database connections | Connection strings, ORM targets, stored-procedure usage |
| External service calls | HTTP clients, service references, message-queue bindings |
| Framework version | Runtime version, target framework moniker, EOL status |
| Migration complexity score | Weighted 1–100 score across six dimensions (see below) |

## Running the Agent

Invoke the `app-inventory` agent with a repository path:

```text
@app-inventory Scan the application at /repos/customer-portal and produce a JSON report
```

Optional parameters:

```text
@app-inventory Scan /repos/customer-portal --output markdown --filters dotnet
```

| Parameter | Values | Default |
|-----------|--------|---------|
| `--output` | `json`, `yaml`, `markdown` | `json` |
| `--filters` | `dotnet`, `node`, `java`, `python`, `all` | `all` |
| `--depth` | integer | unlimited |

## Complexity Scoring

Each application receives a composite score from 1 to 100. Higher scores mean more migration effort.

| Dimension | Weight | What is measured |
|-----------|--------|-----------------|
| Code complexity | 20 % | Cyclomatic complexity, LOC density, anti-patterns |
| Dependency age | 20 % | Average package age, deprecation flags, vulnerability count |
| Architecture | 20 % | Monolith vs services, coupling, layer violations |
| Test coverage | 15 % | Unit test ratio, integration test presence |
| Documentation | 10 % | README quality, inline docs, runbook presence |
| External dependencies | 15 % | Cloud-provider lock-in, proprietary APIs, vendor SDKs |

Score bands:

| Range | Label | Recommended treatment |
|-------|-------|----------------------|
| 1–20 | Low | Quick modernize or replatform |
| 21–40 | Moderate | Planned modernization |
| 41–60 | High | Phased refactoring with strangler fig |
| 61–80 | Very high | Multi-sprint rewrite or replace |
| 81–100 | Critical | Strategic replacement or retirement |

## Dependency Discovery Patterns

### .NET projects

The agent searches for:

- `**/*.csproj` / `**/*.vbproj` / `**/*.fsproj` — SDK-style and legacy project files
- `**/packages.config` — NuGet legacy format
- `**/project.json` — pre-SDK format

Connection strings are extracted from:

- `web.config` / `app.config` `<connectionStrings>` section
- `appsettings.json` / `appsettings.*.json` `ConnectionStrings` object
- Environment variable references (`ASPNETCORE_CONNECTIONSTRINGS__*`)

### Node.js projects

- `**/package.json` — direct dependencies and scripts
- `**/package-lock.json` / `**/yarn.lock` — pinned transitive graph

### Other ecosystems

| Ecosystem | Manifests |
|-----------|-----------|
| Java / Maven | `**/pom.xml` |
| Java / Gradle | `**/build.gradle`, `**/*.gradle.kts` |
| Python | `**/requirements.txt`, `**/pyproject.toml`, `**/Pipfile` |
| Ruby | `**/Gemfile`, `**/Gemfile.lock` |
| Go | `**/go.mod`, `**/go.sum` |

## Output Formats

### JSON (default)

Consumed by downstream tooling, dashboards, and CI pipelines. See the agent definition for the
full schema. Key top-level fields:

```json
{
  "scan_timestamp": "...",
  "application": { "name": "...", "path": "..." },
  "technology_stack": { "primary_language": "...", "framework": "...", "database": "..." },
  "dependencies": { "direct_count": 0, "outdated_count": 0, "vulnerabilities": [] },
  "migration_score": { "overall": 0 },
  "portfolio_category": "...",
  "recommendations": []
}
```

### Markdown report

Human-readable summary suitable for architecture review boards and sprint planning.

### YAML

Ingested by Azure DevOps work-item generators and GitHub Actions matrix strategies.

## Integrating Inventory Data

### Sprint planning

Import the JSON output into the sprint planner agent:

```text
@sprint-planner Here is the inventory JSON for the customer-portal app. Break the
"Modernize" recommendations into two-week sprint tasks.
```

### Treatment decisions

Feed the score and portfolio category into the treatment matrix
(`docs/treatment-matrix.md`) to select the appropriate migration path.

### Dependency lifecycle

Pass the `dependencies` section to the `dependency-lifecycle` agent to generate
upgrade-path plans for outdated or vulnerable packages.

## Related Assets

| Asset | Purpose |
|-------|---------|
| `agents/basecoat-10-core-app-inventory.agent.md` | Agent definition and detailed workflow |
| `agents/basecoat-10-core-legacy-modernization.agent.md` | Executes strangler-fig migration once inventory is done |
| `agents/basecoat-10-core-dependency-lifecycle.agent.md` | Plans dependency upgrades found during inventory |
| `skills/app-inventory/SKILL.md` | Reusable templates: report, complexity scoring |
| `docs/treatment-matrix.md` | Decision framework for app disposition |
