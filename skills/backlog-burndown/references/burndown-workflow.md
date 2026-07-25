# Backlog Burndown Workflow

1. Define scope window (sprint or milestone) and freeze baseline scope set,
   including both open issues and open pull requests in the window.
2. Pull current state counts by status (Todo, In Progress, Blocked, Done);
   for PRs, map draft/open to In Progress and merged to Done. Treat
   closed-unmerged PRs as removed/deferred scope: track them on a separate
   removed-scope line and reduce both baseline and remaining scope by that
   amount, so they are neither credited as delivered burn nor counted as
   outstanding work.
3. Compute ideal burn line and actual burn line by day.
4. Highlight variance, blocked-item concentration, stale/long-open PRs, and
   new-scope injection.
5. Produce a short action plan:
   - remove or defer low-priority items
   - reassign owners for blocked work
   - unblock or close stale open PRs (route to `orphaned-pr-cleanup`)
   - tighten WIP to increase completion flow

## Report Template

```text
Backlog Burndown — <date>
- Baseline scope: <count>
- Remaining scope: <count>
- Days left: <count>
- Required daily burn: <x/day>
- Actual daily burn: <x/day>
- Variance: <+/-> <x/day>
- Blocked items: <count>

Risk: Low | Medium | High
Actions:
1) ...
2) ...
3) ...
```
