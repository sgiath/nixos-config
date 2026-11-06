"""Score-based review states; forge writes are recorded locally, never sent."""

import unittest
from unittest.mock import patch

from auto_review.forge.gitlab import GitLab
from auto_review.models import Note, Thread
from auto_review.settings import SettingsError, apply_patch, effective, repo_view, validate
from tests.engine_case import EngineCase
from tests.fakes import REPO, change, configuration, raw_finding


class RequestChangesSettingsTest(unittest.TestCase):
    def test_default_is_thirty(self):
        settings = effective(configuration("/unused"), {})
        self.assertEqual(settings.get("request_changes_threshold"), 30)
        self.assertEqual(repo_view(settings, REPO).get("request_changes_threshold"), 30)

    def test_null_repo_override_inherits_global(self):
        defaults = configuration("/unused", request_changes_threshold=40)
        defaults["repos"][REPO]["request_changes_threshold"] = None
        settings = effective(defaults, {"request_changes_threshold": 35})
        self.assertEqual(repo_view(settings, REPO)["request_changes_threshold"], 35)

    def test_repo_override_wins_and_null_patch_restores_inheritance(self):
        defaults = configuration("/unused", request_changes_threshold=40)
        overrides = {"repos": {REPO: {"request_changes_threshold": 20}}}
        self.assertEqual(repo_view(effective(defaults, overrides), REPO)["request_changes_threshold"], 20)
        overrides = apply_patch(overrides, {"repos": {REPO: {"request_changes_threshold": None}}}, defaults)
        self.assertEqual(repo_view(effective(defaults, overrides), REPO).get("request_changes_threshold"), 40)

    def test_global_threshold_requires_positive_integer(self):
        for value in (0, -1, True, 1.5, "30", None):
            with self.subTest(value=value):
                settings = effective(configuration("/unused"), {})
                settings["request_changes_threshold"] = value
                with self.assertRaises(SettingsError) as error:
                    validate(settings)
                self.assertEqual(error.exception.field, "request_changes_threshold")

    def test_repo_threshold_requires_positive_integer_or_null(self):
        settings = effective(configuration("/unused"), {})
        settings["repos"][REPO]["request_changes_threshold"] = None
        validate(settings)
        for value in (0, -1, True, 1.5, "30"):
            with self.subTest(value=value):
                settings["repos"][REPO]["request_changes_threshold"] = value
                with self.assertRaises(SettingsError) as error:
                    validate(settings)
                self.assertEqual(error.exception.field, f"repos.{REPO}.request_changes_threshold")


class GitLabReviewStateTest(unittest.TestCase):
    def test_request_changes_sets_state_without_summary_or_drafts(self):
        forge, item = GitLab(), change()
        with patch.object(forge, "_get_all", return_value=[]) as get, patch.object(forge, "_post") as post:
            forge.request_changes("team/service", item)
        get.assert_called_once_with("projects/team%2Fservice/merge_requests/7/draft_notes")
        post.assert_called_once_with("projects/team%2Fservice/merge_requests/7/draft_notes/bulk_publish",
                                     {"reviewer_state": "requested_changes"})

    def test_mark_reviewed_keeps_reviewed_state(self):
        forge = GitLab()
        with patch.object(forge, "_get_all", return_value=[]), patch.object(forge, "_post") as post:
            forge.mark_reviewed("team/service", change())
        post.assert_called_once_with("projects/team%2Fservice/merge_requests/7/draft_notes/bulk_publish",
                                     {"reviewer_state": "reviewed"})

    def test_request_changes_does_not_publish_personal_drafts(self):
        forge = GitLab()
        with patch.object(forge, "_get_all", return_value=[{"id": 99}]), patch.object(forge, "_post") as post:
            forge.request_changes("team/service", change())
        post.assert_not_called()


