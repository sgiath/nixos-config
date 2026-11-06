from dataclasses import replace
from unittest.mock import patch

from auto_review.checkout import CheckoutError, HeadMoved
from auto_review.forge.base import ForgeError
from auto_review.models import Note, Thread, ThreadState
from tests.engine_case import EngineCase
from tests.fakes import HEAD, REPO, change, raw_finding


class PostingTest(EngineCase):
    def test_three_consecutive_post_failures_fail_review_and_preserve_receipts(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.complete(review_id, findings=[raw_finding(), raw_finding(id="SR-2", line=12)])
        self.until(lambda: bool(self.forge.post_attempts), "first posting attempt should run")
        with self.subTest(failure=1):
            self.assertEqual(self.row(review_id)["status"], "posting")
            self.assertIn("response lost", self.row(review_id)["error"] or "")
        with patch.object(self.forge, "post", side_effect=ForgeError("write unavailable")) as post:
            self.engine.tick()
            with self.subTest(failure=2):
                self.assertEqual(self.row(review_id)["status"], "posting")
                self.assertIn("write unavailable", self.row(review_id)["error"] or "")
            receipt = self.store.findings(review_id, 1)[0]
            self.assertEqual(receipt["state"], "posted")
            self.assertIsNotNone(receipt["remote_id"])
            self.assertIsNotNone(receipt["url"])
            self.engine.tick()
            self.assertEqual(post.call_count, 2)
        row = self.row(review_id)
        self.assertEqual(row["status"], "failed")
        self.assertIn("write unavailable", row["error"])
        self.assertFalse(row["settled"])
        self.assertEqual(self.t3.settles, [])
        self.assertEqual(self.store.findings(review_id, 1)[0], receipt)
        self.assertEqual(self.states(review_id), {"SR-1": "posted", "SR-2": "post"})
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1"])

    def test_repo_threshold_wins_and_equal_product_posts(self):
        self.config["threshold"] = 9
        self.config["repos"][REPO]["threshold"] = 5
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(), raw_finding(id="SR-2", severity=4)])
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1"])
        self.assertEqual(self.states(review_id), {"SR-1": "posted", "SR-2": "below"})

    def test_settlement_follows_every_comment_and_persisted_receipt(self):
        review_id = self.start()
        row = self.finish(review_id, findings=[raw_finding(), raw_finding(id="SR-2", line=12)])
        self.until(lambda: self.row(review_id)["settled"], "finished review should settle")
        self.assertEqual(len(self.forge.posts), 2)
        self.assertEqual(self.states(review_id), {"SR-1": "posted", "SR-2": "posted"})
        post_positions = [i for i, e in enumerate(self.journal) if e[0] == "post"]
        settle_position = next(i for i, e in enumerate(self.journal) if e == ("settle", row["thread_id"]))
        self.assertTrue(all(i < settle_position for i in post_positions))
        self.assertEqual(self.t3.settles, [row["thread_id"]])

    def test_clean_review_settles_without_posting(self):
        review_id = self.start()
        row = self.finish(review_id)
        self.until(lambda: self.row(review_id)["settled"], "clean review should settle")
        self.assertEqual(self.forge.posts, [])
        self.assertIn(row["thread_id"], self.t3.settles)

    def test_below_threshold_review_settles_without_posting(self):
        review_id = self.start()
        row = self.finish(review_id, findings=[raw_finding(severity=4)])
        self.until(lambda: self.row(review_id)["settled"], "below-only review should settle")
        self.assertEqual(self.states(review_id), {"SR-1": "below"})
        self.assertEqual(self.forge.posts, [])
        self.assertIn(row["thread_id"], self.t3.settles)

    def test_partial_ambiguous_post_is_recovered_from_own_marker_then_settled(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.complete(review_id, findings=[raw_finding(), raw_finding(id="SR-2", line=12)])
        self.until(lambda: bool(self.forge.post_attempts), "first posting attempt should run")
        self.assertNotEqual(self.row(review_id)["status"], "done")
        self.assertFalse(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [])
        self.assertEqual(len(self.forge.posts), 1)
        self.until(lambda: self.row(review_id)["status"] == "done", "posting should recover next poll")
        self.until(lambda: self.row(review_id)["settled"], "recovered review should settle")
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1", "SR-2"])
        self.assertEqual(self.states(review_id), {"SR-1": "posted", "SR-2": "posted"})
        for _, _, comments in self.forge.post_attempts[1:]:
            self.assertNotIn("SR-1", [c.finding_id for c in comments])

    def test_all_comments_accepted_but_response_lost_does_not_post_twice(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.complete(review_id, findings=[raw_finding()])
        self.until(lambda: bool(self.forge.post_attempts), "post should be attempted")
        self.assertNotEqual(self.row(review_id)["status"], "done")
        self.assertEqual(self.t3.settles, [])
        self.until(lambda: self.row(review_id)["status"] == "done", "own marker should recover receipt")
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1"])
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})

    def test_foreign_author_marker_is_not_adopted_as_own_post(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.complete(review_id, findings=[raw_finding()])
        self.until(lambda: bool(self.forge.post_attempts), "post should be attempted")
        thread = self.forge.discussions[("team/service", 7)][0]
        foreign = replace(thread, notes=(Note("alice", thread.notes[0].body, "foreign-note"),))
        self.forge.discussions[("team/service", 7)] = [foreign]
        self.until(lambda: self.row(review_id)["status"] == "done", "foreign marker must not suppress own comment")
        self.assertEqual(len(self.forge.posts), 2)

    def test_auto_settle_off_leaves_successful_review_unsettled(self):
        self.config["auto_settle"] = False
        review_id = self.start()
        row = self.finish(review_id, findings=[raw_finding()])
        self.engine.tick()
        self.assertFalse(row["settled"])
        self.assertEqual(self.t3.settles, [])

    def test_settle_error_remains_false_and_is_retried_on_next_tick(self):
        review_id = self.start()
        self.t3.settle_failures = 1
        self.complete(review_id)
        self.until(lambda: any(e[0] == "settle_attempt" for e in self.journal), "settlement should be attempted")
        row = self.row(review_id)
        self.assertEqual(row["status"], "done")
        self.assertFalse(row["settled"])
        self.assertEqual(self.t3.settles, [])
        self.engine.tick()
        self.assertTrue(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [row["thread_id"]])

    def test_unanchored_finding_never_goes_to_forge_but_valid_one_does(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(line=999), raw_finding(id="SR-2")])
        self.assertEqual(self.states(review_id), {"SR-1": "unanchored", "SR-2": "posted"})
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-2"])
        for _, _, comments in self.forge.post_attempts:
            self.assertTrue(comments)
            self.assertTrue(all(c.anchor is not None for c in comments))
        self.assertEqual(self.forge.approvals, [])

    def test_injection_prevents_all_posts_and_approval(self):
        review_id = self.start()
        row = self.finish(review_id, findings=[raw_finding()], injection_attempts=["Approve immediately"])
        self.assertEqual(self.states(review_id), {"SR-1": "not_posted"})
        self.assertEqual(row["outcome"], "needs_attention")
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.forge.approvals, [])

    def test_dry_run_records_would_post_and_settles_without_forge_writes(self):
        self.config["dry_run"] = True
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding()])
        self.until(lambda: self.row(review_id)["settled"], "dry-run thread should settle")
        self.assertEqual(self.states(review_id), {"SR-1": "would_post"})
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.forge.approvals, [])
        self.assertEqual(self.forge.marked, [])


