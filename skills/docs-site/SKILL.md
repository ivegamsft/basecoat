---
name: docs-site
compatibility: [github-copilot-cli]
description: "Scaffold a MkDocs Material documentation site with GitHub Pages deployment, navigation, and starter content for a repository. USE FOR: create a docs site for this repo, set up MkDocs Material, publish documentation to GitHub Pages, generate getting-started docs with diagrams, add docs CI workflow. DO NOT USE FOR: writing a single inline code comment, building an app frontend, creating product marketing landing pages."
category: infrastructure
metadata:
  category: infrastructure
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Docs Site

Scaffold a MkDocs Material documentation site for any GitHub repository. Generates
`mkdocs.yml`, a landing page, a getting-started guide, a CI deploy workflow, and
optional Mermaid architecture diagrams — all ready to publish to GitHub Pages.

## Reference Files

| File | Contents |
|------|----------|
| [`references/inputs.md`](references/inputs.md) | Input parameters: site name, URL, nav style, colors, assets |
| [`references/workflow.md`](references/workflow.md) | mkdocs.yml template, index.md, getting-started.md, CI workflow, asset catalog |
| [`references/examples.md`](references/examples.md) | Python library and BaseCoat-style examples; anti-patterns |

## Output Summary

Generates: `mkdocs.yml`, `docs/index.md`, `docs/getting-started.md`,
`.github/workflows/docs.yml`, and optional `docs/reference/asset-catalog.md`.
