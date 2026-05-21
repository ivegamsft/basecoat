---
name: electron-apps
description: "Use when building secure, production-ready Electron desktop apps with guidance for IPC, preload APIs, packaging, updates, and renderer isolation. USE FOR: secure Electron IPC design, preload script API patterns, package and sign desktop app, implement auto-update flow, review BrowserWindow security settings. DO NOT USE FOR: generic web SPA architecture, mobile app development, browser extension work."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Development & Review"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Electron Application Development

Secure IPC design, preload APIs, packaging, and release automation for production Electron apps.

## Reference Files

| File | Contents |
|------|----------|
| [`references/process-architecture.md`](references/process-architecture.md) | Main/renderer process model, IPC patterns, Content Security Policy |
| [`references/packaging-updates.md`](references/packaging-updates.md) | State management, Forge packaging, macOS signing, auto-updates |
| [`references/testing-security.md`](references/testing-security.md) | Unit tests (Jest), integration tests (WebdriverIO), security checklist |

## Key Patterns

| Pattern | Rule |
|---------|------|
| BrowserWindow | `nodeIntegration: false`, `sandbox: true`, `enableRemoteModule: false` |
| IPC | `contextBridge.exposeInMainWorld` + `ipcMain.handle` — no raw Node in renderer |
| CSP | Strict CSP `<meta>` tag in every HTML file |
| State (single window) | React Query over `window.api.*` |
| State (multi-window) | `ipcMain` broadcast from main process |
| Secrets | `process.env` in main only — never in renderer or source |
| Packaging | Sign installers, notarize macOS, verify auto-update metadata |
