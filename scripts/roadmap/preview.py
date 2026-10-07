"""Normalize supplied mapper/advisor evidence into a read-only, checkpointed preview."""

import argparse
import json
import re
import sqlite3
from contextlib import closing
from pathlib import Path

import plan as P

BLOCKERS = [
    "github-conditional-mutation-not-proven",
    "authenticated-current-authority-and-atomic-approval-consumption-not-implemented",
    "milestone-assignment-and-artifact-pr-writes-disabled",
]


def text(value):
    P.require(isinstance(value, str) and bool(value.strip()) and
              not any(ord(c) < 32 for c in value), "invalid-evidence-text")
    return value.strip()


def records(value):
    P.require(isinstance(value, list) and all(isinstance(v, dict) for v in value),
              "malformed-evidence-records")
    return value


def numbers(value):
    P.require(isinstance(value, list), "invalid-evidence-numbers")
    result = sorted(P.number(n) for n in value)
    P.require(len(set(result)) == len(result), "duplicate-evidence-number")
    return result


def normalized_scope(value):
    if isinstance(value, str) and value.strip().startswith("theme:"):
        return "theme:" + text(value.strip()[6:]).lower()
    return P.scope(value)


def unordered(value):
    if isinstance(value, dict):
        return {k: unordered(v) for k, v in value.items()}
    if isinstance(value, list):
        return sorted((unordered(v) for v in value), key=P.canonical)
    return value


def snapshot_digest(snapshot):
    return P.digest(unordered(snapshot))


def write_gate(*_args, **_kwargs):
    # Neither a flag, approval payload, bot label, nor a mock CAS is live proof.
    raise P.Conflict("live-writes-disabled: github-conditional-mutation-not-proven")


