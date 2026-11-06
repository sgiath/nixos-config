from copy import deepcopy
from datetime import datetime, timezone

from auto_review.models import ThreadState
from tests.engine_case import EngineCase
from tests.fakes import Forge, REPO, change, raw_finding


class SchedulingTest(EngineCase):
    def test_max_concurrent_leaves_excess_work_queued(self):
        self.config["max_concurrent"] = 2
        for number in (1, 2, 3):
            self.forge.add(change(number=number))
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 2)
        self.assertEqual(len(self.store.in_status("running")), 2)
        self.assertEqual(len(self.store.in_status("queued")), 1)
        first = self.store.in_status("running")[0]
        self.finish(first["id"])
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 3)
        self.assertEqual(len(self.store.in_status("running")), 2)

    def test_daily_cap_resets_at_local_midnight_not_utc_midnight(self):
        self.config["max_launches_per_day"] = 1
        self.config["timezone"] = "Europe/Prague"
        # November: Prague is UTC+1. Both launches are on November 5 in UTC.
        self.clock.value = datetime(2026, 11, 5, 22, 59, tzinfo=timezone.utc)
        self.start(change(number=1))
        self.forge.add(change(number=2))
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(len(self.store.in_status("queued")), 1)
        self.clock.advance(minutes=2)
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 2)

    def test_retry_does_not_erase_an_attempt_from_daily_launch_budget(self):
        self.config["max_launches_per_day"] = 1
        review_id = self.start()
        self.finish(review_id)
        self.engine.retry(review_id)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "queued")
        self.assertEqual(len(self.t3.launches), 1)
        self.clock.advance(days=1)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "running")
        self.assertEqual(len(self.t3.launches), 2)

    def test_quiet_window_across_midnight_blocks_launch_until_end(self):
        self.config["quiet_hours"] = {"enabled": True, "start": "22:00", "end": "07:00"}
        self.config["timezone"] = "Europe/Prague"
        self.forge.add(change())
        for utc in ((2026, 11, 5, 21, 0), (2026, 11, 6, 0, 0), (2026, 11, 6, 5, 59)):
            with self.subTest(utc=utc):
                self.clock.value = datetime(*utc, tzinfo=timezone.utc)
                self.engine.tick()
                self.assertEqual(self.t3.launches, [])
        self.clock.value = datetime(2026, 11, 6, 6, 0, tzinfo=timezone.utc)
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)

    def test_quiet_window_holds_completed_findings_until_posting_allowed(self):
        self.config["quiet_hours"] = {"enabled": True, "start": "22:00", "end": "07:00"}
        self.config["review_timeout_minutes"] = 1440
        self.clock.value = datetime(2026, 11, 5, 20, 59, tzinfo=timezone.utc)
        review_id = self.start()
        self.complete(review_id, findings=[raw_finding()])
        self.clock.advance(minutes=1)
        self.engine.tick()
        self.assertIn(self.row(review_id)["thread_id"], self.t3.reads)
        self.assertEqual(self.forge.posts, [])
        self.clock.value = datetime(2026, 11, 6, 5, 59, tzinfo=timezone.utc)
        self.engine.tick()
        self.assertEqual(self.forge.posts, [])
        self.clock.advance(minutes=1)
        self.until(lambda: self.row(review_id)["status"] == "done", "quiet end should release posting")
        self.assertEqual(self.states(review_id), {"SR-1": "posted"})

    def test_pause_blocks_launches(self):
        self.config["paused"] = True
        self.forge.add(change())
        self.engine.tick()
        self.assertEqual(self.t3.launches, [])

    def test_pause_still_reads_running_threads(self):
        review_id = self.start()
        self.config["paused"] = True
        before = len(self.t3.reads)
        self.engine.tick()
        self.assertEqual(self.t3.reads[before:], [self.row(review_id)["thread_id"]])
        self.assertEqual(self.row(review_id)["status"], "running")

    def test_pause_holds_posts_and_resume_posts_once(self):
        review_id = self.start()
        self.complete(review_id, findings=[raw_finding()])
        self.config["paused"] = True
        for _ in range(3):
            self.engine.tick()
        self.assertEqual(self.forge.posts, [])
        self.assertEqual(self.forge.approvals, [])
        self.config["paused"] = False
        self.until(lambda: self.row(review_id)["status"] == "done", "unpause should release posts")
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1"])

    def test_pause_applied_during_pre_post_read_overrides_tick_snapshot(self):
        review_id = self.start()

        class PausingForge(Forge):
            def change(self, path, number, me):
                self.config["paused"] = True
                return super().change(path, number, me)

        pausing = PausingForge(self.journal)
        pausing.config = self.config
        pausing.add(change())
        self.forge = self.engine.forges["gitlab"] = pausing
        self.engine.settings = lambda: deepcopy(self.config)
        self.complete(review_id, findings=[raw_finding()])
        self.engine.tick()
        self.assertTrue(self.config["paused"])
        self.assertEqual(self.forge.post_attempts, [])
        self.assertEqual(self.forge.approvals, [])
        self.assertFalse(self.row(review_id)["approved"])
        self.forge.change = lambda path, number, me: Forge.change(self.forge, path, number, me)
        self.config["paused"] = False
        self.until(lambda: self.row(review_id)["status"] == "done", "unpause should release held findings")
        self.engine.tick()
        self.assertEqual([c.finding_id for c in self.forge.posts], ["SR-1"])
        self.assertEqual(len(self.forge.post_attempts), 1)

    def test_disabled_repo_is_not_launched(self):
        self.config["repos"][REPO]["enabled"] = False
        self.forge.add(change())
        self.engine.tick()
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.t3.launches, [])

    def test_draft_waits_without_claim_and_is_reconsidered(self):
        self.forge.add(change(draft=True))
        self.engine.tick()
        self.assertEqual(self.rows(), [])
        [waiting] = self.engine.waiting()
        self.assertEqual((waiting["repo"], waiting["number"]), (REPO, 7))
        self.assertIn("draft", waiting["reason"].lower())
        self.forge.add(change())
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(self.engine.waiting(), [])

    def test_queued_change_is_rechecked_before_launch(self):
        for field, value in (("state", "closed"), ("head_sha", "c" * 40),
                             ("base_sha", "d" * 40), ("author", "sgiath")):
            with self.subTest(field=field):
                item = change(number=100 + len(self.store.in_status("cancelled")))
                self.forge.add(item)
                review_id = self.claim(item)
                # Suppress discovery only: advancement/queued launch must re-read evidence itself.
                self.forge.candidates = lambda path, me, include_authors: []
                from dataclasses import replace
                self.forge.add(replace(item, **{field: value}))
                self.engine.tick()
                self.assertEqual(self.row(review_id)["status"], "cancelled")
                self.assertEqual(self.t3.launches, [])


