"""Authority ledger tests against an in-memory createCommitOnBranch model (no network)."""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
import ledger as L  # noqa: E402
P = L.P


class FakeBranch:  # Models expectedHeadOid compare-and-set and provenance only.
    def __init__(self, protected=True):
        self.commits = [{"oid": "c0", "app": True, "verified": True, "files": {}}]
        self.is_protected, self.lose_next, self.race = protected, False, None
        self.protected_since = "c0"  # Ruleset unchanged since; a rollback re-protects later.

    def head(self):
        return self.commits[-1]["oid"] if self.commits else None

    def read(self, oid, path):
        changes = [c["files"][path] for c in self.history(oid) if path in c["files"]]
        return changes[-1] if changes else None

    def history(self, oid):
        index = [c["oid"] for c in self.commits].index(oid)
        return [dict(c) for c in self.commits[:index + 1]]

    def protected(self, root):
        return self.is_protected and root == self.protected_since

    def push(self, files, app=True):
        self.commits.append({"oid": f"c{len(self.commits)}", "app": app, "verified": app,
                             "files": dict(files)})

    def commit(self, expected, files, message):
        if self.race:
            race, self.race = self.race, None
            race()
        if expected != self.head():
            raise L.StaleHead(expected)
        self.push(files)
        if self.lose_next:
            self.lose_next = False
            raise TimeoutError("response lost")
        return self.head()


def result(digest_seed="a", steps=1):  # Steps narrow a fixed plan, so the digest is stable.
    plan = {"repository": "owner/repo", "scope": "all", "bounds": {"max_releases": 1},
            "evidence_digest": digest_seed, "guards": [{"number": 2, "milestone": 5}],
            "releases": ["v1.1.0", "v1.2.0"], "assignments": [{"number": 2, "release": "v1.1.0"}]}
    return {"plan": plan, "digest": P.digest(plan), "dry_run": True, "steps": [
        {"operation": "create", "key": k, "marker": f"<!-- basecoat-roadmap:v1 key={k} -->"}
        for k in plan["releases"][:steps]]}


class LedgerTests(unittest.TestCase):
    def setUp(self):
        self.branch = FakeBranch()
        self.ledger = L.Ledger(self.branch, "Owner/Repo", apply=True)

    def stored(self, run="run-1"):
        return json.loads(self.branch.read(self.branch.head(), L.run_path("owner/repo", run)))

    def fails(self, code, res=None, run="run-1"):
        with self.assertRaisesRegex(P.Conflict, code):
            self.ledger.propose(res or result(), run)

    def test_propose_commits_one_pending_run_bound_to_digest(self):
        out = self.ledger.propose(result(), "run-1")
        self.assertEqual(out["head"], "c1")
        run = self.stored()
        self.assertEqual((run["state"], run["approval"], run["plan_digest"]),
                         ("proposed", None, result()["digest"]))
        self.assertEqual([s["status"] for s in run["steps"]], ["pending"])
        create = result()["steps"][0]
        assign = {"operation": "assign", "number": 2, "key": "v1.1.0", "expected_milestone": 5}
        for steps in ([{**create, "key": "v2.0.0"}], [{**create, "marker": None}], [create] * 2,
                      [{**assign, "number": 8}], [{**assign, "expected_milestone": 6}],
                      [{**assign, "extra": 1}], [{**create, "operation": "assign"}]):
            self.fails("steps-not-in-plan", {**result(), "steps": steps})
        self.ledger.propose({**result(), "steps": [create, assign]}, "run-2")

    def test_dry_run_is_default_and_reports_unproven_provenance(self):
        self.branch.is_protected = False
        out = L.Ledger(self.branch, "owner/repo").propose(result(), "run-1")
        self.assertEqual((out["dry_run"], out["expected_head"], out["provenance"]),
                         (True, "c0", "ledger-provenance-unproven"))
        self.assertEqual(len(self.branch.commits), 1)

    def test_missing_ruleset_rewritten_history_or_missing_branch_fail_closed(self):
        self.branch.is_protected = False
        self.fails("ledger-provenance-unproven")
        self.branch.is_protected = True
        self.branch.push({"notes.txt": "x"}, app=False)
        self.fails("ledger-provenance-unproven")
        self.branch.commits, self.branch.protected_since = self.branch.commits[:1], "c1"
        self.fails("ledger-provenance-unproven")
        self.branch.commits = []
        self.fails("ledger-branch-missing")

    def test_re_propose_and_tombstone_reuse_are_rejected(self):
        self.ledger.propose(result(), "run-1")
        self.fails("run-exists", result("b"))
        path = L.run_path("owner/repo", "run-1")
        self.branch.push({path: None})
        self.fails("run-exists")

    def test_stale_head_rereads_and_never_overwrites_concurrent_writer(self):
        other = L.Ledger(self.branch, "owner/repo", apply=True)
        self.branch.race = lambda: other.propose(result("b"), "run-1")
        self.fails("run-exists")
        self.assertEqual(self.stored()["evidence_digest"], "b")
        self.assertEqual(len(self.branch.commits), 2)
        self.fails("invalid-run-id", run="../escape")

    def test_persistent_contention_stops_after_bounded_attempts(self):
        def bump():
            self.branch.push({"other.json": "{}"})
            self.branch.race = bump
        self.branch.race = bump
        self.fails("ledger-head-contention")

    def test_lost_response_accepts_only_matching_committed_bytes(self):
        self.branch.lose_next = True
        self.assertEqual(self.ledger.propose(result(), "run-1")["head"], "c1")
        self.assertEqual(self.stored()["state"], "proposed")

        def lost(expected, files, message):
            self.branch.push(files, app=False)  # An unverified writer copies the same bytes.
            raise TimeoutError("lost")
        self.branch.commit = lost
        self.fails("ledger-provenance-unproven", run="run-2")
        self.branch.commits.pop()
        self.branch.push = lambda files, app=True: None
        self.fails("ledger-commit-unconfirmed", run="run-2")

    def rejects(self, code, old, change):
        with self.assertRaisesRegex(P.Conflict, code):
            L.check_forward(old, {**old, **change})

    def test_forward_only_transitions(self):
        self.ledger.propose(result(), "run-1")
        old = self.stored()
        self.rejects("ledger-identity-changed", old, {"plan_digest": "x"})
        for change in ({"state": "approved"}, {"steps": [{**old["steps"][0], "status": "claimed"}]},
                       {"approval": {"comment_id": 1}}):  # Proposed runs stay unapproved and untouched.
            self.rejects("invalid-ledger-transition", old, change)
        approved = {**old, "state": "approved", "approval": {"comment_id": 1}}
        L.check_forward(old, approved)
        for change in ({"state": "proposed"}, {"approval": {"comment_id": 2}}):
            self.rejects("", approved, change)
        self.rejects("ledger-schema-changed", approved, {"assignments": []})
        for step in ({"status": "done"}, {"index": 5}, {"key": "v9.0.0"}):
            self.rejects("invalid-step-transition", approved, {"steps": [{**old["steps"][0], **step}]})
        self.rejects("invalid-ledger-transition", {**approved, "state": "terminal"}, {})


if __name__ == "__main__":
    unittest.main()
