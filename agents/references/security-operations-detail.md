# Security Operations Agent — Detail Reference

Full detection playbook, incident response phases, secrets rotation, audit logging, and
threat intelligence integration for `agents/basecoat-50-security-security-operations.agent.md`.

## Detection Playbook

### Anomaly Detection Patterns

**Failed login spike**: Monitor auth logs for N failed logins in M minutes

```sql
SELECT source_ip, COUNT(*) as failed_attempts
FROM auth_logs
WHERE success = false AND timestamp > NOW() - INTERVAL '10 minutes'
GROUP BY source_ip
HAVING COUNT(*) > 10
```

**Lateral movement**: Track cross-host SSH/RDP connections

```bash
# Linux: Detect cross-host SSH
grep "Accepted password\|Accepted publickey" /var/log/auth.log | \
  awk '{print $1, $2, $8, $9, $11}' | \
  sort | uniq -c | sort -rn | awk '$1 > 5 {print}'
```

**Privilege escalation**: Monitor sudo/RunAs usage

```powershell
# Windows: Detect excessive privilege escalation
Get-EventLog -LogName Security -InstanceId 4688 | `
  Where-Object { $_.Message -match 'cmd.exe|powershell.exe' } | `
  Group-Object { $_.Properties[1].Value } | `
  Where-Object { $_.Count -gt 3 }
```

## Incident Response Workflow

### Containment Phase (0-2 hours)

1. **Isolate affected system**: Remove from network (not shutdown — preserve memory)
2. **Preserve evidence**: Take memory dump, disk image
3. **Notify stakeholders**: SOC → Management → Legal (if breach confirmed)

```bash
# Use an approved, validated acquisition tool for the affected platform.
# Linux example: sudo insmod lime.ko "path=/evidence/memory.lime format=lime"
# macOS example: sudo osxpmem.app/Contents/MacOS/osxpmem -o /evidence/memory.aff4
# Windows example: winpmem_mini_x64_rc2.exe /evidence/memory.raw
# Record the tool/version, operator, and collection time, then preserve the hash.
sha256sum memory.img > memory.img.sha256
```

### Investigation Phase (2-24 hours)

1. **Timeline reconstruction**: Correlate logs, files, processes
2. **Artifact analysis**: File hashes, network connections, registry keys
3. **Root cause analysis**: How did attacker gain access?

```bash
# Linux: Full forensic timeline
find / -newermt "2024-01-01 10:00:00" -type f | sort > timeline.txt

# Windows: Registry forensics
reg export HKLM\SOFTWARE forensic_software.reg
wevtutil qe Security /format:xml > security_events.xml
```

### Recovery Phase (24-72 hours)

1. **Patch systems**: Apply security updates
2. **Rotate credentials**: All service accounts, API keys
3. **Update SIEM rules**: Prevent recurrence
4. **Post-incident review**: Update playbooks

## Secrets Management

### Rotation Playbook

All secrets rotated every 90 days (or immediately if exposed).

```bash
# Inventory explicit rotation timestamps without printing secret values.
kubectl get secrets --all-namespaces \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROTATED:.metadata.annotations.security\.example\.com/rotated-at'

# Replace one credential from protected input and record its rotation timestamp.
read -rs NEW_API_KEY
kubectl create secret generic app-credentials \
  --namespace production \
  --from-literal=api-key="$NEW_API_KEY" \
  --dry-run=client -o yaml |
  kubectl annotate --local -f - security.example.com/rotated-at="$(date -u +%FT%TZ)" -o yaml |
  kubectl apply -f -
unset NEW_API_KEY

# Restart only explicitly identified consumers of the rotated secret.
for deployment in deployment/api deployment/worker; do
  kubectl rollout restart "$deployment" --namespace production
done
```

Record each rotated credential, rotation timestamp, secret version or resource version,
and successful consumer restart in the Secrets Rotation Confirmation. Verify the old
credential is revoked before declaring rotation complete.

### Audit Log Requirement

```yaml
# kubernetes: Audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Metadata preserves actor and resource evidence without recording secret values.
  - level: Metadata
    verbs: ["create", "patch", "update", "delete"]
    resources:
      - group: ""
        resources: ["secrets"]
  - level: Metadata
    verbs: ["get", "list"]
    resources:
      - group: ""
        resources: ["secrets"]
```

## Audit Logging Standards

All security events logged with:

- **Who**: User/service account
- **What**: Action (login, file access, privilege escalation)
- **When**: ISO 8601 timestamp (UTC)
- **Where**: Source IP + hostname
- **Why**: Request context (API call, script execution)

```json
{
  "timestamp": "2024-01-15T14:23:47Z",
  "event_type": "privilege_escalation",
  "principal": "user@example.com",
  "source_ip": "192.168.1.100",
  "action": "sudo /usr/bin/cat /etc/shadow",
  "result": "ALLOWED",
  "context": "Maintenance request MAINT-1234"
}
```

## Threat Intelligence Integration

Subscribe to threat feeds and integrate into SIEM.

```yaml
# Threat feed ingestion
feeds:
  - name: abuse.ch-urlhaus
    url: https://urlhaus-api.abuse.ch/v1/urls/recent/
    frequency: hourly
  - name: cisa-vulnerabilities
    url: https://raw.githubusercontent.com/cisagov/kev-data/develop/known_exploited_vulnerabilities.json
    frequency: daily

# SIEM rule: Auto-block known malicious IPs
if source_ip in threat_intelligence.blocked_ips:
  action: BLOCK
  alert_level: CRITICAL
  assignee: on_call_soc
```
