# Example 3: System Redesign (Deferred / Escalate)

**Original request:** "Redesign the entire authentication system to support SSO."

---

## BAD Decomposition ✗

### The Problem (Too Ambitious)
```
Sub-task 1: Implement OIDC provider integration [1–2 hours]
Sub-task 2: Migrate existing users to SSO [2–3 hours]
Sub-task 3: Update all frontend login flows [2–3 hours]
Sub-task 4: Sunset old JWT-based auth [1 hour]
Sub-task 5: Update deployment and secrets [1 hour]
Sub-task 6: Testing and QA [2–3 hours]
```

**Why this fails for automation:**
- **Massive scope:** 10+ hours of work split into a few tasks
- **Unclear success criteria:** "Migrate users" could mean many things; what about existing sessions?
- **High risk:** One architectural mistake breaks everything
- **Hidden dependencies:** Test strategy depends on OIDC provider integration; migration depends on test results, etc.
- **Human decisions needed:** 
  - Which OIDC provider? (Azure AD? Okta? Google?)
  - Cutover strategy: big-bang or gradual?
  - What happens to existing JWT tokens during transition?
  - How do we validate correctness across all flows?

---

## GOOD APPROACH: Escalate & Research First ✓

### Step 1: Classify Using the Automation Fitness Matrix

```
Criterion                          Answer   Status
─────────────────────────────────────────────────────
Specific, measurable criteria?        NO    ✗
Clear sub-task boundaries?            NO    ✗
Each sub-task <30 min?                NO    ✗
Independent success criteria?         NO    ✗
No mid-flight decisions?              NO    ✗
Loosely coupled?                      NO    ✗
Scope bounded?                        NO    ✗
No unresolved dependencies?           NO    ✗

Score: 0/8 ✓s → **DEFERRED / ESCALATE** 🛑
```

### Step 2: Document Blockers

```
Blockers to Automation:

1. **Unresolved Architecture Decision**
   - Which OIDC provider? (Azure AD vs. Okta vs. generic OIDC)
   - Rationale: Different providers have different sync capabilities, pricing, and onboarding time
   - Blocker: Cannot implement integration without knowing the target

2. **Cutover Strategy Undefined**
   - Big-bang (turn off JWT, enable SSO on day 1) vs. Gradual (dual auth for N days)
   - Rationale: Each strategy requires different code paths and carries different risk
   - Blocker: Cannot write tests or success criteria without knowing the strategy

3. **Compliance & Security Sign-Off Needed**
   - Password policy: SSO may have different requirements
   - User provisioning: Manual vs. JIT (just-in-time) vs. SCIM sync
   - Blocker: Tech decisions depend on org/security team approval

4. **Dependent Systems Unknown**
   - Which internal tools depend on JWT tokens? (Mobile apps? CLI tools? Legacy services?)
   - Blocker: Cannot plan cutover without a full inventory
```

### Step 3: Resolution Plan (Before Decomposition)

```
Action Items (to be done by stakeholders, not sub-agents):

1. Architecture Review (week 1)
   - [ ] Meet with security team on OIDC provider options
   - [ ] Document pros/cons of each provider
   - [ ] Decision: Which provider? (Azure AD chosen → proceed to step 2)

2. Cutover Strategy Decision (week 1–2)
   - [ ] Map dependent systems (mobile app, CLI, legacy APIs)
   - [ ] Decide: big-bang vs. gradual
   - [ ] Document rollback procedure

3. Compliance Sign-Off (week 2)
   - [ ] Security review of chosen OIDC provider
   - [ ] Password policy alignment
   - [ ] User provisioning method approval

4. High-Level Design Doc (week 2–3)
   - [ ] Document OIDC flow
   - [ ] Identify system touchpoints (frontend, backend, mobile, CI/CD)
   - [ ] Define success metrics (e.g., "95% of users can log in via SSO by day X")
```

### Step 4: After Unblocking, Decompose

Once stakeholders provide:
- OIDC provider choice
- Cutover strategy
- Approval from security/compliance
- System inventory

**THEN** it becomes automatable:

```
Revised Sub-tasks (after unblocking):

Sub-task 1: Backend — OIDC Provider Setup [20 min]
  Input: Provider = Azure AD (decided by stakeholders)
  Scope: Register app in Azure AD, obtain client_id and secret
  Success: Credentials in .env.example; no hardcoded secrets
  
Sub-task 2: Backend — OIDC OAuth Flow [25 min]
  Input: Azure AD credentials from Sub-task 1
  Scope: Implement GET /auth/oidc/login and /auth/oidc/callback
  Success: OAuth flow completes; user session created
  
Sub-task 3: Frontend — SSO Login Button [20 min]
  Input: Depends on Sub-task 2
  Scope: Add "Sign in with SSO" button; redirect to /auth/oidc/login
  Success: Click button → Azure login → redirect back → logged in
  
... etc.
```

---

## Key Lessons

1. **Recognize when a task is too big:** If success criteria are unclear or decisions are pending, it's not ready for automation

2. **Use the automation fitness matrix:** This task scores 0/8; it's a clear **DEFER** case

3. **Document blockers explicitly:** Don't try to work around them; make them visible and escalate

4. **Separate concerns:**
   - **Research/Decision phase:** What provider? What strategy? (human-led, stakeholder input)
   - **Decomposition phase:** Once decisions are made, break into concrete sub-tasks
   - **Automation phase:** Execute sub-tasks with clear criteria

5. **Define success before starting:** "SSO works" is too vague. What does success look like? (95% user adoption? All systems integrated? Zero login errors?)

6. **Don't rush architecture decisions into code:** A bad architectural choice costs 3x more to fix later than it does to think through upfront

---

## What NOT to Do

❌ **Don't decompose this task as-is and hope sub-agents figure it out.**
- Sub-agents will make conflicting choices (provider A vs. B) and waste time

❌ **Don't hide the complexity in one "OIDC implementation" task.**
- It's still too big and risky

❌ **Don't make arbitrary decisions for stakeholders.**
- "I'll use Okta" might conflict with org requirements

❌ **Don't assume success criteria ("make it work").**
- Define what "work" means before you start

---

## Summary: When to Escalate vs. Automate

| Signal | Action |
|--------|--------|
| "I don't know which provider" | Escalate (architectural decision) |
| "We haven't decided on cutover strategy" | Escalate (strategic decision) |
| "Security hasn't approved yet" | Escalate (compliance decision) |
| "Some systems might be affected, not sure which" | Escalate (inventory audit first) |
| "Success looks like X, Y, Z" (specific) | Decompose & automate ✓ |
| "We've chosen provider, strategy, and have sign-offs" | Decompose & automate ✓ |
| "Each sub-task is 15–30 minutes with clear criteria" | Decompose & automate ✓ |

