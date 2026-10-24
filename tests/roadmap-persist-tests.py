"""Gated milestone adapter tests: the gate stays closed, and #3700 race/replay scenarios hold."""

import datetime
import importlib.util
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
import ledger as L  # noqa: E402
import persist as S  # noqa: E402


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tests" / file)
    spec.loader.exec_module(module := importlib.util.module_from_spec(spec))
    return module


T, PT = load("ledger_tests", "roadmap-ledger-tests.py"), load("plan_tests", "roadmap-plan-tests.py")
P = L.P
NOW = datetime.datetime(2026, 10, 12, tzinfo=datetime.timezone.utc)
POSITIVE = {c: "positive" for c in ("1", "2a", "2b", "3a", "3b", "4")}


class Milestones:
    def __init__(self, snapshot):
        self.ms = {m["number"]: dict(m) for m in snapshot["milestones"]}
        self.issues = {i["number"]: {"milestone": i["milestone"], "labels": []}
                       for i in snapshot["items"]}
        self.writes, self.hooks, self.lose, self.lost = 0, {}, None, TimeoutError("lost")

    def issue(self, n):
        return {**json.loads(json.dumps(self.issues[n])), "etag": P.digest(self.issues[n])}

    def milestone(self, n):
        return dict(self.ms[n])

    def by_marker(self, marker):
        return [dict(m) for m in self.ms.values() if marker in (m["description"] or "")]

    def write(self, apply):  # Hooks model a concurrent writer acting right after write N.
        self.writes += 1
        apply()
        self.hooks.pop(self.writes, lambda: None)()
        if self.writes == self.lose:
            raise self.lost

    def create(self, key, marker):
        n = len(self.ms) + 9
        self.write(lambda: self.ms.update({n: PT.milestone(n, description=marker)}))

    def assign(self, n, milestone, etag):  # Models positive probe evidence for If-Match.
        P.require(etag == P.digest(self.issues[n]), "precondition-failed")
        self.write(lambda: self.issues[n].update(milestone=milestone))


