import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from auto_review.settings import SettingsError, SettingsFile, apply_patch, effective, repo_view, validate
from tests.fakes import REPO, configuration


class SettingsTest(unittest.TestCase):
    def test_empty_configuration_uses_threshold_five(self):
        self.assertEqual(effective({}, {})["threshold"], 5)

    def test_overrides_win_per_field_and_preserve_siblings(self):
        result = effective({"threshold": 7, "reviewer": {"model": "nix-model", "effort": "high"}},
                           {"threshold": 9, "reviewer": {"effort": "xhigh"}})
        self.assertEqual(result["threshold"], 9)
        self.assertEqual(result["reviewer"]["model"], "nix-model")
        self.assertEqual(result["reviewer"]["effort"], "xhigh")

    def test_repo_threshold_and_reviewer_resolve_against_globals(self):
        defaults = configuration("/unused", threshold=8)
        defaults["repos"][REPO]["threshold"] = 5
        result = effective(defaults, {})
        view = repo_view(result, REPO)
        self.assertEqual(view["threshold"], 5)
        self.assertEqual(view["reviewer"], result["reviewer"])

    def test_null_repo_threshold_inherits_global(self):
        result = effective(configuration("/unused", threshold=8), {})
        self.assertEqual(repo_view(result, REPO)["threshold"], 8)

    def test_repos_merge_by_id_and_fill_rules_and_identity(self):
        defaults = configuration("/unused")
        overrides = {"repos": {
            REPO: {"context": "UI context", "rules": {"skip_drafts": False}},
            "github:owner/other": {"forge": "github", "path": "owner/other", "checkout": "/other",
                                   "t3_project": "project-other"},
        }}
        result = effective(defaults, overrides)
        self.assertEqual(set(result["repos"]), {REPO, "github:owner/other"})
        repo = result["repos"][REPO]
        self.assertEqual((repo["forge"], repo["path"], repo["checkout"]), ("gitlab", "team/service", "/unused"))
        self.assertEqual(repo["context"], "UI context")
        self.assertFalse(repo["rules"]["skip_drafts"])
        self.assertTrue(repo["rules"]["wait_for_pipeline"])

    def test_patch_null_removes_only_that_override(self):
        defaults = configuration("/unused", threshold=7)
        overrides = {"threshold": 9, "reviewer": {"effort": "xhigh", "model": "ui-model"}}
        result = apply_patch(overrides, {"threshold": None, "reviewer": {"effort": None}}, defaults)
        self.assertNotIn("threshold", result)
        self.assertEqual(result["reviewer"], {"model": "ui-model"})
        self.assertEqual(effective(defaults, result)["threshold"], 7)
        self.assertEqual(overrides["threshold"], 9, "patch must not mutate the caller's overrides")

    def test_null_nix_repo_resets_overrides_without_deleting_repo(self):
        defaults = configuration("/unused")
        overrides = {"repos": {REPO: {"enabled": False, "threshold": 9}}}
        result = apply_patch(overrides, {"repos": {REPO: None}}, defaults)
        repo = effective(defaults, result)["repos"][REPO]
        self.assertTrue(repo["enabled"])
        self.assertIsNone(repo["threshold"])

    def test_null_ui_repo_removes_it(self):
        extra = "github:owner/extra"
        overrides = {"repos": {extra: {"forge": "github", "path": "owner/extra",
                                      "checkout": "/extra", "t3_project": "p"}}}
        result = apply_patch(overrides, {"repos": {extra: None}}, configuration("/unused"))
        self.assertNotIn(extra, effective(configuration("/unused"), result)["repos"])

    def test_invalid_values_name_the_dotted_field(self):
        cases = [
            ("threshold", 0), ("threshold", True),
            ("poll_interval_seconds", 14), ("max_concurrent", 0),
            ("max_launches_per_day", -1), ("review_timeout_minutes", 0),
            ("timezone", "No/SuchZone"), ("quiet_hours.start", "25:00"),
            (f"repos.{REPO}.threshold", 0), (f"repos.{REPO}.approval", "always"),
            (f"repos.{REPO}.rules.include_authors", "alice"),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                settings = configuration("/unused")
                if field.startswith("repos."):
                    target = settings["repos"][REPO]
                    parts = field.removeprefix(f"repos.{REPO}.").split(".")
                else:
                    target, parts = settings, field.split(".")
                for part in parts[:-1]:
                    target = target[part]
                target[parts[-1]] = value
                with self.assertRaises(SettingsError) as error:
                    validate(settings)
                self.assertEqual(error.exception.field, field)

    def test_patch_validates_before_returning_overrides(self):
        with self.assertRaises(SettingsError) as error:
            apply_patch({}, {"threshold": 0}, configuration("/unused"))
        self.assertEqual(error.exception.field, "threshold")


class SettingsFileTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.defaults_path = self.root / "defaults.json"
        self.overrides_path = self.root / "overrides.json"
        self.defaults_path.write_text(json.dumps(configuration(self.root, threshold=7)))
        self.overrides_path.write_text('{"paused": true}')
        self.file = SettingsFile(self.defaults_path, self.overrides_path)

    def test_get_and_patch_preserve_defaults_and_write_only_overrides(self):
        original = self.defaults_path.read_bytes()
        self.assertTrue(self.file.get()["paused"])
        result = self.file.patch({"threshold": 9})
        self.assertEqual(result["threshold"], 9)
        self.assertEqual(self.file.overrides(), {"paused": True, "threshold": 9})
        self.assertEqual(json.loads(self.overrides_path.read_text()), self.file.overrides())
        self.assertEqual(self.defaults_path.read_bytes(), original)
        self.assertEqual(self.file.defaults()["threshold"], 7)

    def test_patch_publishes_complete_json_by_atomic_same_directory_rename(self):
        observed = []
        real_replace, real_rename = os.replace, os.rename

        def observe(operation, source, destination, *args, **kwargs):
            if Path(destination) == self.overrides_path:
                self.assertNotEqual(Path(source), self.overrides_path)
                self.assertEqual(Path(source).parent, self.overrides_path.parent)
                self.assertEqual(json.loads(Path(source).read_text()), {"paused": True, "threshold": 9})
                self.assertEqual(json.loads(self.overrides_path.read_text()), {"paused": True})
                observed.append(True)
            return operation(source, destination, *args, **kwargs)

        with patch("os.replace", side_effect=lambda *a, **k: observe(real_replace, *a, **k)), \
             patch("os.rename", side_effect=lambda *a, **k: observe(real_rename, *a, **k)):
            self.file.patch({"threshold": 9})
        self.assertEqual(observed, [True])
        self.assertEqual(SettingsFile(self.defaults_path, self.overrides_path).get()["threshold"], 9)

    def test_failed_atomic_publish_preserves_prior_file(self):
        original = self.overrides_path.read_bytes()
        with patch("os.replace", side_effect=OSError("disk failure")), \
             patch("os.rename", side_effect=OSError("disk failure")):
            with self.assertRaises(OSError):
                self.file.patch({"threshold": 9})
        self.assertEqual(self.overrides_path.read_bytes(), original)
        self.assertEqual(SettingsFile(self.defaults_path, self.overrides_path).get()["threshold"], 7)

    def test_invalid_patch_leaves_file_unchanged(self):
        original = self.overrides_path.read_bytes()
        with self.assertRaises(SettingsError):
            self.file.patch({"threshold": 0})
        self.assertEqual(self.overrides_path.read_bytes(), original)
