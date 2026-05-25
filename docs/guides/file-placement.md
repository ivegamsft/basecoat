# File Placement Guide

Where things go in the BaseCoat repository. When in doubt, check this guide before creating a file.

---

## Repo root — what belongs here

Only these file types live at the repo root:

| File | Purpose |
|---|---|
| `README.md` | Project overview and quick start |
| `CHANGELOG.md` | Release history (canonical — do not duplicate in docs/) |
| `CONTRIBUTING.md` | Contribution guide |
| `LICENSE` | License file |
| `version.json` | Current BaseCoat version |
| `basecoat-metadata.json` | Agent router index |
| `sync.ps1` / `sync.sh` | Consumer sync scripts |
| `mkdocs.yml` | Docs site configuration |
| `docker-compose.yml` | Local dev services |
| `.gitignore`, `.gitattributes` | Git config |
| `.markdownlint.json`, `.markdownlintignore` | Lint config |
| `.gitleaks.toml` | Secret scanning config |
| `.lexicon.md` | Canonical vocabulary (hidden config-style) |
| `.basecoat.yml.example` | Consumer config template |
| `.env.example` | Environment variable template |

**Never commit to root:**

- AI-generated summary or status `.txt` files (`*_COMPLETION_SUMMARY.txt`, `WAVE*_DAY*_*.txt`)
- Agent scratch/session files (for example `base.txt`, `blocked-issues.json`, `labels.txt`, `issue-*.json`)
- API specs (→ `docs/reference/api/`)
- Sprint output directories (→ `docs/archive/` if worth keeping)
- One-off tracking files (→ `docs/operations/`)

---

## docs/ — documentation hierarchy

```text
docs/
├── index.md              ← GH Pages landing page (do not move)
├── getting-started.md    ← First-run guide (do not move — nav entry)
├── PHILOSOPHY.md         ← Design philosophy
├── story.md              ← Experiment narrative
│
├── guides/               ← How-to guides, tutorials, recipes
│   └── (this file)
├── reference/            ← Stable reference material
│   └── api/              ← API specs and schemas
├── architecture/         ← ADRs and design decisions
│   └── decisions/        ← One file per ADR: adr-NNN-title.md
├── agents/               ← Documentation about the agent system
├── memory/               ← Memory system documentation
├── operations/           ← Runbooks, release process, ops docs
├── integrations/         ← Integration patterns (markdown only — no code)
├── research/             ← Time-boxed spikes and investigation notes
├── diagrams/             ← Excalidraw and image files
├── templates/            ← Document templates (PRD, issue, etc.)
└── archive/              ← Retired content. Do not add new content
    └── wave3/            ← Example: sprint output archived here
```

### What goes where

| Content type | Location |
|---|---|
| How-to guide or tutorial | `docs/guides/` |
| Stable reference (QUICK_REFERENCE, INVENTORY, etc.) | `docs/reference/` |
| API spec or schema | `docs/reference/api/` |
| Architecture decision record | `docs/architecture/decisions/adr-NNN-title.md` |
| Runbook, incident response, release process | `docs/operations/` |
| Integration pattern (markdown description) | `docs/integrations/` |
| Research spike or investigation note | `docs/research/` |
| Diagram or visual | `docs/diagrams/` |
| Document template (PRD, issue, etc.) | `docs/templates/` |
| Sprint output or historical artifact | `docs/archive/<sprint-or-date>/` |

**Do not put in docs/:**

- Source code files (`.py`, `.ts`, `.sql`, etc.) → `examples/` or relevant source dir
- Data files (`.json`, `.csv`) → if ephemeral, delete; if reference, `docs/reference/`
- Duplicates of root-level files (`CHANGELOG.md`, `README.md`)

---

## assets/ — the four primitives

| Asset type | Location | Naming |
|---|---|---|
| Agent | `agents/` (flat) | `kebab-case.agent.md` |
| Skill | `skills/<name>/` | `SKILL.md` + supporting files |
| Instruction | `instructions/` (flat) | `kebab-case.instructions.md` |
| Prompt | `prompts/` (flat) | `kebab-case.prompt.md` |

**Flat means flat:** agents and instructions live directly in their directory, not in subdirectories.
Reference shards for an instruction live in `instructions/references/<topic>/`, not alongside the instruction.

Meta-docs about the agent system (taxonomy, model routing) go in `docs/agents/` or `docs/reference/`, not inside `agents/`.

---

## templates/ — repo templates

Consumer repo templates (not document templates) live at `templates/` at the repo root:

```text
templates/
└── basecoat-memory/    ← Starter repo for the shared memory store
    └── .github/workflows/validate-memory.yml
```

Document templates (PRD, issue, gitignore) stay in `docs/templates/`.

---

## scripts/ and tests/

| Item | Location |
|---|---|
| Automation scripts | `scripts/` |
| Consumer sync scripts | Repo root (`sync.ps1`, `sync.sh`) — exception to the scripts/ rule |
| Test suite | `tests/` |
| CI workflows | `.github/workflows/` |

---

## What AI agents must not commit

- `*_COMPLETION_SUMMARY.txt` / `*_SUMMARY.txt`
- `WAVE*_DAY*_*.txt` / `WAVE*_DAY*_*.md`
- `*_STATUS.txt`
- Any file named `plan*.md` or `status*.md` at the repo root
- Raw sprint output directories at the repo root (e.g. `wave3-results/`)

If a completion summary is genuinely useful, archive it: `docs/archive/<date>/<name>.md`.
