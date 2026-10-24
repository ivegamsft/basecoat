"""Milestone/assignment adapter behind a gate that only positive probe evidence can open."""

import argparse
import datetime
import json
import os
from pathlib import Path

import plan as P
from github_io import GitHubAuthority, GitHubBranch, GitHubMilestones, Unconfirmed
from ledger import BRANCH, Ledger, approved_steps, milestone_state as state

EVIDENCE = Path(__file__).resolve().parents[2] / "docs/reference/roadmap-contract-probe.json"
REQUIRED = {"assign": ("2a", "2b", "3a", "3b"), "create": ("4",), "edit": ("1",)}
MAX_AGE = datetime.timedelta(days=30)
MARK = "<!-- basecoat-roadmap:v1 key={} -->"
OFF, UNPROVEN = "live-writes-disabled: ", "live-writes-disabled: conditional-mutation-not-proven"


def gate(ledger, run, authority, holder, epoch, steps, evidence_path=EVIDENCE, now=None):
    """Every condition must hold; a flag, approval, label or mock alone never opens it."""
    doc, lease = ledger.authority(run, authority)
    P.require(lease and lease["run_id"] == run and lease["holder"] == holder and
              lease["epoch"] == epoch, OFF + "fenced-holder")
    P.require(approved_steps(doc) == steps, OFF + "steps-not-approved")
    P.require(P.CONFIG.get("roadmap_persistence_enabled") is True,
              OFF + "roadmap_persistence_enabled-false")
    try:
        evidence = json.loads(Path(evidence_path).read_text(encoding="utf-8"))
        recorded = datetime.datetime.fromisoformat(evidence["recorded_at"])
        cases = evidence["cases"]
    except (OSError, ValueError, KeyError, TypeError):
        raise P.Conflict(UNPROVEN)
    now = now or datetime.datetime.now(datetime.timezone.utc)
    P.require(evidence.get("schema") == 1 and recorded.tzinfo is not None and
              datetime.timedelta(0) <= now - recorded <= MAX_AGE, UNPROVEN)
    for step in steps:
        needed = REQUIRED.get(step["operation"])
        P.require(needed and all((cases.get(c) or {}).get("result") == "positive"
                                 for c in needed), UNPROVEN)
    return doc


def sole_target(step, targets):
    """Exactly one open, unpinned milestone whose only managed key is the approved key."""
    return len(targets) == 1 and (targets[0]["key"], targets[0]["state"],
                                  targets[0]["pinned"]) == (step["key"], "open", False)


class Persist:  # Re-reads the full read set before and after each mutation, one step at a time.
    def __init__(self, client, ledger, run, authority, holder, epoch):
        self.client, self.ledger, self.run = client, ledger, run
        self.authority, self.holder, self.epoch = authority, holder, epoch

    def observe(self, step):
        """Sanitized pre-write read set (persisted with the claim), guard verdict and ETag."""
        if step["operation"] == "create":
            found = [state(m) for m in self.client.by_marker(step["marker"])]
            return {"targets": found}, not found, None  # never adopt existing
        issue = self.client.issue(step["number"])
        source = issue["milestone"] and state(self.client.milestone(issue["milestone"]))
        targets = [state(m) for m in self.client.by_marker(MARK.format(step["key"]))]
        pinned = "roadmap:pinned" in [s.lower() for s in issue["labels"]]
        ok = (issue["milestone"] == step["expected_milestone"] and not pinned and
              bool(issue["etag"]) and (not source or (source["key"], source["pinned"]) == (
                  step["source_key"], False)) and sole_target(step, targets))
        return {"item": {"milestone": issue["milestone"], "pinned": pinned},
                "source": source or None, "targets": targets}, ok, issue["etag"]

    def verify(self, step, seen):
        """Operation-specific post-write read set; any drift is a conflict, never compensated."""
        create = step["operation"] == "create"
        marker = step["marker"] if create else MARK.format(step["key"])
        targets = [state(m) for m in self.client.by_marker(marker)]
        if not sole_target(step, targets):
            return False
        if create:
            return True
        issue, source = self.client.issue(step["number"]), seen["source"]
        return (issue["milestone"] == seen["targets"][0]["number"] == targets[0]["number"] and
                "roadmap:pinned" not in [s.lower() for s in issue["labels"]] and
                (not source or state(self.client.milestone(source["number"])) == source))

    def execute(self, steps):
        for index in range(len(steps)):
            doc = gate(self.ledger, self.run, self.authority, self.holder, self.epoch, steps)
            step = doc["steps"][index]  # The approved step, including its source key.
            if step["status"] == "done":
                continue  # Resume after a crash from the first step not yet done.
            seen, ok, etag = self.observe(step)
            self.ledger.claim(self.run, index, self.holder, self.epoch, seen)
            if not ok:
                return self.finish(index, "conflict", 409, "pre-write-state-changed")
            create = step["operation"] == "create"
            target = None if create else seen["targets"][0]["number"]
            try:
                (self.client.create(step["key"], step["marker"]) if create else
                 self.client.assign(step["number"], target, etag))
            except (OSError, TimeoutError, Unconfirmed):
                pass  # Unknown outcome only: the post-write read below decides.
            except P.Conflict as error:  # A definitive rejection is never recovered by reading.
                if str(error) == "precondition-failed":
                    return self.finish(index, "conflict", 412, "precondition-failed")
                return self.finish(index, "failed", 0, "write-rejected")
            if not self.verify(step, seen):
                return self.finish(index, "conflict", 409, "post-write-state-mismatch")
            self.finish(index, "done", 200)
        return {"status": "complete", "steps": len(steps)}

    def finish(self, index, outcome, status, error=None):
        self.ledger.checkpoint(self.run, index, self.holder, self.epoch, outcome, status, error)
        return {"status": outcome, "step": index, "error": error}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("--repo", "--run-id", "--result"):
        parser.add_argument(name, required=True)
    parser.add_argument("--epoch", type=int, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    app = (os.environ.get("ROADMAP_APP_SLUG"), os.environ.get("ROADMAP_APP_ID"))
    ledger = Ledger(GitHubBranch(args.repo, BRANCH, *app), args.repo, apply=args.apply)
    steps = json.loads(Path(args.result).read_text(encoding="utf-8-sig"))["steps"]
    env, authority = os.environ.get, GitHubAuthority(args.repo)
    holder = f"{env('GITHUB_RUN_ID', 'local')}-{env('GITHUB_RUN_ATTEMPT', '1')}"
    gate(ledger, args.run_id, authority, holder, args.epoch, steps)
    if not args.apply:
        return {"gate": "open", "dry_run": True, "steps": len(steps)}
    return Persist(GitHubMilestones(args.repo), ledger, args.run_id, authority, holder,
                   args.epoch).execute(steps)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2))
    except P.Conflict as error:
        raise SystemExit(f"roadmap-persist-failed: {error}")
    except (ValueError, KeyError, TypeError, OSError):
        raise SystemExit("roadmap-persist-failed: invalid input or transport failure")
