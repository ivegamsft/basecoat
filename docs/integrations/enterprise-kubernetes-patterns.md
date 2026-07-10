# Enterprise Kubernetes Operational Patterns

This document provides best practices for operating Kubernetes workloads in enterprise environments, with emphasis on Azure Kubernetes Service (AKS).

## Cluster Architecture

### Node Pools

Use multiple node pools for workload isolation:

`yaml
apiVersion: Microsoft.ContainerService/managedClusters
kind: AKS
metadata:
  name: prod-cluster
spec:
  agentPoolProfiles:
  - name: system
    count: 3
    vmSize: Standard_DS2_v2
    osType: Linux
    mode: System  # System pods only
  - name: workload
    count: 6
    vmSize: Standard_D4s_v3
    osType: Linux
    mode: User  # User workloads
  - name: gpu
    count: 2
    vmSize: Standard_NC6s_v3  # GPU VMs
    osType: Linux
    mode: User
`

### Pod Security Standards

Enforce pod security policies:

- **Restricted**: Minimal privileges; read-only filesystem
- **Baseline**: Allow common configurations
- **Unrestricted**: Legacy workloads (deprecated)

### Network Policies

Control traffic between pods:

`yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
`

## Observability

### Prometheus and Grafana

Collect metrics and visualize:

- **CPU/Memory usage**: Per pod, per node
- **Request latency**: P50, P95, P99
- **Error rates**: By service and endpoint
- **Custom metrics**: Business events

### Container Insights

Native AKS monitoring:

- **Cluster health**: Node, pod, container metrics
- **Performance**: Compare baseline vs. current
- **Logs**: Container stdout/stderr in Log Analytics
- **Alerts**: Thresholds for resource utilization

## Security

### RBAC

Control who can access what:

`ash
# Create role for developers
kubectl create role developer --verb=get,list,watch --resource=pods
kubectl create rolebinding dev-binding --role=developer --user=developer@company.com
`

### Network Policies

Restrict inter-pod communication by default:

`yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
`

## Resource Management

### Resource Requests and Limits

Define resource requirements for each pod:

`yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
`

### Horizontal Pod Autoscaler

Scale pods based on metrics:

`yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
`

### Vertical Pod Autoscaler

Right-size resource requests based on usage.

## Storage

### StatefulSets

For applications requiring stable identity:

`yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-statefulset
spec:
  serviceName: db-service
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: postgres:14
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
`

### Persistent Volumes

Use Azure Disk or Azure Files:

`yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 50Gi
`

## Deployment Strategies

### Rolling Update

Gradually replace old pods with new:

`yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # No downtime
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:v2
`

### Blue-Green Deployment

Run two identical environments; switch traffic:

- **Blue**: Current production version
- **Green**: New version (tested in parallel)
- **Switch**: Point load balancer to green; monitor

## Backup and Disaster Recovery

### Velero

Backup Kubernetes cluster state:

`ash
# Install Velero
velero install --provider azure --bucket mybackups --secret-file credentials-azureblobstorage

# Create backup
velero backup create my-backup

# Restore from backup
velero restore create --from-backup my-backup
`

### Cluster Recovery

Steps to recover from cluster failure:

1. Create new AKS cluster in same region
2. Restore applications from backup (Velero)
3. Point DNS to new cluster
4. Validate data and functionality

## Base Coat Assets

**Related agents & skills**:

- Agent: \gents/azure-kubernetes.agent.md\ — AKS cluster design and operations
- Agent: \gents/sre-engineer.agent.md\ — Reliability patterns and monitoring
- Skill: \skills/kubernetes-operators/\ — Automation and orchestration
- Instruction: \instructions/kubernetes-security-hardening.instructions.md\

## Next Steps

1. **Design**: Plan node pools, pod security, and network policies
2. **Deploy**: Create AKS cluster with monitoring enabled
3. **Secure**: Implement RBAC and network policies
4. **Monitor**: Set up Prometheus/Grafana and Container Insights
5. **Backup**: Configure Velero for cluster recovery

## References

- [Azure Kubernetes Service (AKS) Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
- [Velero Documentation](https://velero.io/docs/)
