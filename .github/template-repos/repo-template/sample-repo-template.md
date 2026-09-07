# Sample Repository Template

This sample shows a template repository setup that installs and enforces Base Coat in new repositories.

## Included Files

- `.github/base-coat.lock.json`: pinned Base Coat source and version.
- `.github/basecoat-hook-profiles.json`: hook onboarding profiles that enable or disable standardized `.github/hooks/*.json` packs.
- `.github/hooks/*.json`: native hook pack files using platform-safe event names such as `Stop` and `errorOccurred`.
- `scripts/hooks/*`: safe default bash and PowerShell stubs for the hook packs.
- `.github/workflows/bootstrap-basecoat-template.yml`: installs Base Coat from the pinned release.
- `.github/workflows/enforce-basecoat-template.yml`: blocks drift and validates baseline presence.

## Quick Start

1. Copy this template structure into your new repository template.
2. Update `.github/base-coat.lock.json` for your organization and approved version.
3. Pick a hook onboarding profile in `.github/basecoat-hook-profiles.json`
   (`none`, `memory`, `guardrails`, `lane-closeout`, or `standard`).
4. Run `Bootstrap Base Coat From Lock` workflow.
5. Commit imported `.github/base-coat` files plus the selected `.github/hooks/*.json` packs.
6. Add the consumer repo's `.github/basecoat-onboarding-profile.json` and run
   `scripts/bootstrap.ps1` from the imported BaseCoat content.
7. Install downstream workflows with `scripts/configure-downstream-workflows.ps1`.
8. Keep default workflow permissions read-only. If the repo installs
   PR-creating automation such as `issue-to-spec-synthesis.yml`, enable
   **Allow GitHub Actions to create and approve pull requests** only where the
   policy can be constrained to the repo or org. Do not enable an
   Enterprise-wide global checkbox solely for one downstream repo.
9. Set `enforce-basecoat-template` as a required status check.

## Notes

- Keep lock updates and Base Coat content updates in the same pull request.
- Avoid direct edits under `.github/base-coat` except approved upgrade pull requests.
- `lane-closeout` captures dirty WIP to a unique `wip/` ref, pushes when safe,
  and conservatively records `PARKED`; full classification is deferred to the
  skill, and the hook never performs destructive cleanup.
- `standard` is the recommended profile. It includes safe lane closeout with
  session memory, tool guardrails, and error and budget handling.
