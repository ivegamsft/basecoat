# Latest Release Notes

## 4.6.2 - 2026-10-06

### Changed

- Exclude generated `package-lock.json` churn from PR size labels so lockfile-dominated dependency fixes are sized by reviewable changes; lockfile content stays gated by the npm lock integrity policy (#3563).
- Reduce PR merge latency by running isolated Windows core and sync lanes under the single required Windows job without weakening solo-dev gates (#3521).
- Report inaccessible or unverifiable downstream surfaces as unknown in the post-onboarding drift scorecard and keep remediation open until all surfaces are measured (#3522).

### Fixed

- Make the PR-time public payload identifier gate evaluate the real payload instead of passing vacuously (#3548).
- Use a per-PR concurrency group for size labeler dispatches (#3569).
- Remediate npm audit findings, including critical `proxy-addr`, across the MCP extension, portal, SDK, plugin, and skill packages; upgrade the Jest chain to a non-vulnerable major (#3553, #3554, #3555, #3556, #3557, #3558, #3559, #3560, #3561).
- Publish 4.6.1 release notes to the latest release notes report (#3546).
