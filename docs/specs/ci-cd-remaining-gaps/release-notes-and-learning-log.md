# CI/CD Remaining Gaps Release Notes and Learning Log

## Release Notes

- Added the sprint 1 triage doc for the CI/CD remaining gaps.
- Hardened the adoption scanner test for Windows parameter validation.
- Added a null-safe guard in the asset health workflow before indexing `$Matches`.
- Deferred the unreproduced items (`#1696`, `#1710`) as "needs CI evidence".

## Learning Log

### What changed

- The reported Windows validation regression was a test-harness issue, not a product logic defect.
- The asset-health workflow needed defensive regex handling around optional matches.
- Some reported CI failures were already aligned or could not be reproduced locally.

### Follow-up

- Keep the remaining deferred items documented until CI produces a reproducible failure.
- Close out the parent sprint issue once this documentation PR lands.
