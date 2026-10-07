"""Grouping contract, immutable local replay, and no-write end-to-end tests."""

import copy
import importlib.util
import json
import sqlite3
import subprocess
import sys
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
SPEC = importlib.util.spec_from_file_location("roadmap_preview", ROOT / "scripts" / "roadmap" /
                                             "preview.py")
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
P = V.P


def fixture():
    snapshot = {"repository": "owner/repo", "complete": True, "errors": [], "milestones": [],
                "tags": ["v1.0.0"], "items": [
                    {"number": n, "kind": "issue", "state": "open", "labels": ["area:ui"],
                     "milestone": None} for n in range(1, 7)] + [
                    {"number": n, "kind": "pr", "state": "open", "labels": [],
                     "milestone": None} for n in (7, 8, 9)]}
    group = {"id": "ui", "issues": [1, 2, 3, 4, 5], "merged_prs": 0, "loc": 200,
             "activity_days": 7, "explicit_binding": False,
             "debate": {"split": "Single area but multiple entry points.",
                        "merge": "Same scoped surface.", "decision": "retain", "confidence": 0.70}}
    evidence = {"schema": 1, "repository": "owner/repo", "scope": "all",
                "current_version": "v1.0.0", "snapshot_digest": V.snapshot_digest(snapshot),
                "mapper": {"source": "sprint-project-mapper", "groups": [group],
                           "themes": [{"theme": "UI", "issues": [1, 2, 3, 4, 5, 6]}],
                           "links": [{"pr": 7, "issues": [1]}, {"pr": 8, "issues": [1, 2]}],
                           "residuals": [{"number": 6, "reason": "No release linkage."}]},
                "advisor": {"source": "release-impact-advisor", "current_version": "v1.0.0",
                            "recommendations": [
                                {"group": "ui", "release": "v1.1.0", "risks": "Supplied risk.",
                                 "rollout": "Feature flag.", "rollback": "Revert."}]}}
    return evidence, snapshot


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.evidence, self.snapshot = fixture()
        self.paths = []

    def tearDown(self):
        for path in self.paths:
            for suffix in ("", "-journal", "-wal", "-shm"):
                Path(str(path) + suffix).unlink(missing_ok=True)

    def path(self, suffix):
        path = ROOT / "tests" / f"roadmap-test-{uuid.uuid4().hex}.{suffix}"
        self.paths.append(path)
        return path

    def preview(self):
        return V.normalize(self.evidence, self.snapshot)

    def rebind(self):
        self.evidence["snapshot_digest"] = V.snapshot_digest(self.snapshot)

    def test_complete_group_linkage_residuals_and_stable_render(self):
        result = self.preview()
        self.assertEqual([a["number"] for a in result["plan"]["assignments"]], [1, 2, 3, 4, 5, 7])
        self.assertEqual([r["number"] for r in result["plan"]["residuals"]], [6, 8, 9])
        self.snapshot["items"].reverse()
        self.evidence["mapper"]["links"].reverse()
        self.evidence["mapper"]["groups"][0]["issues"].reverse()
        self.assertEqual(result, self.preview())
        self.evidence["scope"] = " all "
        self.evidence["repository"] = "OWNER/REPO"
        self.evidence["mapper"]["themes"][0]["theme"] = "ui"
        self.assertEqual(result, self.preview())
        artifact = V.render(result)
        self.assertEqual(artifact, V.render(self.preview()))
        self.assertNotIn("run-1", artifact)
        self.assertIn("verified tag: none", artifact)
        self.assertIn("not approved", artifact)

    def test_all_label_issue_set_theme_selection(self):
        for selector in ("all", "label:AREA:UI", "issue-set:#6,#5,#4,#3,#2,#1", "theme:UI"):
            self.evidence["scope"] = selector
            self.assertEqual(len(self.preview()["plan"]["assignments"]), 6)
        self.assertEqual(self.preview()["plan"]["scope"], "theme:ui")
        self.evidence["scope"] = "theme:unknown"
        with self.assertRaisesRegex(P.Conflict, "missing-theme"):
            self.preview()
        self.evidence["scope"] = "issue-set:#1"
        with self.assertRaisesRegex(P.Conflict, "out-of-scope|invalid-mapper-residual"):
            self.preview()

    def test_significance_boundaries_debate_and_similarity_not_invented(self):
        for field, value in (("loc", 199), ("activity_days", 6), ("issues", [1, 2, 3, 4])):
            evidence = copy.deepcopy(self.evidence)
            evidence["mapper"]["groups"][0][field] = value
            if field == "issues":
                evidence["mapper"]["residuals"].append({"number": 5, "reason": "Not grouped."})
            evidence["advisor"]["recommendations"] = []
            result = V.normalize(evidence, self.snapshot)
            self.assertFalse(result["plan"]["releases"])
            self.assertIn("mapper-sub-threshold", [r["reason"] for r in result["plan"]["residuals"]])
        self.evidence["mapper"]["groups"][0]["debate"]["confidence"] = 0.69
        self.evidence["advisor"]["recommendations"] = []
        self.assertIn("mapper-needs-human-decision",
                      [r["reason"] for r in self.preview()["plan"]["residuals"]])
        self.evidence, self.snapshot = fixture()
        group = self.evidence["mapper"]["groups"][0]
        group["debate"]["decision"] = "merge"
        group["similarity"] = 0.65
        with self.assertRaisesRegex(P.Conflict, "merge-below"):
            self.preview()
        group["similarity"] = 0.65001
        self.assertTrue(self.preview()["plan"]["releases"])
        group["issues"] = [1, 2]
        group["merged_prs"] = 3
        group["activity_days"] = 0
        group["explicit_binding"] = True
        self.evidence["mapper"]["residuals"] += [
            {"number": n, "reason": "Outside group."} for n in (3, 4, 5)]
        self.assertTrue(self.preview()["plan"]["releases"])

    def test_ownership_exact_marker_pin_and_duplicate_conflicts(self):
        for description in ("Human milestone", P.PIN):
            self.evidence, self.snapshot = fixture()
            self.snapshot["milestones"] = [{"number": 10, "state": "open",
                                           "description": description}]
            self.snapshot["items"][0]["milestone"] = 10
            self.rebind()
            result = self.preview()
            self.assertEqual(result["plan"]["pins"], [1])
            self.assertNotIn(7, [a["number"] for a in result["plan"]["assignments"]])
        self.evidence, self.snapshot = fixture()
        marker = "<!-- basecoat-roadmap:v1 key=v1.1.0 -->"
        self.snapshot["milestones"] = [{"number": 10, "state": "open", "description": marker},
                                       {"number": 11, "state": "open", "description": marker}]
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "duplicate-managed-key"):
            self.preview()
        self.snapshot["milestones"] = [{"number": 10, "state": "open",
                                       "description": marker + P.PIN}]
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "pinned-target"):
            self.preview()

    def test_stale_snapshot_pin_race_assignment_race_and_current_version(self):
        for field, value in (("labels", ["roadmap:pinned"]), ("milestone", 42)):
            evidence, snapshot = fixture()
            snapshot["items"][0][field] = value
            with self.assertRaisesRegex(P.Conflict, "stale-mapper-snapshot"):
                V.normalize(evidence, snapshot)
        self.snapshot["tags"].append("v2.0.0")
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "stale-release-baseline"):
            self.preview()
        self.evidence, self.snapshot = fixture()
        self.evidence["advisor"]["current_version"] = "v2.0.0"
        with self.assertRaisesRegex(P.Conflict, "advisor-baseline"):
            self.preview()

    def test_malformed_missing_duplicate_evidence_and_unaccounted_items(self):
        mutations = [
            lambda e: e["mapper"].update(source="fake-ai"),
            lambda e: e["mapper"].update(groups=None),
            lambda e: e["mapper"]["groups"][0].update(loc=True),
            lambda e: e["mapper"]["groups"][0]["debate"].update(confidence=float("nan")),
            lambda e: e["mapper"]["groups"][0]["debate"].update(split=""),
            lambda e: e["mapper"]["groups"].append(copy.deepcopy(e["mapper"]["groups"][0])),
            lambda e: e["mapper"].update(residuals=[]),
            lambda e: e["mapper"]["links"].append({"pr": 7, "issues": [2]}),
            lambda e: e["mapper"]["links"][0].update(issues=[1, 1]),
            lambda e: e["advisor"].update(recommendations=[]),
            lambda e: e["advisor"]["recommendations"][0].update(release="v01.1.0"),
        ]
        for mutate in mutations:
            evidence = copy.deepcopy(self.evidence)
            mutate(evidence)
            with self.assertRaises((P.Conflict, KeyError, TypeError)):
                V.normalize(evidence, self.snapshot)
        self.snapshot["items"][0]["labels"] = None
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "invalid-label"):
            self.preview()

    def test_sqlite_durable_replay_concurrency_scope_digest_and_no_approval(self):
        path = self.path("sqlite")
        result = self.preview()
        with ThreadPoolExecutor(max_workers=2) as workers:
            states = list(workers.map(lambda _: V.checkpoint(path, "run-1", result), range(2)))
        self.assertEqual(states[0], states[1])
        self.assertIsNone(states[0]["approval"])
        self.assertFalse(states[0]["completed_writes"])
        with closing(sqlite3.connect(path)) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM previews").fetchone()[0], 1)
            self.assertEqual(json.loads(db.execute("SELECT payload FROM previews").fetchone()[0]),
                             states[0])
        self.evidence["scope"] = "theme:UI"
        with self.assertRaisesRegex(P.Conflict, "checkpoint-replay-conflict"):
            V.checkpoint(path, "run-1", self.preview())
        result["plan"]["bounds"]["max_releases"] = 2
        with self.assertRaisesRegex(P.Conflict, "stale-or-non-preview"):
            V.checkpoint(path, "run-1", result)

    def test_timeout_after_local_commit_replays_no_remote_progress(self):
        path = self.path("sqlite")
        state = V.checkpoint(path, "run-1", self.preview())
        # A lost stdout response is not a lost GitHub mutation.
        with self.assertRaises(TimeoutError):
            raise TimeoutError("lost-output-after-local-commit")
        self.assertEqual(state, V.checkpoint(path, "run-1", self.preview()))
        self.snapshot["items"][0]["labels"] = ["roadmap:pinned"]
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "checkpoint-replay-conflict"):
            V.checkpoint(path, "run-1", self.preview())

    def test_corrupted_checkpoint_is_not_reset_or_replaced(self):
        path = self.path("sqlite")
        original = b"Not a SQLite checkpoint"
        path.write_bytes(original)
        with self.assertRaises(sqlite3.DatabaseError):
            V.checkpoint(path, "run-1", self.preview())
        self.assertEqual(path.read_bytes(), original)

    def test_no_approval_or_capability_can_open_write_gate(self):
        with patch.object(P.subprocess, "run") as remote:
            for approval in (None, {"permission": "admin", "trigger": "human"},
                             {"label": "bot", "cas_supported": True}, {"trigger": "schedule"}):
                with self.assertRaisesRegex(P.Conflict, "live-writes-disabled"):
                    V.write_gate(approval=approval, result=self.preview())
            remote.assert_not_called()

    def test_atomic_checkpoint_conflicting_writers_cannot_replace_authority(self):
        path = self.path("sqlite")
        first = self.preview()
        self.evidence["scope"] = "theme:UI"
        second = self.preview()

        def save(result):
            try:
                return V.checkpoint(path, "same-run", result)["digest"]
            except P.Conflict as error:
                return str(error)

        with ThreadPoolExecutor(max_workers=2) as workers:
            responses = list(workers.map(save, [first, second]))
        self.assertEqual(responses.count("checkpoint-replay-conflict"), 1)
        with closing(sqlite3.connect(path)) as db:
            payload = json.loads(db.execute("SELECT payload FROM previews").fetchone()[0])
            self.assertIn(payload["digest"], [first["digest"], second["digest"]])
            self.assertIsNone(payload["approval"])
            self.assertEqual(payload["completed_writes"], [])

    def test_malformed_api_pages_failed_reads_and_invalid_snapshot_fail_closed(self):
        for output in ("{}", "[{}]", "null", "not-json"):
            with patch.object(P.subprocess, "run", return_value=subprocess.CompletedProcess(
                    [], 0, output, "")):
                with self.assertRaises((P.Conflict, json.JSONDecodeError)):
                    P.read_snapshot("owner/repo")
        with patch.object(P.subprocess, "run", return_value=subprocess.CompletedProcess(
                [], 1, "", "secret response")):
            with self.assertRaisesRegex(P.Conflict, "api-read-failed") as caught:
                P.read_snapshot("owner/repo")
            self.assertNotIn("secret", str(caught.exception))
        self.snapshot["complete"] = False
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "incomplete-api-evidence"):
            self.preview()
        self.snapshot["complete"] = True
        self.snapshot["items"][0]["milestone"] = True
        self.rebind()
        with self.assertRaisesRegex(P.Conflict, "invalid-number"):
            self.preview()

    def test_cli_checkpoint_end_to_end_and_apply_fails_before_io(self):
        evidence_path, snapshot_path, db_path = (self.path("json"), self.path("json"),
                                                 self.path("sqlite"))
        evidence_path.write_text(json.dumps(self.evidence), encoding="utf-8")
        snapshot_path.write_text(json.dumps(self.snapshot), encoding="utf-8")
        args = [sys.executable, str(ROOT / "scripts" / "roadmap" / "preview.py"),
                "--evidence", str(evidence_path), "--snapshot", str(snapshot_path),
                "--checkpoint", str(db_path), "--run-id", "e2e"]
        first = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(first.returncode, 0, first.stderr)
        second = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(first.stdout, second.stdout)
        evidence_path.unlink()
        failed = subprocess.run(args + ["--apply"], capture_output=True, text=True)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("roadmap-preview-failed", failed.stderr)
        with closing(sqlite3.connect(db_path)) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM previews").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
