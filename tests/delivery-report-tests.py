"""Deterministic captured API fixtures, no credentials/network needed."""

import copy
import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "delivery_report", Path(__file__).resolve().parents[1] / "scripts" / "metrics" / "delivery_report.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
WINDOWS = [{"start": "2026-10-01T00:00:00Z", "end": "2026-10-01T00:15:00Z"},
           {"start": "2026-10-01T00:15:00Z", "end": "2026-10-01T00:30:00Z"}]
SHA = "a" * 40


def fixture():
    runs = [
        {"id": 1, "run_attempt": 2, "workflow_id": 4, "path": "ci.yml", "head_sha": SHA,
         "head_branch": "feature", "event": "pull_request", "pull_requests": [{"number": 9}],
         "created_at": "2026-10-01T00:01:00Z", "html_url": "https://example.test/run/1"},
        {"id": 2, "run_attempt": 1, "workflow_id": 4, "path": "ci.yml", "head_sha": SHA,
         "head_branch": "gh-readonly-queue/main/test", "event": "merge_group",
         "created_at": "2026-10-01T00:16:00Z", "html_url": "https://example.test/run/2"},
        {"id": 3, "run_attempt": 1, "workflow_id": 4, "path": "ci.yml", "head_sha": SHA,
         "head_branch": "main", "event": "push", "created_at": "2026-10-01T00:17:00Z",
         "html_url": "https://example.test/run/3"}]
    attempts = []
    for run in runs:
        for number in range(1, run["run_attempt"] + 1):
            attempts.append({"run": {**run, "run_attempt": number, "status": "completed",
                                     "conclusion": "success" if number == 1 else "cancelled"},
                             "jobs_complete": True,
                             "jobs": [{"id": 100 * run["id"] + number, "status": "completed",
                                       "conclusion": "success", "started_at": run["created_at"],
                                       "completed_at": run["created_at"].replace(":00Z", ":10Z")}]})
    return {"repository": "owner/repo", "windows": copy.deepcopy(WINDOWS),
            "collected_at": "2026-10-01T01:00:00Z", "inventory": runs, "attempts": attempts,
            "targets": {SHA: {"tree_sha": "b" * 40, "statuses": []}},
            "coverage": {"inventory_complete": [True, True]}, "errors": [],
            "current_runs": [], "limitations": [], "releases": [], "prs": {}}


