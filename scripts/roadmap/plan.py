"""Read-only roadmap foundation. Consumes mapper/advisor evidence; never writes GitHub."""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

CONFIG = json.loads((Path(__file__).parents[1] / "backlog-autopilot" /
                     "autopilot.config.json").read_text(encoding="utf-8-sig"))
MARKER = re.compile(r"<!-- basecoat-roadmap:v1 key=(v[0-9]+\.[0-9]+\.[0-9]+) -->")
PIN = "<!-- basecoat-roadmap-pin:v1 -->"


class Conflict(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise Conflict(code)


def number(value):
    require(type(value) is int and value > 0, "invalid-number")
    return value


def version(value):
    require(isinstance(value, str) and
            re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value),
            "invalid-version")
    return tuple(int(n) for n in value[1:].split("."))


def repository(value):
    require(isinstance(value, str) and
            re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value), "invalid-repository")
    return value.lower()


def scope(value):
    require(isinstance(value, str), "invalid-scope")
    value = value.strip()
    if value == "all":
        return value
    if value.startswith("label:"):
        label = value[6:].strip().lower()
        require(bool(label) and not any(ord(c) < 32 for c in label), "invalid-scope")
        return "label:" + label
    require(re.fullmatch(r"issue-set:#\d+(?:,#\d+)*", value), "unsupported-or-invalid-scope")
    return "issue-set:" + ",".join(f"#{n}" for n in sorted(
        {number(int(n)) for n in re.findall(r"\d+", value)}))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def index(records):
    result = {}
    for record in records:
        n = number(record["number"])
        require(n not in result, "duplicate-number")
        result[n] = record
    return result


def inventory(snapshot):
    require(snapshot.get("complete") is True and not snapshot.get("errors"),
            "incomplete-api-evidence")
    milestones = index(snapshot["milestones"])
    keys = {}
    for n, milestone in milestones.items():
        require(milestone["state"] in ("open", "closed"), "invalid-milestone-state")
        description = milestone.get("description")
        require(description is None or isinstance(description, str),
                "invalid-milestone-description")
        text = description or ""
        matches = MARKER.findall(text)
        require("basecoat-roadmap:v1" not in text or
                (len(matches) == 1 and text.count("basecoat-roadmap:v1") == 1),
                "ambiguous-managed-marker")
        key = matches[0] if matches else None
        if key:
            version(key)
        if key and milestone["state"] == "open":
            require(key not in keys, "duplicate-managed-key")
            keys[key] = n
        milestone = {**milestone, "key": key, "pinned": PIN in text}
        milestones[n] = milestone
    items = index(snapshot["items"])
    for item in items.values():
        labels = item.get("labels")
        require(isinstance(labels, list) and all(isinstance(s, str) for s in labels),
                "invalid-label-evidence")
        require("milestone" in item, "missing-milestone-evidence")
        assigned = item["milestone"]
        if assigned is not None:
            number(assigned)
            require(assigned in milestones, "missing-milestone")
    return milestones, keys, items


def release_baseline(current_version, snapshot):
    current = version(current_version)
    tags = snapshot["tags"]
    require(isinstance(tags, list) and all(isinstance(t, str) and t and
            not any(c.isspace() or ord(c) < 32 for c in t) for t in tags),
            "invalid-tag-evidence")
    normalized = set()
    for tag in tags:
        prefix = tag[1:2] if tag.startswith("v") else tag[:1]
        if prefix.isdecimal():
            require(tag.isascii(), "invalid-version")
        if re.match(r"v?[0-9]", tag):
            key = tag if tag.startswith("v") else "v" + tag
            version(key)
            normalized.add(key)
    require(not normalized or current >= max(version(t) for t in normalized),
            "stale-release-baseline")
    return current, normalized


