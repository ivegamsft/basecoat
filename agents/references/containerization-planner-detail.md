# Containerization Planner — Detail Reference

## Platform Decision Guide

### Docker (Self-managed)

- Use when: full control required, complex networking, existing VM/on-premises infrastructure, small team with deep container expertise.
- Tradeoffs: manual infra management, limited auto-scaling, higher operational overhead.

### Azure Container Apps (ACA)

- Use when: microservices/event-driven workloads, rapid deployment without infra management, serverless scaling, teams new to containers.
- Tradeoffs: limited control over underlying environment, performance overhead for compute-heavy workloads.

### Azure Kubernetes Service (AKS)

- Use when: multi-tenant/multi-environment deployments, complex orchestration, stateful workloads, DevOps-mature teams, existing Kubernetes investments.
- Tradeoffs: steeper learning curve, higher operational complexity, greater resource overhead.

## Dockerfile Template (Multi-Stage)

```dockerfile
FROM <base-image> AS builder
WORKDIR /build
COPY . .
RUN <build-commands>

FROM <runtime-base-image>
WORKDIR /app
COPY --from=builder /build/<output> .
RUN <install-runtime-deps>
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s CMD <health-check-command>
USER appuser
EXPOSE <port>
ENTRYPOINT ["<app-executable>"]
```

Best practices: multi-stage builds, non-root user, health checks, explicit port declaration, minimal final image.

## Health Probe Configuration

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 2
startupProbe:
  httpGet:
    path: /health
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

## Resource Profiles

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Common profiles:

- Light: 100m CPU / 128Mi (stateless APIs, cron jobs)
- Medium: 250m CPU / 256Mi (web apps, workers)
- Heavy: 1000m+ CPU / 1Gi+ (data processing, compute)

## Deployment Manifests

### Docker Compose

```yaml
version: '3.9'
services:
  app:
    build: { context: ., dockerfile: Dockerfile }
    image: registry.example.com/app:latest
    ports: ["8080:8080"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

### AKS Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: containerization-app
  template:
    metadata:
      labels:
        app: containerization-app
    spec:
      containers:
      - name: app
        image: registry.example.com/app:latest
        resources:
          requests: { cpu: "100m", memory: "128Mi" }
          limits: { cpu: "500m", memory: "512Mi" }
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          readOnlyRootFilesystem: true
```

### ACA Container App

```yaml
properties:
  template:
    containers:
    - name: app
      image: registry.example.com/app:latest
      resources: { cpu: 0.25, memory: 0.5Gi }
  scale:
    minReplicas: 1
    maxReplicas: 10
  ingress:
    external: true
    targetPort: 8080
```

## Readiness Assessment Factors

- Application: language/framework compatibility, external dependencies, data persistence, network patterns, startup behavior
- Operational: build time, image size, multi-stage build strategy, health checks, resource limits, logging/monitoring
- Security: base image selection, secrets management, registry access control, network policies
