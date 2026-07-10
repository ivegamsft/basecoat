---
name: supply-chain-security
compatibility: [github-copilot-cli]
title: Supply Chain Security - SLSA, SBOM, Sigstore
description: "Use when securing build and release pipelines with signing, SBOMs, provenance, and dependency scanning. USE FOR: sign container image with Cosign, generate CycloneDX or SPDX SBOM, add SLSA provenance to GitHub Actions, scan dependencies and images for vulnerabilities, verify release artifact integrity. DO NOT USE FOR: application authorization logic, runtime incident triage only."
category: security
metadata:
  category: security
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Supply Chain Security Skill

Secure software supply chains through artifact signing, SBOM generation, and SLSA provenance.

## Reference Files

| File | Contents |
|------|----------|
| [`references/signing-sbom.md`](references/signing-sbom.md) | Cosign image signing/verification, CycloneDX and SPDX SBOM generation |
| [`references/slsa-scanning.md`](references/slsa-scanning.md) | SLSA Level 3 GitHub Actions workflow, Python dependency and container scanning |

## Quick Reference

| Tool | Purpose |
|------|---------|
| Cosign | Sign and verify container images |
| Syft | Generate CycloneDX or SPDX SBOM |
| Grype | Scan images/SBOMs for vulnerabilities |
| pip-audit | Python dependency vulnerability scanning |
| Trivy | Container and filesystem scanning |
| SLSA Generator | Add SLSA Level 3 build provenance to releases |
