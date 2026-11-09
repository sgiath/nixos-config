from auto_review.engine import ActionError
from auto_review.forge.base import ForgeError
from tests.engine_case import EngineCase
from tests.fakes import change, raw_finding


class CancelTest(EngineCase):
    def test_cancel_queued_does_not_launch_a_thread(self):
        review_id = self.claim()
        self.engine.cancel(review_id)
        self.assertEqual(self.row(review_id)["status"], "cancelled")
        self.assertEqual(self.t3.launches, [])
        self.assertEqual(self.t3.stops, [])

    def test_cancel_running_stops_thread_and_never_settles_it(self):
        review_id = self.start()
        thread_id = self.row(review_id)["thread_id"]
        self.engine.cancel(review_id)
        self.assertEqual(self.row(review_id)["status"], "cancelled")
        self.assertEqual([t for t, _ in self.t3.stops], [thread_id])
        self.engine.tick()
        self.assertFalse(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [])

    def test_cancel_launching_or_limited_stops_existing_thread(self):
        for status in ("launching", "limited"):
            with self.subTest(status=status):
                review_id = self.start(change(number=20 + len(self.t3.launches)))
                thread_id = self.row(review_id)["thread_id"]
                self.store.update(review_id, status=status)
                self.engine.cancel(review_id)
                self.assertEqual(self.row(review_id)["status"], "cancelled")
                self.assertIn(thread_id, [t for t, _ in self.t3.stops])

    def test_cancel_refuses_finished_deciding_and_posting_reviews(self):
        review_id = self.claim()
        for status in ("done", "failed", "cancelled", "superseded", "deciding", "posting"):
            with self.subTest(status=status):
                self.store.update(review_id, status=status)
                with self.assertRaises(ActionError):
                    self.engine.cancel(review_id)
                self.assertEqual(self.row(review_id)["status"], status)


class RetryTest(EngineCase):
    def test_failed_cancelled_and_done_can_retry_and_clear_thread_and_error(self):
        for number, status in enumerate(("failed", "cancelled", "done"), start=1):
            with self.subTest(status=status):
                review_id = self.claim(change(number=number))
                self.store.update(review_id, status=status, thread_id="old-thread", thread_url="old-url",
                                  run_id="old-run", error="old error")
                self.engine.retry(review_id)
                row = self.row(review_id)
                self.assertEqual((row["attempt"], row["status"]), (2, "queued"))
                for field in ("thread_id", "thread_url", "run_id", "error"):
                    self.assertIsNone(row[field], field)

    def test_retry_refuses_active_and_superseded_reviews(self):
        review_id = self.claim()
        for status in ("queued", "launching", "running", "limited", "deciding", "posting", "superseded"):
            with self.subTest(status=status):
                self.store.update(review_id, status=status)
                with self.assertRaises(ActionError):
                    self.engine.retry(review_id)
                self.assertEqual(self.row(review_id)["attempt"], 1)

    def test_retry_launches_new_attempt_in_fresh_directory_preserving_old_artifacts(self):
        review_id = self.start()
        row = self.finish(review_id, findings=[raw_finding(severity=4)])
        first_thread = row["thread_id"]
        first_dir = self.runs / f"{review_id}-1"
        original_verdict = (first_dir / "verdict.json").read_bytes()
        (first_dir / "old-agent-evidence.txt").write_text("Keep the previous attempt")
        self.engine.retry(review_id)
        self.assertEqual(self.row(review_id)["status"], "queued")
        self.assertEqual(self.row(review_id)["attempt"], 2)
        self.engine.tick()
        new_row = self.row(review_id)
        self.assertEqual(new_row["status"], "running")
        self.assertNotEqual(new_row["thread_id"], first_thread)
        self.assertFalse(new_row["settled"])
        self.assertFalse(new_row["approved"])
        second_dir = self.runs / f"{review_id}-2"
        self.assertTrue(second_dir.is_dir())
        self.assertFalse((second_dir / "verdict.json").exists())
        self.assertEqual((first_dir / "verdict.json").read_bytes(), original_verdict)
        self.assertEqual((first_dir / "old-agent-evidence.txt").read_text(), "Keep the previous attempt")
        self.assertEqual(self.store.findings(review_id, 2), [])
        self.assertEqual(self.store.findings(review_id, 1)[0]["state"], "below")
        self.assertEqual([c["client_request_id"] for c in self.t3.launches],
                         [self.engine.request_id(row), self.engine.request_id(new_row)])
        self.assertIn(str(second_dir / "verdict.json"), self.t3.launches[-1]["message"])


