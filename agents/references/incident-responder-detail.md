# Incident Responder — Credential Exposure Closure Protocol

Supporting detail for [`agents/basecoat-60-workflow-incident-responder.agent.md`](../basecoat-60-workflow-incident-responder.agent.md).

## Environment Resolution

Before reading logs, querying metrics, or initiating mitigation in Azure-backed incidents, resolve the target
environment using the `operation-context-resolver` skill:

1. Pass the incident signal, severity, and GitHub event context as `ResolverInput`.
2. Use `OperationContext.azure_subscription`, `resource_group`, and `log_analytics_workspace` for all Azure API
   calls — never hard-code environment names.
3. If `OperationContext.mode` resolves to `incident_readonly`, restrict actions to log reads and diagnostics;
   escalate before taking any write actions.
4. Check `OperationContext.drift_status` — a `critical` or `high` drift reading may be the root cause of the
   incident. Surface it in the incident timeline.
5. For GitHub-only credential incidents (leaked PATs, exposed Actions secrets, repository token disclosure)
   where no Azure resource is in scope, skip the `azure_subscription` dependency and run a GitHub context
   path: scope affected repositories/workflows, revoke and replace credentials, and verify consumer recovery.

See [`docs/guides/operation-context-resolver.md`](../../docs/guides/operation-context-resolver.md) for
integration examples.

## Credential Exposure Closure Protocol

1. Stop or isolate the path that is disclosing the credential without reading, copying, or reproducing its
   value.
2. Identify the credential owner and every known consumer.
3. Require revocation of the exposed credential and creation of a replacement. Updating a repository secret
   alone does not prove the original credential was revoked.
4. Capture a sanitized timeline and non-sensitive evidence before deleting exposed logs or artifacts. Deletion
   may happen immediately to reduce access, but it never satisfies the revocation or rotation gate.
5. Delegate lifecycle work to `Secrets Manager`; keep owner-only credential generation or revocation as an
   explicit blocked action.
6. Validate the replacement through a least-privilege preflight, confirm secret metadata is newer than the
   exposure, and verify every consumer recovered.
7. Re-run the affected workflow or service path and record recovery evidence.

Do not close the incident until all closure gates are satisfied: disclosure path fixed, exposed credential
revoked, replacement installed, exposed artifacts removed after evidence capture, consumers verified, and
learnings/follow-ups logged. If any owner-only action remains, keep the incident open and blocked.
