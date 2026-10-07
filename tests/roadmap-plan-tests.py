"""Foundation contract tests. The CAS adapter below is NOT a GitHub write adapter."""

import copy
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("roadmap_plan", ROOT / "scripts" / "roadmap" / "plan.py")
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)


def fixture():
    proposal = {"repository": "owner/repo", "scope": "issue-set:#2,#1", "max_releases": 2,
                "current_version": "v1.0.0",
                "groups": [{"issues": [2], "significant": True, "release": "v1.10.0"},
                           {"issues": [1], "significant": True, "release": "v1.2.0"}]}
    items = [{"number": n, "kind": "issue", "state": "open", "milestone": None,
              "labels": [], "linked_issues": []} for n in (1, 2)]
    items += [{"number": 3, "kind": "pr", "state": "open", "milestone": None,
               "labels": [], "linked_issues": [1]},
              {"number": 4, "kind": "pr", "state": "open", "milestone": None,
               "labels": [], "linked_issues": []}]
    return proposal, {"repository": "owner/repo", "complete": True, "errors": [],
                      "milestones": [], "items": items, "tags": ["v1.0.0"]}


def milestone(n=10, key="v1.2.0", description=None):
    return {"number": n, "state": "open", "title": "Human display text",
            "description": description if description is not None else
            f"<!-- basecoat-roadmap:v1 key={key} -->"}


class MockStore:
    """Models the REQUIRED atomic storage contract, not REST's weaker semantics."""

    def __init__(self, snapshot):
        self.state = copy.deepcopy(snapshot)
        self.consumed = {}
        self.steps = []

    def apply(self, proposal, approved, run_id="run-1", race=None, lose_response=None):
        fresh = P.build_plan(proposal, self.state)
        authority = {"repository": proposal["repository"], "run_id": run_id,
                     "digest": approved["digest"]}
        if run_id not in self.consumed:
            P.check_approval(authority, fresh, proposal["repository"], run_id, "write", "human")
            self.consumed[run_id] = {"digest": approved["digest"], "proposal": P.digest(proposal),
                                     "snapshot": P.digest(self.state)}
        else:
            authority = self.consumed[run_id]
            P.require(authority["digest"] == approved["digest"] and
                      authority["proposal"] == P.digest(proposal) and
                      authority["snapshot"] == P.digest(self.state), "replay-authority-conflict")
        # Replay continues the same committed operations; no second approval.
        for step in fresh["steps"]:
            token = P.digest(self.state)
            if race:
                race(self.state)
            P.require(token == P.digest(self.state), "cas-conflict")
            identity = P.canonical(step)
            if step["operation"] == "create":
                n = max([m["number"] for m in self.state["milestones"]] + [9]) + 1
                self.state["milestones"].append(milestone(n, step["key"]))
            else:
                keys = P.inventory(self.state)[1]
                item = next(i for i in self.state["items"] if i["number"] == step["number"])
                P.require(item["milestone"] == step["expected_milestone"], "assignment-conflict")
                item["milestone"] = keys[step["key"]]
            self.steps.append(identity)
            self.consumed[run_id]["snapshot"] = P.digest(self.state)
            if lose_response == step["operation"]:
                raise TimeoutError("response-lost-after-commit")
        return P.build_plan(proposal, self.state)


