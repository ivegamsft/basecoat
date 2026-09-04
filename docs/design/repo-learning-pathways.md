# Design: Repo-Learning Pathways Skill (`learn:`)

## Summary

A skill that mines a target repo's own history — merged PR diffs, CI
failure/fix cycles, and resolved review threads — to build and maintain a
durable, citation-backed "pathways" artifact: symptom to root cause to
verified fix/shortcut. The goal is to stop agents from independently
rediscovering the same repo-specific gotchas across sessions, and to give
them one predictable place to check before re-diagnosing a known failure
class.

## Evidence This Gap Is Real

In a single ship-it session against this repo, two already-known
repo-specific facts were independently rediscovered from scratch:

1. `workflow_run`-triggered workflows always execute the version of the
   workflow file on the default branch (`main`), not the version on the PR
   branch that triggered them.
2. `sed -n '<range>p' file | grep -qxF -- '---'` under `set -o pipefail` can
   spuriously fail: `grep -q` exits as soon as it finds a match, closing the
   pipe early, and `sed` can receive `SIGPIPE` while still writing — this was
   rediscovered **twice**, once while fixing PR #2892 and again while
   reviewing PR #2901's own fix for the same issue.

`@memory-promoter` (`agents/basecoat-10-core-memory-promoter.agent.md`)
explicitly **excludes** repo-specific facts ("facts that are only true for
one named repository... would not generalize"), so nothing in the current
agent roster captures this class of knowledge at all today.

## Debate

### Question

Should BaseCoat gain a skill that mines a repo's own history to build and
maintain durable "pathways," and if so, how should it be implemented?

### Option 1 — New dedicated `repo-learning` skill + `pathways` artifact

A skill that periodically (or on-demand via a `learn:` prefix) scans
merged-PR diffs, CI re-run/failure logs, and resolved review threads for a
target repo, and writes/updates a structured, versioned artifact (e.g.
`docs/reference/repo-pathways.md` or a machine-readable `pathways.json`)
containing: symptom, root cause, verified fix/shortcut, and citation
(commit/PR). Other agents/skills would be instructed to consult this file
before diagnosing a class of problem (CI failure triage, workflow debugging,
merge-eligibility blocks, etc.).

- **Evidence**: mirrors the `memory-promoter` frequency x impact scoring
  model but flips the generalization filter (repo-specific facts are the
  target, not the exclusion) — reuses a proven pattern instead of inventing
  one.
- **User impact**: fastest path to "stop repeating mistakes" — an agent
  hitting a `validate-unix` failure could grep `repo-pathways.md` before
  re-diagnosing from raw CI logs, cutting multi-round investigation (as
  happened twice in one session) to a single lookup.
- **Implementation scope**: medium — new skill + `eval.yaml` + a defined
  artifact schema + wiring into at least the CI-triage-adjacent agents
  (`@rca`, `@ci-failure-escalation`, `@self-healing-ci`) to read it, plus a
  write path (either a background/scheduled agent or an explicit `learn:`
  trigger after a wave completes).
- **Accessibility impact**: none (developer-facing artifact only).
- **Risks**: staleness (a pathway can rot if code changes and the shortcut
  no longer applies) and false confidence (an agent trusts a stale pathway
  instead of re-verifying); needs a "last verified" citation/date and a
  lightweight invalidation signal (e.g., flag if the cited file/line has
  changed since). The miner's inputs (PR text, commit messages, CI logs) are
  contributor-controlled and untrusted: embedded instructions in that text
  could otherwise be promoted verbatim into an artifact other agents are
  told to trust, and CI logs can contain secrets or PII. The implementation
  contract must therefore (a) treat mined text as data, never as
  instructions to execute or follow, (b) redact secret- and PII-shaped
  content before writing anything to the pathways artifact, and (c) include
  adversarial eval scenarios (e.g., a PR description or log line that tries
  to inject a directive) in `eval.yaml` before this skill ships.

### Option 2 — Extend `@memory-promoter` with a repo-scoped mode

Add a `--scope repo` mode to the existing memory-promoter contract that
inverts its current generalization filter: instead of discarding
repo-specific facts, it captures them into a per-repo pathways file, while
the existing cross-repo path keeps flowing into `store_memory`/basecoat-memory
as today.

- **Evidence**: reuses an already-shipped, tested scoring/output contract
  rather than building parallel infrastructure.
- **User impact**: less new surface area to learn — one agent, two scopes —
  but the "USE FOR" contract becomes harder to reason about (one agent
  serving two audiences with opposite filtering rules).
- **Implementation scope**: smaller than Option 1 (edit one agent file + add
  a scope flag), but conflates two genuinely different consumers (cross-repo
  BaseCoat memory vs. single-repo operational shortcuts) inside one agent
  contract with opposite filtering rules — the same eval suite would need to
  assert both "discard repo-specific facts" and "capture repo-specific
  facts" depending on an invocation flag, which is harder to test and reason
  about than two separate assets with a single, unambiguous purpose each.
- **Accessibility impact**: none.
- **Risks**: scope creep inside a single agent's contract; harder to test in
  isolation (eval scenarios would need to assert two contradictory filtering
  behaviors from the same agent).

### Option 3 — No new asset; capture pathways as a discipline inside existing agents

Whenever an agent (e.g. `@rca`, `@ci-failure-escalation`) roots-causes a
repo-specific gotcha, it directly appends a short "known gotchas" note to the
most relevant existing instruction/agent file (e.g., a `## Known Repo
Gotchas` section in `testing-validation.instructions.md`), with no new skill
or generated artifact.

- **Evidence**: zero new infrastructure; matches how cross-cutting facts are
  already stored today via `store_memory`.
- **User impact**: weakest of the three — knowledge scatters across whichever
  instruction file the diagnosing agent happened to be looking at, with no
  single "check here first" pathway, so the same rediscovery risk remains for
  anyone who doesn't already know which file to check.
- **Implementation scope**: smallest, but shifts all the organizing/scoring/
  staleness work onto ad hoc human judgment every time, with no scoring,
  frequency tracking, or citation discipline.
- **Accessibility impact**: none.
- **Risks**: highest — no consistent location, no de-duplication, no
  staleness signal; likely converges back to the exact problem (two
  independent rediscoveries in one session) that motivated this request.

## Recommendation

**Option 1** — a dedicated `repo-learning` skill producing a citation-backed,
staleness-aware `pathways` artifact. It is the only option that gives agents
one predictable place to check before re-diagnosing, keeps the frequency x
impact scoring discipline that `memory-promoter` already validated, and
cleanly separates "cross-repo BaseCoat memory" (Option 2's agent) from "this
repo's own operational shortcuts" (a different consumer with an inverted
filter) rather than conflating them in one contract. Ship it as an opt-in
`learn:` prefix (consistent with existing prefix conventions) rather than a
background daemon, so pathway capture stays reviewable before it's trusted.

**Follow-up validation plan**: pilot on this repo using the two gotchas
rediscovered this session as the seed pathways; measure on the next 2-3
CI-failure-triage sessions whether the responsible agent consults the
pathways file before re-deriving root cause from raw logs, and require a
"last verified" citation refresh whenever the cited file/line changes.

## Approval Boundary

Discovery and debate are complete. No files have been changed for this item
beyond this doc and its tracking issue, **#2906**
(https://github.com/ivegamsft/basecoat/issues/2906) — implementation
(the `repo-learning` skill, its `eval.yaml`, the `pathways` artifact schema,
the untrusted-input handling and redaction contract, and wiring into any
existing agent) awaits explicit approval.
