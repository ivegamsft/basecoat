---
description: Guard against silent GitHub Actions workflow file corruption and enforce checksum validation when programmatically modifying workflow YAML.
applyTo: ".github/workflows/**/*.{yml,yaml},scripts/**/*.{ps1,sh,py}"
---

# Workflow File Integrity Rules

These rules prevent silent corruption when workflow files are created or modified programmatically.

## Never write workflow YAML with PowerShell Set-Content

PowerShell `Set-Content` and `Out-File` use CRLF line endings by default on Windows, which can cause YAML parsing failures or invisible diffs. Always use Python with binary mode or the file creation tools.

**Bad:**

```powershell
Set-Content -Path .github/workflows/ci.yml -Value $content
```

**Good (Python):**

```python
with open('.github/workflows/ci.yml', 'wb') as f:
    f.write(content.encode('utf-8'))
```

## Validate YAML syntax before committing

After generating or modifying a workflow file, validate it parses correctly.

```bash
python -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" .github/workflows/ci.yml
```

## Do not modify workflow files via GitHub API without verification

The GitHub API `contents` endpoint silently truncates files over certain sizes and may corrupt multi-document YAML. Always verify file integrity after API writes:

1. Fetch the file back from the API
2. Decode base64 content
3. Compare SHA against local copy

## Use checksums for critical workflow files

For workflows with security implications (deploy, release, secret access), maintain a checksum registry and verify on each CI run.

```bash
sha256sum .github/workflows/deploy.yml >> .github/workflow-checksums.sha256
sha256sum --check .github/workflow-checksums.sha256
```

## Avoid `eval` and dynamic `run:` construction

Never construct `run:` script content dynamically from untrusted inputs. If dynamic behavior is needed, use a pre-written script file with explicit input parameters.
