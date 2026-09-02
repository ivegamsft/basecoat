## 4.2.1 - 2026-08-31

### Added

- Added the repo-cleanup skill and `repo-cleanup:` intent prefix. (#2903)
- Added downstream prompt catalog documentation. (#2856)
- Registered `basecoat-sheen` as the delegate for UI, UX, IA, and design routing. (#2867)

### Changed

- Trimmed oversized agent files through token-budget waves 14 through 19. (#2928, #2930, #2931, #2932, #2934, #2950)
- Documented stacked PR integration, branch-hygiene cleanup, explicit ship-it defaults, product design onboarding, and release authorization decisions. (#2841, #2849, #2850, #2870, #2904, #2959)
- Added BaseCoat release-audit token bootstrap guidance before retiring the token for the internal repository release path. (#2913, #2959)

### Fixed

- Stabilized dependency graph report generation. (#2848)
- Waited for current-head automated review and auto-approved trusted merge-eligibility runs blocked by the Copilot review race. (#2869, #2892)
- Completed front matter model coverage and restored repo-health validation. (#2872, #2901)
- Upgraded gh-aw and Node GitHub Actions pins for current runner compatibility. (#2884, #2886, #2920)
- Deduplicated GitHub Issue Filing boilerplate and repaired agent vocabulary extraction. (#2907, #2924)
- Restored CI by enforcing the repo-cleanup skill budget and failing closed when downstream workflows are missing. (#2941, #2942)
- Corrected bulk-rename over-match corruption across docs. (#2945)
- Granted self-healing CI the GitHub Actions toolset. (#2948)
- Prevented skipped solo-dev cloud workflow approvals. (#2954)
- Preserved extracted guidance safety for idempotent retries, Kustomize rendering, and Argo CD drift/recovery. (#2958)

