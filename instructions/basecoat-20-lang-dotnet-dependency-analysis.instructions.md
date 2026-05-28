---
description: ".NET dependency compatibility and remediation analysis guidance."
applyTo: "**/*.{sln,csproj,props,targets,json}"
---

# .NET Dependency Analysis

## Objective

Analyze direct and transitive dependencies for compatibility with the target .NET runtime and produce a remediation strategy.

## Rules

- Inventory both direct and transitive packages before recommending changes.
- Separate runtime compatibility issues from security, supportability, and ownership risks.
- Check shared dependency definitions in `Directory.Build.props` or central package management files before changing individual projects.
- Recommend upgrade order from shared libraries and foundational packages outward to apps and tests.

## Required steps

1. Generate dependency inventory across all projects.
2. Classify each dependency as compatible, upgradeable, replace-required, or blocked.
3. Flag security and supportability risks for outdated components.
4. Propose replacement/upgrade sequence that minimizes cross-project breakage.

## Examples

### Example compatibility matrix

```text
Package                          Current   Target   Status            Note
Microsoft.Extensions.Logging     6.0.0     8.0.1    upgradeable       Upgrade shared library first
Legacy.Data.Client               3.2.4     n/a      replace-required   No net8 support published
xunit                            2.4.1     2.7.0    compatible         Upgrade with test SDK
```

### Example project change

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.Data.SqlClient" Version="5.1.0" />
  <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
</ItemGroup>
```

Use the matrix to explain whether each change is safe now, must wait for a shared package update, or requires replacement.

## Output expectations

- Dependency compatibility matrix
- Ordered remediation backlog with risk and owner fields
- Explicit blockers requiring architectural decisions
