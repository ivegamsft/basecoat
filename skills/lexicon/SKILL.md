---
name: lexicon
description: "Use when defining or auditing a project's vocabulary, taxonomy, ontology, and brand voice so docs, agents, and prompts use consistent canonical terms. USE FOR: create project lexicon file, audit docs for terminology drift, define naming taxonomy for assets, detect off-brand tone or vibe mismatches, standardize canonical product terms. DO NOT USE FOR: copyediting grammar only, generating logos or visuals, source code refactoring unrelated to language."
---

# Lexicon Skill

Define how a project speaks — its vocabulary, taxonomy, ontology, and tone — and audit
whether existing content follows those definitions. Runs in **define mode** (establish)
or **audit mode** (detect drift). Output is written to `.lexicon.md` in the project root.

## Reference Files

| File | Contents |
|------|----------|
| [`references/define-mode.md`](references/define-mode.md) | Define mode workflow: explore, clarify, write `.lexicon.md` |
| [`references/audit-mode.md`](references/audit-mode.md) | Audit mode workflow: load, scan violations, report findings |
| [`references/agent-pairing.md`](references/agent-pairing.md) | Agent pairing guide and BaseCoat reference lexicon entries |
| [`lexicon-template.md`](lexicon-template.md) | Canonical `.lexicon.md` structure — vocabulary, taxonomy, ontology, vibe |
| [`audit-checklist.md`](audit-checklist.md) | Structured audit checklist with severity definitions and output format |
