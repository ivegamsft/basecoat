# Technical Specification: Dogfood Asset Discoverability Inside BaseCoat

## Context

BaseCoat is the source repository for a catalog of Copilot skills, agents,
prompts, and instructions. `sync.ps1` projects these canonical trees into the
`.github/` layout that the Copilot CLI discovers, but that projection only runs
when a **consumer** repository installs BaseCoat. BaseCoat never projects its own
canonical trees into its own working tree, so its own assets are undiscoverable
during local BaseCoat sessions.

The concrete failure: the Copilot CLI resolves `skill:` invocations and agents
from the repository-local `.github/` layout (and `$HOME/.copilot/`). BaseCoat's
canonical assets live in top-level `skills/`, `agents/`, `prompts/` — not in
`.github/` — so invoking `repo-cleanup` inside BaseCoat returns
`Skill not found`. Because an unresolved governed skill degrades to a
memory-reconstructed procedure rather than a hard stop, every governance,
security, and release control BaseCoat authors is unenforced in its own
sessions.

## Scope

- Add a **local self-install** that projects a **curated dev-governance subset**
  of the canonical `skills/`, `agents/`, and `prompts/` trees into the
  discoverable `.github/` layout (and `.agents/skills/`), reusing the existing
  `sync.ps1` projection semantics. The projection source is **always the
  repository tree only**; it never reads a contributor's personal `~/.copilot/`
  assets.
- Make the projected copies **gitignored** so canonical trees remain the single
  tracked source of truth.
- Wire the self-install into Copilot and local contributor setup; make it
  idempotent and expose a refresh command.
- Add a staleness self-check to repository validation.

## Out of Scope

- Consumer distribution via `sync.ps1` (unchanged).
- Content/frontmatter/behavior of any skill, agent, prompt, or instruction.
- Changes to the asset-manifest contract; regenerate its selected validator hash
  as needed without changing the manifest schema.
- Discoverability for non-Copilot-CLI clients beyond what reading the same
  `.github/` layout provides.
- **Consumer-facing shipped deliverables** (e.g. `azure-*`, `container-*`,
  `bom-*`, `s4-*`, `backend-dev`/`frontend-dev`/`ux`, DDD/CQRS) — excluded from
  the local projection because they do not govern BaseCoat's own development and
  would inflate the always-on session catalog. They remain fully tracked and
  distributed to consumers unchanged.
- **A contributor's personal `~/.copilot/` skills, agents, and prompts** — the
  self-install never reads, copies, or references them. Personal assets are
  never sourced, tracked, or committed by this mechanism.

## Considered Options

1. **Track the projected copies.** Commit `skills/` → `.github/skills/` etc. as
   real tracked files. Rejected: duplicates ~1,000 files, creates a permanent
   two-copy drift class, and doubles review surface for every asset change.
2. **Symlink/junction the canonical trees into `.github/`.** Rejected:
   directory symlinks are unreliable across Windows, git, and CI, and are not
   portably checked out.
3. **Gitignored local self-install wired into development setup (recommended).**
   Project the canonical trees into `.github/` (and `.agents/skills/`) as
   gitignored copies, generated idempotently by a script that reuses the shared
   `sync.ps1` projection map, invoked by contributor and Copilot setup, and
   validated by a staleness check. Keeps a single tracked source of truth, no
   tracked duplication, and automatic discoverability.

This spec implements option 3, scoped to a **curated dev-governance subset**
(see Scope and Data Model). Consumer shipped deliverables and `instructions/`
are excluded from the ambient local projection to bound always-on session
context; their discoverability/quality is instead covered by a full-catalog
eval pass (see Testing Strategy) rather than by loading them into every session.

## Architecture

### Projection source of truth

Reuse the projection performed by `sync.ps1` (`skills`/`prompts`/`instructions`
→ `.github/`, `skills` → `.agents/skills`, `agents` → `.github/agents`). Factor
the destination mapping into `scripts/dogfood-projection.ps1` so both the
consumer sync and local self-install use one file-to-destination plan.
Consumer sync retains its guidance-lock preflight and ownership-aware writes;
the local self-install applies the same mapping to its curated subset.

### Local self-install

A script (e.g. `scripts/dogfood-install.ps1`) that:

1. Resolves the BaseCoat repo root.
2. Projects the curated canonical `skills/`, `agents/`, `prompts/` entries into
   the gitignored `.github/` destinations (and `.agents/skills/`), refreshing
   only files recorded as owned by the previous install.
3. Removes projected assets whose canonical source no longer exists
   (idempotent, no stale managed files).
4. Never touches tracked `.github/` repo-meta files (see Data Model exclusions).

### Ignore rules

