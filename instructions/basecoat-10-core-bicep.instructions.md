---
description: "Use when creating or reviewing Azure Bicep files or parameter files. Covers symbolic names, parameters, secure values, and Bicep validation best practices."
applyTo: "**/*.{bicep,bicepparam}"
---

# Bicep Standards

Use this instruction for Bicep templates and parameter files.

## Rules

- Prefer symbolic names, typed parameters, and focused modules over string-built resource references.
- Use `parent` for child resources and `existing` for lookups instead of hand-built IDs.
- Mark secrets with `@secure()` and keep them in parameter files or deployment-time inputs.
- Validate with `bicep build` and deployment preview tooling before rollout.

## Expectations

- Prefer `.bicepparam` files over ARM JSON parameters for new work.
- Use symbolic names instead of `resourceId()` and `reference()` where possible.
- Use `parent` for child resources instead of embedding `/` in resource names.
- Mark sensitive inputs with `@secure()`.
- Keep modules focused and avoid unnecessary module `name` properties.
- Prefer precise types and clear parameter descriptions where the intent is not obvious.
- Validate with `bicep build` and deployment preview tooling before rollout.

## Examples

### Example secure parameter

```bicep
@secure()
param adminPassword string

param location string = resourceGroup().location
```

### Example parent relationship

```bicep
resource stg 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: stg
  name: 'default'
}
```

## Review Lens

- Are resource types and properties current and real?
- Are secure values protected correctly?
- Is the file composed for reuse instead of one-off duplication?
- Are child resources modeled with parent references rather than string concatenation?
