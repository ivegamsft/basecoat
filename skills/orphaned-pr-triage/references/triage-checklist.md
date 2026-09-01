# Orphaned PR Triage Checklist

1. Query open PRs and sort by last activity date.
2. Exclude protected labels (`do-not-close`, `release-blocker`).
3. Classify each candidate with `backlog-revalidation` before mutate:
   - Map revive/close/escalate onto `still-needed`, `superseded`,
     `already-resolved`, `not-needed`, `recurring`, or `insufficient-evidence`.
   - Do not close solely because the PR is stale.
   - **Revive**: still needed, missing reviewer/owner
   - **Close**: high-confidence superseded, obsolete, or already-resolved with citations
   - **Escalate**: blocked by merge conflicts, dependency decisions, or low confidence
4. Post a standard comment and assign owner/date.
5. Publish weekly metrics:
   - stale PR count
   - median PR age
   - revived vs closed ratio
