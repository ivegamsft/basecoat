# Enterprise Runners

## Overview

Base Coat leverages enterprise runners from the `shared-build-agents` pool to enable scalable, high-performance CI/CD workflows. Enterprise runners provide specialized hardware capabilities, network isolation, and advanced security features beyond what GitHub-hosted runners offer.

### Available Runner Pools

The following enterprise runner pools are available:

- **shared-build-agents** - Primary pool for general-purpose CI/CD tasks
- **shared-build-agents-gpu** - GPU-accelerated runners for ML/AI workloads
- **shared-build-agents-large** - High-memory, multi-CPU runners for intensive operations

## Runner Labels and Capabilities

Enterprise runners expose capabilities through labels that allow precise runner selection in workflow YAML.

### Operating System Labels

| Label | OS | Version | Notes |
|-------|-----|---------|-------|
| `ubuntu-latest` | Linux | Ubuntu 22.04 LTS | Standard Ubuntu runner |
| `ubuntu-22.04` | Linux | Ubuntu 22.04 | Pinned version |
| `ubuntu-20.04` | Linux | Ubuntu 20.04 | Legacy support |
| `windows-latest` | Windows | Windows Server 2022 | Standard Windows runner |
| `windows-2022` | Windows | Windows Server 2022 | Pinned version |
| `macos-latest` | macOS | macOS 12+ | Intel-based |
| `macos-arm64` | macOS | macOS 12+ | Apple Silicon (M1/M2) |

### Architecture-Specific Labels

| Label | Architecture | Use Cases |
|-------|--------------|-----------|
| `x86_64` | Intel/AMD 64-bit | Standard Linux/Windows workloads |
| `arm64` | ARM 64-bit | Embedded systems, mobile, Apple Silicon |
| `armv7` | ARM 32-bit | Legacy ARM systems |

### GPU-Enabled Runners

GPU runners are available for machine learning, image processing, and compute-intensive workloads.

| Label | GPU | VRAM | Notes |
|-------|-----|------|-------|
| `gpu-nvidia-a100` | NVIDIA A100 | 80GB | High-performance AI training |
| `gpu-nvidia-a10` | NVIDIA A10 | 24GB | General ML inference |
| `gpu-nvidia-t4` | NVIDIA T4 | 16GB | Cost-effective inference |

### Large Runner Labels

| Label | CPU Cores | Memory | Storage | Notes |
|-------|-----------|--------|---------|-------|
| `large-x86` | 16+ | 64GB | 500GB+ | Intensive builds, large test suites |
| `large-memory` | 8 | 256GB | 1TB+ | Memory-intensive workloads |
| `large-storage` | 8 | 64GB | 2TB+ | Large artifact handling |

### Combined Label Examples

Runners may have multiple labels assigned. Common combinations include:

```text
shared-build-agents
ubuntu-latest
x86_64
self-hosted
linux
```

```text
shared-build-agents-gpu
ubuntu-latest
gpu-nvidia-a100
x86_64
self-hosted
linux
```

```text
shared-build-agents-large
ubuntu-latest
large-x86
self-hosted
linux
```

## Runner Selection in Workflows

### Basic Runner Selection

Specify a single runner or multiple labels in your workflow:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
```

### Multiple Label Requirements

Use an array to require multiple labels (AND logic):

```yaml
jobs:
  gpu-inference:
    runs-on:
      - self-hosted
      - linux
      - gpu-nvidia-a100
    steps:
      - uses: actions/checkout@v4
      - run: python inference.py
```

### Fallback Runner Selection

Use a strategy matrix to try runners in order of preference:

```yaml
jobs:
  build:
    strategy:
      matrix:
        runner:
          - large-x86
          - ubuntu-latest
    runs-on:
      - ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
```

### Enterprise Runner with Specific Architecture

Target ARM64 architecture on macOS:

```yaml
jobs:
  build-apple-silicon:
    runs-on:
      - macos-arm64
      - self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