def build_plan(proposal, snapshot):
    require(proposal.get("dry_run", True) is True, "live-writes-disabled")
    repo = repository(proposal["repository"])
    require(repository(snapshot["repository"]) == repo, "repository-mismatch")
    selector = scope(proposal["scope"])
    bounds = {"max_releases": proposal.get("max_releases", 1),
              "concurrency": proposal.get("concurrency", 1),
              "pace": proposal.get("pace", "configured"),
              "stop_conditions": sorted(set(proposal.get("stop_conditions", [])))}
    number(bounds["max_releases"])
    number(bounds["concurrency"])
    require(bounds["max_releases"] <= CONFIG["loop"]["default_max_cycles"] and
            bounds["concurrency"] <= CONFIG["loop"]["default_concurrency"] and
            bounds["pace"] == "configured" and not bounds["stop_conditions"],
            "unsupported-or-over-policy-bounds")
    milestones, keys, items = inventory(snapshot)
    for item in items.values():
        require(item["kind"] in ("issue", "pr") and item["state"] in ("open", "closed"),
                "invalid-item-state")
        require(isinstance(item.get("linked_issues", []), list), "invalid-link-evidence")
        for linked in item.get("linked_issues", []):
            number(linked)
    issues = {n: i for n, i in items.items() if i["kind"] == "issue" and i["state"] == "open"}
    if selector.startswith("issue-set:"):
        selected = {int(n) for n in re.findall(r"\d+", selector)}
        require(selected <= issues.keys(), "missing-or-closed-scoped-issue")
    elif selector.startswith("label:"):
        selected = {n for n, i in issues.items()
                    if selector[6:] in [s.lower() for s in i.get("labels", [])]}
    else:
        selected = set(issues)
    current, tags = release_baseline(proposal["current_version"], snapshot)
    releases, assignments, residuals, pins, guards = [], {}, {}, [], []
    for n, item in sorted(items.items()):
        if item["state"] != "open":
            continue
        links = item.get("linked_issues", [])
        eligible = n in selected if item["kind"] == "issue" else (
            len(links) == 1 and links[0] in selected)
        if not eligible:
            if item["kind"] == "pr":
                residuals[n] = "unlinked-ambiguous-or-out-of-scope-pr"
            continue
        milestone = milestones.get(item.get("milestone"))
        require(not item.get("milestone") or milestone is not None, "missing-milestone")
        pinned = "roadmap:pinned" in [s.lower() for s in item.get("labels", [])] or (
            milestone is not None and (milestone["pinned"] or not milestone["key"]))
        guards.append({"number": n, "milestone": item.get("milestone"),
                       "managed_key": milestone["key"] if milestone else None,
                       "pinned": pinned})
        if pinned:
            pins.append(n)
        else:
            residuals[n] = "mapper-residual"
    seen = set()
    for group in proposal["groups"]:
        members = sorted({number(n) for n in group["issues"]})
        require(bool(members) and set(members) <= selected, "out-of-scope-group")
        require(type(group["significant"]) is bool, "invalid-mapper-evidence")
        if not group["significant"]:
            continue
        key = group["release"]
        require(version(key) > current and key not in tags, "existing-or-old-version")
        require(key not in releases, "duplicate-release")
        releases.append(key)
        for n in members:
            require(n not in seen, "overlapping-groups")
            seen.add(n)
            if n not in pins:
                assignments[n] = key
            for pr, item in items.items():
                if item["kind"] == "pr" and item["state"] == "open" and (
                        item.get("linked_issues") == [n]) and pr not in pins:
                    if n in pins:
                        residuals[pr] = "linked-issue-pinned"
                    else:
                        assignments[pr] = key
    releases.sort(key=version)
    require(len(releases) <= bounds["max_releases"], "release-bound-exceeded")
    for n in assignments:
        residuals.pop(n, None)
    # These guards bind approval to observed ownership and pins, not display text.
    plan = {"schema": 1, "repository": repo, "scope": selector, "bounds": bounds,
            "current_version": proposal["current_version"], "releases": releases,
            "assignments": [{"number": n, "release": k} for n, k in sorted(assignments.items())],
            "pins": sorted(pins),
            "residuals": [{"number": n, "reason": r} for n, r in sorted(residuals.items())],
            "guards": guards,
            "milestones": [{"number": n, "key": m["key"], "state": m["state"],
                            "pinned": m["pinned"]} for n, m in sorted(milestones.items())]}
    return {"plan": plan, "digest": digest(plan), "dry_run": True,
            "steps": storage_steps(plan, snapshot)}


