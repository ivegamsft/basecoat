# Shared approval contract

## Requirements and design

Issue approval, PR-side forwarding, and delivery dispatch use the same trusted
default-branch runtime helper. Implementation authority is a current human
`/approve` directive with write, maintain, or admin repository permission, never
an `approved` label or a bot's assertion.

- Accept case-insensitive `/approve` with surrounding whitespace only. Reject
  prose, block quotes, code fences, inline code, suffixes, and multiple commands.
- Require an open issue, existing type and priority metadata, no blocking labels,
  and exactly one bare HTTP(S) `- Spec:` URL. Preserve delivery's placeholder-host
  and placeholder-token exclusions; reject malformed URLs and embedded credentials.
  Do not add a new review gate or require commit pinning for ordinary approval.
- Re-fetch the current issue, comments, permissions, and declared dependencies.
  Issues must be closed and dependency PRs must be merged. Qualified dependency
  URLs refer to their named repository, not a same-number local issue.
- PR forwarding validates the identical issue contract before side effects.
  Record the original PR/comment IDs and human directive, actor, and URL in a bot
  receipt. Delivery re-fetches that original comment, checks its repository/PR
  membership and current human permissions, and verifies that the current PR
  still closes the issue. A deleted origin comment is invalid evidence; continue
  searching for later qualified approvals. Other API failures propagate, including
  permission lookup failures. Bot text alone cannot authorize implementation.
- `/spec-2-prod` and all existing delivery aliases require prior real approval;
  they do not create approval. Delivery revalidates metadata and dependencies,
  even when a label or historical approval already exists.

## Migration and boundaries

Existing exact `/approve`, `/APPROVE`, and whitespace-padded equivalents remain
valid. Historically accepted incidental substring commands must be reposted as
standalone `/approve`. Relative, placeholder, and malformed spec references must
be replaced with a real HTTP(S) URL, matching the existing delivery URL policy.
Older bot acknowledgements are not origin evidence: repost a qualified directive
on the issue or PR to produce a verifiable receipt. No auto-approve workflow,
human review requirement, or native merge-queue policy changes are included.

## Verification

Execute the actual shared helper and workflow-extracted scripts with API fixtures
covering all three routes, missing/placeholder/malformed spec references, current
and revoked rights, accepted command equivalents, quoted command spoofing,
forged bot origins, cross-repository and reopened dependencies, and synchronized
distributed workflows. These source fixtures are not deployed-workflow proof.
