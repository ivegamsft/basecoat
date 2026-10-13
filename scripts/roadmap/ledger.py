"""Roadmap authority ledger on a bot branch: authority and progress only, never membership.

Transport: head() -> oid|None; read(oid, path) -> str|None; history(oid) -> oldest-first
[{"oid", "app", "verified", "files": {path: text|None}}]; protected(root) -> bool (ruleset
unchanged since root; no delete/force; app-only updates); commit(head, files, msg) -> oid|StaleHead.
"""

import json
import re

import plan as P

BRANCH = "bot/roadmap-state"
STATES = ("proposed", "approved", "claimed", "needs-reconciliation", "terminal")
STEP_MOVES = {"pending": {"pending", "claimed"}, "claimed": {"claimed", "done", "conflict", "failed"},
              "done": {"done"}, "conflict": {"conflict"}, "failed": {"failed"}}
IDENTITY = ("schema", "repository", "run_id", "plan_digest", "evidence_digest", "scope", "bounds")
RUN_KEYS = {*IDENTITY, "state", "approval", "stop_reason", "blockers", "steps"}
STEP_STATE = dict.fromkeys(("status", "epoch", "evidence"))  # The only mutable step fields.


class StaleHead(Exception):
    """Raised by a transport when expectedHeadOid no longer matches the branch head."""


def run_path(repo, run):
    P.require(isinstance(run, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", run), "invalid-run-id")
    return f"runs/{P.repository(repo)}/{run}.json"


def verify_provenance(transport, head):
    P.require(head is not None, "ledger-branch-missing")
    history = transport.history(head)
    P.require(isinstance(history, list) and bool(history) and history[-1]["oid"] == head and
              all(c.get("app") is True and c.get("verified") is True for c in history) and
              transport.protected(history[0]["oid"]) is True, "ledger-provenance-unproven")
    return history


def tombstones(history):
    """Every run path and consumed comment ID that ever existed in branch history."""
    paths, comments = set(), set()
    for commit in history:
        for path, content in commit["files"].items():
            if path.startswith("runs/") and content is not None:
                paths.add(path)
                approval = json.loads(content).get("approval")
                if approval:
                    comments.add(approval["comment_id"])
    return paths, comments


def check_forward(old, new):
    P.require(set(new) == RUN_KEYS, "ledger-schema-changed")  # Authority only, never membership.
    proposed = new["state"] == "proposed"  # Unapproved and untouched; every later state approved.
    P.require(proposed == (new["approval"] is None) and (old is not None or proposed) and all(
        s["status"] == "pending" or not proposed for s in new["steps"]), "invalid-ledger-transition")
    if old is None:
        return
    P.require(all(old[k] == new[k] for k in IDENTITY), "ledger-identity-changed")
    P.require(old["state"] != "terminal" and STATES.index(new["state"]) >= STATES.index(
        old["state"]), "invalid-ledger-transition")
    P.require(old["approval"] in (None, new["approval"]), "approval-already-consumed")
    P.require(len(old["steps"]) == len(new["steps"]) and all(
        {**a, **STEP_STATE} == {**b, **STEP_STATE} and b["status"] in STEP_MOVES[a["status"]]
        for a, b in zip(old["steps"], new["steps"])), "invalid-step-transition")


class Ledger:
    def __init__(self, transport, repo, apply=False, attempts=3):
        self.t, self.repo, self.apply, self.attempts = transport, P.repository(repo), apply, attempts

    def load(self, head, path):
        content = self.t.read(head, path) if head else None
        return None if content is None else json.loads(content)

    def transact(self, message, mutate):
        """Re-read, revalidate, and commit with expectedHeadOid; never overwrite a moved head."""
        for _ in range(self.attempts):
            head = self.t.head()
            try:
                history, proven = verify_provenance(self.t, head), None
            except P.Conflict as error:
                P.require(not self.apply, str(error))
                history, proven = self.t.history(head) if head else [], str(error)
            files = mutate(head, history)
            for path in (p for p in files if p.startswith("runs/")):
                check_forward(self.load(head, path), files[path])
            payload = {p: P.canonical(c) + "\n" for p, c in files.items()}
            if not self.apply:
                return {"dry_run": True, "expected_head": head, "provenance": proven or "verified",
                        "message": message, "files": payload}
            try:
                return {"dry_run": False, "head": self.t.commit(head, payload, message),
                        "files": payload}
            except StaleHead:
                continue
            except (OSError, TimeoutError):
                # Lost response: accept only if the moved head carries exactly these bytes.
                moved = self.t.head()
                verify_provenance(self.t, moved)
                P.require(moved != head and all(self.t.read(moved, p) == c for p, c in
                                                payload.items()), "ledger-commit-unconfirmed")
                return {"dry_run": False, "head": moved, "files": payload}
        raise P.Conflict("ledger-head-contention")

    def propose(self, result, run):
        P.require(result["digest"] == P.digest(result["plan"]) and result["dry_run"] is True and
                  result["plan"]["repository"] == self.repo, "stale-or-non-preview-plan")
        path, plan = run_path(self.repo, run), result["plan"]
        mark = "<!-- basecoat-roadmap:v1 key={} -->".format  # Steps may only narrow the plan.
        owner = {g["number"]: g["milestone"] for g in plan.get("guards", [])}
        allowed = [{"operation": "create", "key": k, "marker": mark(k)} for k in plan["releases"]]
        allowed += [{"operation": "assign", "number": a["number"], "key": a["release"],
                     "expected_milestone": owner[a["number"]]}
                    for a in plan["assignments"] if a["number"] in owner]  # Exact canonical shape.
        steps = result["steps"]
        P.require(all(s in allowed and steps.count(s) == 1 for s in steps), "steps-not-in-plan")

        def mutate(head, history):
            P.require(path not in tombstones(history)[0] and self.load(head, path) is None,
                      "run-exists")
            return {path: {"schema": 1, "repository": self.repo, "run_id": run,
                           "plan_digest": result["digest"],
                           "evidence_digest": plan.get("evidence_digest"),
                           "scope": plan["scope"], "bounds": plan["bounds"], "state": "proposed",
                           "approval": None, "stop_reason": None, "blockers": [],
                           "steps": [{**s, "index": i, **STEP_STATE, "status": "pending"}
                                     for i, s in enumerate(steps)]}}
        return self.transact(f"roadmap: propose {run}", mutate)
