"""Contract probe tests: refusal, classifier and case runner against a simulated sandbox."""

import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
import contract_probe as C  # noqa: E402

P = C.P


class Sandbox:
    """Simulated REST surface; `enforce` honors If-Match per resource, `unique` milestone titles."""

    def __init__(self, enforce=False, unique=False, down=False):
        self.enforce, self.unique, self.down = enforce, unique, down
        self.res = {"milestones/99": {"description": "human", "title": "keep", "v": 0}}
        self.next = 100

    def __call__(self, method, path, fields=None, headers=None):
        if self.down:
            return None, None, {}
        path = path.split("/", 3)[3]
        fields = fields or {}
        if method == "POST" and path in ("milestones", "issues"):
            if self.unique and path == "milestones" and any(
                    r.get("title") == fields["title"] for r in self.res.values()):
                return 422, None, {"errors": [{"code": "already_exists"}]}
            self.next += 1
            self.res[f"{path}/{self.next}"] = {**fields, "v": 0}
            return 201, None, {"number": self.next}
        target = self.res.get(path.replace("/labels", ""))
        if target is None:
            return 404, None, {}
        etag = f'"{target["v"]}"'
        if method == "GET":
            return 200, etag, dict(target)
        if method == "DELETE":
            del self.res[path]
            return 204, None, {}
        if self.enforce and headers and headers["If-Match"] != etag:
            return 412, None, {"message": "Precondition Failed"}
        target.update({k: v for k, v in fields.items() if k != "labels[]"}, v=target["v"] + 1)
        return 200, f'"{target["v"]}"', dict(target)


class ProbeTests(unittest.TestCase):
    def test_refuses_unconfirmed_unlisted_or_home_repository(self):
        allow = ROOT / "tests" / "roadmap-probe-allowlist.tmp.json"
        self.addCleanup(allow.unlink)
        allow.write_text(json.dumps({"repositories": ["Owner/Sandbox"]}), encoding="utf-8")
        home = "Owner/Home"
        self.assertEqual(C.confirm("owner/sandbox", "Owner/Sandbox", allow, home), "owner/sandbox")
        for repo, confirmation in (("owner/sandbox", "owner/other"), ("owner/other", "owner/other"),
                                   (home, home)):
            with self.subTest(repo=repo):
                with self.assertRaisesRegex(P.Conflict, "probe-repository-refused"):
                    C.confirm(repo, confirmation, allow, home)
        allow.write_text(json.dumps({"repositories": ["owner/sandbox", home]}), encoding="utf-8")
        with self.assertRaisesRegex(P.Conflict, "probe-repository-refused"):
            C.confirm("owner/sandbox", "owner/sandbox", allow, home)
        with patch.object(C, "home_repository", return_value=None), \
                self.assertRaisesRegex(P.Conflict, "probe-repository-refused"):
            C.confirm("owner/sandbox", "owner/sandbox", allow)
        with patch.dict(C.os.environ, {"GITHUB_REPOSITORY": "Owner/Home"}):
            self.assertEqual(C.home_repository(), "Owner/Home")
        self.assertEqual(json.loads(C.ALLOWLIST.read_text(encoding="utf-8")),
                         {"repositories": []})

    def test_classifier_only_attributable_conflicts_are_positive(self):
        ok = {"status": 200}
        for control, stale, expected in (
                (ok, {"status": 412}, "positive"),
                (ok, {"status": 422, "error": "already_exists"}, "inconclusive"),
                (ok, {"status": 200}, "negative"),
                ({"status": 403}, {"status": 412}, "inconclusive"),
                ({"status": None}, {"status": 412}, "inconclusive"),
                (ok, {"status": 422, "error": "invalid"}, "inconclusive"),
                (ok, {"status": 403}, "inconclusive"), (ok, {"status": 429}, "inconclusive"),
                (ok, {"status": 502}, "inconclusive"), (ok, {"status": None}, "inconclusive")):
            with self.subTest(control=control, stale=stale):
                self.assertEqual(C.classify(control, stale), expected)
        self.assertEqual(C.classify(ok, {"status": 422, "error": "already_exists"}, True),
                         "positive")

    def results(self, sandbox):
        evidence = C.Probe("owner/sandbox", sandbox).run(now="t")
        return {k: v["result"] for k, v in evidence["cases"].items()}

    def test_applied_stale_writes_are_negative_and_cleanup_is_scoped(self):
        sandbox = Sandbox()
        self.assertEqual(set(self.results(sandbox).values()), {"negative"})
        self.assertEqual([k for k in sandbox.res if k.startswith("milestones/")], ["milestones/99"])
        self.assertTrue(all(v["state"] == "closed" for k, v in sandbox.res.items()
                            if k.startswith("issues/")))

    def test_if_match_protects_single_resource_but_not_cross_resource_read_set(self):
        results = self.results(Sandbox(enforce=True, unique=True))
        self.assertEqual(results, {"1": "positive", "2a": "positive", "2b": "positive",
                                   "3a": "negative", "3b": "negative", "4": "positive"})

    def test_transport_failure_is_inconclusive(self):
        self.assertEqual(set(self.results(Sandbox(down=True)).values()), {"inconclusive"})

    def test_gh_api_parses_status_etag_and_error(self):
        out = 'HTTP/2.0 412 Precondition Failed\r\nEtag: W/"x"\r\n\r\n{"message": "no"}'
        with patch.object(C.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 1, out, "")) as run:
            self.assertEqual(C.gh_api("PATCH", "repos/o/r/issues/1", {"milestone": 2},
                                      {"If-Match": 'W/"x"'}), (412, 'W/"x"', {"message": "no"}))
        self.assertIn("milestone=2", run.call_args[0][0])
        with patch.object(C.subprocess, "run", side_effect=subprocess.TimeoutExpired("gh", 60)):
            self.assertEqual(C.gh_api("GET", "x")[0], None)


if __name__ == "__main__":
    unittest.main()