`.gitignore` ignores exactly the projected destinations plus the install's
ownership manifest and its temporary manifest file. The projection must not
shadow the small set of already-tracked `.github/` paths
(e.g. `.github/instructions/*.instructions.md` repo-meta, workflows). The
projected skill/agent/prompt directories are additive and disjoint from tracked
repo-meta.

### Onboarding wiring

`.github/copilot-setup-steps.yml` invokes the self-install for Copilot coding
agent sessions, and `scripts/dev-setup.ps1` provides the same install/check
entry point for local contributors.

## Data Model

**Projection source:** the repository working tree only (`skills/`, `agents/`,
`prompts/` at the repo root). The self-install resolves the repo root and reads
exclusively from it. It **never** reads `~/.copilot/` or any path outside the
repo, so personal contributor assets cannot enter the projection.

**Curated dev-governance subset:** only assets that govern BaseCoat's own SDLC
are projected. Selection is metadata-driven and auditable: skills whose
`category` is a governance/workflow/dev-meta category (`workflow`,
`flow-governance`, `governance`, `platform-governance`, `sdlc-governance`,
`agent-development`, `documentation`, `framework`), plus a named allowlist of
SDLC/authoring skills from mixed categories. Consumer shipped deliverables are
excluded; the current selection is listed in the subset audit below.

Projection map (curated canonical subset → gitignored destination):

| Canonical (subset) | Destination |
|---|---|
| `skills/<dogfood>/` | `.github/skills/` |
| `skills/<dogfood>/` | `.agents/skills/` |
| `agents/<dogfood>` | `.github/agents/` |
| `prompts/<dogfood>` | `.github/prompts/` |

Exclusions: (1) tracked repo-meta already under `.github/` (instructions routing
stubs, workflows, governance) are not generated by and not removed by the
self-install; (2) consumer shipped-deliverable assets; (3) all personal
`~/.copilot/` content. The self-install owns only the destinations above and
only for the curated subset.

**Instructions are deliberately not projected.** `instructions/*.instructions.md`
auto-load their bodies via `applyTo` globs and are the highest ambient-context
cost. BaseCoat's tracked repo-meta instructions remain the only instructions in
a local session; a specific instruction is dogfooded by loading it explicitly.

## API / Interface Contracts

- `scripts/dogfood-install.ps1` — parameterless default installs into the repo
  root; idempotent; exit 0 on success, non-zero on projection failure. Optional
  `-Check` mode reports drift without writing (used by validation), and
  `-RootDir` supports isolated test fixtures.
- `scripts/dogfood-projection.ps1` — shared deterministic file-to-destination
  plan used by consumer sync and dogfood self-install.
- `scripts/dev-setup.ps1` — contributor entry point for install and check.

## Security and Privacy

- The projection copies only repository-owned canonical assets already present
  in the tree; it introduces no external input and no new trust boundary.
- **No personal-asset leakage.** The projection source is strictly the
  repository tree. The self-install never reads, copies, tracks, or commits a
  contributor's personal `~/.copilot/` skills, agents, or prompts. Personal
  assets therefore cannot be projected into `.github/` or committed to the repo
  by this mechanism. (Note: the Copilot CLI independently merges personal and
  repository skills into one *session* discovery list at runtime — that
  pre-existing behavior is out of scope and is neither introduced nor changed
  here.)
- Projected `.github/skills` and `.github/agents` become CLI-trusted local
  config; because they are byte-copies of tracked canonical assets, trust is
  equivalent to the tracked tree. The staleness check ensures the trusted local
  copy cannot silently diverge from the reviewed canonical source.
- Path handling must resolve within the repo root and refuse to write outside
  it (consistent with repo path-containment conventions).

## Reliability and Failure Modes

- **Stale local install:** canonical trees change but the projection is not
  refreshed. Mitigation: idempotent refresh at bootstrap + `-Check` staleness
  validation reporting the exact refresh command.
- **Orphaned projected assets:** a canonical asset is deleted but its projected
  copy remains and stays discoverable. Mitigation: the self-install removes
  destination entries with no canonical source (FR4).
- **Clobbering tracked repo-meta:** mitigated by the disjoint destination set
  and explicit exclusions; the self-install never writes tracked `.github/`
  repo-meta paths.
- **Partial projection:** a failed copy leaves a partial `.github/skills`.
  Mitigation: fail non-zero and leave a detectable stale state that `-Check`
  reports.

## Performance

The projection is a bounded directory copy (hundreds of small files) run at
onboarding and on demand; cost is negligible and off the hot path.

## Implementation Plan

1. Extract `sync.ps1` file-to-destination mapping into a shared projection
   helper.
