# Guardrail: GitHub Actions Must Use Immutable SHA Pins

## Rule

Consumer workflows must pin every external `uses:` reference to a full
40-character commit SHA. Mutable refs such as `@v4`, `@main`, branch names, and
short SHAs are forbidden for actions and reusable workflows.

Local actions referenced with `./` are allowed because they are versioned with
the repository checkout. Docker action references must use an immutable
`@sha256:` digest.

## Why

| Reason | Detail |
|---|---|
| **Supply-chain safety** | Mutable action tags can be repointed by the action owner after review. |
| **Reproducibility** | Full SHAs make a workflow run resolve the same action code every time. |
| **Auditability** | Incident review can map every workflow dependency to an exact commit or image digest. |

## Pattern

Use the full action commit SHA:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
```

Do not use mutable tags:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

## How to Verify

After installing or syncing BaseCoat, run the consumer workflow validator from
the installed baseline:

```bash
python .github/base-coat/scripts/validate-workflow-action-pins.py --root . --mode consumer
```

PowerShell users can run the wrapper:

```powershell
pwsh .github/base-coat/scripts/validate-workflow-action-pins.ps1 -RootDir . -Mode Consumer
```

## Enforcement

- The BaseCoat repo template enforces this guardrail in
  `.github/workflows/enforce-basecoat-template.yml`.
- The validator scans consumer `.github/workflows/**` files and fails on
  executable `uses:` references that are not full commit SHAs or Docker digests.
- Direct edits to generated `.github/base-coat/**` content remain blocked by the
  template enforcement workflow; consumers should update their BaseCoat version
  and re-sync instead.