def storage_steps(plan, snapshot):
    milestones, keys, items = inventory(snapshot)
    current, tags = release_baseline(plan["current_version"], snapshot)
    for key in plan["releases"]:
        require(version(key) > current and key not in tags, "existing-or-old-version")
    steps = [{"operation": "create", "key": k,
              "marker": f"<!-- basecoat-roadmap:v1 key={k} -->"}
             for k in plan["releases"] if k not in keys]
    for key in plan["releases"]:
        require(not any(m["key"] == key and m["state"] == "closed"
                        for m in milestones.values()), "closed-managed-key")
        require(key not in keys or not milestones[keys[key]]["pinned"],
                "pinned-target-milestone")
    for assignment in plan["assignments"]:
        n, key = assignment["number"], assignment["release"]
        item = items[n]
        old = milestones.get(item.get("milestone"))
        require("roadmap:pinned" not in [s.lower() for s in item.get("labels", [])] and
                (old is None or (old["key"] and not old["pinned"])), "pin-or-ownership-conflict")
        if item.get("milestone") != keys.get(key) or key not in keys:
            steps.append({"operation": "assign", "number": n, "key": key,
                          "expected_milestone": item.get("milestone")})
    return steps


def check_approval(approval, result, repo, run_id, permission, trigger):
    require(isinstance(run_id, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", run_id),
            "invalid-run-id")
    require(permission in ("write", "maintain", "admin") and trigger == "human",
            "unauthorized-approval")
    require(result["digest"] == digest(result["plan"]) and
            approval == {"repository": repository(repo), "run_id": run_id,
                         "digest": result["digest"]} and
            result["plan"]["repository"] == repository(repo), "stale-or-mismatched-approval")
    # Validation is pure: it is NOT atomic consumption or permission authentication.
    return True


def ordering(mode, result=None, approved_digest=None):
    require(mode in ("off", "prefer", "required"), "invalid-ordering-mode")
    if mode == "off":
        return {"ordering": "oldest-first"}
    if result is None:
        require(mode == "prefer", "approved-roadmap-required")
        return {"ordering": "fallback-oldest-first", "reason": "no-active-approved-roadmap"}
    plan = result["plan"]
    require(result["digest"] == digest(plan) == approved_digest, "stale-or-unapproved-roadmap")
    require(not plan["pins"] and not any(m["pinned"] or not m["key"]
                                       for m in plan["milestones"] if m["state"] == "open"),
            "unknown-pinned-position")
    require(bool(plan["releases"]), "no-eligible-release")
    numbers = [a["number"] for a in plan["assignments"]
               if a["release"] == plan["releases"][0]]
    require(bool(numbers), "earliest-release-has-no-eligible-items")
    return {"ordering": "roadmap", "release": plan["releases"][0], "numbers": numbers}


def read_snapshot(repo, get=None):
    repo = repository(repo)

    def gh_get(endpoint):
        response = subprocess.run(["gh", "api", "--method", "GET", endpoint,
                                   "--paginate", "--slurp"], capture_output=True,
                                  text=True, encoding="utf-8")
        require(response.returncode == 0,
                f"api-read-failed endpoint={endpoint} exit={response.returncode}")
        pages = json.loads(response.stdout)
        require(isinstance(pages, list) and all(isinstance(p, list) for p in pages),
                "malformed-api-pages")
        return [item for page in pages for item in page]

    get = get or gh_get
    milestones = get(f"repos/{repo}/milestones?state=all&per_page=100")
    raw = get(f"repos/{repo}/issues?state=open&per_page=100")
    tags = get(f"repos/{repo}/tags?per_page=100")
    items = [{"number": i["number"], "kind": "pr" if "pull_request" in i else "issue",
              "state": i["state"], "labels": [s["name"] for s in i["labels"]],
              "milestone": i["milestone"]["number"] if i["milestone"] else None,
              "linked_issues": []} for i in raw]
    return {"repository": repo, "complete": True, "errors": [], "milestones": milestones,
            "items": items, "tags": [t["name"] for t in tags]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proposal", required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--snapshot")
    source.add_argument("--repo")
    args = parser.parse_args()
    proposal = json.loads(Path(args.proposal).read_text(encoding="utf-8-sig"))
    snapshot = read_snapshot(args.repo) if args.repo else json.loads(
        Path(args.snapshot).read_text(encoding="utf-8-sig"))
    print(json.dumps(build_plan(proposal, snapshot), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"roadmap-plan-failed: {error}")