class AdapterTests(unittest.TestCase):
    def setUp(self):
        proposal, snapshot = PT.fixture()  # Item 1 starts in managed milestone 7 (v1.1.0).
        snapshot["milestones"], snapshot["items"][0]["milestone"] = [PT.milestone(7, "v1.1.0")], 7
        self.result = P.build_plan(proposal, snapshot)
        self.branch, self.gh = T.FakeBranch(), T.FakeGitHub()
        self.ledger = L.Ledger(self.branch, "owner/repo", apply=True)
        self.ledger.propose(self.result, "run-1")
        self.gh.approve(1, "run-1", self.result["digest"])
        self.ledger.consume("run-1", 1, self.gh, lambda: self.result, "issue_comment", "h1",
                            now=lambda: 1)
        self.client = Milestones(snapshot)
        self.evidence = ROOT / "tests" / "roadmap-probe-evidence.tmp.json"
        self.addCleanup(lambda: self.evidence.unlink(missing_ok=True))

    def gate(self, cases=None, recorded=NOW, holder="h1"):
        if cases is not None:
            self.evidence.write_text(json.dumps({"schema": 1, "recorded_at": recorded.isoformat(),
                                                 "cases": {c: {"result": r}
                                                           for c, r in cases.items()}}))
        return S.gate(self.ledger, "run-1", self.gh, holder, 1, self.result["steps"],
                      self.evidence, now=NOW)

    def execute(self):
        with patch.object(S, "gate", lambda *_a: self.run_doc()):
            return S.Persist(self.client, self.ledger, "run-1", self.gh, "h1", 1).execute(
                self.result["steps"])

    def run_doc(self):
        return json.loads(self.branch.read(self.branch.head(), L.run_path("owner/repo", "run-1")))

    def test_gate_closed_unless_every_condition_holds(self):
        with self.assertRaisesRegex(P.Conflict, "roadmap_persistence_enabled-false"):
            self.gate(POSITIVE)
        with patch.dict(P.CONFIG, {"roadmap_persistence_enabled": True}):
            self.assertEqual(self.gate(POSITIVE)["run_id"], "run-1")
            reordered = {**self.result, "steps": self.result["steps"][::-1]}
            with patch.object(self, "result", reordered), self.assertRaisesRegex(
                    P.Conflict, "steps-not-approved"):
                self.gate(POSITIVE)
            day = datetime.timedelta(days=1)
            for cases, recorded in (({**POSITIVE, "3b": "negative"}, NOW),
                                    ({**POSITIVE, "2a": "inconclusive"}, NOW),
                                    ({k: v for k, v in POSITIVE.items() if k != "4"}, NOW),
                                    (POSITIVE, NOW - 31 * day), (POSITIVE, NOW + day)):
                with self.subTest(cases=cases, recorded=recorded):
                    with self.assertRaisesRegex(P.Conflict, "conditional-mutation-not-proven"):
                        self.gate(cases, recorded)
            self.evidence.unlink()
            with self.assertRaisesRegex(P.Conflict, "conditional-mutation-not-proven"):
                self.gate()
            with self.assertRaisesRegex(P.Conflict, "fenced-holder"):
                self.gate(POSITIVE, holder="h2")
            self.gh.permissions["alice"] = "read"
            with self.assertRaisesRegex(P.Conflict, "unauthorized-approval"):
                self.gate(POSITIVE)
        self.assertFalse(S.EVIDENCE.exists())

    def test_executes_steps_in_order_and_resolves_lost_responses_by_reading(self):
        self.client.lose = 1
        self.assertEqual(self.execute()["status"], "complete")
        keys = {m["number"]: P.MARKER.search(m["description"]).group(1)
                for m in self.client.ms.values()}
        self.assertEqual({n: keys.get(i["milestone"]) for n, i in self.client.issues.items()},
                         {1: "v1.2.0", 2: "v1.10.0", 3: "v1.2.0", 4: None})
        self.assertEqual(self.run_doc()["stop_reason"], "complete")
        seen = self.run_doc()["steps"][2]["observed"]  # Persisted pre-write read set.
        self.assertEqual((seen["item"], seen["source"]["key"], seen["targets"][0]["key"]),
                         ({"milestone": 7, "pinned": False}, "v1.1.0", "v1.2.0"))

    def test_unconfirmed_applied_write_is_verified_not_failed(self):
        self.client.lose, self.client.lost = 3, S.Unconfirmed("api-outcome-unknown exit=1")
        self.assertEqual(self.execute()["status"], "complete")
        self.assertEqual(self.client.writes, 5)

    def test_replay_resumes_from_first_pending_step(self):
        step = self.result["steps"][0]
        self.ledger.claim("run-1", 0, "h1", 1, now=lambda: 1)
        self.client.create(step["key"], step["marker"])
        self.ledger.checkpoint("run-1", 0, "h1", 1, "done", 201, now=lambda: 1)
        self.assertEqual(self.execute()["status"], "complete")
        self.assertEqual((self.client.writes, len(self.client.by_marker(step["marker"]))), (5, 1))

    def test_item_edit_between_read_and_patch_fails_if_match(self):
        self.client.hooks[2] = lambda: setattr(self.branch, "race", lambda: setattr(
            self.branch, "race", lambda: self.client.issues[1]["labels"].append("triage")))
        self.assertEqual(self.execute()["error"], "precondition-failed")
        self.assertEqual(self.client.issues[1]["milestone"], 7)

    def test_item_or_milestone_race_is_a_conflict_without_write(self):
        races = {"pin": lambda c: c.issues[1]["labels"].append("roadmap:pinned"),
                 "reassigned": lambda c: c.issues[1].update(milestone=10),
                 "source-moved": lambda c: c.ms[7].update(description=S.MARK.format("v1.3.0")),
                 "target-closed": lambda c: c.ms[10].update(state="closed"),
                 "target-pinned": lambda c: c.ms[10].update(description=c.ms[10]["description"] +
                                                            P.PIN),
                 "target-ambiguous": lambda c: c.ms[10].update(
                     description=c.ms[10]["description"] + S.MARK.format("v1.9.9"))}
        for name, race in races.items():
            with self.subTest(race=name):
                self.setUp()
                self.client.hooks[2] = lambda race=race: race(self.client)
                self.assertEqual(self.execute()["status"], "conflict")
                self.assertEqual(self.run_doc()["stop_reason"], "step-conflict")
                self.assertIsNone(self.client.issues[3]["milestone"])

    def test_duplicate_create_is_detected_and_never_adopted(self):
        marker = self.result["steps"][0]["marker"]
        duplicate = PT.milestone(5, description=marker)
        self.client.ms[5] = dict(duplicate)
        self.assertEqual(self.execute()["error"], "pre-write-state-changed")
        self.setUp()
        self.client.hooks[1] = lambda: self.client.ms.update({5: duplicate})
        self.assertEqual(self.execute()["error"], "post-write-state-mismatch")

    def test_definitive_write_rejection_fails_without_adopting_a_concurrent_create(self):
        step = self.result["steps"][0]

        def rejected(key, marker):  # Another writer wins the marker, and our POST is refused.
            self.client.ms[5] = PT.milestone(5, description=marker)
            raise P.Conflict("api-request-failed exit=1")
        self.client.create = rejected
        self.assertEqual(self.execute(), {"status": "failed", "step": 0, "error": "write-rejected"})
        self.assertEqual((self.run_doc()["stop_reason"], len(self.client.by_marker(step["marker"]))),
                         ("step-failed", 1))

    def test_post_write_drift_is_a_conflict_without_compensating_writes(self):
        drifts = {"target-pinned": lambda c: [m.update(description=m["description"] + P.PIN)
                                              for n, m in c.ms.items() if n != 7],
                  "item-pinned": lambda c: [i["labels"].append("roadmap:pinned")
                                            for i in c.issues.values()],
                  "source-moved": lambda c: c.ms[7].update(description=S.MARK.format("v1.3.0")),
                  "create-unmarked": lambda c: c.ms[10].update(description="")}
        for name, drift in drifts.items():
            with self.subTest(drift=name):
                self.setUp()
                write = 1 if name == "create-unmarked" else 3
                self.client.hooks[write] = lambda drift=drift: drift(self.client)
                self.assertEqual(self.execute()["error"], "post-write-state-mismatch")
                self.assertEqual((self.run_doc()["stop_reason"], self.client.writes),
                                 ("step-conflict", write))


if __name__ == "__main__":
    unittest.main()