def normalize(evidence, snapshot):
    P.require(isinstance(evidence, dict) and type(evidence.get("schema")) is int and
              evidence["schema"] == 1,
              "unsupported-evidence-schema")
    repo = P.repository(evidence["repository"])
    P.require(repo == P.repository(snapshot["repository"]), "repository-mismatch")
    P.require(evidence["snapshot_digest"] == snapshot_digest(snapshot), "stale-mapper-snapshot")
    milestones, keys, items = P.inventory(snapshot)
    del milestones, keys
    mapper, advisor = evidence["mapper"], evidence["advisor"]
    P.require(mapper["source"] == "sprint-project-mapper" and
              advisor["source"] == "release-impact-advisor", "wrong-evidence-source")
    P.require(advisor["current_version"] == evidence["current_version"],
              "advisor-baseline-mismatch")
    P.release_baseline(evidence["current_version"], snapshot)
    selector = normalized_scope(evidence["scope"])
    open_issues = {n for n, i in items.items()
                   if i["kind"] == "issue" and i["state"] == "open"}
    themes = {}
    for entry in records(mapper["themes"]):
        theme = text(entry["theme"]).lower()
        P.require(theme not in themes, "duplicate-theme")
        members = numbers(entry["issues"])
        P.require(set(members) <= open_issues, "invalid-theme-members")
        themes[theme] = members
    if selector.startswith("theme:"):
        P.require(selector[6:] in themes and bool(themes[selector[6:]]),
                  "missing-theme-evidence")
        selected = set(themes[selector[6:]])
        planner_scope = "issue-set:" + ",".join(f"#{n}" for n in sorted(selected))
    else:
        planner_scope = selector
        if selector == "all":
            selected = open_issues
        elif selector.startswith("label:"):
            selected = {n for n in open_issues if selector[6:] in
                        [s.lower() for s in items[n]["labels"]]}
        else:
            selected = {int(n) for n in re.findall(r"\d+", selector)}
            P.require(selected <= open_issues, "missing-or-closed-scoped-issue")
    normalized = json.loads(P.canonical(snapshot))
    normalized_items = P.index(normalized["items"])
    # Do not infer links from bodies or accept stale/unbound snapshot annotations.
    for item in normalized_items.values():
        item["linked_issues"] = []
    linked_prs = set()
    for link in records(mapper["links"]):
        pr = P.number(link["pr"])
        P.require(pr not in linked_prs and pr in items and
                  items[pr]["kind"] == "pr" and items[pr]["state"] == "open",
                  "invalid-or-duplicate-pr-link")
        linked_prs.add(pr)
        linked = numbers(link["issues"])
        P.require(all(n in items and items[n]["kind"] == "issue" for n in linked),
                  "invalid-link-target")
        normalized_items[pr]["linked_issues"] = linked
    recommendations = {}
    for recommendation in records(advisor["recommendations"]):
        group = text(recommendation["group"])
        P.require(group not in recommendations, "duplicate-advisor-group")
        P.version(recommendation["release"])
        for field in ("risks", "rollout", "rollback"):
            text(recommendation[field])
        recommendations[group] = recommendation
    groups, seen, ids, significant_ids = [], set(), set(), set()
    explicit_residuals = {}
    for residual in records(mapper["residuals"]):
        n = P.number(residual["number"])
        P.require(n in selected and n not in explicit_residuals, "invalid-mapper-residual")
        explicit_residuals[n] = text(residual["reason"])
    for group in records(mapper["groups"]):
        group_id = text(group["id"])
        P.require(group_id not in ids, "duplicate-mapper-group")
        ids.add(group_id)
        members = numbers(group["issues"])
        P.require(bool(members) and set(members) <= selected and not seen.intersection(members),
                  "overlapping-or-out-of-scope-group")
        seen.update(members)
        P.require(not set(members).intersection(explicit_residuals), "group-residual-overlap")
        debate = group["debate"]
        text(debate["split"])
        text(debate["merge"])
        P.require(debate["decision"] in ("split", "merge", "retain", "needs-human-decision"),
                  "invalid-debate-decision")
        confidence = debate["confidence"]
        P.require(type(confidence) in (int, float) and 0 <= confidence <= 1,
                  "invalid-debate-confidence")
        for field in ("merged_prs", "loc", "activity_days"):
            P.require(type(group[field]) is int and group[field] >= 0,
                      "invalid-significance-metrics")
        P.require(type(group["explicit_binding"]) is bool, "invalid-binding-evidence")
        if debate["decision"] == "merge":
            similarity = group["similarity"]
            P.require(type(similarity) in (int, float) and 0 <= similarity <= 1,
                      "invalid-similarity")
            P.require(similarity > 0.65, "merge-below-mapper-similarity")
        significant = (confidence >= 0.70 and debate["decision"] != "needs-human-decision" and
                       (len(members) >= 5 or group["merged_prs"] >= 3) and
                       group["loc"] >= 200 and
                       (group["activity_days"] >= 7 or group["explicit_binding"]))
        candidate = {"issues": members, "significant": significant}
        if significant:
            P.require(group_id in recommendations, "missing-advisor-recommendation")
            significant_ids.add(group_id)
            candidate["release"] = recommendations[group_id]["release"]
        else:
            for n in members:
                explicit_residuals[n] = ("mapper-needs-human-decision" if confidence < 0.70 or
                                        debate["decision"] == "needs-human-decision" else
                                        "mapper-sub-threshold")
        groups.append(candidate)
    P.require(seen | explicit_residuals.keys() == selected, "unaccounted-scoped-issues")
    P.require(recommendations.keys() == significant_ids, "unexpected-advisor-recommendation")
    proposal = {"repository": repo, "scope": planner_scope,
                "current_version": evidence["current_version"], "groups": groups}
    for field in ("max_releases", "concurrency", "pace", "stop_conditions"):
        if field in evidence:
            proposal[field] = evidence[field]
    result = P.build_plan(proposal, normalized)
    result["plan"]["scope"] = selector
    # Evidence decisions and original theme selector are approval-relevant, not AI output.
    bound_evidence = json.loads(P.canonical(evidence))
    bound_evidence.update(repository=repo, scope=selector)
    for theme in bound_evidence["mapper"]["themes"]:
        theme["theme"] = text(theme["theme"]).lower()
    result["plan"]["evidence_digest"] = P.digest(unordered(bound_evidence))
    for residual in result["plan"]["residuals"]:
        if residual["number"] in explicit_residuals:
            residual["reason"] = explicit_residuals[residual["number"]]
    result["digest"] = P.digest(result["plan"])
    return result