2. Add `scripts/dogfood-install.ps1` (install + `-Check`) using the shared plan
   against the repo root and an ownership manifest for generated files.
3. Add `.gitignore` rules for the four projected destinations and ownership
   manifest.
4. Wire the self-install into Copilot setup steps and `scripts/dev-setup.ps1`.
5. Add a warning-only staleness self-check to source validation.
6. Document the refresh command in contributor onboarding.

## Testing Strategy

- **Unit:** the shared projection produces the four destinations from a fixture
  canonical tree; idempotent re-run is a no-op; a removed canonical source
  removes its projected copy.
- **Discoverability (acceptance):** in a fresh bootstrapped clone, invoking
  `repo-cleanup` (and a sampled set of governed skills) resolves — 0
  `Skill not found` for BaseCoat-authored assets.
- **No tracked drift:** after self-install, `git status` reports no new tracked
  files under the projected destinations; the ignored ownership manifest lists
  only files created by the installer.
- **Staleness:** `-Check` flags an out-of-date install and returns non-zero;
  source validation reports the warning without failing clean CI checkouts.
- **Manifest integrity:** asset distribution tests confirm the regenerated
  manifest hash for `scripts/validate-basecoat.ps1` matches the tracked file.
- **Subset selection:** the selector projects the dev-governance subset and
  excludes shipped deliverables, `instructions/`, and any `~/.copilot/` path;
  assert a shipped deliverable (e.g. `azure-landing-zone`) is not projected and
  no path outside the repo root is read.
- **Full-catalog eval (non-ambient):** an eval/CI pass exercises discoverability
  and quality across the entire tracked catalog (including shipped deliverables
  not locally projected), so excluded assets still get coverage without
  polluting interactive sessions.
- Run `pwsh scripts/validate-basecoat.ps1` and `pwsh tests/run-tests.ps1`.

## Rollout, Migration, and Rollback

- **Rollout:** Copilot coding-agent setup performs the first install; local
  contributors run `pwsh scripts/dev-setup.ps1` once or rerun it to refresh.
- **Migration:** none — no tracked files change; existing clones run the
  self-install once.
- **Rollback:** delete `scripts/dogfood-install.ps1`, revert the setup-step
  wiring and `.gitignore` rules; contributors delete the gitignored projected
  directories. No tracked state or external dependency is affected.

## Observability

- The self-install and `-Check` emit a clear summary (counts projected/removed,
  stale/current) so onboarding and CI show whether the local install is
  current.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Local copy drifts from canonical | Idempotent dev-setup refresh + `-Check` staleness gate |
| Projection shadows tracked repo-meta | Disjoint destination set + explicit exclusions |
| Two projection code paths diverge | Single shared function reused by sync + self-install |
| Gitignore over-broad, hides tracked assets | Ignore only the projected destinations |
| Personal `~/.copilot/` assets leak into repo | Projection source is repo tree only; never reads `~/.copilot/` |
| Curated subset omits a genuinely dev-relevant asset | Metadata-driven, auditable selector; boundary reviewable and adjustable |

## Dogfood Subset Audit (skills)

The catalog currently contains 143 skills. The implementation projects the
eight governance/workflow/dev-meta categories (`workflow`, `flow-governance`,
`governance`, `platform-governance`, `sdlc-governance`, `agent-development`,
`documentation`, `framework`) plus a named SDLC/authoring allowlist.

- **Dev-governance (projected): 58 skills** in the current catalog.
- **Not projected: 85 skills**, including shipped deliverables such as
  `azure-*`, `container-*`, `bom-*`, data/EF/service-bus migrations, `s4-*`,
  `station-bottleneck-analyzer`, `takt-time-measurement`,
  `backend-dev`/`frontend-dev`/`ux`, DDD/CQRS/`twelve-factor`, `api-*`,
  `penetration-testing`, `observability`, and `ha-resilience`.

The implementation narrows the original 90-skill audit estimate to an explicit
58-skill selector to keep unrelated operational and consumer-facing assets out
of BaseCoat authoring sessions. Boundary calls kept in the dev subset include
`security`, `security-operations`, `refactoring`, `tech-debt`, `docs-site`, and
`ci-flake-quarantine`. Agents are limited to 20 named
development/governance agents plus referenced detail files; prompts are limited
to six authoring prompts. The selector is in
`scripts/dogfood-projection.ps1` and is covered by fixture tests.

## References

- PRD: `docs/prd/3348-dogfood-asset-discoverability.md`
- Issue #3348
- `sync.ps1` (consumer projection reused by the self-install)
- `.github/copilot-setup-steps.yml` and `scripts/dev-setup.ps1` (onboarding wiring)
