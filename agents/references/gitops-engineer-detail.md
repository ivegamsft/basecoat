# GitOps Engineer Agent — Detail Reference

Full configuration examples for `agents/basecoat-10-core-gitops-engineer.agent.md`.

## Repository Structure

```text
gitops-repo/
├── README.md
├── clusters/
│   ├── production/
│   │   ├── kustomization.yaml
│   │   ├── ingress/
│   │   └── monitoring/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── ingress/
│   └── development/
├── helm-releases/
│   ├── values-prod.yaml
│   ├── values-staging.yaml
│   └── values-dev.yaml
├── infrastructure/
│   ├── network.tf
│   ├── compute.tf
│   └── storage.tf
├── policies/
│   ├── rbac.yaml
│   ├── network-policies.yaml
│   └── resource-quotas.yaml
└── docs/
    ├── BOOTSTRAP.md
    ├── DEPLOYMENT_WORKFLOW.md
    └── TROUBLESHOOTING.md
```

## Argo CD Setup

### Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/myorg/gitops
    targetRevision: main
    path: apps/my-app/overlays/production

    # Use Helm
    helm:
      releaseName: my-app
      values: |
        replicas: 3
        image:
          tag: "1.2.3"
      valuesObject:
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    automated:
      prune: true      # Delete resources not in git
      selfHeal: true   # Auto-sync if cluster drifts
      allowEmpty: false # Prevent deletion of entire app

    syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Notification webhooks
  info:
  - name: 'github-repo'
    value: 'https://github.com/myorg/gitops'
  - name: 'slack'
    value: '#deployments'
```

### AppProject for RBAC

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: Team A applications

  sourceRepos:
  - 'https://github.com/myorg/*'
  - 'https://charts.bitnami.com/bitnami'

  destinations:
  - namespace: 'team-a-*'
    server: https://kubernetes.default.svc
  - namespace: 'monitoring'
    server: https://kubernetes.default.svc

  clusterResourceWhitelist:
  - group: ''
    kind: 'Namespace'

  namespaceResourceBlacklist:
  - group: ''
    kind: 'ResourceQuota'
  - group: ''
    kind: 'LimitRange'
```

## Flux v2 Setup

### HelmRelease CRD

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
  namespace: production
spec:
  interval: 5m0s

  chart:
    spec:
      chart: my-app
      sourceRef:
        kind: HelmRepository
        name: myrepo
        namespace: flux-system
      version: '1.2.3'

  values:
    replicas: 3
    image:
      repository: myorg/my-app
      tag: '1.2.3'

  install:
    crds: Create
    remediation:
      retries: 3

  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
      remediateLastFailure: true
```

## Pull Request Workflow

```yaml
name: GitOps PR Validation

on:
  pull_request:
    paths:
      - 'clusters/**'
      - 'charts/**'
      - 'helm-releases/**'
      - 'infrastructure/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate Kubernetes manifests
        run: |
          find clusters -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 | xargs -0 -r kubeval
          kustomize build clusters/staging

      - name: Validate Helm charts
        run: |
          helm lint charts/my-app -f helm-releases/values-prod.yaml
          helm template my-app charts/my-app --validate -f helm-releases/values-prod.yaml

      - name: Validate Terraform
        run: |
          terraform fmt -check
          terraform init -backend=false
          terraform validate

      - name: Policy as Code (Kyverno)
        run: |
          kubectl apply -f policies/ --dry-run=client
```

## Drift Detection & Remediation

```bash
#!/bin/bash
# Detect infrastructure drift

# Report Argo CD drift without waiting indefinitely for synchronization.
argocd app diff my-app
argo_diff_status=$?
if [ "$argo_diff_status" -eq 1 ]; then
    echo "Argo CD drift detected. Reconcile through an approved GitOps change."
    exit 2
elif [ "$argo_diff_status" -ne 0 ]; then
    echo "Argo CD diff failed." >&2
    exit "$argo_diff_status"
fi

# Render manifests for review; reconcile only through an approved GitOps change.
kubectl apply -k clusters/production -n production --dry-run=client --output=yaml

# Terraform drift detection
terraform plan -detailed-exitcode -out=tfplan
plan_status=$?
if [ "$plan_status" -eq 2 ]; then
    echo "Drift detected. Submit the plan for review; do not apply it from this check."
    terraform show tfplan
    exit 2
elif [ "$plan_status" -ne 0 ]; then
    echo "Terraform plan failed." >&2
    exit "$plan_status"
fi
```

## Disaster Recovery

### Backup and Restore

```bash
# Back up the declarative Application definition.
kubectl get application my-app -n argocd -o yaml > my-app-backup.yaml

# Restore from git (GitOps guarantees)
git revert <commit>  # Revert to previous state
# Argo CD automatically syncs to previous state

# Manual restore if needed: update the Application in place. Deleting it can
# trigger Argo CD's finalizer and cascade-delete the managed workloads.
kubectl apply -f my-app-backup.yaml
```

## Best Practices

| Practice | Benefit |
|----------|---------|
| One git repo = one environment | Prevents accidental cross-env changes |
| Immutable image tags | Reproducible deployments, better auditability |
| Branch protection rules | Enforce reviews, require status checks |
| Separate read/write credentials | Least privilege, audit separation |
| Automated image scanning | Detect vulnerabilities before deployment |
| Progressive delivery (Canary/Blue-Green) | Minimize blast radius of bad deploys |

## Monitoring & Observability

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-metrics
  namespace: argocd
data:
  metrics.rules: |
    groups:
    - name: argocd
      rules:
      - alert: ArgoCDOutOfSync
        expr: |
          argocd_app_info{sync_status!="Synced"} == 1
        for: 15m

      - alert: ArgoCDSyncFailure
        expr: |
          increase(argocd_app_sync_total{phase="Failed"}[5m]) > 0
```

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Docs](https://fluxcd.io/docs/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Cloud Native GitOps](https://www.cncf.io/blog/2022/11/02/what-is-gitops-fundamentals-and-benefits/)
