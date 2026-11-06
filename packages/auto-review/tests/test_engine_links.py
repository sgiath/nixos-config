from auto_review.engine import Engine
from auto_review.models import ThreadState
from tests.engine_case import EngineCase
from tests.fakes import change


class ReviewLinkTest(EngineCase):
    def test_launch_links_review_web_url_once_before_later_ticks(self):
        review_id = self.start()
        row = self.row(review_id)
        expected = [(row["thread_id"], row["url"])]
        self.assertEqual(self.t3.links, expected)
        launch = next(i for i, event in enumerate(self.journal) if event[0] == "launch")
        self.assertEqual(self.journal[launch + 1], ("link", *expected[0]))
        self.engine.tick()
        self.engine.tick()
        self.assertEqual(self.t3.links, expected)

    def test_existing_active_reviews_are_linked_once_in_every_busy_status(self):
        # Persist pre-feature reviews without launching them in this engine instance.
        self.config["paused"] = True
        expected = []
        for number, status in enumerate(("launching", "running", "limited", "deciding", "posting"), 10):
            item = self.forge.add(change(number=number, url=f"https://forge.invalid/{number}"))
            review_id = self.claim(item)
            thread_id = f"existing-{number}"
            self.store.update(review_id, status=status, thread_id=thread_id,
                              limited_until="2026-11-06T12:00:00Z")
            self.t3.states[thread_id] = ThreadState("limited" if status == "limited" else "active")
            expected.append((thread_id, item.url))
        self.engine.tick()
        self.assertCountEqual(self.t3.links, expected)
        self.engine.tick()
        self.assertCountEqual(self.t3.links, expected)
        self.assertEqual(self.t3.launches, [])

    def test_restart_links_running_review_again_once_for_new_engine_instance(self):
        review_id = self.start()
        row = self.row(review_id)
        self.t3.links.clear()
        restarted = Engine(self.store, lambda: self.config,
                           {"gitlab": self.forge, "github": self.github}, self.t3,
                           self.fetch, self.runs, self.notify, self.clock)
        restarted.tick()
        self.assertEqual(self.t3.links, [(row["thread_id"], row["url"])])
        restarted.tick()
        self.assertEqual(self.t3.links, [(row["thread_id"], row["url"])])
        self.assertEqual(len(self.t3.launches), 1)

    def test_link_failure_warns_without_stopping_review_and_retries_next_tick(self):
        self.t3.link_failures = 2
        review_id = self.start()
        row = self.row(review_id)
        expected = (row["thread_id"], row["url"])
        self.assertEqual(self.t3.links, [expected])
        self.assertEqual(row["status"], "running")
        self.engine.tick()
        self.assertEqual(self.t3.links, [expected, expected])
        self.assertEqual(self.row(review_id)["status"], "running")
        warnings = [e for e in self.store.events(review_id=review_id) if e["level"] == "warn"]
        self.assertTrue(any("link unavailable" in e["message"] for e in warnings))
        self.assertEqual(self.t3.stops, [])
        self.assertEqual(self.t3.settles, [])
        self.assertEqual(self.notify.calls, [])
        self.engine.tick()
        self.assertEqual(self.t3.links, [expected] * 3)
        self.assertEqual(self.row(review_id)["status"], "running")
        self.engine.tick()
        self.assertEqual(self.t3.links, [expected] * 3)
