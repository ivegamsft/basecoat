# Sub-Agent Prompt Validation Checklist

Use this checklist to validate that sub-agent prompts are **clear, complete, and ready for dispatch**. Each prompt should be self-contained and leave no ambiguity about what success looks like.

---

## Validation Checklist

### CLARITY: Is the prompt unambiguous?

- [ ] **Primary goal is stated in the first sentence.** 
  - ✓ Good: "Implement JWT token refresh logic in the auth module so tokens auto-refresh without manual server restart."
  - ✗ Bad: "Do the auth thing."

- [ ] **No jargon without definition.** 
  - ✓ Good: "Add CSRF validation using the standard SameSite=Strict cookie flag per OWASP guidelines."
  - ✗ Bad: "Make it CSRF-safe."

- [ ] **Negative constraints are explicit.** 
  - ✓ Good: "Do not add external dependencies; use only stdlib or already-vendored packages."
  - ✗ Bad: "Keep it simple."

- [ ] **Scope boundaries are clear** (what IS in scope, what IS NOT).
  - ✓ Good: "Add login UI (forms only); do not implement password reset in this task."
  - ✗ Bad: "Do the auth UI."

### COMPLETENESS: Is all needed context included?

- [ ] **Input artifacts are specified.** 
  - ✓ Good: "Start from the branch `feature/auth-refactor`. The service lives in `src/services/auth.ts`."
  - ✗ Bad: "Modify the auth service."

- [ ] **Expected output is named** (file, test, artifact).
  - ✓ Good: "Output: updated `src/services/auth.ts` and new test file `src/services/auth.test.ts` with 90%+ coverage."
  - ✗ Bad: "Make it work."

- [ ] **Success criteria are measurable and specific.** 
  - ✓ Good: "All tests pass. No console errors or warnings. Tokens refresh within 1 second of expiry."
  - ✗ Bad: "Make sure it works."

- [ ] **Any required context is embedded** (design doc, spec, prior decision).
  - ✓ Good: "Token expiry should be 15 minutes (see ADR-005 for rationale). Use RSA-256 for signing."
  - ✗ Bad: "Use the right token strategy."

- [ ] **Constraints on code style or patterns** (if relevant).
  - ✓ Good: "Follow the async/await pattern used in other services; no callback style. Use TypeScript for type safety."
  - ✗ Bad: "Write good code."

### INDEPENDENCE: Can this sub-task run standalone?

- [ ] **Prompt is self-contained.** The agent does not need to:
  - Ask "What should I do next?"
  - Wait for another task's output
  - Guess at design decisions

- [ ] **If the sub-task depends on another task's output, that dependency is explicit.**
  - ✓ Good: "This task depends on 'Implement OAuth provider integration' (sub-task 1). Assume the provider client is already available at `services.oauth.provider`."
  - ✗ Bad: "Write the login UI." [without mentioning the auth service must exist first]

- [ ] **Agent has all context needed to validate their own success** (e.g., test files, design docs, acceptance criteria).
  - ✓ Good: Include links to spec, test patterns, related modules.
  - ✗ Bad: Expect the agent to search or guess.

### FEASIBILITY: Can one agent realistically complete this in scope?

- [ ] **Estimated time is reasonable** (5–30 minutes for most tasks; up to 1 hour for complex deep work).
  - ✓ Good: "Expected time: 20–30 minutes. Involves modifying one service and writing 3–4 test cases."
  - ✗ Bad: "Redesign the entire backend architecture." [Way too big for one sub-task.]

- [ ] **The task is not a hidden multi-step workflow.** 
  - ✓ Good: "Add unit tests for the new refactored function." [Clear, single task.]
  - ✗ Bad: "Improve the code quality." [Implies multiple steps: profile, refactor, test, review, etc.]

- [ ] **Required tools or access are available to the agent.**
  - ✓ Good: "You have access to the repo, linter config, and test runner."
  - ✗ Bad: [If the agent needs special access or permissions, note it.]

### TESTABILITY: How will success be verified?

- [ ] **Success criteria include a test or validation step.**
  - ✓ Good: "Run `npm test` and confirm 90%+ coverage. No lint errors."
  - ✗ Bad: "Make sure the code is good."

- [ ] **Acceptance criteria are easily checkable by a human or CI/CD.**
  - ✓ Good: "All 5 test cases pass; TypeScript compilation succeeds; no breaking changes to public API."
  - ✗ Bad: "Looks good."

- [ ] **If the agent must commit or PR, the commit message format is specified.**
  - ✓ Good: "Commit message format: `feat(auth): implement JWT refresh logic`. Include `Closes #123`."
  - ✗ Bad: [Assume default.]

---

