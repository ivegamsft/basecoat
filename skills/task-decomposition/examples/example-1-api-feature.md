# Example 1: Adding a New API Feature

**Original request:** "Add user profile endpoints to the API."

---

## BAD Decomposition ✗

### The Problem
```
Sub-task 1: Implement user profile endpoints
  - Create the endpoints
  - Add database schema changes
  - Write tests
  - Update API docs
  - Deploy to production
```

**Why it's bad:**
- **Too big:** "Implement user profile endpoints" is 2–3 hours of work, not 30 minutes
- **Tightly coupled:** DB schema, API logic, docs, and deployment are all intertwined
- **No parallelism:** All work must happen sequentially
- **Unclear success:** "Create endpoints" could mean anything
- **No agent assignment:** Which agent owns what?

---

## GOOD Decomposition ✓

### The Solution
```
Sub-task 1: Backend — Implement profile CRUD endpoints [20 min]
  Input: Branch feature/user-profiles, existing User model in src/models/user.ts
  Scope: POST /users/{id}/profile, GET /users/{id}/profile, PUT /users/{id}/profile
  Success: All endpoints return 200 with correct payload shape; 85%+ unit test coverage
  
Sub-task 2: Backend — Add database migration [15 min]
  Input: Existing migration pattern in db/migrations/
  Scope: Create user_profiles table with name, avatar_url, bio fields
  Success: Migration runs cleanly on PostgreSQL; rollback works
  
Sub-task 3: Frontend — Add profile edit UI [25 min]
  Input: Depends on Sub-task 1 (API endpoints)
  Scope: React component with form for name, bio, avatar upload
  Success: Form submits to API; displays profile after save; no console errors
  
Sub-task 4: Code Review — Security and API design review [15 min]
  Input: PRs from Sub-tasks 1 and 2
  Scope: Review for SQL injection, CORS misconfiguration, API versioning
  Success: All code review comments addressed or documented as tech debt
  
Sub-task 5: Documentation — Update API docs [10 min]
  Input: Completed endpoints from Sub-task 1
  Scope: OpenAPI spec entries for profile CRUD; example requests/responses
  Success: API docs build without warnings; examples validated
```

### Parallelization
```
Timeline:
- Sub-tasks 1 & 2 can run in parallel (both backend-independent)
- Sub-task 3 waits for Sub-task 1 (depends on API)
- Sub-task 4 waits for Sub-tasks 1 & 2 (code review)
- Sub-task 5 can run after Sub-task 1 is complete

Optimal order:
Time 0–20 min: Sub-tasks 1 & 2 in parallel
Time 20–45 min: Sub-task 3 (API now available)
Time 45–60 min: Sub-task 4 (review both backend PRs)
Time 50–60 min: Sub-task 5 (docs, parallel with review if possible)

Total time: ~60 min (vs. ~90+ min if fully sequential)
```

---

## Key Lessons

1. **Specificity:** Instead of "implement endpoints", name each endpoint (`POST /users/{id}/profile`, etc.)

2. **Clear input/output:** Each sub-task knows what files it touches and what success looks like

3. **Testability:** Success criteria are measurable (test coverage %, HTTP 200, no console errors)

4. **Parallelism:** Backend and database changes can overlap; frontend waits for the API to be ready

5. **Agent assignment:** Clear which skill/agent owns each piece (backend-dev, frontend-dev, code-review, documentation)

6. **Time realism:** Each sub-task is 10–25 minutes, not 2 hours

7. **Scope boundaries:** Each sub-task is isolated enough that one agent can own it end-to-end

---

## Anti-Patterns to Avoid

- ❌ "Do the thing" (too vague)
- ❌ "Make it work" (no definition of success)
- ❌ "Implement the whole feature" (should be broken into smaller tasks)
- ❌ "Deploy to production" (shouldn't be part of a sub-agent task; that's a separate CI/CD step)
- ❌ Implicit dependencies ("you'll know when task 1 is done because...") — make them explicit

