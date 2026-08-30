# Dependency Lifecycle Agent — Detail Reference

Full capability catalog for `agents/basecoat-10-core-dependency-lifecycle.agent.md`.

## Capabilities

- **Dependency Update Tracking**: Monitor package versions, identify available updates, and track update history
- **Breaking Change Detection**: Analyze version changes for breaking changes and compatibility issues
- **Upgrade Path Planning**: Generate safe upgrade strategies with staged rollout options
- **CVE/Vulnerability Monitoring**: Track security advisories and prioritize vulnerability patching
- **Semantic Versioning Analysis**: Parse and interpret semver ranges, constraints, and pre-release versions
- **Migration Guide Generation**: Create detailed migration documents for major version upgrades
- **Lock File Management**: Maintain reproducible builds and manage dependency resolution conflicts

## Dependency Analysis

### Version Information

```yaml
- Current version
- Latest available version
- Pre-release versions
- Deprecated versions
- Maintenance status
```

### Dependency Graph

```yaml
- Direct dependencies
- Transitive dependencies
- Circular dependency detection
- Dependency conflicts
- Peer dependency requirements
```

### Compatibility Assessment

```yaml
- Engine requirements (Node, Python, etc.)
- Platform compatibility
- Architecture requirements
- Operating system support
```

## Upgrade Strategies

### Patch Updates

Patch releases (X.Y.Z) typically include bug fixes and minor improvements with no breaking changes. The agent recommends:

- Automatic application for security patches
- Batch testing across test suite
- Rapid deployment to production

### Minor Version Updates

Minor releases (X.Y.0) introduce backwards-compatible features. The agent coordinates:

- Feature compatibility assessment
- Changelog review and documentation
- Staged testing in development environments
- Gradual rollout with monitoring

### Major Version Updates

Major releases (X.0.0) may include breaking changes. The agent provides:

- Breaking change enumeration
- Migration path planning
- Test coverage requirements
- Rollback procedures

## Security Scanning

### Vulnerability Detection

The agent monitors multiple security databases:

```yaml
- National Vulnerability Database (NVD)
- GitHub Security Advisories
- NPM Security Registry
- Python Safety Database
- Maven Central Security Alerts
```

### Risk Assessment

```yaml
- CVSS scoring and severity classification
- Exploitability analysis
- Affected version ranges
- Available patches and workarounds
```

### Compliance Tracking

```yaml
- License compliance verification
- SBOM (Software Bill of Materials) generation
- Supply chain risk assessment
- Policy violation detection
```

## Integration Points

### Version Control Integration

The agent integrates with Git workflows to:

- Create feature branches for dependency updates
- Generate pull requests with changelogs
- Manage merge conflicts in lock files
- Track upgrade commit history

### CI/CD Pipeline Integration

```yaml
- Pre-commit: Lock file validation
- Build: Dependency tree analysis and vulnerability scanning
- Test: Compatibility testing and regression detection
- Deploy: Staged rollout with health checks
```

### Package Registry Integration

The agent connects to:

- npm Registry (Node.js packages)
- PyPI (Python packages)
- Maven Central (Java packages)
- NuGet Gallery (.NET packages)
- RubyGems (Ruby packages)

### Monitoring and Observability

The agent tracks:

- Dependency vulnerability trends
- Update lag behind latest releases
- Supply chain health metrics
- Performance impact of upgrades
- Error rates post-deployment

## Output Format

| Section | Content |
|---------|---------|
| Dependency Report | Current versions, latest versions, and available updates with semver analysis |
| Vulnerability Summary | Identified CVEs, CVSS scores, affected versions, and remediation steps |
| Breaking Changes | List of incompatibilities found between current and target versions |
| Upgrade Strategy | Phased upgrade plan with testing checkpoints and rollback procedures |
| Migration Guide | Step-by-step instructions and code examples for major version transitions |
| Lock File Changes | Updated dependency specifications and resolution information |
| Testing Plan | Test coverage requirements and validation procedures for the upgrade |
