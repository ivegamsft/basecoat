# Scheduled delivery recovery

Implementation spec for #3590.

## Contract

- Enable trusted default-branch reconciliation for solo-dev as well as team and
  regulated profiles. Human review is not a discovery prerequisite.
- Route solo-dev recovery by the selected trusted profile in the workflow,
  independently of the existing review-driven discovery flag. Preserve both
  policy packs unchanged: the executor rejects candidate policy drift except
  production workflow digests. Do not relax this comparator to deliver recovery.
- The existing executor remains the only authorization and delivery authority:
  fresh issue approval, spec, policy, reviews, checks, holds and snapshot validation
  remain mandatory according to the selected profile.
- Scan one REST page of at most 100 open default-branch PRs per tick; rotate pages
  across ten scheduled windows and rotate each page's starting offset to avoid
  starving later candidates. Empty rotated pages fall back to page one using
  one additional bounded query. Inspect at most twenty candidates and dispatch
  at most five evaluations per tick.
- Re-read each candidate immediately before dispatch. Skip draft, closed,
  delivery-held, fork and changed-head candidates.
- A current-head eligibility watermark younger than 30 minutes suppresses
  equivalent recovery work, including pending evaluations. After that cooldown,
  fingerprint trusted main/profile, PR metadata, checks/statuses, reviews and
  linked issue/comment evidence. Ignore evaluator reporting effects. Persist
  the marker in existing executor status URLs; never add checkpoint statuses.
- Never redispatch a fingerprint already observed from GitHub Actions. Allow
  changed evidence, but cap scheduled recovery at fifty distinct evaluation
  runs per head; stop when fewer than two writes remain in a two-hundred-status
  recovery budget, reserving at least eight hundred slots for event-driven progress.
- Evidence reads are bounded: at most three status pages, one page per review,
  comment or check list, and ten linked issues. Truncated evidence fails closed.
  Recovery requests read-only status/check/issue permissions, not new write
  privileges. Event-driven/manual executor notifications remain available when
  recovery reaches its budget or cannot read a complete snapshot.
- Defer recovery while the executor has active work, and use its existing
  per-PR serialized mailbox for races with event-driven notifications.
- Dispatch is only a request for fresh evaluation, not authorization, queue
  admission or completed delivery. Report this distinction in the run summary.
- Do not change token ownership, auto-merge authorization or queue credentials.
  Known #3604 remains: automatic GITHUB_TOKEN queue admission suppresses group
  CI; reconciliation cannot promise a working automatic queue delivery path.

## Verification and rollout

Execute mocked REST tests against both installed workflow scripts: zero-review
discovery, current-head rereads, holds, drafts, stale evidence, cooldown, bounds,
active evaluator work and dispatch failures. Exercise the existing executor's
profile and authorization tests separately; discovery never grants eligibility.
Read trusted-main and candidate policy independently in evaluator API mocks:
reject reconciliation, approval-rule and environment-binding drift; allow only
digest updates whose workflow bytes and production environment binding match.
Keep distributed copies and both policy-pack digest inventories unchanged.
Roll out through native merge queue; revert the merge to disable recovery.
