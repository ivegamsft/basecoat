"""Roadmap authority ledger on a bot branch: authority and progress only, never membership.

Transport: head() -> oid|None; read(oid, path) -> str|None; history(oid) -> oldest-first
[{"oid", "app", "verified", "files": {path: text|None}}]; protected(root) -> bool (ruleset
unchanged since root; no delete/force; app-only updates); commit(head, files, msg) -> oid|StaleHead.
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

import plan as P

BRANCH = "bot/roadmap-state"
LEASE = "lease.json"
WRITERS = ("write", "maintain", "admin")
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
    paths, comments = set(), {}
    for commit in history:
        for path, content in commit["files"].items():
            if path.startswith("runs/") and content is not None:
                paths.add(path)
                approval = json.loads(content).get("approval")
                if approval:
                    comments.setdefault(approval["comment_id"], set()).add(path)
    return paths, comments


def human_approval(github, comment_id, run, digest):
    """Resolve approval from GitHub by comment ID at call time; comment text is never executed."""
    comment = github.comment(comment_id)
    P.require(comment["id"] == comment_id and comment["user_type"] == "User",
              "unauthorized-approval")
    P.require(comment["body"] == f"roadmap: approve {run} {digest}",
              "stale-or-mismatched-approval")
    permission = github.permission(comment["user_login"])
    P.require(permission in WRITERS, "unauthorized-approval")
    return {"actor": comment["user_login"], "actor_id": comment["user_id"],
            "permission": permission, "comment_id": comment_id, "url": comment["url"],
            "digest": digest}


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


def step_index(steps, index):
    P.require(type(index) is int and 0 <= index < len(steps), "invalid-step-order")


def require_holder(holder):
    P.require(type(holder) is str and holder.strip() == holder != "", "invalid-holder")


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

    def held(self, head, run, holder, epoch, now, ttl):
        lease = self.load(head, LEASE)
        P.require(lease is not None and lease["run_id"] == run and lease["holder"] == holder and
                  lease["epoch"] == epoch, "fenced-holder")
        return {**lease, "lease_expires_at": now + ttl}

    def authority(self, run, github):
        """Re-verify a consumed approval from provenance-checked history and GitHub, never cache."""
        head = self.t.head()
        history = verify_provenance(self.t, head)
        path = run_path(self.repo, run)
        doc = self.load(head, path)
        self.reverify(history, path, doc, run, github)
        return doc, self.load(head, LEASE)

    @staticmethod
    def reverify(history, path, doc, run, github):
        P.require(doc is not None and doc["approval"] is not None, "approval-required")
        current = human_approval(github, doc["approval"]["comment_id"], run, doc["plan_digest"])
        P.require(tombstones(history)[1].get(current["comment_id"]) == {path} and all(
            doc["approval"][k] == current[k] for k in ("actor_id", "comment_id", "digest")),
            "stale-or-mismatched-approval")

    def consume(self, run, comment_id, github, recompute, trigger, holder, now=time.time, ttl=900):
        P.require(trigger == "issue_comment", "unauthorized-approval")
        require_holder(holder)
        path = run_path(self.repo, run)

        def mutate(head, history):
            doc = self.load(head, path)
            P.require(doc is not None, "run-missing")
            P.require(doc["approval"] is None and comment_id not in tombstones(history)[1],
                      "approval-already-consumed")
            approval = human_approval(github, comment_id, run, doc["plan_digest"])
            fresh = recompute()
            P.require(fresh["digest"] == P.digest(fresh["plan"]) == doc["plan_digest"] and fresh["plan"]["scope"] ==
                      doc["scope"] and fresh["plan"]["bounds"] == doc["bounds"] and
                      fresh["plan"].get("evidence_digest") == doc["evidence_digest"],
                      "stale-or-mismatched-approval")
            lease = self.load(head, LEASE) or {"epoch": 0, "holder": None, "run_id": None}
            prior = lease["run_id"] and self.load(head, run_path(self.repo, lease["run_id"]))
            P.require((lease["holder"] is None or now() >= lease["lease_expires_at"]) and not (
                prior and any(s["status"] == "claimed" for s in prior["steps"])),
                "repository-lease-held")
            return {path: {**doc, "state": "approved", "approval": approval},
                    LEASE: {"run_id": run, "epoch": lease["epoch"] + 1, "holder": holder,
                            "lease_expires_at": now() + ttl}}
        return self.transact(f"roadmap: consume {run}", mutate)

    def claim(self, run, index, holder, epoch, now=time.time, ttl=900):
        path = run_path(self.repo, run)

        def mutate(head, history):
            lease, doc = self.held(head, run, holder, epoch, now(), ttl), self.load(head, path)
            steps = [dict(s) for s in doc["steps"]]
            step_index(steps, index)
            P.require(doc["state"] in ("approved", "claimed") and steps[index]["status"] ==
                      "pending" and all(s["status"] == "done" for s in steps[:index]),
                      "invalid-step-order")
            steps[index].update(status="claimed", epoch=epoch)
            return {path: {**doc, "state": "claimed", "steps": steps}, LEASE: lease}
        return self.transact(f"roadmap: claim {run} {index}", mutate)

    def checkpoint(self, run, index, holder, epoch, outcome, status, error=None, now=time.time,
                   ttl=900):
        P.require(outcome in ("done", "conflict", "failed") and type(status) is int and
                  (error is None or re.fullmatch(r"[a-z0-9_-]{1,64}", error)), "invalid-evidence")
        path = run_path(self.repo, run)

        def mutate(head, history):
            lease, doc = self.held(head, run, holder, epoch, now(), ttl), self.load(head, path)
            steps = [dict(s) for s in doc["steps"]]
            step_index(steps, index)
            P.require(steps[index]["status"] == "claimed" and steps[index]["epoch"] == epoch,
                      "fenced-holder")
            steps[index].update(status=outcome, evidence={"status": status, "error": error})
            finished = outcome != "done" or all(s["status"] == "done" for s in steps)
            if finished:
                lease["holder"] = None
            return {path: {**doc, "steps": steps, "state": "terminal" if finished else "claimed",
                           "stop_reason": ("complete" if outcome == "done" else f"step-{outcome}")
                           if finished else None}, LEASE: lease}
        return self.transact(f"roadmap: checkpoint {run} {index}", mutate)

    def takeover(self, run, holder, github, now=time.time, ttl=900):
        """After lease expiry exactly one replacement wins epoch + 1; approval is re-verified, not
        re-consumed."""
        require_holder(holder)
        path = run_path(self.repo, run)

        def mutate(head, history):
            lease, doc = self.load(head, LEASE), self.load(head, path)
            P.require(lease is not None and lease["run_id"] == run and lease["holder"] is not None
                      and now() >= lease["lease_expires_at"], "repository-lease-held")
            self.reverify(history, path, doc, run, github)
            unknown = any(s["status"] == "claimed" for s in doc["steps"])
            lease = {**lease, "epoch": lease["epoch"] + 1, "lease_expires_at": now() + ttl,
                     "holder": None if unknown else holder}
            if unknown:
                doc = {**doc, "state": "needs-reconciliation", "stop_reason": "needs-reconciliation"}
            return {path: doc, LEASE: lease}
        return self.transact(f"roadmap: takeover {run}", mutate)


def main(argv=None, transport=None, authority=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=("propose", "consume", "claim", "checkpoint",
                                            "takeover"))
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--result", help="Preview result JSON (propose)")
    parser.add_argument("--evidence", help="Mapper/advisor evidence JSON (consume recompute)")
    parser.add_argument("--comment-id", type=int)
    parser.add_argument("--step", type=int)
    parser.add_argument("--epoch", type=int)
    parser.add_argument("--outcome", choices=("done", "conflict", "failed"))
    parser.add_argument("--status", type=int)
    parser.add_argument("--error")
    parser.add_argument("--apply", action="store_true", help="Commit; default prints the commit")
    args = parser.parse_args(argv)
    if transport is None:
        sys.modules.setdefault("ledger", sys.modules[__name__])  # one StaleHead class
        import github_io
        transport = github_io.GitHubBranch(args.repo, BRANCH, os.environ.get("ROADMAP_APP_SLUG"),
                                           os.environ.get("ROADMAP_APP_ID"))
        authority = github_io.GitHubAuthority(args.repo)
    ledger = Ledger(transport, args.repo, apply=args.apply)
    env = os.environ.get
    holder = f"{env('GITHUB_RUN_ID', 'local')}-{env('GITHUB_RUN_ATTEMPT', '1')}"
    if args.command == "propose":
        return ledger.propose(json.loads(Path(args.result).read_text(encoding="utf-8-sig")),
                              args.run_id)
    if args.command == "consume":
        import preview
        evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8-sig"))
        return ledger.consume(args.run_id, args.comment_id, authority, lambda: preview.normalize(
            evidence, P.read_snapshot(args.repo)), env("GITHUB_EVENT_NAME"), holder)
    if args.command == "claim":
        return ledger.claim(args.run_id, args.step, holder, args.epoch)
    if args.command == "checkpoint":
        return ledger.checkpoint(args.run_id, args.step, holder, args.epoch, args.outcome,
                                 args.status, args.error)
    return ledger.takeover(args.run_id, holder, authority)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2))
    except P.Conflict as error:
        raise SystemExit(f"roadmap-ledger-failed: {error}")
    except (ValueError, KeyError, TypeError, OSError):
        raise SystemExit("roadmap-ledger-failed: invalid input or transport failure")
