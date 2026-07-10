# Context-Rot Detection and Mitigation Runbook

## What Is Context Rot

Context rot occurs when an active session accumulates stale, contradictory, or redundant
history that degrades the quality of new responses and drives up token cost without adding
value. Unlike a session that is simply long, a context-rot session actively misleads the
agent: prior tool results, superseded decisions, or restated setup turns crowd out the
working context needed for the current task.

Context rot is distinct from high event count alone. A session with 400 events on a
focused, well-compacted task can be healthy. A session with 200 events that is cycling
through the same setup loop is already rot-impacted.

## How Context Rot Differs From Normal Context Growth

| Condition | Normal growth | Context rot |
|---|---|---|
| History | Grows but stays relevant | Grows with stale or repeated material |
| Agent behavior | Stays consistent | Contradictions or restatements increase |
| Tool calls | New work each turn | Repeat same calls with no artifact progress |
| Setup-to-action ratio | Stable or declining as task matures | Rising as session continues |
| Token ratio | Near or below 250x | Entering or exceeding warning zone (>= 300x) |

---

## Detection Signals

### Primary heuristics

Check for any two or more of the following in the same session. A single primary signal
warrants a triage pass; two or more confirm rot risk.

| Signal | Measurable threshold | Example |
|---|---|---|
| Repeated restatement | >= 3 consecutive turns where the agent recaps prior context before acting | "As I mentioned earlier..." repeated verbatim in turns 18, 19, and 20 |
| Contradictory outputs | Agent produces output that directly conflicts with a decision from the last 10 turns, without an explicit acknowledged pivot | Recommends option A in turn 12, then option B in turn 15 with no stated reason for the change |
| Rising setup-to-action ratio | > 30% of the last 10 turns are recap or orientation rather than producing artifacts | 4 of 10 turns re-explain the task before editing a file |
| Tool-call churn | >= 5 identical tool calls (same tool, same input) within a 10-turn window with no artifact change between calls | `view` on the same file called 6 times; no edit follows any call |
| Expanding preamble | Agent preamble grows by >= 50 tokens per turn for 5 or more consecutive turns | Response header grows from 200 to 600 tokens across 5 turns |
| Stale reference persistence | Agent references a closed PR, merged branch, or resolved issue as if still active | References PR #400 as "open" when it was merged 20 turns ago |

### Supporting signals

These alone do not confirm rot, but raise suspicion when any primary signal is also present:

- Events >= 400 in a single session without a `/compact` call.
- Token ratio >= 300x and still climbing turn-over-turn.
- Multiple re-plan cycles within the same session on the same issue.
- User messages contain full instruction dumps (> 10 KB per message), inflating every
  subsequent context re-send.

### Auto-detection via `/token-status`

Run `/token-status` at each phase boundary. Map the output to the following action table.

| Status | Condition | Action |
|---|---|---|
| Healthy | Ratio < 250x AND events < 300 | Continue; compact at next phase boundary |
| Warning | Ratio >= 300x OR events >= 400 | Run `/compact`; re-check afterward |
| Rot risk | Two or more primary heuristics active | Run triage checklist (Section 3) |
| Rot confirmed | Three or more primary heuristics active OR contradictory output detected | Execute mitigation ladder starting at Step 2 or Step 3 |
| Hard stop | Events >= 594 OR tokens >= 50M | Hard-fork immediately (Step 4 of mitigation ladder) |

---

## Triage Checklist

Use this checklist when Warning status is reached or any primary detection signal fires.

1. Run `/token-status` and record: events, token ratio, and elapsed time.
2. Scan the last 10 turns for each primary heuristic. Tally which ones are active.
3. Check output quality: is the agent's last substantive output consistent with prior
   decisions and artifacts?
4. Identify the last clean checkpoint: find the most recent turn where the agent
   produced a correct, non-contradictory artifact. Note the turn number and artifact path.
5. Classify severity using the table below.

| Active primary signals | Contradictory output present | Severity | Starting mitigation step |
|---|---|---|---|
| 0 | No | Warning only | Step 2 (compact) at next phase boundary |
| 1 | No | Low rot risk | Step 1 (delta prompt); if unresolved, Step 2 |
| 2 or more | No | Rot risk | Step 2 (compact) or Step 3 (soft-fork) |
| Any | Yes | Rot confirmed | Step 3 (soft-fork) minimum |
| Any, events >= 500 | Yes | Critical | Step 4 (hard-fork) immediately |

---

## Mitigation Ladder

Apply steps in order. Stop when output quality and token efficiency are restored.

### Step 1 — Delta prompt

**When to use**: 0–1 primary signals; rising preamble or mild restatement; session is
still early (< 200 events).

**Procedure**:

1. Send a compact delta message that re-anchors the agent to the current objective.
2. Do not repeat full instructions; reference files by path only.
3. Explicitly state what the previous turn accomplished and what the single next action is.

Example:

```text
Done: updated docs/operations/foo.md (commit abc1234). Next: update the operator
checklist in .github/instructions/cost-optimization.instructions.md at the
"Warning thresholds" section. Load: .github/instructions/cost-optimization.instructions.md.
Do not recap prior turns.
```

**Success criteria**: Agent responds without restating prior context; next output is a
direct artifact, not a restatement.

**If not resolved in two turns**: escalate to Step 2.

---

### Step 2 — Compact

**When to use**: Warning status; 1–2 primary signals; session has crossed a phase boundary
without compaction.