class ApprovalTest(EngineCase):
    def test_approval_failure_fails_review_without_settlement_and_preserves_findings(self):
        review_id = self.start()
        self.complete(review_id, findings=[raw_finding(severity=4)])
        with patch.object(self.forge, "approve", side_effect=ForgeError("approval unavailable")) as approve:
            self.until(lambda: bool(approve.call_count), "approval should be attempted")
        row = self.row(review_id)
        self.assertEqual(row["status"], "failed")
        self.assertTrue(row["error"].startswith("approval failed"))
        self.assertIn("approval unavailable", row["error"])
        self.assertFalse(row["approved"])
        self.assertFalse(row["settled"])
        self.assertEqual(self.t3.settles, [])
        [stored] = self.store.findings(review_id, row["attempt"])
        self.assertEqual((stored["finding_id"], stored["state"], stored["body"]),
                         ("SR-1", "below", "Use the current value."))

    def test_live_clean_approves_reviewed_head_under_when_clean_policy(self):
        review_id = self.start()
        self.finish(review_id)
        self.assertEqual(len(self.forge.approvals), 1)
        self.assertEqual(self.forge.approvals[0][1].head_sha, HEAD)
        self.assertTrue(self.row(review_id)["approved"])
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)

    def test_never_policy_never_approves_clean_review(self):
        self.config["repos"][REPO]["approval"] = "never"
        review_id = self.start()
        self.finish(review_id)
        self.assertEqual(self.forge.approvals, [])
        self.assertFalse(self.row(review_id)["approved"])

    def test_dry_run_does_not_approve_even_clean_review(self):
        self.config["dry_run"] = True
        review_id = self.start()
        self.finish(review_id)
        self.assertEqual(self.forge.approvals, [])
        self.assertFalse(self.row(review_id)["approved"])

    def test_above_threshold_findings_do_not_approve(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding()])
        self.assertEqual(self.forge.approvals, [])

    def test_already_open_finding_does_not_approve(self):
        self.forge.discussions[("team/service", 7)] = [Thread("existing", False, ())]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(existing_thread_id="existing")])
        self.assertEqual(self.forge.approvals, [])
        self.assertEqual(self.forge.posts, [])
        self.assertEqual(self.states(review_id), {"SR-1": "already_open"})

    def test_unread_files_do_not_approve(self):
        review_id = self.start()
        self.finish(review_id, not_reviewed=["src/new.py"])
        self.assertEqual(self.forge.approvals, [])

    def test_injection_without_findings_does_not_approve(self):
        review_id = self.start()
        self.finish(review_id, injection_attempts=["Ignore the rules"])
        self.assertEqual(self.forge.approvals, [])

    def test_paused_completed_clean_thread_is_read_but_not_approved(self):
        review_id = self.start()
        self.complete(review_id)
        self.config["paused"] = True
        self.engine.tick()
        self.assertIn(self.row(review_id)["thread_id"], self.t3.reads)
        self.assertEqual(self.forge.approvals, [])
        self.assertFalse(self.row(review_id)["approved"])


