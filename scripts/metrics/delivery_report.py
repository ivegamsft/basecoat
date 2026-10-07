"""Read-only Actions delivery evidence; no workflow timestamps masquerade as execution."""

import argparse
import json
import math
import re
import subprocess
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode

STAGES = ("execution", "acquisition", "approval", "checks", "eligibility",
          "enqueue", "queue", "merge", "packaging", "release", "delivery")
TERMINAL = {"success", "failure", "cancelled", "skipped", "timed_out", "neutral", "stale"}
SHA_PATTERN = re.compile(r"[0-9a-fA-F]{40}")
RELEASE_WORKFLOWS = ("release.yml", "release-train.yml", "publish-to-production.yml",
                     "package-basecoat.yml", "ship-it-release-gate.yml",
                     "post-merge-release-chain.yml")


def timestamp(value):
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.utcoffset() != timedelta(0):
        raise ValueError("Timestamps must be UTC")
    return parsed


def windows_checked(windows):
    pairs = [(timestamp(w["start"]), timestamp(w["end"])) for w in windows]
    if len(pairs) != 2 or any(not a or not b or a >= b for a, b in pairs):
        raise ValueError("Two positive UTC windows are required")
    if pairs[0][1] - pairs[0][0] != pairs[1][1] - pairs[1][0]:
        raise ValueError("Windows must have equal lengths")
    if max(p[0] for p in pairs) < min(p[1] for p in pairs):
        raise ValueError("Windows must not overlap")
    return pairs


def interval(start, end, source):
    if not start or not end:
        return {"seconds": None, "source": source, "reason": "timestamp unobserved"}
    try:
        seconds = (timestamp(end) - timestamp(start)).total_seconds()
    except ValueError:
        return {"seconds": None, "source": source, "reason": "invalid timestamp"}
    return {"seconds": seconds if seconds >= 0 else None, "source": source,
            "reason": "negative interval" if seconds < 0 else None}


def summary(values):
    valid = sorted(v["seconds"] for v in values if v["seconds"] is not None)
    return {"unit": "seconds", "valid_samples": len(valid),
            "excluded_unknown": len(values) - len(valid),
            "p50": valid[math.ceil(.5 * len(valid)) - 1] if valid else None,
            "p95": valid[math.ceil(.95 * len(valid)) - 1] if valid else None,
            "sources": sorted({v["source"] for v in values})}