**Procedure**:

1. Before compacting, write down the canonical references for the current phase:
   - Issue URL and active branch.
   - Last artifact produced (path and one-line description).
   - "Done / next / blocked" note (three bullets maximum).
2. Run `/compact`.
3. After compact, reload only the references needed for the current phase. Do not
   reload full history.

See: `docs/guides/kept-patterns/phase-boundary-compaction.md`

**Success criteria**: Event count resets; `/token-status` shows ratio below 250x after
compact; the first three post-compact turns produce artifacts without restatement.

**If rot recurs within 50 events post-compact**: escalate to Step 3.

---

### Step 3 — Soft-fork (skill-scoped subtask)

**When to use**: Rot confirmed (2+ primary signals); the objective is still valid but the
session history is contaminated; the remaining work is scoped to one skill or subtask.

**Procedure**:

1. Write a clean handoff artifact containing:
   - Issue URL and current branch name.
   - Last known-good artifact path and commit SHA.
   - Next action in one sentence.
   - Validation command or success criterion.
2. Open a new session or worktree scoped to the remaining subtask.
3. Load only the handoff artifact and the one or two files needed for the subtask.
4. Keep (do not delete) the contaminated session until the new session produces its
   first successful artifact, so recovery is possible.
5. Close the contaminated session after verification.

See: `docs/operations/session-per-task.md` for handoff artifact requirements.

**Success criteria**: New session produces a correct artifact in the first two turns;
no restatement of history from the old session.

**If output quality is still degraded after two turns in the new session**: escalate to
Step 4.

---

### Step 4 — Hard-fork (new session, new branch)

**When to use**: Rot confirmed with contradictory outputs; events >= 500; tokens >= 50M;
soft-fork did not restore quality; or the contaminated session produced incorrect commits
that require reverting.

**Procedure**:

1. Run `git log --oneline -10` to identify the last clean commit SHA.
2. If the contaminated session committed incorrect artifacts, create a revert commit
   targeting the last known-good SHA:

   ```bash
   git revert <bad-commit-sha>..<HEAD> --no-edit
   ```

3. Write a complete handoff artifact (same fields as Step 3).
4. Start a new session from the clean commit or from `main` if the branch state is in
   doubt.
5. Load only: issue link, clean commit SHA, and the single file to produce next.
6. Do not export or paste the contaminated session's transcript into the new session.

**Success criteria**: New session reaches the same objective with <= 150 events and a
token ratio below 300x.

---

## Escalation Criteria

| Condition | Required action |
|---|---|
| Hard-stop threshold reached (events >= 594 OR tokens >= 50M) | Hard-fork immediately; do not attempt compact or soft-fork first |
| Contradictory outputs already committed to the branch | Revert to last-known-good SHA; hard-fork |
| Session spent > 20 turns on the same subtask with zero artifact change | Stop, run triage checklist, start at Step 2 |
| Rot recurs in the soft-fork session within 50 events | Hard-fork with minimal context |
| Same rot pattern repeats across >= 3 sessions in the same sprint | Log in `.github/backlog-session-metrics.json`; escalate to fleet hygiene review |

---

## Post-Mitigation Verification

After applying any mitigation step, confirm the following before resuming normal work:

- `/token-status` ratio is below 250x (ideally below 200x after compact or fork).
- Next three turns produce artifacts without restating prior context.
- No stale references (closed PRs, merged branches, resolved decisions) appear in the
  new session.
- If commits were reverted, run the relevant validation command (`pwsh tests/run-tests.ps1`
  or the task-specific check) to confirm clean state.

---

## Integration With the Operator Checklist

The following additions apply to the standard phase-boundary review defined in
`.github/instructions/cost-optimization.instructions.md`:

- After each `/compact`: scan the first three post-compact turns for restatement signals.
  If any appear, run the triage checklist immediately.
- At events >= 300: run the triage checklist regardless of whether an explicit signal has
  fired. Confirm at least one primary heuristic is absent before continuing.
- At end of each task: record rot occurrence (yes/no), highest-active-signal count, and
  mitigation step used in the session metrics log.

---

## Quick-Reference Card

```text
Context-Rot Quick Check
═══════════════════════
1. Run /token-status
   - Ratio >= 300x OR events >= 400 → Compact (Step 2)
   - Events >= 594 OR tokens >= 50M → Hard-fork (Step 4)

2. Scan last 10 turns:
   - Restatement (>= 3 consecutive)?
   - Contradiction in last 10 turns?
   - Setup-to-action ratio > 30%?
   - Same tool called >= 5 times, no edit?
   - Preamble growing +50 tokens/turn?

3. Tally active primary signals:
   0    → Warning; compact at next boundary
   1    → Delta prompt (Step 1); escalate to compact if unresolved
   2+   → Compact (Step 2) or soft-fork (Step 3)
   Any + contradiction → Soft-fork (Step 3) minimum
   Any + events >= 500 + contradiction → Hard-fork (Step 4)
```

---

## Related

- `.github/instructions/cost-optimization.instructions.md` — threshold definitions and
  operator checklist
- `docs/guides/kept-patterns/phase-boundary-compaction.md` — compact procedure
- `docs/operations/session-per-task.md` — session lifecycle and cross-session handoff
  artifacts
- `docs/guides/token-optimization.md` — token budget management and event/ratio tracking
- Issue: [#2010](https://github.com/IBuySpy-Shared/basecoat/issues/2010)
