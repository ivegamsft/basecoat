"""GitHub ledger transport tests with a patched `gh api` runner (no network)."""

import base64
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "roadmap"))
import github_io as G  # noqa: E402
import ledger as L  # noqa: E402

SPEC = importlib.util.spec_from_file_location("ledger_tests", ROOT / "tests" /
                                             "roadmap-ledger-tests.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
RULES = [{"type": "deletion", "ruleset_id": 9}, {"type": "non_fast_forward", "ruleset_id": 9},
         {"type": "update", "ruleset_id": 9}]
BYPASS = {"updated_at": "2026-01-01T00:00:00.000-08:00", "bypass_actors": [
    {"actor_id": 42, "actor_type": "Integration", "bypass_mode": "always"}]}
ROOT_COMMIT = {"commit": {"committer": {"date": "2026-01-01T08:00:00Z"}}}


class FakeGh:
    def __init__(self, routes):
        self.routes, self.calls = routes, []

    def __call__(self, cmd, input=None, **_kwargs):
        self.calls.append((cmd, input))
        for key, value in self.routes.items():
            if key in " ".join(cmd):
                if isinstance(value, Exception):
                    raise value
                code, out = value if isinstance(value, tuple) else (0, json.dumps(value))
                return subprocess.CompletedProcess(cmd, code, out, "")
        return subprocess.CompletedProcess(cmd, 1, "", "gh: Not Found (HTTP 404)")


def b64(text):
    return base64.b64encode(text.encode()).decode()


class TransportTests(unittest.TestCase):
    def branch(self, routes, app_id="42"):
        self.fake = FakeGh(routes)
        patcher = patch.object(G.subprocess, "run", self.fake)
        patcher.start()
        self.addCleanup(patcher.stop)
        return G.GitHubBranch("Owner/Repo", L.BRANCH, "roadmap-app", app_id)

    def test_only_bot_branches_and_missing_refs_read_as_absent(self):
        with self.assertRaisesRegex(G.P.Conflict, "invalid-bot-branch"):
            G.GitHubBranch("owner/repo", "main")
        branch = self.branch({"contents/runs/a.json?ref=c1": {"content": b64("{}")}})
        self.assertIsNone(branch.head())
        self.assertEqual(branch.read("c1", "runs/a.json"), "{}")
        self.assertIsNone(branch.read("c1", "runs/b.json"))

    def test_failures_without_a_4xx_have_unknown_outcome(self):
        for out, unknown in (("gh: Validation Failed (HTTP 422)", False),
                             ("HTTP/2.0 404 Not Found\n\n{}", False),
                             ("gh: Bad Gateway (HTTP 502)", True),
                             ("gh: connection reset by peer", True)):
            with self.subTest(out=out):
                self.branch({"issues/1": (1, out)})
                for call in (lambda: G.gh(["repos/o/r/issues/1"]),
                             lambda: G.request(["repos/o/r/issues/1"])):
                    with self.assertRaises(G.P.Conflict) as caught:
                        call()
                    self.assertIs(isinstance(caught.exception, G.Unconfirmed), unknown)

    def test_commit_binds_expected_head_and_maps_stale_and_lost_responses(self):
        branch = self.branch({"graphql": {"data": {"createCommitOnBranch": {
            "commit": {"oid": "c2"}}}}})
        self.assertEqual(branch.commit("c1", {"lease.json": "{}\n"}, "msg"), "c2")
        body = json.loads(self.fake.calls[-1][1])["variables"]["input"]
        self.assertEqual((body["expectedHeadOid"], body["branch"]["branchName"],
                          body["fileChanges"]["additions"][0]["contents"]),
                         ("c1", "bot/roadmap-state", b64("{}\n")))
        for value, error in (((1, 'gh: Expected branch to point to "c1"'), L.StaleHead),
                             ((1, "gh: Something went wrong"), G.P.Conflict),
                             (subprocess.TimeoutExpired("gh", 60), TimeoutError)):
            with self.subTest(value=value):
                branch = self.branch({"graphql": value})
                with self.assertRaises(error):
                    branch.commit("c1", {"lease.json": "{}\n"}, "msg")

    def test_create_from_points_new_bot_branch_at_base_head(self):
        branch = self.branch({"git/ref/heads/main": {"object": {"sha": "m1"}}, "git/refs": {}})
        self.assertEqual(branch.create_from("main"), "m1")
        self.assertIn("ref=refs/heads/bot/roadmap-state", self.fake.calls[-1][0])
        self.assertIn("sha=m1", self.fake.calls[-1][0])
        exists = (1, "gh: Reference already exists (HTTP 422)")
        for ref, error in (({"object": {"sha": "b1"}}, L.StaleHead), (None, G.P.Conflict)):
            with self.subTest(error=error):
                routes = {"git/ref/heads/main": {"object": {"sha": "m1"}}, "git/refs": exists}
                branch = self.branch({**routes, **({"git/ref/heads/bot/": ref} if ref else {})})
                with self.assertRaises(error):
                    branch.create_from("main")

    def test_bootstrap_provisions_parentless_app_root_that_passes_provenance(self):
        branch = self.branch({"git/trees": {"sha": "t1"}, "git/commits": {"sha": "r0"},
                              "git/refs": {}})
        files = {L.ROOT_FILE: '{"schema":1}\n'}
        self.assertEqual(branch.bootstrap(files, "roadmap: bootstrap ledger root"), "r0")
        tree, commit = (json.loads(self.fake.calls[i][1]) for i in (1, 2))
        self.assertEqual((tree["tree"][0]["path"], commit["parents"], commit["tree"]),
                         (L.ROOT_FILE, [], "t1"))
        self.assertNotIn("author", commit)  # GitHub signs it as the app installation.
        self.assertIn("sha=r0", self.fake.calls[-1][0])
        detail = {"sha": "r0", "parents": [], "author": {"type": "Bot",
                                                         "login": "roadmap-app[bot]"},
                  "commit": {"verification": {"verified": True}},
                  "files": [{"filename": L.ROOT_FILE, "status": "added"}]}
        provisioned = {"git/ref/heads/bot/": {"object": {"sha": "r0"}},
                       "commits?sha=r0": [[{"sha": "r0"}]], "commits/r0?per_page": [detail],
                       "commits/r0": ROOT_COMMIT, "rules/branches": RULES, "rulesets/9": BYPASS}
        branch = self.branch(provisioned)
        self.assertEqual(L.verify_provenance(branch, branch.head())[0]["oid"], "r0")
        missing = {k: v for k, v in detail.items() if k != "parents"}  # Fails closed.
        for bad in ({**detail, "parents": [{"sha": "m0"}]}, missing):
            branch = self.branch({**provisioned, "commits/r0?per_page": [bad]})
            with self.assertRaisesRegex(G.P.Conflict, "ledger-provenance-unproven"):
                L.verify_provenance(branch, "r0")
        exists = (1, "gh: Reference already exists (HTTP 422)")
        for routes in ({"git/ref/heads/bot/": {"object": {"sha": "b1"}}},
                       {"git/trees": {"sha": "t1"}, "git/commits": {"sha": "r0"},
                        "git/refs": exists}):
            with self.subTest(routes=routes):
                with self.assertRaises(G.P.Conflict):
                    self.branch(routes).bootstrap(files, "msg")

    def test_protected_requires_exact_app_only_ruleset(self):
        ok = {"rules/branches": RULES, "rulesets/9": BYPASS, "commits/c0": ROOT_COMMIT}
        self.assertTrue(self.branch(ok).protected("c0"))
        other = {**BYPASS, "bypass_actors": BYPASS["bypass_actors"] + [
            {"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]}
        late = {**BYPASS, "updated_at": "2026-01-01T08:00:01Z"}
        cases = [(ok, None), ({**ok, "rules/branches": RULES[1:]}, "42"),
                 ({"rules/branches": RULES, "rulesets/9": BYPASS}, "42")]
        cases += [({**ok, "rulesets/9": ruleset}, "42") for ruleset in (other, late)]
        split = [{**RULES[0], "ruleset_id": 8}, *RULES[1:]]
        cases.append(({**ok, "rules/branches": split, "rulesets/8": other}, "42"))
        for routes, app_id in cases:
            with self.subTest(routes=routes, app_id=app_id):
                self.assertFalse(self.branch(routes, app_id).protected("c0"))

    def test_history_marks_app_authorship_verification_and_removals(self):
        def commit(sha, login, verified, files):
            return {"sha": sha, "author": {"type": "Bot", "login": login},
                    "commit": {"verification": {"verified": verified}}, "files": files}
        branch = self.branch({
            "commits?sha=c2": [[{"sha": "c2"}, {"sha": "c1"}]],
            "commits/c1": [commit("c1", "roadmap-app[bot]", True,
                                  [{"filename": "docs/x.md", "status": "added"}]),
                           commit("c1", "roadmap-app[bot]", True,
                                  [{"filename": "runs/a.json", "status": "added"}])],
            "commits/c2": [commit("c2", "someone[bot]", True,
                                  [{"filename": "runs/a.json", "status": "removed"}])],
            "contents/runs/a.json?ref=c1": {"content": b64('{"approval": null}')}})
        history = branch.history("c2")
        self.assertEqual([(c["oid"], c["app"], c["files"]["runs/a.json"]) for c in history],
                         [("c1", True, '{"approval": null}'), ("c2", False, None)])

    def test_request_returns_etag_and_maps_failed_if_match_to_conflict(self):
        ok = (0, 'HTTP/2.0 200 OK\r\nEtag: W/"abc"\r\n\r\n{"number": 1}')
        self.branch({"issues/1": ok})
        self.assertEqual(G.request(["repos/o/r/issues/1"]), ('W/"abc"', {"number": 1}))
        self.branch({"issues/1": (0, "HTTP/2.0 204 No Content\r\n\r\n")})
        self.assertEqual(G.request(["repos/o/r/issues/1"], if_match='W/"abc"'), (None, None))
        self.assertIn('If-Match: W/"abc"', self.fake.calls[-1][0])
        for out, code in (("HTTP/2.0 412 Precondition Failed\r\n\r\n{}", "precondition-failed"),
                          ("HTTP/2.0 500 Error\r\n\r\n{}", "api-outcome-unknown")):
            self.branch({"issues/1": (1, out)})
            with self.subTest(code=code), self.assertRaisesRegex(G.P.Conflict, code):
                G.request(["repos/o/r/issues/1"], if_match='W/"abc"')
        self.branch({"issues/1": (0, 'HTTP/2.0 200 OK\r\nETag: "e1"\r\n\r\n'
                                     '{"milestone": {"number": 7}, "labels": [{"name": "x"}]}')})
        milestones = G.GitHubMilestones("owner/repo")
        self.assertEqual(milestones.issue(1), {"etag": '"e1"', "milestone": 7, "labels": ["x"]})
        milestones.assign(1, 9, '"e1"')
        self.assertEqual(self.fake.calls[-1][0][-4:], ["-F", "milestone=9", "-H",
                                                       'If-Match: "e1"'])

    def test_authority_maps_comment_and_current_role(self):
        self.branch({"comments/7": {"id": 7, "user": {"type": "User", "login": "al", "id": 3},
                                    "html_url": "u", "body": "b"},
                     "collaborators/al/permission": {"permission": "write",
                                                     "role_name": "maintain"}})
        authority = G.GitHubAuthority("owner/repo")
        self.assertEqual(authority.comment(7)["user_id"], 3)
        self.assertEqual(authority.permission("al"), "maintain")
        with self.assertRaisesRegex(G.P.Conflict, "unauthorized-approval"):
            authority.permission("../x")

    def test_cli_defaults_to_dry_run(self):
        branch = T.FakeBranch()
        path = ROOT / "tests" / "roadmap-ledger-cli-result.tmp.json"
        path.write_text(json.dumps(T.result()), encoding="utf-8")
        self.addCleanup(path.unlink)
        out = L.main(["propose", "--repo", "owner/repo", "--run-id", "r1", "--result", str(path)],
                     transport=branch)
        self.assertEqual((out["dry_run"], len(branch.commits)), (True, 1))


if __name__ == "__main__":
    unittest.main()
