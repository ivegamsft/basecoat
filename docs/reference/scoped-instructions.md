# Scoped Instructions Guide

How to use `applyTo` patterns so instruction files activate in the right places, compose cleanly, and avoid wasting context.

---

## What Is Scoping?

Instruction scoping lets you target guidance to specific file types, directories, or working contexts.

The `applyTo` field uses glob patterns to decide which files an instruction applies to.

Good scoping keeps guidance precise and context-appropriate without adding noise to unrelated work.

---

## Why Scoping Matters

- Broad instructions are useful for universal rules such as safety, ethics, and response format.
- Narrow instructions are useful for language, framework, directory, or workflow-specific expectations.
- A good scope reduces false activations and helps the right guidance appear at the right time.

---

## `applyTo` Pattern Reference

| Pattern | Matches | Use Case |
|---------|---------|----------|
| `**/*` | All files | Universal guidance (style, safety) |
| `**/*.ts` | TypeScript files | Language-specific patterns |
| `src/api/**` | API directory | Service-specific rules |
| `tests/**` | Test files | Testing conventions |
| `*.{ts,js}` | TS and JS | JavaScript ecosystem |
| `!**/vendor/**` | Exclude vendor | Skip third-party code |

### Pattern Notes

- Use `**/*` sparingly and only for truly universal guidance.
- Use file-extension patterns for language rules.
- Use directory patterns for bounded contexts such as services or domains.
- Use exclusions to keep instructions away from generated or third-party code.

---

## Layering Strategy

Think about instruction scope as a stack, from broadest to most specific.

### Layer 0 — Universal

Use `applyTo: "**/*"` for rules that should always be present.

Examples:

- Safety
- Ethics
- Output format

### Layer 1 — Language

Use language-level patterns such as `applyTo: "**/*.py"` or `applyTo: "**/*.{ts,js}"`.

Examples:

- Coding standards
- Naming conventions
- Language idioms

### Layer 2 — Domain

Use directory-level patterns such as `applyTo: "src/billing/**"`.

Examples:

- Business rules
- Domain terminology
- Integration constraints

### Layer 3 — Task

Use workflow-specific patterns such as `applyTo: "tests/**"`.

Examples:

- Test-writing guidance
- Fixture conventions
- Verification expectations

---

## Composition Rules

- Multiple instructions can match the same file, and they compose additively.
- More specific patterns should win when guidance conflicts with a broader instruction.
- Keep instructions atomic so each file covers one concern cleanly.
- Name instruction files descriptively using `{concern}.instructions.md`.

A file such as `src/billing/invoice.test.ts` may legitimately activate:

- a universal instruction
- a TypeScript instruction
- a billing-domain instruction
- a testing instruction

That is a feature, not a problem, as long as each instruction has a clear concern.

---

## Anti-Patterns

- Do not use `**/*` for language-specific guidance.
- Do not create overly narrow patterns that almost never match.
- Do not duplicate the same guidance across multiple scope levels.
- Do not use `applyTo` to gate safety rules that should always be universal.

A common failure mode is putting TypeScript rules in a universal instruction file. That wastes context tokens and adds irrelevant guidance for non-TypeScript work.

---

## Testing Your Patterns

Use the validation script to confirm frontmatter is valid.

```powershell
pwsh scripts/validate-basecoat.ps1
```

Then manually test the mental model:

- If I open file X, which instructions activate?
- Is any guidance missing?
- Is any guidance firing where it should not?

Keep a mental model of the instruction stack for common file types and directories.

---

## Migration Guide

If you already have many broad instruction files, narrow them gradually.

1. Audit existing `applyTo: "**/*"` instructions.
2. Identify files that are activating guidance unnecessarily.
3. Start broad when introducing a new rule, then narrow once false activations become clear.
4. Document important scope decisions in the instruction file itself so future maintainers understand why the pattern exists.

Prefer iterative refinement over inventing highly complex patterns up front.

---

## Example Instruction Stack

```yaml
---
description: "Universal guardrails"
applyTo: "**/*"
---
```

```yaml
---
description: "TypeScript guidance"
applyTo: "**/*.ts"
---
```

```yaml
---
description: "Billing domain rules"
applyTo: "src/billing/**"
---
```

```yaml
---
description: "Test conventions"
applyTo: "tests/**"
---
```

A file should receive only the guidance that is relevant to its actual location, language, and task context.
