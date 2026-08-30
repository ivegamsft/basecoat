# App Inventory Agent — Detail Reference

Full checklists, manifests, and output examples for `agents/basecoat-10-core-app-inventory.agent.md`.

## 1. Dependency Discovery

The agent scans for dependency manifests across multiple package managers:

```yaml
manifests:
  dotnet:
    - "**/*.csproj"
    - "**/*.fsproj"
    - "**/packages.config"
    - "**/project.json"
  npm:
    - "**/package.json"
    - "**/package-lock.json"
    - "**/yarn.lock"
  maven:
    - "**/pom.xml"
  python:
    - "**/requirements.txt"
    - "**/setup.py"
    - "**/pyproject.toml"
    - "**/Pipfile"
  ruby:
    - "**/Gemfile"
    - "**/Gemfile.lock"
  go:
    - "**/go.mod"
    - "**/go.sum"
```

## 2. Technology Stack Identification

Parse configuration files to identify:

- **Frameworks**: Spring Boot, ASP.NET Core, Express.js, Django, Rails
- **Libraries**: Logging (log4j, NLog, Serilog), ORM (Entity Framework, Hibernate, Sequelize)
- **Databases**: SQL Server, PostgreSQL, MongoDB, Oracle, MySQL
- **Build tools**: Maven, Gradle, MSBuild, npm, Webpack, Gulp
- **Container platforms**: Docker, Kubernetes, cloud services

## 3. Dependency Mapping

Build a dependency graph to identify:

```json
{
  "direct_dependencies": 42,
  "transitive_dependencies": 156,
  "outdated_packages": 8,
  "security_vulnerabilities": 3,
  "license_risks": 2
}
```

- Direct vs transitive dependencies
- Version constraints and range specifications
- Outdated package versions
- Known security vulnerabilities
- License compatibility issues
- Circular dependencies

## 4. Migration Complexity Scoring

Assess migration readiness based on:

- **Code complexity**: Cyclomatic complexity, code density, patterns used
- **Dependency age**: Average package age, deprecation status
- **Architecture**: Monolithic vs microservices, coupling analysis
- **Test coverage**: Unit test ratios, integration test presence
- **Documentation**: README quality, inline documentation
- **Build times**: Current build performance metrics
- **External dependencies**: Cloud provider lock-in, proprietary integrations

Complexity scores range from 1-100:

```text
1-20:   Low complexity (quick modernization)
21-40:  Moderate complexity (planned migration)
41-60:  High complexity (significant refactoring required)
61-80:  Very high complexity (phased approach needed)
81-100: Critical complexity (major rewrite or replacement)
```

## 5. Portfolio Categorization

Classify applications into strategic categories:

```text
Keep & Invest:    Modern architecture, active maintenance, strategic value
Keep & Maintain:  Stable, working applications, minimal changes
Modernize:        Legacy but valuable, benefits from technology update
Consolidate:      Duplicate functionality, candidate for consolidation
Retire:           Obsolete, low usage, can be replaced
```

## 6. Architecture Diagram Generation

Create visual representations of application architecture:

```text
- Component diagrams (services, modules, layers)
- Dependency diagrams (external integrations, APIs)
- Data flow diagrams (input/output, database connections)
- Technology stack visualizations
```

## Output Examples

### JSON Output

```json
{
  "scan_timestamp": "2024-01-15T10:30:00Z",
  "application": {
    "name": "CustomerPortal",
    "path": "/apps/customer-portal",
    "last_modified": "2024-01-10"
  },
  "technology_stack": {
    "primary_language": "C#",
    "framework": "ASP.NET Core 6",
    "database": "SQL Server 2019",
    "containers": "Docker",
    "deployment": "Kubernetes"
  },
  "dependencies": {
    "package_managers": ["NuGet", "npm"],
    "direct_count": 45,
    "transitive_count": 187,
    "outdated_count": 8,
    "vulnerabilities": [
      {
        "package": "log4j",
        "version": "2.14.0",
        "severity": "CRITICAL",
        "cve": "CVE-2021-44228"
      }
    ]
  },
  "architecture": {
    "style": "Monolithic",
    "layers": ["Presentation", "Business Logic", "Data Access"],
    "external_integrations": [
      "Payment Gateway",
      "Email Service",
      "Analytics"
    ]
  },
  "migration_score": {
    "overall": 62,
    "code_complexity": 55,
    "dependency_age": 70,
    "architecture": 65,
    "test_coverage": 45,
    "documentation": 58
  },
  "recommendations": [
    "Update critical NuGet packages",
    "Add unit tests for business logic",
    "Refactor monolithic service layer",
    "Consider .NET 8 upgrade path"
  ],
  "portfolio_category": "Modernize"
}
```

### YAML Output

```yaml
scan_timestamp: 2024-01-15T10:30:00Z
application:
  name: CustomerPortal
  path: /apps/customer-portal
  last_modified: 2024-01-10
technology_stack:
  primary_language: C#
  framework: ASP.NET Core 6
  database: SQL Server 2019
  containers: Docker
  deployment: Kubernetes
dependencies:
  package_managers:
    - NuGet
    - npm
  direct_count: 45
  transitive_count: 187
  outdated_count: 8
  vulnerabilities:
    - package: log4j
      version: 2.14.0
      severity: CRITICAL
      cve: CVE-2021-44228
migration_score:
  overall: 62
  code_complexity: 55
  dependency_age: 70
  architecture: 65
  test_coverage: 45
  documentation: 58
portfolio_category: Modernize
```

### Markdown Report Example

```markdown
# App Inventory Report: CustomerPortal

## Overview

- **Scan Date**: 2024-01-15 10:30 UTC
- **Application**: CustomerPortal
- **Last Modified**: 2024-01-10

## Technology Stack

- **Primary Language**: C#
- **Framework**: ASP.NET Core 6
- **Database**: SQL Server 2019
- **Containers**: Docker
- **Deployment**: Kubernetes

## Dependency Summary

- **Package Managers**: NuGet, npm
- **Direct Dependencies**: 45
- **Transitive Dependencies**: 187
- **Outdated Packages**: 8
- **Security Vulnerabilities**: 1 CRITICAL

## Migration Complexity Score: 62/100

- Code Complexity: 55/100
- Dependency Age: 70/100
- Architecture: 65/100
- Test Coverage: 45/100
- Documentation: 58/100

## Portfolio Category

Modernize

## Key Recommendations

1. Update critical NuGet packages
2. Add unit tests for business logic
3. Refactor monolithic service layer
4. Consider .NET 8 upgrade path
```

### Supported Output Formats

The agent produces standardized reports in multiple formats suitable for different stakeholders:

- **Technical Teams**: Detailed JSON with all dependency and architecture information
- **Architecture Review Boards**: YAML summaries with scoring and recommendations
- **Portfolio Managers**: Markdown reports with executive summaries and categorization

All outputs include timestamps, versioning information, and traceable scanning results for audit and compliance purposes.
