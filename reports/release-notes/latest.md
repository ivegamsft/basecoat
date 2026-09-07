# Latest Release Notes

## 4.3.0 - 2026-09-07

### Added

- Enforced SHA-pinned workflow Actions for consumer repositories. (#3123)
- Added synthesized governance PRD/specs for enforced prose rules, standards mapping, untrusted-content boundaries, tracker mutation review gates, Enterprise PR-toggle onboarding, IP/licensing posture, Responsible AI/privacy review, and warn-rules remediation. (#3160, #3161, #3184, #3185, #3187, #3182, #3183, #3186)
- Preserved fail-closed governance-control criteria for the issue #2976 PRD/spec after the original synthesis PR auto-merged. (#3191)

### Changed

- Compared BaseCoat and HVE governance approaches to guide the governance enhancement backlog. (#3120)
- Documented PR-creation platform permission scope, downstream template setup boundaries, and fallback credential guidance for solo-dev and downstream onboarding. (#3156, #3157)

### Fixed

- Repaired changelog generation, actionlint queue probing, and automation PR authentication. (#3121, #3126, #3132)
- Refreshed vulnerable dependency locks and package overrides across skill, SDK, portal, and workflow surfaces. (#3122, #3124, #3133, #3135)
- Repaired synthesized PRD/spec intake by reconciling labels, splitting read/write token use, removing duplicate Octokit initialization, and preventing production-token fallback writes to the source repo. (#3148, #3149, #3151, #3152, #3153)
- Redacted private source tracker links from public mirror artifacts. (#3150)
