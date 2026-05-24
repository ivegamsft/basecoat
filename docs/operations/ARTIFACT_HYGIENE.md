# Artifact Hygiene

## Why it matters

Generated artifacts committed to git bloat repository history, cause noisy diffs,
and can expose build-environment details. As new workflows and tooling are added to
BaseCoat, the risk of accidentally committing generated output grows. Keeping
`.gitignore` up to date prevents these issues before they accumulate.

## Expected artifact patterns

| Pattern | Source |
|---|---|
| `site/` | MkDocs generated documentation site |
| `dist/` | Build and packaging output |
| `node_modules/` | npm / Node.js dependencies |
| `*.db` | SQLite databases (e.g. local dev caches) |
| `test-results/` | Test runner output and failure logs |
| `.terraform/` | Terraform working directory |
| `__pycache__/` | Python bytecode cache directories |
| `*.pyc` | Python compiled bytecode files |
| `.pytest_cache/` | pytest cache directory |
| `coverage/` | Code coverage report output |
| `.nyc_output/` | NYC / Istanbul JavaScript coverage data |
| `*.log` | Log files from any tooling |

## Adding new patterns

When introducing new tooling that produces generated output:

1. Identify all directories and file extensions the tool writes.
2. Add each pattern to `.gitignore` at the repository root.
3. Add a corresponding entry to the `$patterns` array in
   `scripts/check-gitignore-coverage.ps1` with a short rationale string.
4. Run the coverage check to confirm no warnings remain.

## Running the coverage check

```powershell
pwsh scripts/check-gitignore-coverage.ps1
```

The script exits 0 in all cases by default (advisory mode). A `-Strict` flag is
available to exit 1 on any warning, which can be used to gate a PR or workflow:

```powershell
pwsh scripts/check-gitignore-coverage.ps1 -Strict
```

The check is also wired into the full test suite (`tests/run-tests.ps1`) as a
non-blocking advisory step.