```

## Self-Hosted vs GitHub-Hosted Runners

### GitHub-Hosted Runners

GitHub-hosted runners are ephemeral, managed by GitHub, and included with GitHub Actions.

Pros:

- No infrastructure management required
- Automatic OS patching and updates
- Immediate availability, no queue
- Clean environment for each job
- Included in plan (2,000 minutes/month free on public repos)

Cons:

- Limited to 20 GB of storage
- 7 GB of RAM (standard), 14 GB (large)
- Slower for large monorepos or extensive artifact handling
- Cannot access private networks or on-premises resources
- Limited customization options

### Self-Hosted Enterprise Runners

Self-hosted runners are provisioned from the enterprise runner pool and managed by the infrastructure team.

Pros:

- Customizable hardware (CPU, memory, storage, GPU)
- Access to private networks and on-premises resources
- Persistent caching reduces build times
- Cost-effective for high-volume CI/CD
- Support for specialized dependencies (CUDA, ML frameworks)
- Network isolation and security controls

Cons:

- Requires infrastructure maintenance
- Potential queue during peak usage
- Security responsibility shifts to team
- Must manage runner software updates
- Idle runner capacity costs

### Decision Matrix

| Requirement | GitHub-Hosted | Self-Hosted |
|-------------|---------------|-------------|
| Basic Node/Python builds | ✅ Preferred | ⏸ Overkill |
| GPU workloads | ❌ Unavailable | ✅ Required |
| >100GB artifacts | ❌ Limited | ✅ Supported |
| Private network access | ❌ No | ✅ Yes |
| High-volume CI/CD | ❌ Expensive | ✅ Cost-effective |
| Regulatory compliance | ❌ Shared tenancy | ✅ Isolated |
| Persistent cache | ❌ Not available | ✅ Supported |

## Security Considerations

### Network Isolation

Enterprise runners operate in isolated network segments with restricted egress rules.

### Default Outbound Access

- ✅ GitHub API and repository access
- ✅ npm, PyPI, and other public package registries
- ❌ Direct internet access restricted
- ❌ Private network access requires VPN tunnel

### Requesting Network Access

Contact the infrastructure team to add network routes for specific services:

```text
Request format:
- Destination CIDR or hostname
- Port and protocol (TCP/UDP)
- Justification and use case
- Expected data volume
```

### Secrets Management

Secrets are encrypted at rest and in transit. Handle with care:

### Best Practices

- Use GitHub Secrets for sensitive data (tokens, credentials)
- Never log secrets in workflow output
- Rotate secrets regularly (quarterly minimum)
- Use separate secrets for each environment (dev, staging, prod)
- Audit secret access through GitHub's audit logs

### Example: Safe Secret Handling

```yaml
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Deploy with credentials
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          # Token is available only in this step
          ./scripts/deploy.sh
          # Token is not logged by default
          echo "Deployment complete"
```

### Access Control

Runner access is governed by GitHub team membership and repository permissions.

### Permission Levels

- **Repository Collaborators** - Can trigger workflows (all runners available)
- **Organization Members** - Can access shared runners if granted permission
- **External Contributors** - Workflows require approval before running on enterprise runners

### Approval Workflow

1. Contributor opens pull request
1. GitHub Actions workflow requires approval (first-time contributors)
1. Repository maintainer reviews PR and approves workflow run
1. Workflow proceeds on appropriate runner

### Audit Logging

All runner activity is logged and auditable:

```bash

# View runner usage in GitHub

gh api repos/owner/repo/actions/runs \
  --paginate \
  --jq '.workflow_runs[] | {name, status, runner_name, created_at}'
```

## Capacity Planning and Autoscaling

### Current Capacity

| Pool | Total Runners | Typical Queue Time | Peak Utilization |
|------|---------------|-------------------|------------------|
| shared-build-agents | 16 | < 1 min | 80-90% |
| shared-build-agents-gpu | 4 | 5-10 min | 85-95% |
| shared-build-agents-large | 8 | 2-5 min | 75-85% |

### Autoscaling Policy

The enterprise runner infrastructure auto-scales based on queue depth and wait times.

### Scaling Triggers

- Queue depth > 5 jobs for > 5 minutes → scale up
- Average wait time > 10 minutes → scale up
- CPU utilization > 90% for > 10 minutes → scale up
- Idle runners > 30 minutes → scale down

### Scaling Limits

- Maximum concurrent runners: 32 per pool
- Scale-up increment: 2-4 runners per event
- Scale-down window: 30-60 minutes idle time

### Monitoring Queue Depth

Check runner availability before scheduling resource-intensive jobs:

```yaml
jobs:
  check-capacity:
    runs-on: ubuntu-latest
    steps:
      - name: Check GPU runner availability
        run: |
          curl -s <https://runner-api.internal/capacity/gpu> | jq .
          # Response: {"available": 2, "total": 4, "queue_length": 3}
```

### Capacity Requests

For sustained capacity increases, submit a capacity request:

```text
Subject: Enterprise Runner Capacity Request - [PROJECT]

Current Usage:
- Pool: shared-build-agents-gpu
- Daily runs: 50-100
- Average queue time: 15-20 minutes
- Peak concurrent jobs: 8-10

Requested Capacity:
- Additional runners: 4x NVIDIA A100
- Justification: Parallel training jobs for ML pipeline
- Expected ROI: 30% faster model iteration

Timeline: Needed by [DATE]
```

## Troubleshooting Common Runner Issues

### Runner Not Available

**Symptom:** Workflow stuck in "Waiting for a runner..." state.

### Diagnosis

1. Check runner labels match job requirements:

```bash
gh api repos/owner/repo/actions/runs/[run_id] \
  --jq '.jobs[] | {name, status, labels: .runs_on}'
