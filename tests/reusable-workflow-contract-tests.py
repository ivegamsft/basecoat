#!/usr/bin/env python3
"""Regression tests for packaged and legacy reusable-workflow contracts."""

from __future__ import annotations

import hashlib
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "validate-reusable-workflow-contracts.py"
CALLABLE = ROOT / ".github" / "workflows" / "check-basecoat-version-callable.yml"
CURRENT_CALLER = (
    ROOT / ".github" / "workflow-templates" / "check-basecoat-version.yml"
)
LEGACY_CALLER = (
    ROOT
    / "tests"
    / "fixtures"
    / "version-workflow"
    / "v4.1.0-check-basecoat-version.yml"
)
SCRATCH = ROOT / "test-results" / "reusable-workflow-contract-tests"


def run(*paths: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), *(str(path) for path in paths)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def require_success(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{label} failed:\n{result.stdout}\n{result.stderr}")


def main() -> None:
    shutil.rmtree(SCRATCH, ignore_errors=True)
    SCRATCH.mkdir(parents=True)
    try:
        normalized_legacy = LEGACY_CALLER.read_bytes().replace(b"\r\n", b"\n")
        legacy_digest = hashlib.sha256(normalized_legacy).hexdigest()
        if legacy_digest != (
            "9dcb9c70a5eff8aeec8b444cde266d40d6a2a3f20041529b2f3e6ecefaa0471e"
        ):
            raise AssertionError(
                "v4.1.0 caller fixture no longer matches the released source"
            )

        require_success(run(CALLABLE, CURRENT_CALLER), "current caller contract")
        require_success(
            run(CALLABLE, LEGACY_CALLER),
            "exact v4.1.0 @main caller compatibility",
        )
        callable_job = CALLABLE.read_text(encoding="utf-8").split("jobs:", 1)[1]
        if "permissions:" in callable_job.split("steps:", 1)[0]:
            raise AssertionError(
                "callable jobs must inherit the caller's permission grant so "
                "both exact v4.1 and current PR-mode callers can start"
            )

        incompatible = (
            SCRATCH
            / "without-legacy-input"
            / "check-basecoat-version-callable.yml"
        )
        incompatible.parent.mkdir()
        content = CALLABLE.read_text(encoding="utf-8")
        start = content.index("      source_repo:")
        end = content.index("      source_ref:", start)
        incompatible.write_text(content[:start] + content[end:], encoding="utf-8")
        result = run(incompatible, LEGACY_CALLER)
        if result.returncode == 0 or "source_repo" not in result.stderr:
            raise AssertionError(
                "validator did not reject the v4.1.0 caller when source_repo "
                f"was undeclared:\n{result.stdout}\n{result.stderr}"
            )

        incompatible_secret = (
            SCRATCH
            / "without-fetch-secret"
            / "check-basecoat-version-callable.yml"
        )
        incompatible_secret.parent.mkdir()
        content = CALLABLE.read_text(encoding="utf-8")
        start = content.index("      fetch_token:")
        next_secret = content.find("\n      ", start + 1)
        next_job = content.find("\njobs:", start + 1)
        end = min(value for value in (next_secret, next_job) if value >= 0) + 1
        incompatible_secret.write_text(
            content[:start] + content[end:], encoding="utf-8"
        )
        result = run(incompatible_secret, CURRENT_CALLER)
        if result.returncode == 0 or "fetch_token" not in result.stderr:
            raise AssertionError(
                "validator did not reject an undeclared named secret:\n"
                f"{result.stdout}\n{result.stderr}"
            )

        content = CURRENT_CALLER.read_text(encoding="utf-8")
        secrets_start = content.index("    secrets:")
        for index, inherit_value in enumerate(
            (
                "inherit",
                "inherit # broad forwarding",
                '"inherit"',
                "'inherit'",
                "&all inherit",
                "*all",
                "!!str inherit",
                "\n      &all inherit",
                "\n      *all",
                "\n      !!str inherit",
            )
        ):
            inherited_secrets_caller = (
                SCRATCH / f"caller-with-inherited-secrets-{index}.yml"
            )
            inherited_secrets_caller.write_text(
                content[:secrets_start] + f"    secrets: {inherit_value}\n",
                encoding="utf-8",
            )
            result = run(CALLABLE, inherited_secrets_caller)
            if result.returncode == 0 or not (
                "secrets: inherit" in result.stderr
                or "explicit named mapping" in result.stderr
            ):
                raise AssertionError(
                    f"validator did not reject secrets: {inherit_value}:\n"
                    f"{result.stdout}\n{result.stderr}"
                )

        named_secret_line = (
            "      update_token: ${{ secrets.BASECOAT_UPDATE_TOKEN }}"
        )
        for index, forbidden_value in enumerate(
            (
                "|",
                ">\n        folded",
                "*all",
                "&token secret",
                "!!str secret",
                "{ token: secret }",
                "[secret]",
            )
        ):
            forbidden_caller = SCRATCH / f"caller-forbidden-secret-value-{index}.yml"
            forbidden_caller.write_text(
                content.replace(
                    named_secret_line,
                    f"      update_token: {forbidden_value}",
                    1,
                ),
                encoding="utf-8",
            )
            result = run(CALLABLE, forbidden_caller)
            if result.returncode == 0 or "single-line" not in result.stderr:
                raise AssertionError(
                    f"validator accepted forbidden named secret value {forbidden_value!r}:\n"
                    f"{result.stdout}\n{result.stderr}"
                )

        for workflow_name in ("release.yml", "package-basecoat.yml"):
            release_workflow = (
                ROOT / ".github" / "workflows" / workflow_name
            ).read_text(encoding="utf-8")
            for retired_audit_dependency in (
                "actions/permissions/access",
                "BASECOAT_RELEASE_AUDIT_TOKEN",
            ):
                if retired_audit_dependency in release_workflow:
                    raise AssertionError(
                        f"{workflow_name} must not require the retired "
                        f"release audit dependency: {retired_audit_dependency}"
                    )

        bash_packager = (ROOT / "scripts" / "package-basecoat.sh").read_text(
            encoding="utf-8"
        )
        if "mapfile" in bash_packager:
            raise AssertionError(
                "package-basecoat.sh must remain compatible with macOS Bash 3.2"
            )

        print("Reusable-workflow contract tests passed.")
    finally:
        shutil.rmtree(SCRATCH, ignore_errors=True)


if __name__ == "__main__":
    main()
