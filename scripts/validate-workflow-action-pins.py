#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


SOURCE_SCOPE_PATHS = (
    Path(".github/workflows"),
    Path(".github/base-coat/workflows"),
    Path(".github/workflow-templates"),
    Path("docs/examples/workflows"),
)
TEMPLATE_ROOT = Path(".github/template-repos")
SKILL_ROOT = Path("skills")
INSTALLED_SCOPE = Path("workflows")
WORKFLOW_SUFFIXES = {".yml", ".yaml"}
ANCHOR_NAME_TOKEN = r"[^\s\[\]{},]+"
NODE_PROPERTY_TOKEN = rf"(?:&{ANCHOR_NAME_TOKEN}|![^\s\[\]{{}},]+)"
BLOCK_MAPPING_RE = re.compile(
    r"^(?P<indent> *)(?:-\s+)?"
    rf"(?:{NODE_PROPERTY_TOKEN}\s+)*"
    r"(?P<key>\"(?:[^\"\\]|\\.)*\"|'(?:[^']|'')*'|[A-Za-z_][A-Za-z0-9_-]*)"
    r"\s*:\s*(?P<value>.*)$"
)
BLOCK_SCALAR_RE = re.compile(r"^[|>](?:[1-9][+-]?|[+-][1-9]?|[+-])?$")
FULL_SHA_RE = re.compile(r"^[^@\s]+@[0-9a-fA-F]{40}$")
DOCKER_DIGEST_RE = re.compile(r"^docker://.+@sha256:[0-9a-fA-F]{64}$", re.IGNORECASE)
NODE_PROPERTY_RE = re.compile(rf"^(?:&{ANCHOR_NAME_TOKEN}|![^\s\[\]{{}},]+)\s*")


class ScopeError(RuntimeError):
    pass


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    reference: str
    reason: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate immutable GitHub workflow action references.")
    parser.add_argument("--root", required=True, help="Source repository or installed BaseCoat payload root.")
    parser.add_argument("--mode", choices=("auto", "source", "installed"), default="auto")
    return parser.parse_args()


def workflow_files(directory: Path, source_root: Path | None = None) -> list[Path]:
    exclusion_root = source_root or directory
    return sorted(
        path
        for path in directory.rglob("*")
        if (
            path.is_file()
            and path.suffix.lower() in WORKFLOW_SUFFIXES
            and "node_modules" not in path.relative_to(exclusion_root).parts
        )
    )


def source_workflow_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for relative_scope in SOURCE_SCOPE_PATHS:
        scope = root / relative_scope
        if not scope.is_dir():
            raise ScopeError(f"Required workflow validation scope is missing: {relative_scope.as_posix()}")
        files.extend(workflow_files(scope, root))

    template_root = root / TEMPLATE_ROOT
    if not template_root.is_dir():
        raise ScopeError(
            f"Required workflow validation scope is missing: {TEMPLATE_ROOT.as_posix()}/**/.github/workflows"
        )

    template_scopes = sorted(
        path
        for path in template_root.rglob("workflows")
        if (
            path.is_dir()
            and path.parent.name == ".github"
            and "node_modules" not in path.relative_to(root).parts
        )
    )
    if not template_scopes:
        raise ScopeError(
            f"Required workflow validation scope is missing: {TEMPLATE_ROOT.as_posix()}/**/.github/workflows"
        )
    for scope in template_scopes:
        files.extend(workflow_files(scope, root))

    skill_root = root / SKILL_ROOT
    if not skill_root.is_dir():
        raise ScopeError(f"Required workflow validation scope is missing: {SKILL_ROOT.as_posix()}")
    files.extend(workflow_files(skill_root, root))

    return sorted(set(files))


def installed_workflow_files(root: Path) -> list[Path]:
    scope = root / INSTALLED_SCOPE
    if not scope.is_dir():
        raise ScopeError(f"Required workflow validation scope is missing: {INSTALLED_SCOPE.as_posix()}")
    return workflow_files(scope, root)


def detect_mode(root: Path, requested_mode: str) -> str:
    if requested_mode != "auto":
        return requested_mode
    if (root / ".git").exists():
        return "source"
    if (root / INSTALLED_SCOPE).is_dir():
        return "installed"
    source_hints = (*SOURCE_SCOPE_PATHS, TEMPLATE_ROOT, SKILL_ROOT)
    if any((root / path).exists() for path in source_hints):
        return "source"
    raise ScopeError(
        "Unable to auto-detect workflow validation mode: expected source workflow scopes or installed workflows/."
    )


