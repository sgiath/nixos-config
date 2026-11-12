"""Repository routing regressions for plan-status's public JSON/error interface.

Run: python3 -I -m unittest discover -s modules/home/agents/skills/drive/scripts -p 'test_*.py' -v

primary_repo names the code checkout of a plan kept outside it. Git roots/remotes are
real temporary repositories; branch inventories, forge responses and T3 inventory
are injected at the subprocess boundary. The deploy command runs for real.
"""

import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("plan-status")
REAL_RUN = subprocess.run
TOPIC = "server-side-sessions"
SLUG = "2026-11-10-server-side-sessions"
ACTIVE_BRANCH = f"{TOPIC}/01-active"
DEPLOY_BRANCH = f"{TOPIC}/02-deploy"


class RepositoryRoutingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="drive-routing-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        self.code = self.base / "core_v2"
        self.state = self.base / "state"
        self.deploy_cwd = self.base / "deploy-cwd"
        self.environment = patch.dict(os.environ, {
            "XDG_STATE_HOME": str(self.state),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_SYSTEM": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        for root, remote, branch in (
            (self.home, "Example/home", "main"),
            (self.code, "CrazyEggInc/ce", "master"),
        ):
            REAL_RUN(["git", "init", "--quiet", "--initial-branch", branch, str(root)],
                     check=True, capture_output=True, timeout=10)
            REAL_RUN(["git", "remote", "add", "origin", f"git@github.com:{remote}.git"],
                     cwd=root, check=True, capture_output=True, timeout=10)
        # A supported home origin deliberately exposes silent fallback even if the
        # home repo eventually gains a remote (the current live home has none).
        self.git_branch_roots = []
        self.t3_projects = []
        self.forge_repos = []
        self.main = runpy.run_path(str(SCRIPT))["main"]

    def plan(self, root, *, declared=False):
        directory = root / ("plans" if root == self.home else ".agents/plans") / SLUG
        directory.mkdir(parents=True)
        command = shlex.join([
            sys.executable, "-I", "-c",
            "from pathlib import Path; "
            f"Path({str(self.deploy_cwd)!r}).write_text(str(Path.cwd()))",
        ]) + " {sha}"
        declaration = f"primary_repo: {self.code}\n" if declared else ""
        (directory / "plan.md").write_text(
            f"---\ntopic: {TOPIC}\n{declaration}"
            f"repos: [CrazyEggInc/ce]\ndeploy_check: {command}\n---\n"
        )
        for name in ("01-active", "02-deploy"):
            (directory / f"{name}.md").write_text(
                "---\nblocked_by: []\nrepos: [CrazyEggInc/ce]\n---\n"
            )
        answers = self.state / "drive/ce" / SLUG / "answers"
        answers.mkdir(parents=True, exist_ok=True)
        (answers / "01.md").write_text("No questions.\n")
        return directory

    def external_run(self, args, **kwargs):
        if isinstance(args, list) and args[:2] == ["git", "for-each-ref"]:
            root = Path(kwargs["cwd"]).resolve()
            self.git_branch_roots.append(root)
            return subprocess.CompletedProcess(args, 0, ACTIVE_BRANCH + "\n" if root == self.code else "", "")
        if isinstance(args, list) and args[:3] == ["gh", "pr", "list"]:
            repo = args[args.index("--repo") + 1]
            branch = args[args.index("--head") + 1]
            self.forge_repos.append(repo)
            prs = [{
                "number": 2, "url": "https://github.com/CrazyEggInc/ce/pull/2",
                "state": "MERGED", "headRefName": DEPLOY_BRANCH,
                "headRefOid": "a" * 40, "updatedAt": "2026-11-12T00:00:00Z",
                "mergedAt": "2026-11-12T00:00:00Z", "mergeCommit": {"oid": "b" * 40},
                "isDraft": False,
            }] if repo == "CrazyEggInc/ce" and branch == DEPLOY_BRANCH else []
            return subprocess.CompletedProcess(args, 0, json.dumps(prs), "")
        if isinstance(args, list) and args[:3] == ["t3", "thread", "list"]:
            self.t3_projects.append(Path(args[args.index("--project") + 1]))
            return subprocess.CompletedProcess(args, 0, "[]", "")
        if isinstance(args, list) and args[0] != "git":
            raise AssertionError(f"Unexpected external command: {args}")
        kwargs.setdefault("timeout", 10)
        return REAL_RUN(args, **kwargs)

    def invoke(self, directory):
        stdout, stderr = io.StringIO(), io.StringIO()
        code = 0
        with patch.object(sys, "argv", [str(SCRIPT), str(directory), "--full"]), \
                patch.object(subprocess, "run", side_effect=self.external_run), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                self.main()
            except SystemExit as error:
                code = error.code
        return code, stdout.getvalue(), stderr.getvalue()

    def assert_code_routing(self, directory):
        code, stdout, stderr = self.invoke(directory)
        self.assertEqual(code, 0, stderr)
        status = json.loads(stdout)
        expected_state = self.state / "drive/ce" / SLUG
        slices = {item["id"]: item for item in status["slices"]}
        expectations = {
            "main_repo": (status["repository"], "CrazyEggInc/ce"),
            "repos": (status["repos"], ["CrazyEggInc/ce"]),
            "state key": (Path(status["state_dir"]), expected_state),
            "existing answers": (slices["01"]["answered"], True),
            "branch cwd": (self.git_branch_roots, [self.code]),
            "branch state": (slices["01"]["state"], "in_progress"),
            "deploy cwd": (self.deploy_cwd.read_text() if self.deploy_cwd.exists() else None, str(self.code)),
            "deploy result": (slices["02"]["state"], "done"),
            "forge repos": (set(self.forge_repos), {"CrazyEggInc/ce"}),
        }
        for name, (actual, expected) in expectations.items():
            with self.subTest(contract=name):
                self.assertEqual(actual, expected)
        # Workers are threads of the T3 project that holds the plan: the code
        # repository for an in-repo plan, the home repository otherwise.
        expected_project = self.code if directory.is_relative_to(self.code) else self.home
        with self.subTest(contract="T3 project"):
            self.assertEqual(self.t3_projects, [expected_project])

    def test_home_plan_declares_primary_code_repository(self):
        self.assert_code_routing(self.plan(self.home, declared=True))

    def test_home_plan_requires_explicit_primary_repository(self):
        code, stdout, stderr = self.invoke(self.plan(self.home))
        with self.subTest(contract="exit status"):
            self.assertEqual(code, 2, "An external plan must not adopt the home repository")
        with self.subTest(contract="diagnostic"):
            self.assertRegex(stderr.lower(), r"primary[ _-]repo(?:sitory)?",
                             "Explain the missing primary repository instead of a git/forge failure")
        with self.subTest(contract="no status"):
            self.assertEqual(stdout, "")
        with self.subTest(contract="no forge requests"):
            self.assertEqual(self.forge_repos, [])

    def test_plan_inside_code_repository_keeps_existing_behavior(self):
        self.assert_code_routing(self.plan(self.code))


if __name__ == "__main__":
    unittest.main()