class ReportTests(unittest.TestCase):
    def test_nearest_rank_and_empty(self):
        values = [{"seconds": i, "source": "fixture"} for i in range(1, 21)]
        result = D.summary(values)
        self.assertEqual((result["p50"], result["p95"]), (10, 19))
        self.assertIsNone(D.summary([])["p50"])
        self.assertIsNone(D.interval("2026-10-01T01:00:00Z", "2026-10-01T00:00:00Z", "x")["seconds"])
        self.assertEqual(D.interval("2026-10-01T00:00:00Z", "2026-10-01T00:00:00Z", "x")["seconds"], 0)

    def test_windows(self):
        for windows in ([WINDOWS[0]], [WINDOWS[0], WINDOWS[0]],
                        [WINDOWS[0], {"start": WINDOWS[1]["start"], "end": "2026-10-01T00:31:00Z"}],
                        [{**WINDOWS[0], "start": "2026-10-01T00:00:00-04:00"}, WINDOWS[1]]):
            with self.assertRaises(ValueError):
                D.windows_checked(windows)

    def test_dry_run_and_production_evidence_remain_distinct(self):
        capture = fixture()
        capture["attempts"][0]["run"].update(deployment_mode="dry-run", deployment_mode_source="captured gate inputs")
        capture["attempts"][-1]["run"].update(deployment_mode="production", deployment_mode_source="captured deployment inputs")
        report = D.normalize(capture)
        self.assertEqual(report["attempts"][0]["promotion"], "dry-run gate; not production")
        self.assertIn("not promotion proof", report["attempts"][-1]["promotion"])
        self.assertIsNone(report["attempts"][1]["deployment_mode"]["value"])

    def test_attempt_identity_context_no_duplicate_claim(self):
        capture = fixture()
        capture["inventory"].append(capture["inventory"][0])
        capture["attempts"].append(capture["attempts"][0])
        report = D.normalize(capture)
        self.assertTrue(report["complete"])
        self.assertEqual(len(report["attempts"]), 4)
        self.assertEqual(report["windows"][0]["counts"]["unique_runs_observed"], 1)
        self.assertEqual({a["context"] for a in report["attempts"]}, {"PR", "merge-group", "main"})
        self.assertEqual(report["repeat_candidates"][0]["classification"], "candidate only")
        self.assertEqual(report["windows"][0]["stages"]["execution"]["p95"], 10)
        self.assertIsNone(report["windows"][0]["stages"]["acquisition"]["p50"])

    def test_missing_negative_and_overlap_separate(self):
        capture = fixture()
        job = capture["attempts"][0]["jobs"][0]
        job.update(requested_at="2026-10-01T00:00:00Z",
                   approval_started_at="2026-10-01T00:00:20Z",
                   approval_completed_at="2026-10-01T00:00:40Z")
        capture["attempts"][1]["jobs"][0]["started_at"] = None
        capture["attempts"][2]["jobs"][0]["completed_at"] = "2026-10-01T00:00:00Z"
        report = D.normalize(capture)
        self.assertEqual(report["jobs"][0]["intervals"]["approval"]["seconds"], 20)
        self.assertIsNone(report["jobs"][0]["intervals"]["acquisition"]["seconds"])
        self.assertIn("overlapping", report["jobs"][0]["intervals"]["acquisition"]["reason"])
        self.assertEqual(report["windows"][0]["counts"]["unacquired_unknown_jobs"], 1)
        self.assertEqual(report["jobs"][2]["intervals"]["execution"]["reason"], "negative interval")

    def test_failures_truncation_retention_no_zero_healthy(self):
        capture = fixture()
        capture["coverage"]["inventory_complete"] = [False, True]
        capture["errors"] = ["permission 403", "rate limit 429", "retention 404"]
        capture["attempts"].pop(0)
        report = D.normalize(capture)
        self.assertFalse(report["complete"])
        self.assertTrue(any("Attempt missing" in e for e in report["errors"]))
        self.assertTrue(any(a["kind"] == "incomplete" for a in report["alerts"]))
        capture["attempts"][0]["jobs"] = []
        capture["attempts"][0]["jobs_complete"] = False
        self.assertGreater(D.normalize(capture)["windows"][0]["stages"]["execution"]["excluded_unknown"], 0)

    def test_empty_and_zero_baseline(self):
        capture = fixture()
        for a in capture["attempts"]:
            a["run"]["conclusion"] = "success"
        capture["attempts"][-1]["run"]["conclusion"] = "cancelled"
        report = D.normalize(capture)
        self.assertIsNone(report["comparisons"]["cancellation_rate"]["relative_change"])
        self.assertEqual(report["comparisons"]["cancellation_rate"]["absolute_change"], .5)
        capture.update(inventory=[], attempts=[])
        report = D.normalize(capture)
        self.assertIsNone(report["windows"][0]["fanout"]["value"])
        self.assertIsNone(report["windows"][0]["stages"]["execution"]["p50"])

    def test_immutable_stage_joins_and_ref_movement(self):
        capture = fixture()
        capture["releases"] = [{"target_commitish": "main", "tag_name": "v1", "published_at":
                                "2026-10-01T00:25:00Z", "html_url": "https://example.test/release"}]
        capture["stage_evidence"] = [
            {"stage": "queue", "target_sha": "main", "start": WINDOWS[0]["start"],
             "end": WINDOWS[0]["end"], "source": "queue history", "html_url": "https://example.test/queue"},
            {"stage": "queue", "target_sha": SHA, "start": WINDOWS[0]["start"],
             "end": WINDOWS[0]["end"], "source": "observed enqueue -> merge",
             "run_id": 1, "run_attempt": 1,
             "html_url": "https://example.test/queue"}]
        capture["prs"] = {"9": {"merged_at": "2026-10-01T00:25:00Z", "merge_commit_sha": "c" * 40}}
        report = D.normalize(capture)
        self.assertIsNone(report["milestones"][1]["target_sha"])
        self.assertEqual(report["windows"][0]["stages"]["queue"]["p50"], 900)
        self.assertIsNone(report["windows"][0]["stages"]["merge"]["p50"])
        self.assertTrue(any("Unjoinable" in e for e in report["errors"]))
        self.assertTrue(all("unknown" in a["promotion"] for a in report["attempts"]))

    def test_current_failure_and_markdown_same_normalized_data(self):
        capture = fixture()
        capture["current_runs"] = [{**capture["inventory"][-1], "conclusion": "failure"}]
        report = D.normalize(capture)
        output = D.markdown(report)
        self.assertIn(report["current_failures"][0]["html_url"], output)
        self.assertIn(json.dumps(report["windows"][0]["counts"], sort_keys=True), output)
        self.assertIn("| execution | seconds | 2 | 0 | 10.0 | 10.0 |", output)
        self.assertEqual(json.loads(json.dumps(report))["schema_version"], 1)

    def test_eligibility_and_release_intervals(self):
        capture = fixture()
        capture["targets"][SHA]["statuses"] = [
            {"context": "BaseCoat merge eligibility", "state": "success",
             "created_at": "2026-10-01T00:01:40Z", "target_url": "https://example.test/status"}]
        for a in capture["attempts"]:
            if a["run"]["id"] == 3:
                a["run"]["path"] = ".github/workflows/package-basecoat.yml"
                a["package_target"] = {"sha": SHA, "source": "captured package assertion",
                                       "html_url": "https://example.test/package"}
        capture["releases"] = [{"target_commitish": SHA, "published_at": "2026-10-01T00:18:00Z",
                                "html_url": "https://example.test/release", "draft": False}]
        capture["prs"] = {"9": {"created_at": "2026-10-01T00:00:00Z",
                                "merged_at": "2026-10-01T00:17:00Z", "merge_commit_sha": SHA,
                                "head": {"sha": SHA}}}
        report = D.normalize(capture)
        self.assertEqual(report["windows"][0]["stages"]["eligibility"]["p50"], 30)
        self.assertIsNone(report["windows"][1]["stages"]["eligibility"]["p50"])
        self.assertEqual(report["windows"][1]["stages"]["packaging"]["p50"], 10)
        self.assertEqual(report["windows"][1]["stages"]["release"]["p50"], 50)
        self.assertEqual(report["windows"][0]["stages"]["delivery"]["p50"], 1080)
        self.assertNotIn("production", report["milestones"][0].get("promotion", "").split(";")[0])

    def test_package_controller_sha_is_not_artifact_target(self):
        capture = fixture()
        target = "b" * 40
        package = capture["attempts"][-1]
        package["run"]["path"] = ".github/workflows/package-basecoat.yml"
        capture["releases"] = [{"target_commitish": SHA, "published_at": "2026-10-01T00:18:00Z",
                                "html_url": "https://example.test/a", "draft": False},
                               {"target_commitish": target, "published_at": "2026-10-01T00:18:00Z",
                                "html_url": "https://example.test/b", "draft": False}]
        unknown = [e for e in D.normalize(capture)["stage_evidence"] if e["stage"] == "packaging"][0]
        self.assertEqual((unknown["controller_sha"], unknown["artifact_target_sha"]), (SHA, None))
        self.assertIn("unavailable", unknown["artifact_target_reason"])
        self.assertFalse([e for e in D.normalize(capture)["stage_evidence"] if e["stage"] == "release"])
        package["package_target"] = {"sha": target, "source": "captured package assertion",
                                     "html_url": "https://example.test/package"}
        evidence = [e for e in D.normalize(capture)["stage_evidence"] if e["stage"] in ("packaging", "release")]
        self.assertEqual((evidence[0]["controller_sha"], evidence[0]["artifact_target_sha"]), (SHA, target))
        self.assertEqual([e["html_url"] for e in evidence[1:]], ["https://example.test/b"])

    def test_nonterminal_attempts_and_jobs_have_no_end(self):
        for field, value in (("status", "in_progress"), ("conclusion", None)):
            capture = fixture()
            capture["attempts"][0]["jobs"][0][field] = value
            check = D.normalize(capture)["stage_evidence"][0]
            self.assertIsNone(check["end"])
            self.assertEqual(check["interval"]["reason"], "nonterminal attempt/job")
        capture = fixture()
        capture["attempts"][0]["run"]["status"] = "in_progress"
        self.assertIsNone(D.normalize(capture)["stage_evidence"][0]["end"])

    def test_pagination_and_partition(self):
        collector = D.Collector("owner/repo")
        with patch.object(collector, "api", side_effect=[
                {"total_count": 101, "jobs": [{}] * 100}, {"total_count": 101, "jobs": [{}]}]):
            rows, complete = collector.listing("jobs", "jobs")
        self.assertEqual(len(rows), 101)
        self.assertTrue(complete)
        with patch.object(collector, "api", return_value={"total_count": 10, "jobs": [{}]}):
            self.assertFalse(collector.listing("jobs", "jobs")[1])
        for invalid, key in (({"total_count": 1, "jobs": {}}, "jobs"), ({"message": "not a list"}, None)):
            with patch.object(collector, "api", return_value=invalid):
                self.assertFalse(collector.listing("shape", key)[1])
            self.assertIn("Invalid pagination shape: shape", collector.errors[-1])
        with patch.object(collector, "api", side_effect=[
                {"total_count": 1001, "workflow_runs": [{}] * 100},
                {"total_count": 1, "workflow_runs": [{"id": 1}]},
                {"total_count": 1, "workflow_runs": [{"id": 2}]}]):
            rows, complete = collector.inventory(D.timestamp(WINDOWS[0]["start"]),
                                                  D.timestamp(WINDOWS[0]["end"]))
        self.assertTrue(complete)
        self.assertEqual([r["id"] for r in rows], [1, 2])

    def test_api_failure_and_budget(self):
        collector = D.Collector("owner/repo", 1)
        with patch.object(D.subprocess, "run") as run:
            run.return_value.returncode = 1
            run.return_value.stderr = "SECRET gh: API rate limit exceeded (HTTP 403)"
            self.assertIsNone(collector.api("actions/runs"))
        self.assertNotIn("SECRET", str(collector.errors))
        self.assertIn("rate limit; HTTP 403", collector.errors[0])
        self.assertIsNone(collector.api("actions/runs"))
        self.assertIn("budget exhausted", collector.errors[-1])
        collector = D.Collector("owner/repo")
        for code, expected in ((403, "permission"), (429, "rate limit"), (404, "retention")):
            with patch.object(D.subprocess, "run") as run:
                run.return_value.returncode = 1
                run.return_value.stderr = f"gh error (HTTP {code}) SECRET"
                self.assertIsNone(collector.api("actions/runs"))
            self.assertIn(expected, collector.errors[-1])


if __name__ == "__main__":
    unittest.main()