def strip_yaml_comment(value: str) -> str:
    single_quoted = False
    double_quoted = False
    escaped = False
    index = 0
    while index < len(value):
        char = value[index]
        if double_quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                double_quoted = False
        elif single_quoted:
            if char == "'" and index + 1 < len(value) and value[index + 1] == "'":
                index += 1
            elif char == "'":
                single_quoted = False
        elif char == '"':
            double_quoted = True
        elif char == "'":
            single_quoted = True
        elif char == "#" and (index == 0 or value[index - 1].isspace()):
            return value[:index]
        index += 1
    return value


def decode_quoted_scalar(token: str) -> str | None:
    if len(token) < 2:
        return None
    if token[0] == token[-1] == '"':
        try:
            decoded = json.loads(token)
        except json.JSONDecodeError:
            return None
        return decoded if isinstance(decoded, str) else None
    if token[0] == token[-1] == "'":
        return token[1:-1].replace("''", "'")
    return None


def decode_key(token: str) -> str | None:
    if token.startswith(("'", '"')):
        return decode_quoted_scalar(token)
    return token


def parse_reference(value: str) -> str:
    value = strip_yaml_comment(value).strip()
    if value.startswith(("'", '"')):
        decoded = decode_quoted_scalar(value)
        return decoded if decoded is not None else value
    return value


def strip_node_properties(value: str) -> str:
    value = strip_yaml_comment(value).strip()
    while True:
        match = NODE_PROPERTY_RE.match(value)
        if not match:
            return value
        value = value[match.end():].lstrip()


def unclosed_quoted_scalar(value: str) -> str | None:
    if not value.startswith(("'", '"')):
        return None
    quote = value[0]
    index = 1
    escaped = False
    while index < len(value):
        char = value[index]
        if quote == '"' and escaped:
            escaped = False
        elif quote == '"' and char == "\\":
            escaped = True
        elif quote == "'" and char == "'" and index + 1 < len(value) and value[index + 1] == "'":
            index += 1
        elif char == quote:
            return None
        index += 1
    return quote


def closes_multiline_quoted_scalar(value: str, quote: str) -> bool:
    index = 0
    escaped = False
    while index < len(value):
        char = value[index]
        if quote == '"' and escaped:
            escaped = False
        elif quote == '"' and char == "\\":
            escaped = True
        elif quote == "'" and char == "'" and index + 1 < len(value) and value[index + 1] == "'":
            index += 1
        elif char == quote:
            return True
        index += 1
    return False


def iter_yaml_tokens(content: str):
    index = 0
    while index < len(content):
        char = content[index]
        if char == "#":
            if index == 0 or content[index - 1].isspace():
                return
            index += 1
            continue
        if char in ("'", '"'):
            quote = char
            start = index
            index += 1
            escaped = False
            while index < len(content):
                current = content[index]
                if quote == '"' and escaped:
                    escaped = False
                elif quote == '"' and current == "\\":
                    escaped = True
                elif quote == "'" and current == "'" and index + 1 < len(content) and content[index + 1] == "'":
                    index += 1
                elif current == quote:
                    index += 1
                    break
                index += 1
            yield ("quoted", content[start:index], start, index)
            continue
        if char.isalpha() or char == "_":
            start = index
            index += 1
            while index < len(content) and (content[index].isalnum() or content[index] in "_-"):
                index += 1
            yield ("plain", content[start:index], start, index)
            continue
        yield ("punctuation", char, index, index + 1)
        index += 1


def contains_uses_mapping_key(content: str) -> bool:
    tokens = list(iter_yaml_tokens(content))
    for kind, token, _start, end in tokens:
        decoded = decode_quoted_scalar(token) if kind == "quoted" else token
        if decoded != "uses":
            continue
        index = end
        while index < len(content) and content[index].isspace():
            index += 1
        if index < len(content) and content[index] == ":":
            return True
    return False


def contains_undecodable_quoted_mapping_key(content: str) -> bool:
    for kind, token, _start, end in iter_yaml_tokens(content):
        if kind != "quoted" or decode_quoted_scalar(token) is not None:
            continue
        index = end
        while index < len(content) and content[index].isspace():
            index += 1
        if index < len(content) and content[index] == ":":
            return True
    return False


def contains_explicit_uses_key(content: str) -> bool:
    stripped = content.lstrip()
    if stripped.startswith("-") and len(stripped) > 1 and stripped[1].isspace():
        stripped = stripped[1:].lstrip()
    if not stripped.startswith("?"):
        return False
    remainder = strip_yaml_comment(stripped[1:]).strip()
    if not remainder:
        return False
    for kind, token, _start, _end in iter_yaml_tokens(remainder):
        decoded = decode_quoted_scalar(token) if kind == "quoted" else token
        if decoded == "uses":
            return True
    return False


def contains_uses_token(content: str) -> bool:
    for kind, token, _start, _end in iter_yaml_tokens(content):
        decoded = decode_quoted_scalar(token) if kind == "quoted" else token
        if decoded == "uses":
            return True
    return False


