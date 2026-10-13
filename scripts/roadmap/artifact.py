"""Roadmap artifact publisher: one bot branch and one PR to main. Dry-run by default."""

import argparse
import difflib
import json
import os
from pathlib import Path

import preview
import plan as P
from github_io import GitHubAuthority, GitHubBranch, gh
from ledger import BRANCH as LEDGER_BRANCH, Ledger
from ledger import StaleHead

BRANCH = "bot/roadmap-artifact"
PATH = "docs/reference/roadmap.md"
TITLE = "docs(roadmap): refresh roadmap artifact"
INTRO = "Read-only proposal; not approved, assigned, or shipped."


def lifecycle(doc):
    if doc["state"] in ("approved", "claimed"):
        return "approved"
    if doc["state"] == "terminal" and doc["stop_reason"] == "complete":
        return "persisted"
    return "conflict" if doc["state"] != "proposed" else "proposed"


def render(result, doc):
    P.require(doc["plan_digest"] == result["digest"] == P.digest(result["plan"]),
              "stale-or-mismatched-approval")
    state = lifecycle(doc)
    # Identical plan and ledger state always produce identical bytes.
    return preview.render(result).replace(INTRO, f"Ledger state: {state}; run `{doc['run_id']}`.")\
        .replace("Lifecycle: proposed;", f"Lifecycle: {state};")


def publish(ledger, run, result, authority, branch, pulls, apply=False, attempts=3):
    """Requires a re-verified consumed approval before any branch or PR write."""
    P.require(branch.branch == BRANCH, "invalid-bot-branch")
    for _ in range(attempts):
        doc, _lease = ledger.authority(run, authority)
        content = render(result, doc)
        head = branch.head()
        current = branch.read(head, PATH) if head else None
        if current == content:
            return {"status": "unchanged", "head": head, "pr": pulls.ensure(apply)}
        if not apply:
            diff = difflib.unified_diff((current or "").splitlines(True),
                                        content.splitlines(True), f"a/{PATH}", f"b/{PATH}")
            return {"status": "dry-run", "expected_head": head, "create_branch": head is None,
                    "path": PATH, "content": content, "diff": "".join(diff)}
        try:
            head = head or branch.create_from("main")
            oid = branch.commit(head, {PATH: content}, TITLE)
        except StaleHead:
            continue
        return {"status": "committed", "head": oid, "pr": pulls.ensure(apply)}
    raise P.Conflict("artifact-head-contention")


class GitHubPulls:
    """The single artifact PR; a closed unmerged PR is reported, never reopened."""

    def __init__(self, repo):
        self.repo = P.repository(repo)

    def ensure(self, apply):
        owner = self.repo.split("/")[0]
        pulls = gh([f"repos/{self.repo}/pulls?state=all&head={owner}:{BRANCH}&per_page=100"])
        open_pr = [p["number"] for p in pulls if p["state"] == "open"]
        if open_pr:
            return {"number": open_pr[0], "action": "updated"}
        latest = max(pulls, key=lambda p: p["number"], default=None)
        if latest and not latest.get("merged_at"):
            return {"number": latest["number"], "action": "closed-unmerged-reported"}
        if not apply:
            return {"number": None, "action": "would-open"}
        created = gh(["--method", "POST", f"repos/{self.repo}/pulls", "-f", f"title={TITLE}",
                      "-f", f"head={BRANCH}", "-f", "base=main", "-f",
                      "body=Automated roadmap artifact refresh. Admission gates apply."])
        return {"number": created["number"], "action": "opened"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--result", required=True, help="Approved preview result JSON")
    parser.add_argument("--apply", action="store_true", help="Commit and open/update the PR")
    args = parser.parse_args(argv)
    app = (os.environ.get("ROADMAP_APP_SLUG"), os.environ.get("ROADMAP_APP_ID"))
    ledger = Ledger(GitHubBranch(args.repo, LEDGER_BRANCH, *app), args.repo)
    result = json.loads(Path(args.result).read_text(encoding="utf-8-sig"))
    return publish(ledger, args.run_id, result, GitHubAuthority(args.repo),
                   GitHubBranch(args.repo, BRANCH, *app), GitHubPulls(args.repo), args.apply)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2))
    except P.Conflict as error:
        raise SystemExit(f"roadmap-artifact-failed: {error}")
    except (ValueError, KeyError, TypeError, OSError):
        raise SystemExit("roadmap-artifact-failed: invalid input or transport failure")