def markdown_text(value):
    return str(value).replace("\\", "\\\\").replace("<", "&lt;").replace(">", "&gt;").replace(
        "\n", " ").replace("\r", " ").replace("`", "\\`").replace("|", "\\|")


def render(result):
    plan = result["plan"]
    P.require(result["digest"] == P.digest(plan), "stale-plan")
    lines = ["# Roadmap preview", "", "Read-only proposal; not approved, assigned, or shipped.",
             "", f"Repository: `{plan['repository']}`",
             f"Scope: {markdown_text(plan['scope'])}", f"Plan digest: `{result['digest']}`", "",
             "## Proposed releases", ""]
    for release in plan["releases"]:
        lines.extend([f"### {release}", "", "Lifecycle: proposed; verified tag: none.", ""])
        for item in plan["assignments"]:
            if item["release"] == release:
                lines.append(f"- #{item['number']}")
        lines.append("")
    if not plan["releases"]:
        lines.extend(["None.", ""])
    lines.extend(["## Preserved pins and human ownership", ""])
    lines.extend([f"- #{n}" for n in plan["pins"]] or ["None."])
    lines.extend(["", "## Residuals", ""])
    lines.extend([f"- #{r['number']}: {markdown_text(r['reason'])}"
                  for r in plan["residuals"]] or ["None."])
    lines.extend(["", "## Blockers", ""])
    lines.extend(f"- {blocker}" for blocker in BLOCKERS)
    return "\n".join(lines) + "\n"


def checkpoint(path, run_id, result):
    P.require(isinstance(run_id, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", run_id),
              "invalid-run-id")
    P.require(result["digest"] == P.digest(result["plan"]) and result["dry_run"] is True,
              "stale-or-non-preview-plan")
    state = {"schema": 1, "repository": result["plan"]["repository"], "run_id": run_id,
             "phase": "preview-only", "digest": result["digest"], "result": result,
             "artifact_path": "docs/reference/roadmap.md", "artifact": render(result),
             "completed_writes": [], "approval": None, "blockers": BLOCKERS}
    payload = P.canonical(state)
    # The transaction is local durability only; it is NOT GitHub CAS or approval consumption.
    with closing(sqlite3.connect(path, timeout=10)) as db, db:
        db.execute("PRAGMA synchronous=FULL")
        db.execute("BEGIN IMMEDIATE")
        db.execute("CREATE TABLE IF NOT EXISTS previews "
                   "(repository TEXT, run_id TEXT, payload TEXT NOT NULL, "
                   "PRIMARY KEY (repository, run_id))")
        previous = db.execute("SELECT payload FROM previews WHERE repository=? AND run_id=?",
                              (state["repository"], run_id)).fetchone()
        if previous:
            P.require(previous[0] == payload, "checkpoint-replay-conflict")
        else:
            db.execute("INSERT INTO previews VALUES (?, ?, ?)",
                       (state["repository"], run_id, payload))
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--snapshot")
    source.add_argument("--repo")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--checkpoint", required=True, help="Local SQLite preview store")
    parser.add_argument("--apply", action="store_true", help="Always rejected; no live adapter")
    args = parser.parse_args()
    if args.apply:
        write_gate()
    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8-sig"))
    snapshot = P.read_snapshot(args.repo) if args.repo else json.loads(
        Path(args.snapshot).read_text(encoding="utf-8-sig"))
    result = normalize(evidence, snapshot)
    print(json.dumps(checkpoint(args.checkpoint, args.run_id, result), indent=2))


if __name__ == "__main__":
    try:
        main()
    except P.Conflict as error:
        raise SystemExit(f"roadmap-preview-failed: {error}")
    except (ValueError, KeyError, TypeError, OSError, sqlite3.Error):
        raise SystemExit("roadmap-preview-failed: invalid evidence, conflict, or local storage failure")
