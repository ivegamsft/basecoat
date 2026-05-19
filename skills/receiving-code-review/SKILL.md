---

name: receiving-code-review
description: "Use when responding to pull request review feedback. Covers acknowledging comments, categorizing severity, addressing changes, and re-requesting review. USE FOR: address PR review comments, respond to code review feedback, categorize review items, re-request review after changes, resolve review threads. DO NOT USE FOR: performing initial code review, writing review comments on others' PRs, general PR creation."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Developer Workflow"
  tags: ["code-review", "pull-requests", "collaboration"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "gh"]

---

# Receiving Code Review — Response Protocol

This skill defines the structured workflow for responding to pull request review
feedback. It ensures review comments are acknowledged, prioritized, and addressed
systematically rather than ad-hoc.

## Workflow Phases

### Phase 1 — Acknowledge

When review feedback arrives:

1. Read every comment before responding to any.
2. Categorize each comment into one of:
   - **Must-fix** — blocking issues (bugs, security, correctness)
   - **Suggestion** — non-blocking improvements the reviewer recommends
   - **Question** — reviewer needs clarification to complete their review
   - **Nit** — style, naming, or minor preference items
3. Acknowledge receipt with a brief summary (e.g., "Reviewing 3 must-fix, 2 suggestions, 1 question").

### Phase 2 — Prioritize

Address feedback in this order:

1. **Questions first** — unblock the reviewer's understanding before making changes.
2. **Must-fix items** — these block merge; resolve before anything else.
3. **Suggestions** — address if they improve the code; explain reasoning if declining.
4. **Nits** — batch these into a single commit; never ignore without acknowledgment.

### Phase 3 — Respond

For each comment:

- **Must-fix**: Make the change, reference the commit SHA in a reply thread.
- **Suggestion (accepted)**: Make the change, reply "Done in [commit]".
- **Suggestion (declined)**: Explain reasoning clearly. Do not silently ignore.
- **Question**: Answer directly. Provide code context or links if helpful.
- **Nit**: Fix and batch. Reply "Addressed nits in [commit]" on one thread.

Rules for responses:

- Never force-push without notifying the reviewer.
- Each commit addressing review feedback should reference the comment it resolves.
- If you disagree with a must-fix, escalate to a second reviewer rather than overriding.
- Resolve your own threads only after the reviewer confirms (or for trivial nits).

### Phase 4 — Re-request Review

Only re-request review when ALL of:

- [ ] Every must-fix item is addressed (committed, not just discussed)
- [ ] All questions have answers
- [ ] Tests pass on the updated branch
- [ ] CI is green
- [ ] The PR description is updated if scope changed

## Anti-Patterns

- **Silent force-push** — Pushing changes without notifying reviewers invalidates their context.
- **Ignoring nits** — Even if you disagree, acknowledge and explain. Silence signals disrespect.
- **Addressing only some must-fix items** — Partial resolution wastes another review cycle.
- **Defensive responses** — Treat feedback as collaborative, not adversarial.
- **Re-requesting before CI passes** — Wastes reviewer time on broken builds.
- **Mega-commit responses** — One commit addressing 10 comments makes verification impossible.

## Integration with Code Review Agent

When the code-review agent identifies issues on your PR:

1. Use this skill's Phase 1 to categorize the agent's output.
2. Apply Phase 2 priority ordering.
3. Commit fixes with clear messages referencing the review comment.
4. Let CI validate before re-requesting human review.
