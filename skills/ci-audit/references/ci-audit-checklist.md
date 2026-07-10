# CI/CD Audit Checklist

Use this checklist to ensure your audit covers all critical areas.

## GitHub Organization Settings

### Runner & Concurrency Configuration

- [ ] Total Actions minutes quota per month
- [ ] Concurrent job limits for GitHub-hosted runners
- [ ] Concurrent job limits for self-hosted runners
- [ ] Default runner allocation (GitHub-hosted vs self-hosted)
- [ ] Workflow run retention period (default vs custom)
- [ ] Queue depth for pending jobs
- [ ] Average job queue wait time

### Secrets & Access Control

- [ ] Secret scanning enabled for repositories
- [ ] Secret push protection enabled
- [ ] Dependabot alerts enabled
- [ ] Dependabot security updates enabled
- [ ] Dependency graph enabled
- [ ] Default token permission scope (read vs write)
- [ ] Token expiration policy configured
- [ ] OAuth app access restrictions applied

### Artifacts & Caching

- [ ] Artifact retention period set (days)
- [ ] Artifact size limits per workflow
- [ ] Cache storage limits configured
- [ ] Cache retention period set
- [ ] Log retention period configured

### Billing & Usage Tracking

- [ ] Actions usage dashboard reviewed
- [ ] Monthly Actions minutes trending
- [ ] Cost per build metric tracked
- [ ] Storage usage trending
- [ ] Peak usage times identified

## Enterprise Settings

### Authentication & SSO

- [ ] SAML SSO enforced (if applicable)
- [ ] IP allowlist configured
- [ ] IP allowlist whitelist rules documented
- [ ] MFA enforcement policy set
- [ ] Session timeout policy configured
- [ ] OAuth token expiration enforced

### Audit & Compliance

- [ ] Audit log retention period configured
- [ ] Audit log access controls in place
- [ ] Audit log archival/export process documented
- [ ] Compliance frameworks mapped (SOC 2, ISO 27001, etc.)
- [ ] Data retention policies documented

### App & API Policies

- [ ] Approved GitHub Apps list maintained
- [ ] Restricted GitHub Apps blocked
- [ ] Custom app review process documented
- [ ] App permission audit performed
- [ ] API rate limits configured
- [ ] Personal access token limits enforced

## Dependency Health

### Node.js Projects

- [ ] `package.json` present and up-to-date
- [ ] `package-lock.json` committed to repo
- [ ] Node version pinned in `.nvmrc` or workflow
- [ ] npm version specified in `package.json`
- [ ] Outdated dependencies identified (`npm outdated`)
- [ ] Security vulnerabilities scanned (`npm audit`)
- [ ] License compliance checked

### Python Projects

- [ ] `requirements.txt` or `Pipfile` present
- [ ] Lock file committed (`requirements.lock` or `Pipfile.lock`)
- [ ] Python version pinned (`.python-version` or workflow)
- [ ] Pip version specified
- [ ] Outdated packages identified (`pip list --outdated`)
- [ ] Security vulnerabilities scanned (`pip-audit`)
- [ ] License compliance checked

### .NET Projects

- [ ] Project files (`*.csproj`) committed
- [ ] `Directory.Build.props` for version management
- [ ] .NET version targeted properly
- [ ] NuGet dependencies pinned or floating
- [ ] `packages.lock.json` committed (if package lock enabled)
- [ ] Outdated packages identified (`dotnet outdated`)
- [ ] License compliance checked

### General Dependency Practices

- [ ] Lock files present for all package managers
- [ ] Dependencies updated at least quarterly
- [ ] Automated dependency scanning enabled (Dependabot)
- [ ] Security patch SLA documented
- [ ] Pre-release dependencies policy documented
- [ ] Transitive dependency conflicts resolved

## Self-Hosted Runner Profiles

### Runner Registration & Status

- [ ] All expected runners registered and visible
- [ ] Runner status (online/offline) verified
- [ ] Runner last activity timestamp checked
- [ ] Runner registration date and age documented
- [ ] Runners deregistered if offline >30 days

### Runner Capacity

- [ ] CPU core allocation documented
- [ ] Memory allocation documented
- [ ] Disk space available documented
- [ ] Capacity vs demand analysis completed
- [ ] Overprovisioned runners identified
- [ ] Underprovisioned runners identified

### Runner Configuration

- [ ] Runner labels documented
- [ ] Label usage in workflows verified
- [ ] Concurrent job limits per runner
- [ ] Job queue depth monitored
- [ ] Average wait time per runner tracked
- [ ] Runner autoscaling configured (if applicable)

### Runner Security & Maintenance

- [ ] Runners on supported OS versions
- [ ] Runners in isolated networks (if required)
- [ ] Runner software updated within SLA
- [ ] Security patches applied timely
- [ ] Runner-to-repo access controlled by labels
- [ ] Sensitive repos restricted to dedicated runners

## GitHub Apps & SDKs

### Installed Apps Inventory

- [ ] GitHub Apps list extracted
- [ ] App permissions documented
- [ ] App access scopes noted
- [ ] Last activity date tracked
- [ ] Unused apps identified (no activity >90 days)
- [ ] App owner/admin contact documented

### Security & Monitoring Apps

- [ ] Dependabot installed and configured
- [ ] Secret scanning app enabled
- [ ] Code scanning (CodeQL) enabled
- [ ] Container scanning enabled
- [ ] Supply chain security app configured

### CI/CD Integration Apps

- [ ] Cloud provider SDKs listed (AWS, Azure, GCP)
- [ ] Authentication method per SDK documented
- [ ] SDK versions pinned or floating
- [ ] SDK update frequency documented
- [ ] SDK security scanning enabled

### Unnecessary Apps & Permission Creep

- [ ] Apps with unused permissions identified
- [ ] Apps with overly broad permissions documented
- [ ] Deprovisioning strategy for unused apps
- [ ] Permission review schedule established

## Workflow Analysis

### Runner Usage Patterns

- [ ] GitHub-hosted runner workflow jobs cataloged
- [ ] Self-hosted runner workflow jobs cataloged
- [ ] Runner label usage mapped to workflows
- [ ] Workflow concurrency constraints documented
- [ ] Workflow timeout settings reviewed

### Performance Metrics

- [ ] Average workflow duration tracked
- [ ] Workflow failure rate calculated
- [ ] Cache hit ratio measured
- [ ] Artifact size distribution analyzed
- [ ] Job parallelization effectiveness assessed

### Cost Attribution

- [ ] Actions minutes per workflow calculated
- [ ] Storage costs per artifact tracked
- [ ] Cost per deployment computed
- [ ] High-cost workflows identified
- [ ] Optimization opportunities prioritized

## Documentation & Handoff

- [ ] Audit findings documented with evidence
- [ ] Recommendations prioritized by ROI
- [ ] Action items assigned to owners
- [ ] Timeline for remediation established
- [ ] Success metrics defined for each recommendation
- [ ] Follow-up audit scheduled (e.g., quarterly)
