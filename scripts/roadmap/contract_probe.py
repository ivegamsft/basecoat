"""Sandbox-only live contract probe: does GitHub reject a write made against a stale read?"""

import argparse
import datetime
import json
import os
import re
import subprocess
import uuid
from pathlib import Path

import plan as P

ALLOWLIST = Path(__file__).with_name("probe-allowlist.json")
CASES = ("1", "2a", "2b", "3a", "3b", "4")


def home_repository():
    """This checkout's own repository (Actions env or origin remote); None if unknown."""
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"]
    try:
        url = subprocess.run(["git", "config", "--get", "remote.origin.url"], capture_output=True,
                             text=True, cwd=Path(__file__).parent, timeout=10).stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        return None
    match = re.search(r"[:/]([^/:]+/[^/]+?)(?:\.git)?$", url)
    return match.group(1) if match else None


def confirm(repo, confirmation, allowlist=None, home=None):
    allowed = json.loads((allowlist or ALLOWLIST).read_text(encoding="utf-8"))["repositories"]
    repo, home = P.repository(repo), home or home_repository()
    P.require(home is not None, "probe-repository-refused")  # Unknown home fails closed.
    home = P.repository(home)
    P.require(repo != home and home not in [P.repository(r) for r in allowed] and
              repo == P.repository(confirmation) and repo in [P.repository(r) for r in allowed],
              "probe-repository-refused")
    return repo


def classify(control, stale, uniqueness=False):
    """Only an attributable stale-state or (concurrent-create case only) uniqueness conflict."""
    if control.get("status") is None or not 200 <= control["status"] < 300:
        return "inconclusive"
    status = stale.get("status")
    if status is not None and 200 <= status < 300:
        return "negative"
    if status == 412 or (uniqueness and status == 422 and stale.get("error") == "already_exists"):
        return "positive"
    return "inconclusive"


def gh_api(method, path, fields=None, headers=None):
    """Return (status, etag, body) from `gh api -i`; transport failure yields status None."""
    cmd = ["gh", "api", "-i", "--method", method, path]
    for key, value in (headers or {}).items():
        cmd += ["-H", f"{key}: {value}"]
    for key, value in (fields or {}).items():
        cmd += ["-F" if isinstance(value, int) else "-f", f"{key}={value}"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                             timeout=60).stdout
    except (subprocess.TimeoutExpired, OSError):
        return None, None, {}
    head, _, body = out.replace("\r\n", "\n").partition("\n\n")
    status = re.match(r"HTTP/\S+ (\d{3})", head)
    etag = re.search(r"(?im)^etag: (.+)$", head)
    try:
        parsed = json.loads(body) if body.strip() else {}
    except ValueError:
        parsed = {}
    return (int(status.group(1)) if status else None, etag.group(1).strip() if etag else None,
            parsed)


class Probe:
    def __init__(self, repo, api=gh_api):
        self.repo, self.api = repo, api
        self.token = uuid.uuid4().hex
        self.marker = f"<!-- basecoat-roadmap-probe:{self.token} -->"
        self.milestones, self.issues = [], []

    def call(self, method, path, fields=None, etag=None):
        status, tag, body = self.api(method, f"repos/{self.repo}/{path}", fields,
                                     {"If-Match": etag} if etag else None)
        errors = body.get("errors") or [{}] if isinstance(body, dict) else [{}]
        return {"status": status, "etag": tag, "body": body,
                "error": errors[0].get("code") if isinstance(errors[0], dict) else None}

    def milestone(self, title):
        r = self.call("POST", "milestones", {"title": f"{title} {self.token}",
                                             "description": self.marker})
        self.milestones.append(r["body"].get("number"))
        return r["body"].get("number")

    def issue(self):
        r = self.call("POST", "issues", {"title": "roadmap contract probe", "body": self.marker})
        self.issues.append(r["body"].get("number"))
        return r["body"].get("number")

    def stale(self, path, write, external):
        """Fresh control write, then an external change, then the original write on the old read."""
        control = self.call("PATCH", path, write, self.call("GET", path)["etag"])
        observed = self.call("GET", path)["etag"]
        external()
        return control, self.call("PATCH", path, write, observed)

    def case(self, name):
        if name == "1":
            m = f"milestones/{self.milestone('probe-1')}"
            return self.stale(m, {"description": self.marker + " v1"},
                              lambda: self.call("PATCH", m, {"description": self.marker + " x"}))
        if name == "4":
            fields = {"title": f"probe-4 {self.token}", "description": self.marker}
            first, second = (self.call("POST", "milestones", fields) for _ in range(2))
            self.milestones += [r["body"].get("number") for r in (first, second)]
            return first, second
        source, target, n = self.milestone(f"src-{name}"), self.milestone(f"dst-{name}"), self.issue()
        self.call("PATCH", f"issues/{n}", {"milestone": source})
        external = {
            "2a": lambda: self.call("PATCH", f"issues/{n}", {"milestone": self.milestone("ext-2a")}),
            "2b": lambda: self.call("POST", f"issues/{n}/labels", {"labels[]": "roadmap:pinned"}),
            "3a": lambda: self.call("PATCH", f"milestones/{source}",
                                    {"description": self.marker + P.PIN}),
            "3b": lambda: self.call("PATCH", f"milestones/{target}",
                                    {"description": self.marker + P.PIN})}[name]
        return self.stale(f"issues/{n}", {"milestone": target}, external)

    def cleanup(self):
        """Delete or close only resources this run created and that still carry its marker."""
        for n in filter(None, self.milestones):
            if self.marker in (self.call("GET", f"milestones/{n}")["body"].get("description") or ""):
                self.call("DELETE", f"milestones/{n}")
        for n in filter(None, self.issues):
            if self.marker in (self.call("GET", f"issues/{n}")["body"].get("body") or ""):
                self.call("PATCH", f"issues/{n}", {"state": "closed"})

    def run(self, now=None):
        cases = {}
        try:
            for name in CASES:
                control, stale = self.case(name)
                cases[name] = {"result": classify(control, stale, name == "4"),
                               "surface": "rest-if-match",
                               "control_status": control["status"],
                               "stale_status": stale["status"], "error": stale["error"]}
        finally:
            self.cleanup()
        recorded = now or datetime.datetime.now(datetime.timezone.utc).isoformat()
        return {"schema": 1, "repository": self.repo, "recorded_at": recorded, "cases": cases}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--confirm-sandbox", required=True)
    args = parser.parse_args(argv)
    return Probe(confirm(args.repo, args.confirm_sandbox)).run()


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2))
    except P.Conflict as error:
        raise SystemExit(f"roadmap-probe-failed: {error}")
