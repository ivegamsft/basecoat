---
description: "Use when building secure Electron desktop applications. Covers process architecture, inter-process communication, content security policy, code signing, auto-updates, credential storage, and ASAR integrity. Reference skill at skills/electron-apps/SKILL.md for implementation patterns."
applyTo: "**/electron/**/*.{ts,tsx,js,jsx,cjs,mjs,json,yml,yaml},**/*electron*.{ts,tsx,js,jsx,cjs,mjs,json,yml,yaml,md}"
---

# Electron Desktop Application Security Standards

Use this instruction when developing Electron applications to ensure secure process architecture, IPC patterns, and protective measures against common desktop vulnerabilities.

## Expectations

- All renderer processes run in sandbox mode with `nodeIntegration: false`.
- IPC is restricted to explicit preload-exposed APIs via `contextBridge`.
- `child_process.spawn()` is restricted to whitelisted commands; `shell: false` always.
- All executables are code-signed (Windows/macOS).
- Auto-updates validate checksums before installing.
- Sensitive credentials are stored in OS keychains, never in application memory or files.
- CSP headers restrict inline scripts and external resource loading.
- ASAR packages are integrity-checked on load.

## Process Architecture

Electron runs two processes with distinct privilege levels:

| Process | Runtime | Privileges | Responsibility |
|---|---|---|---|
| **Main** | Node.js | Full system access | App lifecycle, native APIs, file I/O, window management |
| **Renderer** | Chromium | Restricted (sandboxed) | UI rendering, user interaction, DOM manipulation |

**Critical**: Renderer processes are the attack surface. Restrict their capabilities aggressively.

## Reference Files

| File | Contents |
|---|---|
| [`references/electron/ipc-security.md`](references/electron/ipc-security.md) | Preload script patterns, main process IPC handlers, safe file path access, anti-patterns |
| [`references/electron/csp-child-process.md`](references/electron/csp-child-process.md) | CSP directives table, child process whitelisting, code signing, auto-updates, credential storage |

## IPC, CSP & Child Process Summary

- Use `contextBridge.exposeInMainWorld()` in preload scripts — never expose `ipcRenderer`, `require`, or `process` directly.
- Main process handlers validate all input and return only necessary fields.
- Prevent path traversal by normalizing paths and checking they start within a safe root.
- CSP: `default-src 'none'; script-src 'self'` — block inline scripts and external resources.
- Child processes: use `spawn()` with `shell: false`, a command whitelist, and argument metacharacter validation.
- Code signing: sign binaries with platform tools (`codesign` on macOS, `signtool` on Windows).
- Auto-updates: call `autoUpdater.checkForUpdatesAndNotify()`; verify SHA-256 checksums before install.
- Credentials: use `keytar` (OS keychain) — never store in config files or application memory.
- ASAR integrity: compute SHA-256 hash of `app.asar` on `app.on('ready')` and quit if mismatch.

## Review Lens

When reviewing Electron code, verify:

- [ ] All renderer processes run with `sandbox: true` in `webPreferences`.
- [ ] `nodeIntegration` is explicitly set to `false`.
- [ ] `enableRemoteModule` is set to `false`.
- [ ] IPC is restricted to explicit preload-exposed APIs.
- [ ] Preload scripts use `contextBridge` to expose only necessary functions.
- [ ] All IPC handlers validate input and sanitize responses.
- [ ] `child_process.spawn()` never uses `shell: true`.
- [ ] Commands are whitelisted; arguments are validated for shell metacharacters.
- [ ] CSP headers are enforced; inline scripts are blocked.
- [ ] Credentials are stored in OS keychains, not files or memory.
- [ ] Code is signed for distribution (Windows/macOS).
- [ ] Auto-updates validate checksums before installation.
- [ ] ASAR packages are integrity-checked on load.

## Standards and References

- **Electron Security** — Official Electron documentation on security best practices.
- **OWASP Desktop Application Security** — Guidance for desktop app vulnerabilities.
- **CWE-502 (Deserialization of Untrusted Data)** — Risk of unmarshaling untrusted objects.
- **CWE-95 (Improper Neutralization of Directives in Dynamically Evaluated Code)** — Code injection via eval/exec.
- **CWE-426 (Untrusted Search Path)** — Risk of loading compromised modules from PATH.
