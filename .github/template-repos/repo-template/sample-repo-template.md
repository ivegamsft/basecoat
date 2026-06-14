# Sample Repository Template

This sample shows a template repository setup that installs and enforces Base Coat in new repositories.

## Included Files

- `.github/base-coat.lock.json`: pinned Base Coat source and version.
- `.github/workflows/bootstrap-basecoat-template.yml`: installs Base Coat from the pinned release.
- `.github/workflows/enforce-basecoat-template.yml`: blocks drift and validates baseline presence.

## Quick Start

1. Copy this template structure into your new repository template.
2. Update `.github/base-coat.lock.json` for your organization and approved version.
3. Run `Bootstrap Base Coat From Lock` workflow.
4. Commit imported `.github/base-coat` files.
5. Set `enforce-basecoat-template` as a required status check.

## Notes

- Keep lock updates and Base Coat content updates in the same pull request.
- Avoid direct edits under `.github/base-coat` except approved upgrade pull requests.
