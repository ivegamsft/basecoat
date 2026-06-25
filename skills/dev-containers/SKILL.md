---
name: dev-containers
compatibility: [github-copilot-cli]
description: "VS Code Dev Containers and GitHub Codespaces guidance for reproducible development environments and team onboarding. USE FOR: create devcontainer.json for this repo, set up Codespaces for contributors, containerize local dev toolchain, add VS Code extensions inside container, make development setup reproducible across machines. DO NOT USE FOR: production container deployment, Kubernetes runtime troubleshooting, packaging a desktop application."
---
# VS Code Dev Containers

Reproducible development environments using VS Code Dev Containers and GitHub Codespaces.
Eliminates "works on my machine" by bundling runtimes, tools, and extensions in Docker.

## Reference Files

| File | Contents |
|------|----------|
| [`references/configuration.md`](references/configuration.md) | devcontainer.json structure (minimal & full), image selection, features, extensions, port forwarding, mounts |
| [`references/workflows.md`](references/workflows.md) | GitHub Codespaces, CI integration, Docker Compose, lifecycle hooks, best practices |

## Minimal Config

```json
{
  "name": "My Project",
  "image": "mcr.microsoft.com/vscode/devcontainers/python:3.12",
  "features": { "ghcr.io/devcontainers/features/github-cli:1": {} },
  "postCreateCommand": "pip install -r requirements.txt"
}
```

## Key Rules

- Commit `devcontainer.json` to git (team consistency)
- Pin feature and image versions — avoid `latest`
- Never embed credentials in `Dockerfile` or `devcontainer.json`
- Use `postCreateCommand` scripts for idempotent setup