class RequestChangesPublishingTest(EngineCase):
    def setUp(self):
        super().setUp()
        # Supply the new setting independently of defaults to isolate the publisher contract.
        self.config["request_changes_threshold"] = 30
        self.config["repos"][REPO]["request_changes_threshold"] = None

    def test_posted_score_thirty_requests_changes_instead_of_marking_reviewed(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6)])
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        self.assertEqual(len(self.forge.change_requests), 1, "posted score 30 must request changes")
        self.assertEqual(self.forge.marked, [])
        self.assertEqual(self.forge.approvals, [])
        self.assertLess(next(i for i, e in enumerate(self.journal) if e[0] == "post"),
                        next(i for i, e in enumerate(self.journal) if e[0] == "request_changes"))

    def test_already_open_score_thirty_requests_changes_without_new_comment(self):
        review_id = self.start()
        self.forge.discussions[("team/service", 7)] = [Thread("existing", False, (Note("alice", "Bug", "n1"),))]
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6, existing_thread_id="existing")])
        self.assertEqual(self.states(review_id), {"SR-1": "already_open"})
        self.assertEqual(self.forge.posts, [])
        self.assertEqual(len(self.forge.change_requests), 1, "open score 30 must request changes")
        self.assertEqual(self.forge.marked, [])

    def test_posted_score_below_thirty_marks_reviewed(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=1, severity=5)])
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(len(self.forge.marked), 1)

    def test_repo_request_threshold_overrides_global(self):
        self.config["repos"][REPO]["request_changes_threshold"] = 20
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=4, severity=5)])
        self.assertEqual(len(self.forge.change_requests), 1, "repo threshold 20 must override global 30")
        self.assertEqual(self.forge.marked, [])

    def test_below_comment_threshold_does_not_request_changes(self):
        self.config["threshold"] = 40
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6)])
        self.assertEqual(self.states(review_id), {"SR-1": "below"})
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(self.forge.marked, [])

    def test_already_resolved_high_finding_does_not_request_changes(self):
        review_id = self.start()
        self.forge.discussions[("team/service", 7)] = [Thread("existing", True, (Note("alice", "Fixed", "n1"),))]
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6, existing_thread_id="existing"),
                                         raw_finding(id="SR-2")])
        self.assertEqual(self.states(review_id), {"SR-1": "already_resolved", "SR-2": "posted"})
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(len(self.forge.marked), 1)

    def test_unanchored_high_finding_does_not_request_changes(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6, line=999), raw_finding(id="SR-2")])
        self.assertEqual(self.states(review_id), {"SR-1": "unanchored", "SR-2": "posted"})
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(len(self.forge.marked), 1)

    def test_dry_run_high_finding_reports_intent_without_forge_writes(self):
        self.config["dry_run"] = True
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6)])
        self.assertEqual(self.states(review_id), {"SR-1": "would_post"})
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(self.forge.marked, [])
        self.assertEqual(self.forge.posts, [])
        self.assertEqual(self.forge.approvals, [])
        # Completion notes are persisted events, not notifications for a normal finding.
        events = [e["message"].lower() for e in self.store.events(review_id=review_id)]
        self.assertTrue(any("would" in e and "request changes" in e for e in events),
                        "dry-run done note must say it would request changes")

    def test_moved_head_holds_high_finding_without_requesting_changes(self):
        review_id = self.start()
        self.forge.add(change(head_sha="c" * 40))
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6)])
        self.assertEqual(self.states(review_id), {"SR-1": "not_posted"})
        self.assertEqual(self.forge.change_requests, [])
        self.assertEqual(self.forge.marked, [])
        self.assertEqual(self.forge.posts, [])

    def test_marker_recovery_requests_changes_without_duplicate_comment(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.complete(review_id, findings=[raw_finding(frequency=5, severity=6)])
        self.until(lambda: bool(self.forge.post_attempts), "post should be attempted")
        self.until(lambda: self.row(review_id)["status"] == "done", "marker should recover accepted comment")
        self.assertEqual(len(self.forge.posts), 1)
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        self.assertEqual(len(self.forge.change_requests), 1, "recovered high finding must request changes")
        self.assertEqual(self.forge.marked, [])
