#!/usr/bin/env python3
"""Generate docs/reference/TOKEN_CONTEXT_INVENTORY.md.

Estimation heuristic aligns with scripts/validate-basecoat.ps1:
approx_tokens = round(word_count * 1.35)
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import re


TOKEN_MULTIPLIER = 1.35


@dataclass
class Row:
    type_name: str
    name: str
    location: str
    words: int
    approx_tokens: int


def word_count(text: str) -> int:
    return len([w for w in re.split(r"\s+", text.strip()) if w])


def collect_rows(root: Path, pattern: str, type_name: str) -> list[Row]:
    rows: list[Row] = []
    for path in sorted(root.glob(pattern)):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        words = word_count(text)
        approx_tokens = round(words * TOKEN_MULTIPLIER)
        rel = path.relative_to(root).as_posix()
        if type_name == "Skill":
            display_name = path.parent.name
        elif type_name == "Agent":
            display_name = path.name.removesuffix(".agent.md")
        elif type_name == "Instruction":
            display_name = path.name.removesuffix(".instructions.md")
        else:
            display_name = path.stem

        rows.append(
            Row(
                type_name=type_name,
                name=display_name,
                location=rel,
                words=words,
                approx_tokens=approx_tokens,
            )
        )
    return rows


def table_rows(rows: list[Row]) -> str:
    lines = ["| Name | Location | Words | Approx Tokens |", "|---|---|---:|---:|"]
    for row in rows:
        name = row.name.replace("|", r"\|")
        location = row.location.replace("|", r"\|")
        lines.append(f"| {name} | `{location}` | {row.words} | {row.approx_tokens} |")
    return "\n".join(lines)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    output_path = repo_root / "docs" / "reference" / "token-context-inventory.md"

    agents = collect_rows(repo_root, "agents/*.agent.md", "Agent")
    skills = collect_rows(repo_root, "skills/*/SKILL.md", "Skill")
    instructions = collect_rows(repo_root, "instructions/*.instructions.md", "Instruction")
    all_rows = [*agents, *skills, *instructions]

    def type_totals(rows: list[Row]) -> tuple[int, int, int]:
        count = len(rows)
        total_words = sum(r.words for r in rows)
        total_tokens = sum(r.approx_tokens for r in rows)
        return count, total_words, total_tokens

    gen_time = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")

    sections: list[str] = [
        "# Token Context Inventory",
        "",
        "Generated as a standalone inventory (no edits to agent/skill/instruction files).",
        "",
        f"- Generated: {gen_time}",
        "- Estimation method: `approx_tokens = round(word_count × 1.35)` (same heuristic used in `scripts/validate-basecoat.ps1`).",
        "- Scope: `agents/*.agent.md`, `skills/*/SKILL.md`, `instructions/*.instructions.md`.",
        "",
        "## Summary",
        "",
        "| Type | Count | Total Words | Total Approx Tokens | Avg Approx Tokens |",
        "|---|---:|---:|---:|---:|",
    ]

    for type_name, rows in [("Agent", agents), ("Skill", skills), ("Instruction", instructions)]:
        count, words, tokens = type_totals(rows)
        avg = round(tokens / max(1, count))
        sections.append(f"| {type_name} | {count} | {words} | {tokens} | {avg} |")

    all_count, all_words, all_tokens = type_totals(all_rows)
    all_avg = round(all_tokens / max(1, all_count))
    sections.append(f"| **All** | {all_count} | {all_words} | {all_tokens} | {all_avg} |")
    sections.extend(
        [
            "",
            "## Agents",
            "",
            table_rows(sorted(agents, key=lambda r: (-r.approx_tokens, r.name.lower()))),
            "",
            "## Skills",
            "",
            table_rows(sorted(skills, key=lambda r: (-r.approx_tokens, r.name.lower()))),
            "",
            "## Instructions",
            "",
            table_rows(sorted(instructions, key=lambda r: (-r.approx_tokens, r.name.lower()))),
            "",
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(sections), encoding="utf-8")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
