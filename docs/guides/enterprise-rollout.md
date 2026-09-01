# Enterprise Rollout

This document describes how to distribute Base Coat broadly, safely, and repeatably across an organization.

## Goals

- Make new repositories start from a consistent approved baseline
- Prevent direct drift from ad hoc copy-paste adoption
- Roll out updates through versioned releases and validation gates
- Support Windows, macOS, Linux, and CLI-driven bootstrap paths

## Recommended Distribution Model

1. Validate changes on every pull request.
2. Package versioned artifacts on approved tags.
3. Publish `.zip`, `.tar.gz`, and `SHA256SUMS.txt` as release assets.
4. Mirror approved artifacts to an internal package or release store if required.
5. Require new repositories to bootstrap from a pinned release.

## Bootstrap Channels

### Windows

- Use the release `.zip` artifact or the version-pinned `sync.ps1`
- Prefer PowerShell execution from a known release tag rather than a moving branch

### macOS and Linux

- Use the release `.tar.gz` artifact or the version-pinned `sync.sh`
- Prefer a pinned release over pulling raw content from `main`

### CLI

- Use GitHub CLI or an internal artifact client to download a specific release
- Example: `gh release download v4.2.1 --repo YOUR-ORG/basecoat`

## Governance Model

- Treat Base Coat changes like platform changes, not local repo tweaks
- Use approval rings such as pilot, early adopters, then broad rollout
- Assign ownership for naming, security, and infrastructure conventions
- Publish release notes that state what changed and whether rollout is required or optional

## Safe Defaults For New Projects

- Pin Base Coat by tag or approved artifact version
- Install under `.github/base-coat`
- Record the installed version in project docs or bootstrap metadata
- Run validation in the consumer repo so missing files are detected early

## Suggested Consumer Workflow

1. Bootstrap from the latest approved release
2. Commit the imported Base Coat files to the repository
3. Add a workflow that validates the imported baseline remains present
4. Review upgrades through pull requests instead of direct overwrites