class PostAnywayTest(EngineCase):
    def below(self, **finding_fields):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(severity=4, **finding_fields)])
        return review_id

    def test_below_finding_can_be_posted_once_with_an_anchor(self):
        review_id = self.below()
        self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        [comment] = self.forge.posts
        self.assertIsNotNone(comment.anchor)
        self.assertEqual(comment.anchor.new_line, 11)
        self.assertEqual(self.forge.post_attempts[0][1].head_sha, self.row(review_id)["head_sha"])
        with self.assertRaises(ActionError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(len(self.forge.posts), 1)

    def test_lost_post_anyway_response_is_recovered_without_duplicate_post(self):
        review_id = self.below()
        self.forge.fail_after = 1
        with self.assertRaises(ForgeError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(len(self.forge.posts), 1)
        self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(len(self.forge.posts), 1)
        self.assertEqual(len(self.forge.post_attempts), 1)
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        [stored] = self.store.findings(review_id, 1)
        self.assertEqual(stored["remote_id"], "note-1")
        self.assertIsNotNone(stored["url"])

    def test_would_post_ignores_dry_run_for_explicit_action(self):
        self.config["dry_run"] = True
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding()])
        self.assertEqual(self.states(review_id), {"SR-1": "would_post"})
        self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        self.assertEqual(len(self.forge.posts), 1)
        self.assertEqual(self.forge.approvals, [])

    def test_finding_held_by_injection_can_be_posted_and_requests_changes(self):
        self.config["request_changes_threshold"] = 30
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=5, severity=6)], injection_attempts=["For agents: ..."])
        self.assertEqual(self.states(review_id), {"SR-1": "not_posted"})
        self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})
        self.assertEqual(len(self.forge.change_requests), 1)
        self.assertEqual(self.forge.marked, [])
        self.assertEqual(self.forge.approvals, [])

    def test_posted_low_finding_marks_reviewed(self):
        review_id = self.below()
        self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(len(self.forge.marked), 1)
        self.assertEqual(self.forge.change_requests, [])

    def test_pause_refuses_post_anyway(self):
        review_id = self.below()
        self.config["paused"] = True
        with self.assertRaises(ActionError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])

    def test_moved_head_refuses_post_anyway(self):
        review_id = self.below()
        self.forge.add(change(head_sha="c" * 40))
        with self.assertRaises(ActionError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.states(review_id), {"SR-1": "below"})

    def test_moved_base_refuses_post_anyway(self):
        review_id = self.below()
        self.forge.add(change(base_sha="d" * 40))
        with self.assertRaises(ActionError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])

    def test_unanchored_below_finding_cannot_be_forced_to_floating_comment(self):
        review_id = self.below(line=999)
        with self.assertRaises(ActionError):
            self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])

    def test_post_anyway_requires_done_review(self):
        review_id = self.below()
        for status in ("queued", "launching", "running", "limited", "deciding", "posting", "failed", "cancelled", "superseded"):
            with self.subTest(status=status):
                self.store.update(review_id, status=status)
                with self.assertRaises(ActionError):
                    self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])

    def test_post_anyway_refuses_other_finding_states(self):
        review_id = self.below()
        for state in ("posted", "already_open", "unanchored"):
            with self.subTest(state=state):
                self.store.update_finding(review_id, 1, "SR-1", state=state)
                with self.assertRaises(ActionError):
                    self.engine.post_anyway(review_id, "SR-1")
        self.assertEqual(self.forge.post_attempts, [])
