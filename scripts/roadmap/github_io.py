"""GitHub transport for the roadmap ledger: REST reads and createCommitOnBranch with expectedHeadOid."""

import base64
import json
import re
import subprocess
from datetime import datetime

import plan as P
from ledger import WRITERS, StaleHead

COMMIT = """mutation($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) { commit { oid } } }"""


def gh(args, payload=None, missing_ok=False):
    try:
        response = subprocess.run(["gh", "api", *args], input=payload, capture_output=True,
                                  text=True, encoding="utf-8", timeout=60)
    except subprocess.TimeoutExpired as error:
        raise TimeoutError("gh-api-timeout") from error
    if response.returncode != 0:
        if missing_ok and "Not Found" in response.stdout + response.stderr:
            return None
        if re.search(r"[Ee]xpected branch to point to", response.stdout + response.stderr):
            raise StaleHead(args[-1])
        raise P.Conflict(f"api-request-failed exit={response.returncode}")
    return json.loads(response.stdout) if response.stdout.strip() else None


class GitHubBranch:
    """Ledger transport for one bot branch; never targets main and never force-updates."""

    def __init__(self, repo, branch, app_slug=None, app_id=None):
        P.require(branch.startswith("bot/"), "invalid-bot-branch")
        self.repo, self.branch = P.repository(repo), branch
        self.app_slug, self.app_id = app_slug, app_id

    def head(self):
        ref = gh([f"repos/{self.repo}/git/ref/heads/{self.branch}"], missing_ok=True)
        return ref["object"]["sha"] if ref else None

    def read(self, oid, path):
        blob = gh([f"repos/{self.repo}/contents/{path}?ref={oid}"], missing_ok=True)
        return base64.b64decode(blob["content"]).decode("utf-8") if blob else None

    def history(self, oid):
        pages = gh(["--paginate", "--slurp", f"repos/{self.repo}/commits?sha={oid}&per_page=100"])
        result = []
        for listed in reversed([c for page in pages for c in page]):
            # The files array paginates; read every page so no runs/ change is hidden.
            detail = gh(["--paginate", "--slurp",
                         f"repos/{self.repo}/commits/{listed['sha']}?per_page=100"])
            commit = detail[0]
            author = commit.get("author") or {}
            files = {f["filename"]: None if f["status"] == "removed" else
                     self.read(commit["sha"], f["filename"])
                     for page in detail for f in page.get("files", [])
                     if f["filename"].startswith("runs/")}
            result.append({"oid": commit["sha"], "files": files,
                           "verified": commit["commit"]["verification"]["verified"] is True,
                           "app": bool(self.app_slug) and author.get("type") == "Bot" and
                           author.get("login") == f"{self.app_slug}[bot]"})
        return result

    def protected(self, root):
        """No deletion/force, app-only updates, and no ruleset created or changed after root."""
        if not self.app_id:
            return False
        try:
            rules = gh([f"repos/{self.repo}/rules/branches/{self.branch}"]) or []
            sets = {i: gh([f"repos/{self.repo}/rulesets/{i}"])
                    for i in {r["ruleset_id"] for r in rules}}
            times = [gh([f"repos/{self.repo}/commits/{root}"])["commit"]["committer"]["date"]]
            times = [datetime.fromisoformat(t.replace("Z", "+00:00")) for t in times + [
                s["updated_at"] for s in sets.values()]]
            types = {r["type"] for r in rules} if all(t <= times[0] for t in times[1:]) else set()
            required = {"deletion", "non_fast_forward", "update"}
            bypass = [sets[r["ruleset_id"]].get("bypass_actors") for r in rules
                      if r["type"] in required]
        except (P.Conflict, KeyError, TypeError, ValueError):
            return False
        return required <= types and bool(bypass) and all(
            b == [{"actor_id": int(self.app_id), "actor_type": "Integration",
                   "bypass_mode": "always"}] for b in bypass)

    def create_from(self, base):
        """Create this missing bot branch at the base branch head; never moves an existing ref."""
        sha = gh([f"repos/{self.repo}/git/ref/heads/{base}"])["object"]["sha"]
        try:
            gh(["--method", "POST", f"repos/{self.repo}/git/refs", "-f",
                f"ref=refs/heads/{self.branch}", "-f", f"sha={sha}"])
        except P.Conflict:
            if self.head() is not None:  # A concurrent creator won; re-read and re-render.
                raise StaleHead(self.branch)
            raise
        return sha

    def commit(self, expected, files, message):
        P.require(expected is not None, "ledger-branch-missing")
        changes = {"additions": [{"path": p, "contents": base64.b64encode(c.encode()).decode()}
                                 for p, c in files.items() if c is not None],
                   "deletions": [{"path": p} for p, c in files.items() if c is None]}
        payload = json.dumps({"query": COMMIT, "variables": {"input": {
            "branch": {"repositoryNameWithOwner": self.repo, "branchName": self.branch},
            "expectedHeadOid": expected, "message": {"headline": message},
            "fileChanges": changes}}})
        out = gh(["graphql", "--input", "-"], payload)
        P.require(not (out or {}).get("errors"), "ledger-commit-failed")
        return out["data"]["createCommitOnBranch"]["commit"]["oid"]


class GitHubAuthority:
    """Approval identity resolved from GitHub at call time; nothing is cached."""

    def __init__(self, repo):
        self.repo = P.repository(repo)

    def comment(self, comment_id):
        c = gh([f"repos/{self.repo}/issues/comments/{P.number(comment_id)}"])
        return {"id": c["id"], "user_type": c["user"]["type"], "user_login": c["user"]["login"],
                "user_id": c["user"]["id"], "url": c["html_url"], "body": c["body"]}

    def permission(self, login):
        P.require(re.fullmatch(r"[A-Za-z0-9-]{1,39}", login) is not None, "unauthorized-approval")
        p = gh([f"repos/{self.repo}/collaborators/{login}/permission"])
        return p.get("role_name") if p.get("role_name") in WRITERS else p.get("permission")