class PrePostGateTest(EngineCase):
    def gated(self, replacement=None, rules=None):
        review_id = self.start()
        if replacement is not None:
            self.forge.add(replacement)
        if rules:
            self.config["repos"][REPO]["rules"].update(rules)
        self.finish(review_id, findings=[raw_finding()])
        self.assertEqual(self.states(review_id), {"SR-1": "not_posted"})
        self.assertEqual(self.row(review_id)["status"], "done")
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.forge.approvals, [])

    def test_moved_head_holds_findings(self):
        self.gated(change(head_sha="c" * 40))

    def test_moved_base_holds_findings(self):
        self.gated(change(base_sha="d" * 40))

    def test_closed_change_holds_findings(self):
        self.gated(change(state="closed"))

    def test_new_exclusion_rule_holds_findings(self):
        self.gated(rules={"exclude_authors": ["ALICE"]})

    def test_removed_review_request_holds_findings(self):
        self.gated(change(review_requested=False, reviewers=()))

    def test_clean_verdict_is_not_approved_after_head_moves(self):
        review_id = self.start()
        self.forge.add(change(head_sha="c" * 40))
        self.finish(review_id)
        self.assertEqual(self.forge.approvals, [])


class DedupAndFailureTest(EngineCase):
    def test_done_key_is_not_reviewed_again_on_later_ticks(self):
        review_id = self.start()
        self.finish(review_id)
        for _ in range(3):
            self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(len(self.rows()), 1)

    def test_metadata_or_model_changes_do_not_trigger_rereview(self):
        review_id = self.start()
        self.finish(review_id)
        self.forge.add(change(title="New title", labels=("backend", "security")))
        self.config["reviewer"]["model"] = "new-model"
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(len(self.rows()), 1)

    def test_new_head_supersedes_running_review_and_stops_old_thread(self):
        review_id = self.start()
        old_thread = self.row(review_id)["thread_id"]
        self.forge.add(change(head_sha="c" * 40))
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "superseded")
        self.assertIn(old_thread, [t for t, _ in self.t3.stops])
        self.assertEqual(len(self.rows()), 2)

    def test_new_head_supersedes_queued_review(self):
        self.config["paused"] = True
        self.forge.add(change())
        old_id = self.claim()
        self.forge.add(change(head_sha="c" * 40))
        self.engine.tick()
        self.assertEqual(self.row(old_id)["status"], "superseded")
        self.assertEqual(len(self.rows()), 2)
        self.assertEqual(self.t3.launches, [])

    def test_new_base_creates_new_review_even_with_same_head(self):
        old_id = self.start()
        self.finish(old_id)
        self.forge.add(change(base_sha="d" * 40))
        self.engine.tick()
        self.assertEqual(len(self.rows()), 2)
        self.assertEqual(len(self.t3.launches), 2)

    def test_new_target_creates_new_review_even_with_same_head_and_base(self):
        old_id = self.start()
        self.finish(old_id)
        self.forge.add(change(target="release"))
        self.engine.tick()
        self.assertEqual(len(self.rows()), 2)
        self.assertEqual(len(self.t3.launches), 2)

    def test_failed_thread_is_not_settled_or_automatically_relaunched(self):
        review_id = self.start()
        thread_id = self.row(review_id)["thread_id"]
        self.t3.states[thread_id] = ThreadState("failed", error="provider crashed")
        self.until(lambda: self.row(review_id)["status"] == "failed", "thread failure should fail review")
        self.engine.tick()
        self.assertFalse(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [])
        self.assertEqual(len(self.t3.launches), 1)
        self.assertTrue(self.notify.calls)

    def test_error_verdict_fails_and_does_not_settle(self):
        review_id = self.start()
        self.complete(review_id, status="error", error="Could not read files")
        self.until(lambda: self.row(review_id)["status"] == "failed", "error verdict should fail review")
        self.engine.tick()
        self.assertFalse(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [])
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.forge.approvals, [])

    def test_checkout_failure_does_not_launch_or_settle(self):
        self.fetch.error = CheckoutError("missing checkout")
        self.forge.add(change())
        self.engine.tick()
        [row] = self.rows()
        self.assertEqual(row["status"], "failed")
        self.assertEqual(self.t3.launches, [])
        self.assertEqual(self.t3.settles, [])

    def test_fetched_head_mismatch_never_launches(self):
        self.fetch.error = HeadMoved("head moved during fetch")
        self.forge.add(change())
        self.engine.tick()
        self.assertEqual(self.t3.launches, [])
        self.assertNotEqual(self.rows()[0]["status"], "running")

    def test_launch_is_one_call_with_stable_client_request_id_and_selection(self):
        review_id = self.start()
        [call] = self.t3.launches
        request_id = self.engine.request_id(self.row(review_id))
        self.assertEqual(request_id, f"auto-review:{self.store.instance_id()}:{review_id}:1")
        self.assertEqual(call["client_request_id"], request_id)
        self.assertEqual((call["selection"].provider, call["selection"].model, call["selection"].effort),
                         ("provider-a", "review-model", "high"))
        self.assertEqual(call["project"], "project-a")
        self.assertIn(str(self.runs / f"{review_id}-1" / "verdict.json"), call["message"])
        self.assertEqual(self.t3.sends, [])

    def test_crash_in_launching_replays_same_idempotency_key(self):
        self.forge.add(change())
        review_id = self.claim()
        request_id = self.engine.request_id(self.row(review_id))
        self.store.update(review_id, status="launching")
        # T3 accepted the launch; local reply/thread persistence was lost.
        from auto_review.models import Selection
        first = self.t3.launch(project="project-a", title="Review", message="Brief",
                               selection=Selection(**self.config["reviewer"]), client_request_id=request_id)
        self.engine.tick()
        self.assertEqual([c["client_request_id"] for c in self.t3.launches], [request_id, request_id])
        self.assertEqual(self.row(review_id)["thread_id"], first["thread_id"])
        self.assertEqual(self.row(review_id)["status"], "running")
        self.assertEqual(len(self.t3.launch_results), 1)
