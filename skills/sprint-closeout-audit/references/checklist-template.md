# Sprint Closeout Audit Template

```markdown
## Sprint Closeout Audit — <sprint-id>

1. ✅ Did everything merge?
- Status: yes | partial | no
- Evidence: <PRs/branches/issues>
- Action (if needed): <carry-forward item>

2. ✅ Did CI pass?
- Status: yes | partial | no
- Evidence: <workflow runs>
- Action (if needed): <remediation item>

3. ✅ Any errors?
- Status: none | partial | unresolved
- Evidence: <error links or logs>
- Action (if needed): <owner + due date>

4. ✅ Any issues?
- Status: none | carryover
- Evidence: <open issues>
- Action (if needed): <move to next sprint or close>

5. ✅ Did you test?
- Status: yes | partial | no
- Evidence: <test command + result>
- Action (if needed): <test gap remediation>

6. ✅ Is latest-main CI green?
- Status: green | failing | action_required
- Required workflows: <list names of required workflows checked>
- Evidence: <https://github.com/<owner>/<repo>/actions?query=branch%3Amain> and run URLs
- Action (if needed): fix failing workflows before marking sprint closed; do not proceed while status is non-green

### Closeout decision
- Latest-main CI gate: pass | BLOCKED
- Ready for next sprint: yes | no
- Blockers: <list>

### Carry-forward actions
1. <item + owner + due date>
2. <item + owner + due date>
```
