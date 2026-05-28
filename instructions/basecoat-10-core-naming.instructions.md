---
description: "Use when defining repository, file, type, variable, test, infrastructure, or Azure resource names. Covers consistent naming conventions across code and platform assets."
applyTo: "**/*.{md,json,yml,yaml,ts,tsx,js,jsx,py,cs,java,go,tf,bicep,ps1,sh}"
---

# Naming Standards

Use this instruction when a change introduces new files, modules, packages, classes, functions, resources, or environments.

## General Conventions

- Repositories, folders, and reusable package names: `kebab-case`
- Markdown, YAML, JSON, shell, and script files: `kebab-case`
- Types, classes, and exported models: `PascalCase`
- Variables, functions, and parameters: `camelCase`
- Constants: follow language conventions, but keep names descriptive rather than abbreviated
- Test names: describe behavior and expected outcome, not only the method under test

## Infrastructure Conventions

- Environment markers should be explicit: `dev`, `test`, `stage`, `prod`
- Azure resource names should be deterministic, policy-compliant, and as short as practical
- Prefer a stable pattern such as `<org>-<workload>-<env>-<region>-<suffix>` where the platform allows it
- Keep tags aligned with naming so ownership and cost reporting stay consistent

## Review Lens

- Does the new name convey purpose without local tribal knowledge?
- Is the name consistent with adjacent code and infrastructure?
- Will the name age well as the component grows beyond its first use case?
