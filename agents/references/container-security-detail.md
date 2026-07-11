# Container Security — Detail Reference

## Pod Security Standards (PSS)

| Level | Allows | Blocks | Use Case |
|---|---|---|---|
| Privileged | Privileged containers, host networking, root user | Nothing | System components |
| Baseline | Root user; capability dropping not enforced | Privileged containers, host paths, host PID/IPC | Most app workloads |
| Restricted | Nothing dangerous | Root user, privileged containers, host access, unsafe capabilities | Sensitive workloads |

Admission controllers: `enforce` (reject non-compliant deployment), `audit` (log only), `warn` (warn only).

## Image Scanning Layers

1. Base image vulnerabilities — Alpine, Ubuntu, Debian CVEs; use minimal base images.
2. Application dependencies — npm/pip/Maven packages; scan lock files for known CVEs.
3. Hardcoded secrets — Gitleaks, TruffleHog scanning in image layers.
4. Malware/anomalies — binary scanning and behavioral heuristics.

Tools: Trivy (Aqua Security), Grype (Anchore), Clair (CoreOS), Snyk Container.

```bash
trivy image gcr.io/myrepo/myimage:v1.0 --severity HIGH,CRITICAL --format json
```

## Falco Runtime Detection Rules

```yaml
- rule: Write below etc
  desc: Detect writes to /etc directory
  condition: >
    open_write and container and fd.name startswith "/etc/"
  output: >
    File written below etc (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: ERROR
```

Behaviors to detect: privilege escalation, unauthorized network activity, suspicious syscalls (ptrace, execve, bpf), writes to system directories, container escape attempts (Docker socket access, cgroup manipulation).

## Kyverno Policy Example (Non-Root)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: enforce
  rules:
  - name: check-runAsNonRoot
    match:
      resources:
        kinds: [Pod]
    validate:
      message: "Running as root is not allowed"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
```

## Sigstore Image Signing (SLSA)

```bash
cosign sign --oidc-provider oidc.example.com gcr.io/myrepo/myimage:v1.0
cosign attest --attestation slsa-provenance.json gcr.io/myrepo/myimage:v1.0
```

SLSA Levels: Level 1 (provenance docs) through Level 4 (hermetic build + offsite verification).

## Common CSPM Findings

Infrastructure: nodes without NetworkPolicy, privileged containers, missing resource limits, outdated API versions.
Access Control: overly permissive ClusterRole bindings, service accounts with cluster-admin.
Networking: NetworkPolicy not enforced, egress to external IPs allowed, ingress from 0.0.0.0/0.
Secrets/Config: secrets stored as ConfigMaps (unencrypted), Vault not configured, etcd encryption disabled.

## Standards and References

- [Kubernetes PSS](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST SP 800-190 — Container Security](https://doi.org/10.6028/NIST.SP.800-190)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore](https://www.sigstore.dev/)
- [Falco](https://falco.org/docs/)
- [Kyverno](https://kyverno.io/)
