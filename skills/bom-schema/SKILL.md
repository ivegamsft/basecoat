---
name: bom-schema
description: "Use when defining or validating BOM schemas, resource ID formats, required cells, or naming conventions. USE FOR: JSON schema for BOM validation, required-field checks, and template creation. DO NOT USE FOR: unrelated app schemas or general data-model design."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# BOM Schema Skill

Define and validate bill-of-materials schemas with stable field names and predictable resource identifiers.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `bom-schema-template.json` | JSON Schema starter for BOM validation rules, required fields, and naming constraints |

## Core Rules

- Validate required fields before downstream processing.
- Keep resource identifiers in a single documented format.
- Enforce naming conventions consistently across every row or item.
- Prefer explicit schema rules over free-form notes.

## Agent Pairing

Use with agents that ingest BOMs, validate structured inventory data, or generate machine-readable contract files.