class UsageLimitTest(EngineCase):
    def test_late_observation_counts_active_time_only_until_thread_limit_timestamp(self):
        self.config["review_timeout_minutes"] = 20
        review_id = self.start()
        thread_id = self.row(review_id)["thread_id"]
        self.clock.advance(minutes=10)
        limited_at = self.clock.iso()
        self.t3.states[thread_id] = ThreadState(
            "limited", updated_at=limited_at, limit_reset="2026-11-08T12:10:00Z")
        self.clock.advance(days=3)
        self.engine.tick()
        self.assertAlmostEqual(self.row(review_id)["active_seconds"], 10 * 60, delta=1)
        self.until(lambda: self.row(review_id)["status"] == "running", "reset should continue the review")
        self.engine.tick()
        row = self.row(review_id)
        self.assertEqual(row["status"], "running")
        self.assertEqual(row["thread_id"], thread_id)
        self.assertEqual([t for t, _ in self.t3.sends], [thread_id])
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(self.t3.stops, [])

    def limited(self):
        review_id = self.start()
        thread_id = self.row(review_id)["thread_id"]
        self.t3.states[thread_id] = ThreadState(
            "limited", limit_reset="2026-11-08T12:00:00Z", error="weekly usage limit")
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "limited")
        self.assertEqual(self.row(review_id)["limited_until"], "2026-11-08T12:00:00Z")
        self.assertFalse(self.row(review_id)["settled"])
        self.assertEqual(self.t3.settles, [])
        return review_id, thread_id

    def test_three_day_limit_blocks_only_its_provider(self):
        review_id, _ = self.limited()
        self.assertEqual(self.store.limits(self.clock.iso())["provider-a"]["until"], "2026-11-08T12:00:00Z")
        self.forge.add(change(number=8))
        other = self.other_repo()
        self.github.add(other)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "limited")
        self.assertEqual([c["selection"].provider for c in self.t3.launches], ["provider-a", "provider-b"])
        self.assertEqual(self.store.for_mr(REPO, 8)[0]["status"], "queued")

    def test_before_reset_no_continue_and_no_new_provider_launch(self):
        review_id, _ = self.limited()
        self.forge.add(change(number=8))
        self.clock.advance(days=2, hours=23, minutes=59)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "limited")
        self.assertEqual(self.t3.sends, [])
        self.assertEqual(len(self.t3.launches), 1)

    def test_at_reset_continues_same_thread_without_new_launch(self):
        review_id, thread_id = self.limited()
        self.clock.advance(days=3)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "running")
        self.assertEqual(self.row(review_id)["thread_id"], thread_id)
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(len(self.t3.sends), 1)
        self.assertEqual(self.t3.sends[0][0], thread_id)
        self.assertIn("continue", self.t3.sends[0][1].lower())
        self.assertEqual(self.store.limits(self.clock.iso()), {})
        self.engine.tick()
        self.assertEqual(len(self.t3.sends), 1)

    def test_after_reset_also_continues_existing_thread(self):
        review_id, thread_id = self.limited()
        self.clock.advance(days=3, minutes=1)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "running")
        self.assertEqual([t for t, _ in self.t3.sends], [thread_id])
        self.assertEqual(len(self.t3.launches), 1)

    def test_limited_days_do_not_count_toward_active_timeout(self):
        self.config["review_timeout_minutes"] = 20
        review_id = self.start()
        thread_id = self.row(review_id)["thread_id"]
        self.clock.advance(minutes=10)
        self.t3.states[thread_id] = ThreadState("limited", limit_reset="2026-11-08T12:10:00Z")
        self.engine.tick()
        self.clock.advance(days=3)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "running")
        self.clock.advance(minutes=5)
        self.engine.tick()
        row = self.row(review_id)
        self.assertEqual(row["status"], "running")
        self.assertLessEqual(row["active_seconds"], 15 * 60)
        self.clock.advance(minutes=16)
        self.engine.tick()
        self.assertEqual(self.row(review_id)["status"], "failed")
        self.assertEqual(self.t3.settles, [])

    def test_limited_review_occupies_a_concurrency_slot(self):
        self.config["max_concurrent"] = 1
        self.limited()
        other = self.other_repo()
        self.github.add(other)
        self.engine.tick()
        self.assertEqual(len(self.t3.launches), 1)
        self.assertEqual(self.store.for_mr(other.repo, other.number)[0]["status"], "queued")