def contains_yaml_alias(content: str) -> bool:
    for kind, token, _start, end in iter_yaml_tokens(content):
        if kind != "punctuation" or token != "*":
            continue
        if re.match(ANCHOR_NAME_TOKEN, content[end:]):
            return True
    return False


def flow_delta(content: str) -> int:
    delta = 0
    for kind, token, _start, _end in iter_yaml_tokens(content):
        if kind != "punctuation":
            continue
        if token in "[{":
            delta += 1
        elif token in "]}":
            delta -= 1
    return delta


def validate_reference(reference: str) -> str | None:
    if reference.startswith("./"):
        return None
    if reference.lower().startswith("docker://"):
        if not DOCKER_DIGEST_RE.fullmatch(reference):
            return "Docker action references must end with an immutable sha256 digest."
        return None
    if not FULL_SHA_RE.fullmatch(reference):
        return "External actions and reusable workflows must use an immutable 40-character commit SHA."
    return None


def is_executable_uses_path(path: list[str]) -> bool:
    return (
        len(path) == 3
        and path[0] == "jobs"
        and path[2] == "uses"
    ) or (
        len(path) == 4
        and path[0] == "jobs"
        and path[2] == "steps"
        and path[3] == "uses"
    )


def is_executable_parent(path: list[str]) -> bool:
    return (
        len(path) == 2
        and path[0] == "jobs"
    ) or (
        len(path) == 3
        and path[0] == "jobs"
        and path[2] == "steps"
    )


def is_executable_flow_root(path: list[str]) -> bool:
    return (
        path == ["jobs"]
        or (len(path) == 2 and path[0] == "jobs")
        or (len(path) == 3 and path[0] == "jobs" and path[2] == "steps")
    )


def is_executable_alias_value_path(path: list[str]) -> bool:
    return (
        path == ["jobs"]
        or (len(path) == 2 and path[0] == "jobs")
        or (len(path) == 3 and path[0] == "jobs" and path[2] == "steps")
    )


