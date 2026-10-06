# ADR-001: basecoat vs base-coat Naming Convention

**Date:** 2026-05-09

**Status:** Accepted

---

## Context

The project uses two visually similar names that serve different roles:

- **`basecoat`** — the GitHub repository name (`ivegamsft/basecoat`), the
  npm package identifier, release artifact names (`basecoat-ghcp.zip`), and all
  internal scripts and environment variable references (e.g., `BASECOAT_REPO`).
- **`base-coat`** — the local installation directory inside consumer repositories
  where synced assets land (`.github/base-coat/`).

Contributors and tooling authors have independently used both forms
interchangeably, causing inconsistent paths, broken sync scripts, and ambiguous
documentation.

## Decision

We will use **`basecoat`** (no hyphen) for all of the following:

- The repository slug and any URL component referencing the repo
- Release asset file names (e.g., `basecoat-ghcp.zip`)
- Environment variables (e.g., `BASECOAT_REPO`, `BASECOAT_REF`)
- Script identifiers, workflow names, and job names
- Human-readable prose referring to the project as a product

We will use **`base-coat`** (hyphen) exclusively for:

- The local directory path inside consumer repos: `.github/base-coat/`

No other usage of the hyphenated form is permitted.

## Consequences

### Positive

- A single rule covers 95 % of usages — everything is `basecoat` except the one
  sync directory path.
- Documentation, scripts, and workflow files are consistent and grep-friendly.
- New contributors have an unambiguous rule to follow.

### Negative

- Existing consumer repos that installed assets into an incorrectly named
  directory will need a one-time migration.

### Risks

- Tooling that pattern-matches on the hyphenated name may miss references to
  the product. Mitigation: add both forms to `.gitleaks.toml` allow-lists if
  needed.
