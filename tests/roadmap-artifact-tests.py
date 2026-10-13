"""Artifact publisher tests: approval-gated bot-branch commits and the single PR (no network)."""

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
import artifact as A  # noqa: E402
import ledger as L  # noqa: E402

SPEC = importlib.util.spec_from_file_location("ledger_tests", ROOT / "tests" /
                                             "roadmap-ledger-tests.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
P = L.P


def result():
    plan = {"repository": "owner/repo", "scope": "all", "bounds": {"max_releases": 1},
            "evidence_digest": "a", "releases": ["v1.1.0"], "pins": [], "residuals": [],
            "assignments": [{"number": 2, "release": "v1.1.0"}],
            "guards": [{"number": 2, "milestone": None}]}
    return {"plan": plan, "digest": P.digest(plan), "dry_run": True,
            "steps": [{"operation": "assign", "number": 2, "key": "v1.1.0",
                       "expected_milestone": None}]}


class Pulls:
    def __init__(self):
        self.calls = []

    def ensure(self, apply):
        self.calls.append(apply)
        return {"action": "updated" if apply else "would-open"}


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.state, self.gh = T.FakeBranch(), T.FakeGitHub()
        self.ledger = L.Ledger(self.state, "owner/repo", apply=True)
        self.ledger.propose(result(), "run-1")
        self.gh.approve(1, "run-1", result()["digest"])
        self.artifact, self.pulls = T.FakeBranch(), Pulls()
        self.artifact.branch = A.BRANCH

    def consume(self):
        self.ledger.consume("run-1", 1, self.gh, result, "issue_comment", "h1", now=lambda: 1)

    def publish(self, apply=True, res=None):
        return A.publish(self.ledger, "run-1", res or result(), self.gh, self.artifact,
                         self.pulls, apply=apply)

    def test_missing_or_stale_approval_writes_nothing(self):
        with self.assertRaisesRegex(P.Conflict, "approval-required"):
            self.publish()
        self.consume()
        changed = result()
        changed["plan"]["scope"] = "label:x"
        changed["digest"] = P.digest(changed["plan"])
        with self.assertRaisesRegex(P.Conflict, "stale-or-mismatched-approval"):
            self.publish(res=changed)
        self.gh.permissions["alice"] = "read"
        with self.assertRaisesRegex(P.Conflict, "unauthorized-approval"):
            self.publish()
        self.assertEqual((len(self.artifact.commits), self.pulls.calls), (1, []))

    def test_dry_run_default_then_byte_stable_commit_and_no_op(self):
        self.consume()
        dry = self.publish(apply=False)
        self.assertEqual((dry["status"], len(self.artifact.commits)), ("dry-run", 1))
        self.assertIn("Lifecycle: approved;", dry["content"])
        self.assertIn("+Ledger state: approved", dry["diff"])
        self.assertTrue(dry["diff"].startswith(f"--- a/{A.PATH}"))
        self.assertEqual(self.publish()["status"], "committed")
        self.assertEqual(self.artifact.read(self.artifact.head(), A.PATH), dry["content"])
        self.assertEqual(self.publish()["status"], "unchanged")
        self.assertEqual(len(self.artifact.commits), 2)

    def test_missing_branch_is_previewed_then_created_from_main_only_on_apply(self):
        self.consume()
        self.artifact.commits, created = [], []
        self.artifact.create_from = lambda base: created.append(base) or self.artifact.push(
            {}) or self.artifact.head()
        dry = self.publish(apply=False)
        self.assertEqual((dry["create_branch"], dry["expected_head"], created),
                         (True, None, []))
        self.assertEqual(self.publish()["status"], "committed")
        self.assertEqual((created, len(self.artifact.commits)), (["main"], 2))

    def test_stale_head_rereads_and_rerenders(self):
        self.consume()
        self.artifact.race = lambda: self.artifact.push({"other.md": "x"})
        self.assertEqual(self.publish()["head"], "c2")
        self.assertEqual(len(self.artifact.commits), 3)

    def test_lifecycle_tracks_ledger_state(self):
        for doc, state in (({"state": "proposed"}, "proposed"),
                           ({"state": "claimed"}, "approved"),
                           ({"state": "terminal", "stop_reason": "complete"}, "persisted"),
                           ({"state": "terminal", "stop_reason": "step-conflict"}, "conflict"),
                           ({"state": "needs-reconciliation"}, "conflict")):
            with self.subTest(state=state):
                self.assertEqual(A.lifecycle({"stop_reason": None, **doc}), state)

    def test_single_pr_reports_closed_unmerged_and_targets_main(self):
        def run(pulls, created=None):
            calls = []

            def fake(cmd, **_kwargs):
                calls.append(cmd)
                out = P.canonical(created if "POST" in cmd else pulls)
                return subprocess.CompletedProcess(cmd, 0, out, "")
            with patch.object(A.gh.__globals__["subprocess"], "run", fake):
                return A.GitHubPulls("owner/repo").ensure(True), calls
        self.assertEqual(run([{"number": 5, "state": "open"}])[0]["action"], "updated")
        closed = [{"number": 5, "state": "closed", "merged_at": None}]
        out, calls = run(closed)
        self.assertEqual((out["action"], len(calls)), ("closed-unmerged-reported", 1))
        out, calls = run([{"number": 5, "state": "closed", "merged_at": "t"}], {"number": 6})
        self.assertEqual(out, {"number": 6, "action": "opened"})
        self.assertIn("base=main", calls[-1])
        self.assertIn(f"head={A.BRANCH}", calls[-1])
        with self.assertRaisesRegex(P.Conflict, "invalid-bot-branch"):
            self.artifact.branch = "main"
            self.publish()


if __name__ == "__main__":
    unittest.main()