class Collector:
    def __init__(self, repository, max_requests=2000):
        self.repository, self.max_requests = repository, max_requests
        self.requests, self.errors, self.pages = 0, [], []

    def api(self, endpoint):
        if self.requests >= self.max_requests:
            if "request budget exhausted; bounded convenience sample" not in self.errors:
                self.errors.append("request budget exhausted; bounded convenience sample")
            return None
        self.requests += 1
        try:
            result = subprocess.run(["gh", "api", f"repos/{self.repository}/{endpoint}"],
                                    capture_output=True, text=True, encoding="utf-8", timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            self.errors.append(f"API unavailable: {endpoint} (CLI unavailable/timeout)")
            return None
        if result.returncode:
            # Extract only fixed categories/status codes, not possibly sensitive helper output.
            text = result.stderr.lower()
            status = re.search(r"http\s+(\d{3})", text)
            code = status[1] if status else "unknown"
            category = "rate limit" if "rate limit" in text or code == "429" else (
                "permission" if code in ("401", "403") else "retention/not found" if code == "404" else "network/API")
            self.errors.append(f"API unavailable: {endpoint} ({category}; HTTP {code}; "
                               f"gh exit {result.returncode})")
            return None
        try:
            return json.loads(result.stdout)
        except ValueError:
            self.errors.append(f"Invalid API JSON: {endpoint}")
            return None

    def listing(self, endpoint, key=None, cap=None):
        rows, page, expected = [], 1, None
        while True:
            data = self.api(endpoint + ("&" if "?" in endpoint else "?") +
                            f"per_page=100&page={page}")
            if data is None:
                return rows, False
            batch = data.get(key) if key and isinstance(data, dict) else data
            if not isinstance(batch, list):
                self.errors.append(f"Invalid pagination shape: {endpoint}")
                return rows, False
            expected = data.get("total_count") if key else None
            self.pages.append({"endpoint": endpoint, "page": page, "rows": len(batch),
                               "total_count": expected})
            rows.extend(batch)
            if cap and expected is not None and expected > cap:
                return rows, False
            if len(batch) < 100 or (expected is not None and len(rows) >= expected):
                complete = expected is None or len(rows) == expected
                if key and rows and all("id" in r for r in rows):
                    complete = complete and len({r["id"] for r in rows}) == len(rows)
                if not complete:
                    self.errors.append(f"Pagination truncated: {endpoint}")
                return rows, complete
            page += 1

    def inventory(self, start, end):
        # GitHub's created filter is inclusive with second precision.
        query = urlencode({"created": f"{start.isoformat()}.."
                                      f"{(end - timedelta(seconds=1)).isoformat()}"})
        page_start = len(self.pages)
        rows, complete = self.listing("actions/runs?" + query, "workflow_runs", 1000)
        total = self.pages[-1]["total_count"] if len(self.pages) > page_start else None
        if total and total > 1000:
            if (end - start).total_seconds() <= 1:
                self.errors.append("Actions cap exceeds one-second partition; inventory truncated")
                return rows, False
            midpoint = start + timedelta(seconds=int((end - start).total_seconds() // 2))
            left, lc = self.inventory(start, midpoint)
            right, rc = self.inventory(midpoint, end)
            return left + right, lc and rc
        return rows, complete

    def collect(self, windows):
        pairs = windows_checked(windows)
        if any(t.microsecond for pair in pairs for t in pair):
            raise ValueError("Live API windows require whole-second boundaries")
        runs, inventory_complete = {}, []
        for start, end in pairs:
            rows, complete = self.inventory(start, end)
            inventory_complete.append(complete)
            for run in rows:
                created = timestamp(run.get("created_at"))
                if created and start <= created < end:
                    runs[run["id"]] = run
        attempts, targets = [], {}
        for run in runs.values():
            sha = run.get("head_sha")
            if sha not in targets:
                commit = self.api(f"commits/{sha}") if sha else None
                statuses, sc = self.listing(f"commits/{sha}/statuses") if sha else ([], False)
                targets[sha] = {"tree_sha": (commit or {}).get("commit", {}).get("tree", {}).get("sha"),
                                "statuses": statuses, "statuses_complete": sc}
            for number in range(1, (run.get("run_attempt") or 1) + 1):
                detail = self.api(f"actions/runs/{run['id']}/attempts/{number}")
                jobs, jc = self.listing(f"actions/runs/{run['id']}/attempts/{number}/jobs", "jobs")
                attempts.append({"run": detail or {**run, "run_attempt": number,
                                                   "status": None, "conclusion": None},
                                 "attempt_available": detail is not None,
                                 "jobs": jobs, "jobs_complete": jc})
        prs = {}
        for run in runs.values():
            for pr in run.get("pull_requests", []):
                if pr["number"] not in prs:
                    prs[pr["number"]] = self.api(f"pulls/{pr['number']}")
        releases, release_complete = self.listing("releases")
        # Current failures are a separate, explicitly bounded snapshot, not window statistics.
        snapshot = self.api("actions/runs?per_page=100")
        return {"repository": self.repository, "windows": windows,
                "collected_at": datetime.now(timezone.utc).isoformat(),
                "inventory": list(runs.values()), "attempts": attempts, "targets": targets,
                "prs": prs, "releases": releases,
                "current_runs": (snapshot or {}).get("workflow_runs", []),
                "coverage": {"inventory_complete": inventory_complete,
                             "release_complete": release_complete, "requests": self.requests,
                             "current_snapshot_available": snapshot is not None,
                             "pagination": self.pages},
                "errors": self.errors,
                "limitations": ["Current failures: latest observed workflow/context among first 100 runs; not a complete current workflow inventory.",
                                "Retention gaps before requested windows cannot be excluded.",
                                "GitHub REST does not expose historical enqueue, approval holds, or job-request timestamps here; these remain unknown.",
                                "Release tags/branch target_commitish are mutable and are not resolved to current tips. Only full immutable release SHAs are joined.",
                                "Eligibility is SHA-scoped status evidence for an unambiguous observed PR target only; it is not queue authorization or a main/merge-group status.",
                                "Package artifact targets are not inferred from controller workflow SHAs; live collection leaves them unknown without trusted captured assertions.",
                                "All attempts of runs created in each window are expanded; attempts may execute outside that window. This is a run-created cohort.",
                                "API collection is not atomic; reruns/ref changes after inventory observation cannot be excluded. Immutable captured identities are retained."]}


def context(run):
    event = run.get("event")
    if event in ("pull_request", "pull_request_target"):
        return "PR"
    if event == "merge_group":
        return "merge-group"
    return "main" if run.get("head_branch") == "main" else "other"


def normalize(capture, fanout_threshold=.25, cancellation_threshold=.10):
    pairs = windows_checked(capture["windows"])
    inventory = {r["id"]: r for r in capture.get("inventory", [])}
    errors = list(capture.get("errors", []))
    coverage = capture.get("coverage", {})
    attempts, jobs, seen = [], [], set()
    for item in capture.get("attempts", []):
        run = item["run"]
        identity = (run["id"], run.get("run_attempt"))
        if identity in seen:
            continue
        seen.add(identity)
        target = capture.get("targets", {}).get(run.get("head_sha"), {})
        row = {key: run.get(key) for key in
               ("workflow_id", "path", "head_sha", "event", "status", "conclusion", "html_url")}
        row.update(run_id=run["id"], run_attempt=run.get("run_attempt"), context=context(run),
                   tree_sha=target.get("tree_sha"),
                   pr_numbers=[p["number"] for p in run.get("pull_requests", [])],
                   created_at=inventory.get(run["id"], run).get("created_at"),
                   jobs_complete=item.get("jobs_complete", False),
                   attempt_available=item.get("attempt_available", True),
                   promotion="unknown: run success does not establish production or dry-run mode",
                   missing={})
        mode = run.get("deployment_mode")
        mode_source = run.get("deployment_mode_source")
        row["deployment_mode"] = {"value": mode if mode in ("dry-run", "production") and mode_source else None,
                                  "source": mode_source,
                                  "reason": None if mode in ("dry-run", "production") and mode_source
                                  else "deployment inputs/authorization unobserved"}
        if row["deployment_mode"]["value"]:
            row["promotion"] = ("dry-run gate; not production" if mode == "dry-run" else
                                "production-mode attempt; conclusion alone is not promotion proof")
        for key in ("workflow_id", "path", "head_sha", "tree_sha", "event", "run_attempt",
                    "created_at", "status", "conclusion", "html_url"):
            if row[key] is None:
                row["missing"][key] = "not available from captured API evidence"
        if not row["pr_numbers"]:
            row["missing"]["pr_numbers"] = "PR not provided by run metadata"
        if not row["jobs_complete"] or not row["attempt_available"]:
            errors.append(f"Incomplete attempt/jobs: {identity}")
        attempts.append(row)
        for job in item.get("jobs", []):
            jr = {**row, "job_id": job.get("id"), "status": job.get("status"),
                  "conclusion": job.get("conclusion"), "html_url": job.get("html_url"),
                  "started_at": job.get("started_at"), "completed_at": job.get("completed_at")}
            jr["missing"] = dict(row["missing"])
            for field in ("job_id", "started_at", "completed_at"):
                if jr[field] is None:
                    jr["missing"][field] = "not observed in attempt job evidence"
            jr["acquisition_state"] = "started" if job.get("started_at") else "unacquired/unknown"
            jr["intervals"] = {"execution": interval(job.get("started_at"), job.get("completed_at"),
                                                   "job.started_at -> job.completed_at"),
                               "approval": interval(job.get("approval_started_at"),
                                                    job.get("approval_completed_at"),
                                                    "captured approval hold"),
                               "acquisition": interval(job.get("requested_at"), job.get("started_at"),
                                                       "captured job request -> job.started_at")}
            # Overlapping approval/acquisition observations cannot both count as separate waits.
            if job.get("approval_started_at") and job.get("requested_at"):
                a, b = timestamp(job["approval_started_at"]), timestamp(job.get("approval_completed_at"))
                c, d = timestamp(job["requested_at"]), timestamp(job.get("started_at"))
                if b and d and max(a, c) < min(b, d):
                    jr["intervals"]["acquisition"].update(seconds=None,
                                                         reason="overlapping approval/acquisition")
                elif not b:
                    jr["intervals"]["acquisition"].update(seconds=None,
                                                         reason="approval end unknown; cannot exclude overlap")
            jobs.append(jr)
    for run in inventory.values():
        for number in range(1, (run.get("run_attempt") or 1) + 1):
            if (run["id"], number) not in seen:
                errors.append(f"Attempt missing: {(run['id'], number)}")
    evidence = []
    observed_prs = {}
    for attempt in attempts:
        observed_prs.setdefault(attempt["head_sha"], set()).update(attempt["pr_numbers"])
    for attempt in attempts:
        associated = [j for j in jobs if (j["run_id"], j["run_attempt"]) ==
                      (attempt["run_id"], attempt["run_attempt"])]
        starts = [j["started_at"] for j in associated if j["started_at"]]
        ends = [j["completed_at"] for j in associated if j["completed_at"]]
        start = min(starts, key=timestamp) if starts else None
        terminal = (attempt["status"] == "completed" and attempt["conclusion"] in TERMINAL and
                    all(j["status"] == "completed" and j["conclusion"] in TERMINAL for j in associated))
        end = (max(ends, key=timestamp) if ends and len(ends) == len(associated)
               and attempt["jobs_complete"] and terminal else None)
        sha = attempt["head_sha"]
        path = (attempt["path"] or "").split("@")[0]
        stage = "packaging" if path.endswith("package-basecoat.yml") else "checks"
        item = {**attempt, "stage": stage, "start": start, "end": end,
                "source": "attempt job wall span (not CPU time)",
                "interval": interval(start, end, "attempt job wall span")}
        if not terminal:
            item["interval"]["reason"] = "nonterminal attempt/job"
        if stage == "packaging":
            assertion = next((i.get("package_target") for i in capture.get("attempts", [])
                              if (i["run"]["id"], i["run"].get("run_attempt")) ==
                              (attempt["run_id"], attempt["run_attempt"])), None) or {}
            target = assertion.get("sha")
            trusted = bool(target and SHA_PATTERN.fullmatch(target) and assertion.get("source")
                           and assertion.get("html_url"))
            item.update(controller_sha=sha, artifact_target_sha=target if trusted else None,
                        artifact_target_source=assertion.get("source") if trusted else None,
                        artifact_target_reason=None if trusted else
                        "trusted package assertion/artifact/log evidence unavailable")
        evidence.append(item)
        if (stage == "checks" and attempt["context"] == "PR" and attempt["pr_numbers"]
                and len(observed_prs.get(sha, set())) == 1 and attempt["conclusion"] == "success"):
            statuses = capture.get("targets", {}).get(sha, {}).get("statuses", [])
            eligible = [s for s in statuses if s.get("context") == "BaseCoat merge eligibility"
                        and s.get("state") == "success"]
            # A status must follow this attempt's completed checks; never use a prior SHA status.
            following = [s for s in eligible if end and s.get("created_at") and
                         timestamp(s["created_at"]) >= timestamp(end)]
            status = min(following, key=lambda s: timestamp(s["created_at"])) if following else {}
            evidence.append({**attempt, "stage": "eligibility", "start": end,
                             "end": status.get("created_at"), "source": "same-SHA status.created_at",
                             "html_url": status.get("target_url") or attempt["html_url"],
                             "interval": interval(end, status.get("created_at"),
                                                  "checks end -> same-SHA eligibility status")})
    # Optional captured history must identify its immutable target, not a mutable ref.
    for entry in capture.get("stage_evidence", []):
        if entry.get("stage") not in STAGES:
            raise ValueError("Unknown captured stage")
        linked = [a for a in attempts if a["head_sha"] and a["head_sha"] == entry.get("target_sha")]
        for field in ("run_id", "run_attempt", "context", "event"):
            if field in entry:
                linked = [a for a in linked if a[field] == entry[field]]
        if len(linked) != 1 or not entry.get("source") or not entry.get("html_url"):
            errors.append("Unjoinable stage evidence (unambiguous immutable attempt/source/link required)")
            continue
        evidence.append({**linked[0], **entry,
                         "interval": interval(entry.get("start"), entry.get("end"), entry["source"])})
    milestones = []
    for number, pr in capture.get("prs", {}).items():
        if pr:
            milestones.append({"stage": "merge", "pr_number": int(number),
                               "target_sha": pr.get("merge_commit_sha"), "at": pr.get("merged_at"),
                               "source": "PR.merged_at (point, not merge duration)", "html_url": pr.get("html_url")})
    for release in capture.get("releases", []):
        sha = release.get("target_commitish")
        immutable = bool(sha and re.fullmatch(r"[0-9a-fA-F]{40}", sha))
        milestones.append({"stage": "release", "target_sha": sha if immutable else None,
                           "at": release.get("published_at"), "html_url": release.get("html_url"),
                           "source": "release.published_at", "promotion": "draft" if release.get("draft")
                           else "prerelease" if release.get("prerelease") else "published release; not production proof",
                           "reason": None if immutable else "mutable release ref; target unknown"})
        if immutable and not release.get("draft"):
            packaging = [e for e in evidence if e["stage"] == "packaging" and e["artifact_target_sha"] == sha
                         and e.get("end") and e.get("conclusion") == "success"
                         and release.get("published_at") and
                         timestamp(e["end"]) <= timestamp(release["published_at"])]
            if packaging:
                package = max(packaging, key=lambda e: timestamp(e["end"]))
                evidence.append({**package, "stage": "release", "html_url": release.get("html_url"),
                                 "source": "trusted package target end -> release published",
                                 "interval": interval(package["end"], release["published_at"],
                                                      "trusted package target end -> release published")})
                for number, pr in capture.get("prs", {}).items():
                    if not pr or not pr.get("merged_at") or pr.get("merge_commit_sha") != sha:
                        continue
                    if timestamp(pr["merged_at"]) > timestamp(package["end"]):
                        continue
                    head = pr.get("head", {}).get("sha")
                    linked = [a for a in attempts if a["context"] == "PR" and a["head_sha"] == head
                              and int(number) in a["pr_numbers"]]
                    if linked:
                        anchor = min(linked, key=lambda a: (a["run_id"], a["run_attempt"]))
                        evidence.append({**anchor, "stage": "delivery", "target_sha": sha,
                                         "source": "PR.created_at -> immutable merged-target release",
                                         "html_url": release.get("html_url"),
                                         "interval": interval(pr.get("created_at"), release["published_at"],
                                                              "PR.created_at -> immutable merged-target release")})
    reports = []
    for index, (start, end) in enumerate(pairs):
        selected = [a for a in attempts if timestamp(a["created_at"]) and
                    start <= timestamp(a["created_at"]) < end]
        ids = {a["run_id"] for a in selected}
        runs = [r for r in inventory.values() if timestamp(r.get("created_at")) and
                start <= timestamp(r["created_at"]) < end]
        targets = {r.get("head_sha") for r in runs if r.get("head_sha")}
        cancels = sum(a["conclusion"] == "cancelled" for a in selected)
        stages = {}
        for stage in STAGES:
            values = [j["intervals"][stage] for j in jobs if j["run_id"] in ids] if stage in (
                "execution", "acquisition", "approval") else [
                    e["interval"] for e in evidence if e["run_id"] in ids and e["stage"] == stage]
            if stage not in ("execution", "acquisition", "approval"):
                observed = {e["head_sha"] for e in evidence if e["run_id"] in ids and e["stage"] == stage}
                values += [interval(None, None, f"{stage}: no joined interval")] * len(targets - observed)
            else:
                job_attempts = {(j["run_id"], j["run_attempt"]) for j in jobs}
                values += [interval(None, None, "attempt jobs absent/unavailable") for a in selected
                           if (a["run_id"], a["run_attempt"]) not in job_attempts]
            stages[stage] = summary(values)
        complete = (coverage.get("inventory_complete", [False, False])[index] and not errors)
        reports.append({"boundaries": capture["windows"][index], "complete": complete,
                        "counts": {"unique_runs_observed": len(runs), "attempts_observed": len(selected),
                                   "expected_attempts": sum(r.get("run_attempt") or 1 for r in runs),
                                   "jobs_observed": sum(j["run_id"] in ids for j in jobs),
                                   "unacquired_unknown_jobs": sum(j["run_id"] in ids and not j["started_at"] for j in jobs),
                                   "targets_observed": len(targets), "cancellations": cancels,
                                   "events": dict(Counter(r.get("event") or "unknown" for r in runs)),
                                   "attempt_events": dict(Counter(a["event"] or "unknown" for a in selected)),
                                   "contexts": dict(Counter(a["context"] for a in selected))},
                        "fanout": {"numerator": len(runs), "denominator": len(targets),
                                   "value": len(runs) / len(targets) if targets else None},
                        "cancellation_rate": {"numerator": cancels, "denominator": len(selected),
                                              "value": cancels / len(selected) if selected else None},
                        "stages": stages})
    comparisons, alerts = {}, []
    for metric, threshold in (("fanout", fanout_threshold), ("cancellation_rate", cancellation_threshold)):
        a, b = (r[metric]["value"] for r in reports)
        delta = b - a if a is not None and b is not None else None
        relative = delta / a if delta is not None and a > 0 else None
        comparisons[metric] = {"absolute_change": delta, "relative_change": relative,
                               "threshold": threshold, "threshold_unit": "relative" if metric == "fanout" else "absolute",
                               "reason": "zero/unknown baseline: no relative increase" if relative is None else None}
        signal = relative if metric == "fanout" else delta
        if signal is not None and signal >= threshold:
            alerts.append({"kind": metric, "message": "increase observed; two windows cannot prove sustained trend",
                           "qualified": not all(r["complete"] for r in reports)})
    current, latest = [], set()
    for run in sorted(capture.get("current_runs", []), key=lambda r: r.get("created_at", ""), reverse=True):
        key = (run.get("workflow_id"), context(run), run.get("event"), run.get("head_branch"))
        if key in latest:
            continue
        latest.add(key)
        if (context(run) == "main" or (run.get("path") or "").split("@")[0].endswith(
                RELEASE_WORKFLOWS)) and run.get("conclusion") in (
                    "failure", "timed_out", "cancelled"):
            current.append({"run_id": run["id"], "workflow": run.get("path"), "context": context(run),
                            "head_sha": run.get("head_sha"), "html_url": run.get("html_url"),
                            "conclusion": run["conclusion"], "promotion": "unknown; not production proof"})
    repeats = []
    groups = {}
    for a in attempts:
        key = (a["workflow_id"], a["path"], a["event"], a["context"], a["head_sha"], a["tree_sha"])
        groups.setdefault(key, []).append((a["run_id"], a["run_attempt"]))
    for key, identities in groups.items():
        if len(identities) > 1:
            repeats.append({"identity": key, "attempts": identities, "classification": "candidate only",
                            "reason": "reruns and same-target observations are not equivalent-work proof"})
    if errors:
        alerts.append({"kind": "incomplete", "message": "API/coverage failures; no healthy conclusion"})
    if not all(coverage.get("inventory_complete", [False, False])):
        alerts.append({"kind": "incomplete", "message": "Inventory incomplete; observed counts are lower bounds"})
    return {"schema_version": 1, "repository": capture["repository"],
            "collected_at": capture.get("collected_at"), "complete": all(r["complete"] for r in reports),
            "sampling": "run-created cohorts; all available attempts; nearest-rank nonnegative seconds; no confidence intervals",
            "coverage": coverage, "limitations": capture.get("limitations", []), "errors": sorted(set(errors)),
            "windows": reports, "attempts": attempts, "jobs": jobs, "stage_evidence": evidence,
            "milestones": milestones, "repeat_candidates": repeats, "comparisons": comparisons,
            "current_failures": current, "alerts": alerts}


def markdown(report):
    lines = ["# Delivery stages report", "", f"Repository: {report['repository']}",
             f"Collected UTC: {report['collected_at']}", f"Complete: {report['complete']}",
             "", report["sampling"], "", "## Coverage and limitations", ""]
    lines += [f"- {v}" for v in report["limitations"] + report["errors"]]
    for index, window in enumerate(report["windows"]):
        lines += ["", f"## Window {index + 1}", "",
                  f"[{window['boundaries']['start']}, {window['boundaries']['end']})",
                  "", f"Counts: `{json.dumps(window['counts'], sort_keys=True)}`", "",
                  f"Fan-out: `{json.dumps(window['fanout'])}`; cancellation: `{json.dumps(window['cancellation_rate'])}`",
                  "", "| Stage | Unit | Valid | Unknown/excluded | P50 | P95 | Source |",
                  "|---|---|---:|---:|---:|---:|---|"]
        for stage, s in window["stages"].items():
            p50 = s["p50"] if s["p50"] is not None else "unknown"
            p95 = s["p95"] if s["p95"] is not None else "unknown"
            lines.append(f"| {stage} | {s['unit']} | {s['valid_samples']} | {s['excluded_unknown']} | "
                         f"{p50} | {p95} | {', '.join(s['sources'])} |")
    lines += ["", "## Comparisons and alerts", ""]
    lines += [f"- {k}: `{json.dumps(v)}`" for k, v in report["comparisons"].items()]
    lines += [f"- {a['kind']}: {a['message']}" for a in report["alerts"]]
    lines += ["", "## Current failures (separate bounded snapshot)", ""]
    lines.append("Latest observed only; missing failures are not evidence of healthy delivery.")
    lines += [f"- [{r['workflow']} / {r['run_id']}]({r['html_url']}): {r['conclusion']}; "
              f"{r['context']}; {r['promotion']}" for r in report["current_failures"]]
    lines += ["", "## Attempt evidence", "",
              "| Workflow | Run / attempt | Context | SHA | Jobs complete | Promotion |",
              "|---|---|---|---|---|---|"]
    lines += [f"| {a['path']} | [{a['run_id']}/{a['run_attempt']}]({a['html_url']}) | "
              f"{a['context']} | {a['head_sha']} | {a['jobs_complete']} | {a['promotion']} |"
              for a in report["attempts"]]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--start", nargs=2, required=True)
    parser.add_argument("--end", nargs=2, required=True)
    parser.add_argument("--output", required=True, help="Output prefix: .json, .md, .capture.json")
    parser.add_argument("--fixture")
    parser.add_argument("--max-requests", type=int, default=2000)
    parser.add_argument("--fanout-threshold", type=float, default=.25)
    parser.add_argument("--cancellation-threshold", type=float, default=.10)
    args = parser.parse_args()
    windows = [dict(start=a, end=b) for a, b in zip(args.start, args.end)]
    windows_checked(windows)
    if args.max_requests < 1 or min(args.fanout_threshold, args.cancellation_threshold) < 0:
        parser.error("Budget must be positive and thresholds nonnegative")
    if args.fixture:
        capture = json.loads(Path(args.fixture).read_text(encoding="utf-8-sig"))
        if capture["repository"] != args.repository or capture["windows"] != windows:
            parser.error("Fixture repository/windows must match requested comparison")
    else:
        capture = Collector(args.repository, args.max_requests).collect(windows)
    report = normalize(capture, args.fanout_threshold, args.cancellation_threshold)
    prefix = Path(args.output)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    for suffix, data in ((".capture.json", capture), (".json", report)):
        Path(str(prefix) + suffix).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    Path(str(prefix) + ".md").write_text(markdown(report), encoding="utf-8")
    print(f"{prefix}: complete={report['complete']}; attempts={len(report['attempts'])}; "
          f"jobs={len(report['jobs'])}; errors={len(report['errors'])}")
    return 0 if report["complete"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
