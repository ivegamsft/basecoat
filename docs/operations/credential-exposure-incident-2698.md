# Credential Exposure Incident 2698

## Summary

On 2026-07-26, a production-repository token was exposed in a GitHub Actions
failure log when a POSIX-oriented workflow step ran on a self-hosted Windows
runner. Shell parsing failed after the secret had been interpolated into the
generated command, causing the credential value to appear in diagnostic output.

This record intentionally contains no credential value or sensitive log content.

## Timeline

- 2026-07-26: The workflow failure exposed the token in Actions run
  `30214820425`.
- 2026-07-26: PR #2697 merged. It stopped inlining the token and pinned the
  affected production dispatch jobs to `ubuntu-latest` with Bash.
- 2026-08-04: Incident review confirmed the repository secret metadata still
  predated the exposure, so rotation could not be considered complete.
- 2026-08-04: The exposed Actions run was deleted after a sanitized incident
  timeline and remediation references were retained in issue #2698.
- Current: The incident remains open and blocked until the credential owner
  revokes the exposed PAT, installs a replacement, and verifies the production
  documentation workflow.

## Root Cause

The workflow combined three unsafe assumptions:

1. A deployment runner selected through repository configuration would provide
   a POSIX shell.
2. A secret could be interpolated into generated shell text without becoming
   part of parser diagnostics.
3. Fixing the workflow and replacing the repository secret would be sufficient
   evidence of credential revocation.

The first two caused the disclosure. The third created a closure gap: repository
secret metadata can show replacement timing, but it cannot prove the source PAT
was revoked by its owner.

## Learnings

1. Pass secrets through masked environment variables or standard input; never
   interpolate them into generated commands.
2. Pin runner OS and shell when workflow syntax depends on either.
3. Treat every exposed credential as compromised. Revocation and replacement
   are separate required actions.
4. Preserve a sanitized timeline and non-sensitive identifiers before deleting
   exposed logs. Log deletion reduces access but is not credential containment.
5. Keep incidents open and blocked when credential creation or revocation
   requires a human-owned account.
6. Verify closure with a recovery run and consumer inventory, not only secret
   presence or an updated timestamp.
7. Bootstrap scripts can detect missing configuration and validate a candidate,
   but they cannot mint a PAT owned by another GitHub account.

## Prevention Changes

- Route credential exposure through the existing `security:` intent to
  `incident-responder`, `Secrets Manager`, and `guardrail`.
- Require explicit closure states for revocation, replacement installation,
  artifact removal, consumer recovery, and learning capture.
- Keep the general run-history cleanup policy unchanged: ordinary cleanup must
  preserve active incident evidence. Exposure removal is an incident-command
  action performed only after sanitized evidence capture.

## Remaining Owner Action

The `ivegamsft` credential owner must revoke the exposed fine-grained PAT,
create a least-privilege replacement scoped to the production repository,
update `PRODUCTION_REPO_TOKEN`, and verify the production documentation
workflow succeeds.
