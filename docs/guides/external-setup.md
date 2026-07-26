# External Setup Guide

This guide covers the minimum setup for external or consumer repositories that need to
consume BaseCoat assets and shared guidance.

## Sync BaseCoat assets

Run sync from the consumer repository root:

```bash
BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git ./sync.sh
```

On PowerShell:

```powershell
$env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
.\sync.ps1
```

## Reference the shared Copilot Space

Consumers should use the canonical BaseCoat Copilot Space for their source organization:

- **Owner**: `YOUR-ORG`
- **Name**: `base-coat`

If your consumer repo references a different owner than your source BaseCoat repo,
update it so prompts resolve the shared, maintained guidance.

## Keep versions pinned in production

Use `BASECOAT_REF` to pin to a release tag:

```bash
BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git \
BASECOAT_REF=v4.0.0 ./sync.sh
```
