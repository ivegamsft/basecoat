---
description: Setup and best practices for npm workspaces and monorepo management
applyTo: "**/package.json,**/turbo.json,**/pnpm-workspace.yaml"
---

# npm Workspaces Instruction

## Overview

npm workspaces enable you to manage multiple interdependent packages within a single repository (monorepo). This instruction covers setting up workspaces, managing dependencies, integrating with build tools, and optimizing CI/CD pipelines.

## Monorepo Structure

A typical npm workspace monorepo structure looks like this:

```text
my-monorepo/
├── package.json (root workspace file)
├── tsconfig.json
├── turbo.json (if using Turborepo)
├── pnpm-workspace.yaml (if using pnpm)
├── packages/
│   ├── core/
│   │   └── package.json
│   ├── ui/
│   │   └── package.json
│   └── utils/
│       └── package.json
├── apps/
│   ├── web/
│   │   └── package.json
│   └── mobile/
│       └── package.json
└── tools/
    ├── build/
    │   └── package.json
    └── lint/
        └── package.json
```

## Setting Up npm Workspaces

### Root Package Configuration

Define your workspaces in the root `package.json`:

```json
{
  "name": "my-monorepo",
  "private": true,
  "workspaces": [
    "packages/*",
    "apps/*",
    "tools/*"
  ],
  "devDependencies": {
    "typescript": "^5.0.0",
    "turbo": "^1.0.0"
  }
}
```

### Workspace Package Configuration

Each workspace package has its own `package.json`:

```json
{
  "name": "@monorepo/core",
  "version": "1.0.0",
  "private": false,
  "main": "dist/index.js",
  "exports": {
    ".": "./dist/index.js"
  },
  "dependencies": {
    "@monorepo/utils": "workspace:*"
  },
  "devDependencies": {
    "typescript": "workspace:*"
  }
}
```

## Shared Packages

### Creating a Shared Package

Create a package in the `packages/` directory that can be used by other workspaces:

```text
packages/utils/
├── package.json
├── src/
│   ├── index.ts
│   ├── string.ts
│   └── array.ts
└── tsconfig.json
```

### Using Shared Packages

Reference shared packages using the workspace protocol (`workspace:*`):

```json
{
  "dependencies": {
    "@monorepo/utils": "workspace:*"
  }
}
```

Or with a specific version:

```json
{
  "dependencies": {
    "@monorepo/utils": "workspace:^1.0.0"
  }
}
```

## Cross-Workspace Dependencies

### Declaring Dependencies

When a workspace depends on another workspace, declare it in `devDependencies` or `dependencies`:

```json
{
  "name": "@monorepo/web",
  "dependencies": {
    "@monorepo/core": "workspace:*",
    "@monorepo/ui": "workspace:*"
  }
}
```

### Dependency Resolution

npm automatically resolves workspace dependencies without requiring separate installations. Use `npm ls` to visualize the dependency tree:

```bash
npm ls --workspaces
```

### Managing Shared Dependencies

Hoist common dependencies to the root to avoid duplication:

```json
{
  "name": "my-monorepo",
  "devDependencies": {
    "typescript": "^5.0.0",
    "eslint": "^8.0.0"
  }
}
```

## Workspace Scripts

### Running Scripts in All Workspaces

Use `npm run` with the `--workspaces` flag:

```bash
npm run build --workspaces
```

### Running Scripts in Specific Workspaces

Target a single workspace:

```bash
npm run build --workspace=@monorepo/core
```

Or multiple workspaces:

```bash
npm run build --workspace=@monorepo/core --workspace=@monorepo/ui
```

### Defining Workspace Scripts

Each workspace can have its own scripts in `package.json`:

```json
{
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "lint": "eslint src/",
    "dev": "tsc --watch"
  }
}
```

## Turborepo Integration

### Installing Turborepo

```bash
npm install --save-dev turbo
```

### Configuring Turborepo

Create a `turbo.json` file at the root:

```json
{
  "$schema": "https://turborepo.org/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"],
      "cache": true
    },
    "test": {
      "dependsOn": ["build"],
      "cache": false
    },
    "lint": {
      "cache": true
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### Running Tasks with Turborepo

```bash
npx turbo run build
npx turbo run test --filter=@monorepo/core
npx turbo run build --parallel
```

## pnpm Workspaces

### Configuration

If using pnpm instead of npm, create `pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"
  - "apps/*"
  - "tools/*"
```

### Installation

```bash
pnpm install
```

### Running Scripts

```bash
pnpm --filter "@monorepo/core" build
pnpm --recursive build
```

## Publishing Workspaces

### Setting Up for Publishing

Mark public workspaces:

```json
{
  "name": "@monorepo/core",
  "private": false,
  "version": "1.0.0",
  "publishConfig": {
    "access": "public"
  }
}
```

### Publishing Changes

```bash
npm publish --workspace=@monorepo/core
```

### Using changesets (Recommended)

Install changesets:

```bash
npm install --save-dev @changesets/cli
```

Create a changeset:

```bash
npx changeset
```

Publish packages:

```bash
npx changeset publish
```

## Dependency Hoisting Strategies

### Root-Level Hoisting

Hoist frequently used dependencies to the root:

```json
{
  "name": "my-monorepo",
  "devDependencies": {
    "typescript": "^5.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.0.0"
  }
}
```

### Workspace-Specific Dependencies

Keep workspace-specific dependencies local:

```json
{
  "name": "@monorepo/api",
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5"
  }
}
```

### Peer Dependencies

Clearly declare peer dependencies:

```json
{
  "name": "@monorepo/react-ui",
  "peerDependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
```

## CI/CD Optimization for Monorepos

### Selective Testing

Only test affected workspaces:

```bash
npx turbo run test --filter=[origin/main...HEAD]
```

### Caching Strategies

Enable caching in Turborepo to skip unchanged workspaces:

```json
{
  "pipeline": {
    "build": {
      "outputs": ["dist/**"],
      "cache": true
    }
  }
}
```

### GitHub Actions Example

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: "18"
      - run: npm ci
      - run: npx turbo run build lint test --cache-dir=.turbo
```

### Dependency Caching

Cache `node_modules` to speed up CI:

```yaml
- uses: actions/setup-node@v3
  with:
    node-version: "18"
    cache: "npm"
```

### Incremental Builds

Build only affected packages:

```bash
npx turbo run build --filter=[main...HEAD]
```

## Best Practices

- Keep workspace names consistent with scoped packages (e.g., `@monorepo/core`)
- Use the `workspace:*` protocol for internal dependencies
- Hoist shared dev dependencies to reduce duplication
- Configure TypeScript path aliases for easier imports:

```json
{
  "compilerOptions": {
    "paths": {
      "@monorepo/core": ["packages/core/src"],
      "@monorepo/ui": ["packages/ui/src"]
    }
  }
}
```

- Use Turborepo or nx for task orchestration and caching
- Implement changesets for version management and changelog generation
- Document workspace purposes and dependencies in a README