def scan_workflow(root: Path, path: Path) -> list[Finding]:
    findings: list[Finding] = []
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    block_scalar_parent_indent: int | None = None
    multiline_quoted_scalar: str | None = None
    explicit_mapping: tuple[int, list[str]] | None = None
    flow_depth = 0
    executable_flow = False
    contexts: list[tuple[int, str]] = []
    relative_path = path.relative_to(root).as_posix()

    for line_number, line in enumerate(lines, start=1):
        if multiline_quoted_scalar is not None:
            if closes_multiline_quoted_scalar(line, multiline_quoted_scalar):
                multiline_quoted_scalar = None
            continue

        if block_scalar_parent_indent is not None:
            if not line.strip():
                continue
            current_indent = len(line) - len(line.lstrip(" "))
            if current_indent > block_scalar_parent_indent:
                continue
            block_scalar_parent_indent = None

        content = strip_yaml_comment(line).rstrip()
        if not content.strip():
            continue

        if not contexts and content.startswith("---"):
            marker_match = re.match(r"^---(?:[ \t]+(?P<node>.*))?$", content)
            if marker_match:
                node = (marker_match.group("node") or "").strip()
                if not node:
                    continue
                content = node

        current_indent = len(content) - len(content.lstrip(" "))
        if executable_flow:
            if (
                contains_uses_mapping_key(content)
                or contains_undecodable_quoted_mapping_key(content)
                or contains_explicit_uses_key(content)
                or contains_yaml_alias(content)
            ):
                findings.append(
                    Finding(
                        relative_path,
                        line_number,
                        content.strip(),
                        "Unsupported YAML form in an executable job/step; use an explicit block mapping.",
                    )
                )
            flow_depth += flow_delta(content)
            if flow_depth <= 0:
                flow_depth = 0
                executable_flow = False
            continue

        indentless_steps_item = (
            contexts
            and contexts[-1][1] == "steps"
            and current_indent == contexts[-1][0]
            and content.lstrip().startswith("-")
        )
        while contexts and (
            current_indent < contexts[-1][0]
            or (current_indent == contexts[-1][0] and not indentless_steps_item)
        ):
            contexts.pop()
        current_path = [key for _indent, key in contexts]

        explicit_form = content.strip()
        if explicit_form.startswith("-") and len(explicit_form) > 1 and explicit_form[1].isspace():
            explicit_form = explicit_form[1:].lstrip()
        if explicit_form.startswith("?") and (
            not current_path
            or current_path == ["jobs"]
            or is_executable_parent(current_path)
        ):
            findings.append(
                Finding(
                    relative_path,
                    line_number,
                    content.strip(),
                    "Unsupported YAML form: explicit mapping key in the workflow jobs hierarchy; use block mappings.",
                )
            )
            explicit_mapping = (current_indent, current_path.copy())
            continue

        root_node = strip_node_properties(content.lstrip()) if not current_path else ""
        if root_node.startswith(("{", "[")):
            findings.append(
                Finding(
                    relative_path,
                    line_number,
                    content.strip(),
                    "Unsupported root YAML flow mapping; use block mappings so executable references can be validated.",
                )
            )
            flow_depth = flow_delta(root_node)
            executable_flow = flow_depth > 0
            continue

        if explicit_mapping is not None:
            explicit_indent, explicit_path = explicit_mapping
            if current_indent > explicit_indent:
                if is_executable_parent(explicit_path) and contains_uses_token(content):
                    findings.append(
                        Finding(
                            relative_path,
                            line_number,
                            content.strip(),
                            "Unsupported YAML form for executable 'uses' key; use a block mapping.",
                        )
                    )
                continue
            explicit_mapping = None

        if explicit_form == "?":
            explicit_mapping = (current_indent, current_path.copy())
            continue

        mapping_match = BLOCK_MAPPING_RE.match(content)
        if mapping_match:
            key = decode_key(mapping_match.group("key"))
            value = mapping_match.group("value").strip()
            if key is None:
                if not current_path or current_path[0] == "jobs":
                    findings.append(
                        Finding(
                            relative_path,
                            line_number,
                            mapping_match.group("key"),
                            "Unsupported YAML quoted mapping key in the jobs hierarchy; use a plain or JSON-compatible key.",
                        )
                    )
                continue
            node_value = strip_node_properties(value)
            path_to_key = [*current_path, key]
            multiline_quoted_scalar = unclosed_quoted_scalar(node_value)
            if key == "uses":
                if is_executable_uses_path(path_to_key):
                    reference = parse_reference(node_value)
                    reason = validate_reference(reference)
                    if reason:
                        findings.append(Finding(relative_path, line_number, reference, reason))
            elif BLOCK_SCALAR_RE.fullmatch(node_value):
                block_scalar_parent_indent = len(mapping_match.group("indent"))
                continue
            elif not node_value:
                contexts.append((current_indent, key))
            elif node_value.startswith(("[", "{")) and is_executable_flow_root(path_to_key):
                if (
                    contains_uses_mapping_key(node_value)
                    or contains_undecodable_quoted_mapping_key(node_value)
                    or contains_yaml_alias(node_value)
                ):
                    findings.append(
                        Finding(
                            relative_path,
                            line_number,
                            content.strip(),
                            "Unsupported YAML form in an executable job/step; use an explicit block mapping.",
                        )
                    )
                flow_depth = flow_delta(node_value)
                executable_flow = flow_depth > 0
            elif contains_yaml_alias(node_value) and is_executable_alias_value_path(path_to_key):
                findings.append(
                    Finding(
                        relative_path,
                        line_number,
                        content.strip(),
                        "YAML aliases are unsupported in executable job/step positions; use an explicit block mapping.",
                    )
                )

            if (
                contains_explicit_uses_key(content)
                and is_executable_parent(current_path)
            ):
                findings.append(
                    Finding(
                        relative_path,
                        line_number,
                        content.strip(),
                        "Unsupported YAML form for executable 'uses' key; use a block mapping.",
                    )
                )
            continue

        if is_executable_parent(current_path):
            if contains_explicit_uses_key(content) or contains_uses_mapping_key(content):
                findings.append(
                    Finding(
                        relative_path,
                        line_number,
                        content.strip(),
                        "Unsupported YAML form for executable 'uses' key; use a block mapping.",
                    )
                )
            if contains_yaml_alias(content):
                findings.append(
                    Finding(
                        relative_path,
                        line_number,
                        content.strip(),
                        "YAML aliases are unsupported in executable job/step positions; use an explicit block mapping.",
                    )
                )
            if content.lstrip().startswith(("[", "{", "- [", "- {")):
                flow_depth = flow_delta(content)
                executable_flow = flow_depth > 0

    return findings


def main() -> int:
    args = parse_args()
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        print(f"ERROR: Validation root does not exist: {root}", file=sys.stderr)
        return 1

    try:
        mode = detect_mode(root, args.mode)
        files = source_workflow_files(root) if mode == "source" else installed_workflow_files(root)
    except ScopeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    findings = [finding for path in files for finding in scan_workflow(root, path)]
    if findings:
        print(f"Workflow action pin validation failed with {len(findings)} violation(s):", file=sys.stderr)
        for finding in findings:
            print(f"ERROR: {finding.path}:{finding.line}", file=sys.stderr)
            print(f"  uses: {finding.reference}", file=sys.stderr)
            print(f"  {finding.reason}", file=sys.stderr)
        return 1

    print(
        f"Workflow action pin validation passed: mode '{mode}', scanned {len(files)} workflow file(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