class PlanTests(unittest.TestCase):
    def setUp(self):
        self.proposal, self.snapshot = fixture()

    def plan(self):
        return P.build_plan(self.proposal, self.snapshot)

    def test_golden_permutations_display_text_and_numeric_semver(self):
        first = self.plan()
        self.assertEqual(first["digest"],
                         "d1dd0a6ec68ada1dfb7dc25aff4afdbb653db3d8c26e1b9816d81cdd21318c48")
        self.proposal["groups"].reverse()
        self.proposal["scope"] = "issue-set:#1,#2,#1"
        self.snapshot["items"].reverse()
        self.assertEqual(first, self.plan())
        self.assertEqual(first["plan"]["releases"], ["v1.2.0", "v1.10.0"])
        self.assertEqual(first["plan"]["residuals"], [
            {"number": 4, "reason": "unlinked-ambiguous-or-out-of-scope-pr"}])
        self.snapshot["milestones"] = [milestone()]
        original = self.plan()["digest"]
        self.snapshot["milestones"][0]["title"] = "Renamed by maintainer"
        self.assertEqual(original, self.plan()["digest"])

    def test_scope_bound_and_assignment_authority_change_digest(self):
        original = self.plan()["digest"]
        for field, value in (("scope", "all"), ("max_releases", 3)):
            changed = {**self.proposal, field: value}
            self.assertNotEqual(original, P.build_plan(changed, self.snapshot)["digest"])
        self.snapshot["milestones"] = [milestone()]
        self.snapshot["items"][0]["milestone"] = 10
        self.assertNotEqual(original, self.plan()["digest"])

    def test_reject_bad_versions_bounds_scope_and_unapproved_writes(self):
        for version in ("v01.2.0", "1.2.0", "v1.0.0", "v1.2.0-rc.1"):
            self.proposal["groups"][0]["release"] = version
            with self.assertRaises(P.Conflict):
                self.plan()
        self.proposal, self.snapshot = fixture()
        for field, value in (("max_releases", 0), ("max_releases", True), ("concurrency", 2),
                             ("max_releases", 1), ("scope", "theme:unsafe"),
                             ("scope", "issue-set:#99"), ("dry_run", False)):
            with self.assertRaises(P.Conflict, msg=field):
                P.build_plan({**self.proposal, field: value}, self.snapshot)
        self.snapshot["tags"].append("v1.2.0")
        with self.assertRaisesRegex(P.Conflict, "existing-or-old-version"):
            self.plan()

    def test_all_label_scope_residue_ambiguous_and_out_of_scope(self):
        self.snapshot["items"][0]["labels"] = ["Area:UI"]
        self.proposal.update(scope="label: AREA:UI ", groups=[self.proposal["groups"][1]])
        result = self.plan()
        self.assertEqual(result["plan"]["scope"], "label:area:ui")
        self.assertEqual([a["number"] for a in result["plan"]["assignments"]], [1, 3])
        self.snapshot["items"][2]["linked_issues"] = [1, 2]
        self.proposal["groups"][0]["significant"] = False
        result = self.plan()
        self.assertFalse(result["plan"]["assignments"])
        self.assertEqual(len(result["plan"]["residuals"]), 3)
        self.proposal["groups"][0]["issues"] = [2]
        with self.assertRaisesRegex(P.Conflict, "out-of-scope"):
            self.plan()

    def test_pins_human_ownership_and_target_pin(self):
        for marker in ("Human-owned", P.PIN):
            self.snapshot["milestones"] = [milestone(description=marker)]
            self.snapshot["items"][0]["milestone"] = 10
            result = self.plan()
            self.assertIn(1, result["plan"]["pins"])
            self.assertNotIn(1, [a["number"] for a in result["plan"]["assignments"]])
            self.assertNotIn(3, [a["number"] for a in result["plan"]["assignments"]])
        self.snapshot["milestones"] = [milestone(description=milestone()["description"] + P.PIN)]
        with self.assertRaisesRegex(P.Conflict, "pinned-target"):
            self.plan()
        self.snapshot["milestones"] = []
        self.snapshot["items"][0].update(milestone=None, labels=["roadmap:pinned"])
        self.assertIn(1, self.plan()["plan"]["pins"])

    def test_duplicate_and_malformed_marker_and_missing_evidence(self):
        for records in ([milestone(), milestone(11)],
                        [milestone(description="<!-- basecoat-roadmap:v1 key=bad -->")],
                        [milestone(description=milestone()["description"] +
                                   "<!-- basecoat-roadmap:v1 key=bad -->")]):
            self.snapshot["milestones"] = records
            with self.assertRaises(P.Conflict):
                self.plan()
        self.snapshot["milestones"] = []
        self.snapshot["errors"] = [{"endpoint": "issues", "status": 403}]
        with self.assertRaisesRegex(P.Conflict, "incomplete-api-evidence"):
            self.plan()
        self.snapshot["errors"] = []
        self.snapshot["milestones"] = [{**milestone(), "state": "closed"}]
        with self.assertRaisesRegex(P.Conflict, "closed-managed-key"):
            self.plan()

    def test_exact_approval_no_schedule_label_merge_or_unauthorized_authority(self):
        result = self.plan()
        approval = {"repository": "owner/repo", "run_id": "run-1", "digest": result["digest"]}
        self.assertTrue(P.check_approval(approval, result, "owner/repo", "run-1", "write", "human"))
        for permission, trigger in (("read", "human"), ("write", "schedule"), ("write", "merge")):
            with self.assertRaises(P.Conflict):
                P.check_approval(approval, result, "owner/repo", "run-1", permission, trigger)
        for field in approval:
            with self.assertRaises(P.Conflict):
                P.check_approval({**approval, field: "wrong"}, result,
                                 "owner/repo", "run-1", "write", "human")
        result["plan"]["scope"] = "all"
        with self.assertRaises(P.Conflict):
            P.check_approval(approval, result, "owner/repo", "run-1", "write", "human")

    def test_mock_storage_idempotency_and_lost_create_assignment_response(self):
        for failure in (None, "create", "assign"):
            store = MockStore(self.snapshot)
            approved = self.plan()
            if failure:
                with self.assertRaises(TimeoutError):
                    store.apply(self.proposal, approved, lose_response=failure)
            result = store.apply(self.proposal, approved)
            count = len(store.steps)
            self.assertEqual(result, store.apply(self.proposal, approved))
            self.assertEqual(len(store.steps), count)
            self.assertEqual(len(store.state["milestones"]), 2)
            self.assertEqual(len(store.consumed), 1)
            self.assertFalse(result["steps"])

    def test_mock_cas_pin_and_human_assignment_race_stale_plan(self):
        approved = self.plan()
        for race in (lambda state: state["items"][0]["labels"].append("roadmap:pinned"),
                     lambda state: state["items"][0].update(milestone=999)):
            store = MockStore(self.snapshot)
            with self.assertRaisesRegex(P.Conflict, "cas-conflict"):
                store.apply(self.proposal, approved, race=race)
            self.assertFalse(store.steps)
        store = MockStore(self.snapshot)
        store.state["items"][0]["labels"].append("roadmap:pinned")
        with self.assertRaisesRegex(P.Conflict, "stale"):
            store.apply(self.proposal, approved)
        self.assertFalse(store.consumed)
        store = MockStore(self.snapshot)
        with self.assertRaises(TimeoutError):
            store.apply(self.proposal, approved, lose_response="create")
        for changed in ({**self.proposal, "scope": "all"},
                        {**self.proposal, "max_releases": 3}):
            with self.assertRaisesRegex(P.Conflict, "replay-authority-conflict"):
                store.apply(changed, approved)
        store.state["items"][0]["labels"].append("roadmap:pinned")
        with self.assertRaisesRegex(P.Conflict, "replay-authority-conflict"):
            store.apply(self.proposal, approved)

    def test_ordering_fallback_only_on_absence_off_does_not_read_state(self):
        self.assertEqual(P.ordering("off", object()), {"ordering": "oldest-first"})
        self.assertEqual(P.ordering("prefer")["ordering"], "fallback-oldest-first")
        with self.assertRaises(P.Conflict):
            P.ordering("required")
        result = self.plan()
        self.assertEqual(P.ordering("required", result, result["digest"])["numbers"], [1, 3])
        for mode in ("required", "prefer"):
            with self.assertRaises(P.Conflict):
                P.ordering(mode, result, "wrong")
        self.snapshot["milestones"] = [milestone(description="Human-owned")]
        result = self.plan()
        with self.assertRaisesRegex(P.Conflict, "unknown-pinned-position"):
            P.ordering("prefer", result, result["digest"])

    def test_read_only_paginated_api_failure_evidence_and_cli(self):
        raw = {"number": 1, "state": "open", "labels": [], "milestone": None}
        outputs = ["[[]]", json.dumps([[raw]]), '[ [{"name":"v1.0.0"}] ]']
        with patch.object(P.subprocess, "run") as run:
            run.side_effect = [subprocess.CompletedProcess([], 0, text, "") for text in outputs]
            snapshot = P.read_snapshot("owner/repo")
            for call in run.call_args_list:
                args = call.args[0]
                self.assertEqual(args[args.index("--method") + 1], "GET")
                self.assertIn("--paginate", args)
                self.assertEqual(call.kwargs["encoding"], "utf-8")
            result = P.build_plan({**self.proposal, "scope": "issue-set:#1", "groups": []}, snapshot)
            self.assertEqual(result["plan"]["residuals"], [{"number": 1, "reason": "mapper-residual"}])
            run.side_effect = None
            run.return_value = subprocess.CompletedProcess([], 1, "", "sensitive stderr")
            with self.assertRaisesRegex(P.Conflict, "endpoint=.*milestones.*exit=1") as error:
                P.read_snapshot("owner/repo")
            self.assertNotIn("sensitive", str(error.exception))
        command = [sys.executable, str(ROOT / "scripts" / "roadmap" / "plan.py"), "--help"]
        response = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(response.returncode, 0)
        self.assertNotIn("--apply", response.stdout)


if __name__ == "__main__":
    unittest.main()
