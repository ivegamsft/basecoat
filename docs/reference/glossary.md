# Glossary

Short definitions for overloaded prompt terms. Prefer the canonical form on
first use. Prefix routing lives in `docs/guides/intent-prefixes.md`.

| Term | Canonical meaning | Qualify or prefer |
|---|---|---|
| WIP | Work in progress | Always say **WIP branch** or **working doc**. Never use bare "WIP". |
| ship-it | Land one specific change: implement, open PR, merge, close linked issue | Prefix `ship-it:`. `fleet: ship-it:` means oldest-first backlog burn using the ship-it loop, not "merge this one diff". Skill: `skills/ship-it/SKILL.md`. |
| cut a release | Informal for publishing a versioned GitHub release | Prefer **publish a release**. Procedure: CHANGELOG, `version.json`, tag, and the ship-it/release control plane. |
| fleet | Whole-repo sprint/backlog operations (triage, PRs, branches, next sprint) | Prefix `fleet:`. Not a synonym for `ship-it:` or `wave:`. |
| wave | One dependency-ordered batch of issues/PRs inside a sprint | Prefix `wave:`. |
| sprint | Plan, execute, or close a single sprint | Prefix `sprint:`. |
| orphan | Issue or PR with no active owner, or a branch whose PR is gone | Say **orphaned PR**, **orphaned branch**, or **orphaned issue**. |
| autopilot | Unattended oldest-to-newest burndown until stopped or blocked | Prefix `autopilot:`. |
| closeout | Sprint-end reporting and carryover | Not "shutdown" or "wrap-up". |

## Related

- `docs/guides/intent-prefixes.md`
- `docs/reference/guidance-vocabulary-syntax-guide.md`
- `docs/guides/ship-it-control-plane.md`
