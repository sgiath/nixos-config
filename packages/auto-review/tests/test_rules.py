import unittest
from copy import deepcopy

from auto_review.rules import eligibility
from auto_review.settings import RULE_DEFAULTS
from tests.fakes import change


class EligibilityTest(unittest.TestCase):
    def check(self, expected, item=None, **overrides):
        rules = {**deepcopy(RULE_DEFAULTS), **overrides}
        self.assertEqual(eligibility(item or change(), rules, "SGIATH").action, expected)

    def test_requested_review_is_eligible(self):
        self.check("review")

    def test_github_open_state_is_also_eligible(self):
        self.check("review", change(repo="github:owner/repo", state="open"))

    def test_own_change_is_never_reviewed_even_if_included(self):
        self.check("skip", change(author="sgiath"), include_authors=["SGIATH"])

    def test_excluded_author_wins_over_inclusion_case_insensitively(self):
        self.check("skip", change(author="Alice"), include_authors=["ALICE"], exclude_authors=["aLiCe"])

    def test_included_author_does_not_need_a_review_request(self):
        self.check("review", change(author="Alice", review_requested=False, reviewers=()), include_authors=["ALICE"])

    def test_unrequested_nonincluded_change_is_skipped(self):
        self.check("skip", change(review_requested=False, reviewers=()))

    def test_disabling_requested_reviews_does_not_enroll_every_author(self):
        self.check("skip", review_requested=False)

    def test_included_author_is_reviewed_when_requested_reviews_disabled(self):
        self.check("review", review_requested=False, include_authors=["ALICE"])

    def test_all_required_labels_must_be_present(self):
        self.check("skip", change(labels=("Backend",)), require_labels=["backend", "security"])
        self.check("review", change(labels=("BACKEND", "Security")), require_labels=["backend", "SECURITY"])

    def test_any_excluded_label_skips_case_insensitively(self):
        self.check("skip", change(labels=("backend", "WIP")), exclude_labels=["docs", "wip"])

    def test_draft_waits_when_skipped(self):
        self.check("wait", change(draft=True))

    def test_draft_can_be_reviewed_when_rule_disabled(self):
        self.check("review", change(draft=True), skip_drafts=False)

    def test_every_non_success_pipeline_waits(self):
        for pipeline in ("none", "running", "failed"):
            with self.subTest(pipeline=pipeline):
                self.check("wait", change(pipeline=pipeline))

    def test_pipeline_can_be_ignored(self):
        self.check("review", change(pipeline="failed"), wait_for_pipeline=False)

    def test_closed_and_merged_are_skipped_before_draft_checks(self):
        for state in ("closed", "merged"):
            with self.subTest(state=state):
                self.check("skip", change(state=state, draft=True), include_authors=["alice"])