```

1. Verify runner pool status:

```bash
curl -s <https://runner-api.internal/status> | jq '.pools'
```

1. Check for labeling issues:

```yaml

# ❌ Wrong - array of strings treated as OR

runs-on:
  - self-hosted
  - gpu-nvidia-a100

# ✅ Correct - array requires all labels (AND)

runs-on:
  - self-hosted
  - gpu-nvidia-a100
```

### Resolution

- Wait for capacity or request additional runners
- Use fallback runner: `runs-on: ubuntu-latest`
- Schedule job during off-peak hours
- Split large jobs into smaller parallel tasks

### Slow Runner Performance

Symptom: Job takes significantly longer than previous runs.

Diagnosis steps

1. Check runner CPU/memory during job:

```bash

# On the runner (via SSH)

top -b -n 1 | head -20
free -h
df -h /var/lib/docker
```

1. Compare with baseline metrics:

```bash
gh run view [run_id] --json jobs --jq '.jobs[] | {name, conclusion, durationMinutes}'
```

1. Check for I/O contention:

```bash
iostat -x 1 5  # Run during workflow execution
```

Resolution:

- Switch to larger runner: `large-x86` instead of standard
- Optimize job to use less resources (parallel steps, caching)
- Schedule during off-peak to avoid contention
- Check for runaway processes: `ps aux --sort=-%cpu`

### Network Connectivity Issues

Symptom: Download/upload failures, package registry timeouts.

Diagnosis steps

1. Test basic connectivity:

```bash
curl -v <https://registry.npmjs.org>
ping 8.8.8.8
traceroute github.com
```

1. Check network policies:

```bash

# From runner, attempt restricted destinations

curl -v <https://internal-service.local>
```

1. Review firewall logs (infrastructure team):

```bash
sudo journalctl -u firewall | tail -50
```

Resolution:

- Retry with exponential backoff in workflow
- Use CDN/mirror for package registry if available
- Request network route approval for private services
- Check for DNS resolution issues: `nslookup package-name.com`

### Out of Disk Space

Symptom: Job fails with no space left on device.

Diagnosis steps

1. Check disk usage:

```bash
df -h /
du -sh /* | sort -hr | head -10
```

1. Identify large files:

```bash
find / -type f -size +1G 2>/dev/null
docker system df
```

1. Review artifact retention:

```bash
ls -lah ~/.cache ~/.m2 /var/lib/docker/containers
```

Resolution:

- Clean workspace between jobs: `rm -rf *`
- Use Docker layer caching: `actions/setup-buildx-action@v3`
- Compress artifacts before upload
- Reduce artifact retention: `retention-days: 5`
- Request larger runner pool: `large-storage`

## Integration with Base Coat CI Workflows

### Standard Base Coat Workflow

Base Coat CI uses a matrix strategy to test across multiple runners:

```yaml
name: Base Coat CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    strategy:
      matrix:
        runner:
          - ubuntu-latest
          - ubuntu-22.04
        node-version:
          - 18
          - 20
    runs-on:
      - ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm run test
      - uses: codecov/codecov-action@v3
```

### GPU-Accelerated Builds

For ML model training and inference:

```yaml
jobs:
  train-model:
    runs-on:
      - self-hosted
      - gpu-nvidia-a100
    container:
      image: nvidia/cuda:12.2.0-devel-ubuntu22.04
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: pip install -r requirements-gpu.txt
      - name: Train model
        run: python train.py --epochs 100 --batch-size 256
      - name: Upload checkpoint
        uses: actions/upload-artifact@v3
        with:
          name: model-checkpoint
          path: checkpoints/
```

### Large-Scale Build

For monorepos and intensive compilation:

```yaml
jobs:
  build-monorepo:
    runs-on:
      - self-hosted
      - large-x86
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for size calculation
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build:all
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-output
          path: dist/
          retention-days: 30
```

### Conditional Runner Selection

Route jobs to appropriate runners based on conditions:

```yaml
jobs:
  adaptive-test:
    runs-on: ${{ github.event_name == 'pull_request' && 'ubuntu-latest' || 'self-hosted' }}
    steps:
      - uses: actions/checkout@v4
      - run: npm run test
```

### Cross-Platform Builds

Test across multiple OS targets:

```yaml
jobs:
  build-all-platforms:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            artifact: app-linux
          - os: windows-2022
            artifact: app-windows.exe
          - os: macos-arm64
            artifact: app-macos
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.artifact }}
          path: dist/
```

## Contact and Support

For issues, questions, or capacity requests:

- **Infrastructure Team:** #infrastructure-support (Slack)
- **GitHub Actions Docs:** <https://docs.github.com/en/actions>
- **Enterprise Runner Status:** <https://runner-status.internal>
- **Capacity Planning:** Submit request via infrastructure portal
