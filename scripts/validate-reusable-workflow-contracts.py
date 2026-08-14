#!/usr/bin/env python3
"""Validate reusable-workflow caller keys against a callable workflow schema."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


KEY_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?:(?:\"(?P<double>[^\"]+)\")|"
    r"(?:'(?P<single>[^']+)')|(?P<plain>[A-Za-z0-9_.-]+)):"
    r"(?P<value>.*)$"
)


def mapping_line(line: str) -> tuple[int, str, str] | None:
    match = KEY_RE.match(line.rstrip())
    if not match:
        return None
    indent_text = match.group("indent").replace("\t", "  ")
    key = match.group("double") or match.group("single") or match.group("plain")
    return len(indent_text), key, match.group("value").strip()


def direct_mapping(lines: list[str], start: int, parent_indent: int) -> dict[str, str]:
    result: dict[str, str] = {}
    child_indent: int | None = None
    for line in lines[start + 1 :]:
        parsed = mapping_line(line)
        if parsed is None:
            continue
        indent, key, value = parsed
        if indent <= parent_indent:
            break
        if child_indent is None:
            child_indent = indent
        if indent == child_indent:
            result[key] = value
    return result


def explicit_mapping(
    lines: list[str], start: int, parent_indent: int, *, label: str
) -> dict[str, str]:
    result: dict[str, str] = {}
    child_indent: int | None = None
    for line in lines[start + 1 :]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        leading = len(line) - len(line.lstrip(" \t"))
        if leading <= parent_indent:
            break
        parsed = mapping_line(line)
        if child_indent is None:
            if parsed is None:
                raise ValueError(
                    f"{label} must be an explicit named mapping; aliases, "
                    "anchors, tags, and multiline scalars are forbidden"
                )
            child_indent = parsed[0]
        if leading > child_indent:
            raise ValueError(
                f"{label} entries must use single-line scalar values; "
                "multiline continuations are forbidden"
            )
        if leading == child_indent:
            if parsed is None or parsed[0] != child_indent:
                raise ValueError(
                    f"{label} must contain only explicit named mapping entries"
                )
            value = parsed[2].lstrip()
            if not value or value[0] in "|>*&!{[":
                raise ValueError(
                    f"{label} entries must use direct single-line values; "
                    "aliases, anchors, tags, collections, and multiline "
                    "scalars are forbidden"
                )
            result[parsed[1]] = parsed[2]
    return result


def find_mapping(
    lines: list[str], key: str, *, start: int = -1, parent_indent: int = -1
) -> tuple[int, int]:
    for index in range(start + 1, len(lines)):
        parsed = mapping_line(lines[index])
        if parsed is None:
            continue
        indent, candidate, _ = parsed
        if start >= 0 and indent <= parent_indent:
            break
        if candidate == key:
            return index, indent
    raise ValueError(f"missing YAML mapping '{key}'")


def callable_contract(path: pathlib.Path) -> tuple[set[str], set[str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    on_index, on_indent = find_mapping(lines, "on")
    call_index, call_indent = find_mapping(
        lines, "workflow_call", start=on_index, parent_indent=on_indent
    )

    result: dict[str, set[str]] = {"inputs": set(), "secrets": set()}
    for section in result:
        try:
            section_index, section_indent = find_mapping(
                lines, section, start=call_index, parent_indent=call_indent
            )
        except ValueError:
            continue
        result[section] = set(direct_mapping(lines, section_index, section_indent))
    return result["inputs"], result["secrets"]


def reusable_jobs(path: pathlib.Path) -> list[tuple[str, str, set[str], set[str]]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    jobs_index, jobs_indent = find_mapping(lines, "jobs")
    jobs = direct_mapping(lines, jobs_index, jobs_indent)
    results: list[tuple[str, str, set[str], set[str]]] = []

    for job_name in jobs:
        job_index, job_indent = find_mapping(
            lines, job_name, start=jobs_index, parent_indent=jobs_indent
        )
        fields = direct_mapping(lines, job_index, job_indent)
        uses = fields.get("uses", "").strip("'\"")
        if "/.github/workflows/" not in uses and not uses.startswith(
            "./.github/workflows/"
        ):
            continue

        sections: dict[str, set[str]] = {"with": set(), "secrets": set()}
        for section in sections:
            try:
                section_index, section_indent = find_mapping(
                    lines, section, start=job_index, parent_indent=job_indent
                )
            except ValueError:
                continue
            section_fields = direct_mapping(lines, section_index, section_indent)
            if section == "secrets" and fields.get("secrets", "").strip():
                raise ValueError(
                    f"{path}: job '{job_name}' uses a scalar secrets value; "
                    "'secrets: inherit', aliases, anchors, and inline mappings "
                    "are forbidden. Forward explicit named secrets."
                )
            if section == "secrets":
                section_fields = explicit_mapping(
                    lines,
                    section_index,
                    section_indent,
                    label=f"{path}: job '{job_name}' secrets",
                )
            sections[section] = set(section_fields)
        results.append((job_name, uses, sections["with"], sections["secrets"]))
    return results


def validate(caller: pathlib.Path, callable_path: pathlib.Path) -> list[str]:
    declared_inputs, declared_secrets = callable_contract(callable_path)
    failures: list[str] = []
    jobs = [
        job
        for job in reusable_jobs(caller)
        if job[1].split("@", 1)[0].endswith("/" + callable_path.name)
    ]
    if not jobs:
        return [
            f"{caller}: no caller jobs found for reusable workflow "
            f"'{callable_path.name}'"
        ]

    for job_name, uses, provided_inputs, provided_secrets in jobs:
        unknown_inputs = sorted(provided_inputs - declared_inputs)
        unknown_secrets = sorted(provided_secrets - declared_secrets)
        if unknown_inputs:
            failures.append(
                f"{caller}: job '{job_name}' passes undeclared input(s) to "
                f"{uses}: {', '.join(unknown_inputs)}"
            )
        if unknown_secrets:
            failures.append(
                f"{caller}: job '{job_name}' passes undeclared secret(s) to "
                f"{uses}: {', '.join(unknown_secrets)}"
            )
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("callable", type=pathlib.Path)
    parser.add_argument("callers", nargs="+", type=pathlib.Path)
    args = parser.parse_args()

    failures: list[str] = []
    try:
        for caller in args.callers:
            failures.extend(validate(caller, args.callable))
    except (OSError, ValueError) as error:
        failures.append(str(error))

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1

    print(
        f"Reusable-workflow contract validation passed for "
        f"{len(args.callers)} caller(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