## Red Flags (Stop and Clarify)

If any of these apply, **do not dispatch the prompt**. Go back and refine:

- ❌ **Prompt is longer than 1 page (~500 words).**  
  ➜ Break into smaller sub-tasks or move context to a separate doc with a clear link.

- ❌ **Multiple conditional branches** ("if X, do Y; if Z, do W").  
  ➜ Either clarify which branch applies, or split into separate sub-tasks.

- ❌ **Vague success criteria** like "make it better", "improve performance", "do the right thing".  
  ➜ Define specific, measurable targets (e.g., "reduce response time by 30%", "all tests pass").

- ❌ **Success depends on a human review or decision.**  
  ➜ Either ask the human first (deferred to research), or structure as code review task with clear criteria.

- ❌ **No mention of what NOT to do.**  
  ➜ Add constraints. Agents often over-solve; narrowing scope prevents wasted effort.

- ❌ **Dependencies are unclear** ("depends on stuff you'll find", "coordinate with the frontend team").  
  ➜ Name explicitly which tasks or artifacts must exist first.

---

## Prompt Template (Quick Reference)

Use this template to structure your sub-agent prompt:

```markdown
## [Sub-Task Title]

**Goal:** [1–2 sentence summary of what to build/fix/review]

**Input:**
- Start from branch: [branch name]
- Key files: [path/to/file1, path/to/file2]
- Context: [Link to spec / design doc / related PR / ADR]

**Scope (DO):**
- Implement [feature X]
- Add tests for [scenario Y]
- [Specific action 3]

**Out of Scope (DON'T):**
- Do not [common over-reach]
- Do not [another common mistake]

**Success Criteria:**
- [ ] All unit tests pass (90%+ coverage)
- [ ] No lint errors or TypeScript compilation errors
- [ ] [Custom criteria]

**Estimated Time:** 20–30 minutes

**Output Artifact(s):**
- Updated `src/services/[file].ts`
- New test file `src/services/[file].test.ts`
- (Optional) Updated README if API changed

**Constraints:**
- Use async/await; no callbacks
- Follow TypeScript strict mode
- [Any org/project-specific rule]

**If You Get Stuck:**
- Escalate to [person or agent name] with:
  - What you tried
  - Why it didn't work
  - What you think the blocker is
```

---

## Validation Workflow

1. **Write the sub-agent prompt** (1st draft)
2. **Run through this checklist** (5 min)
3. **Refine based on red flags** (iterate)
4. **Ask one critical question:** "Could another agent successfully complete this with ONLY this prompt and the linked context?"  
   - If NO → go back to step 3
   - If YES → ready to dispatch

---

## Examples

### ✓ GOOD: Clear, Complete, Ready

```markdown
## Backend: Add JWT Token Refresh Endpoint

**Goal:** Implement a `/auth/refresh` endpoint so clients can extend session life without re-authenticating.

**Input:**
- Branch: `feature/auth-refactor`
- Service file: `src/services/authService.ts`
- Test patterns: See `src/services/auth.test.ts` (existing login tests)
- Context: ADR-005 (JWT expiry is 15 min)

**Scope (DO):**
- Add `/api/auth/refresh` POST endpoint
- Accept expired JWT in Authorization header
- Return new JWT if refresh token is valid
- Add 3 unit tests

**Out of Scope (DON'T):**
- Do not implement refresh token rotation or revocation (separate task)
- Do not add rate limiting (DevOps task)

**Success Criteria:**
- [ ] Unit tests pass (90%+ coverage)
- [ ] Manual curl test: `curl -X POST http://localhost:3000/api/auth/refresh -H "Authorization: Bearer <token>"`
  returns 200 with new JWT
- [ ] TypeScript strict: no errors

**Estimated Time:** 25 minutes

**Output:** Updated `src/services/authService.ts` + test cases
```

---

### ✗ BAD: Vague, Incomplete

```markdown
## Add Auth Stuff

Make sure the authentication system works. Implement whatever you think is needed.
Use best practices and follow the team's conventions.
Make sure it's tested.
```

**Problems:**
- No clear goal
- No input files named
- No success criteria
- "Whatever you think" = agents will over-solve
- "Best practices" = subjective
- No time estimate

**How to fix:** Use the template above and be specific about inputs, outputs, and success criteria.

---

## Tips for Faster Validation

- **Use a linter for prompts:** (hypothetically) check for subjective language ("make it better", "optimize"), vague scope ("improve"), missing specifics ("standard practices")
- **Walk through the prompt as an agent:** Pretend you're the sub-agent. Can you start working immediately, or do you have 3+ follow-up questions?
- **Test on junior developers:** If a junior dev (or junior agent) understands it fully, it's ready.
