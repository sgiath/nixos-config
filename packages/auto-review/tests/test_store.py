import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from auto_review.settings import CONTRACT
from auto_review.store import Store
from tests.fakes import NOW, REPO, SELECTION, change


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "state.db"
        self.store = Store(self.path)

    def claim(self, item=None):
        return self.store.claim(item or change(), forge="gitlab", path="team/service",
                                selection=SELECTION, contract=CONTRACT, now=NOW)

    def test_claim_starts_queued_at_attempt_one(self):
        review_id = self.claim()
        row = self.store.get(review_id)
        self.assertEqual((row["status"], row["attempt"], row["repo"]), ("queued", 1, REPO))
        self.assertEqual((row["provider"], row["model"], row["effort"]),
                         (SELECTION.provider, SELECTION.model, SELECTION.effort))

    def test_instance_id_survives_reopen_and_differs_between_databases(self):
        self.assertTrue(callable(getattr(self.store, "instance_id", None)), "Store must expose instance_id()")
        instance = self.store.instance_id()
        self.assertIsInstance(instance, str)
        self.assertTrue(instance)
        self.assertEqual(self.store.instance_id(), instance)
        self.assertEqual(Store(self.path).instance_id(), instance)
        self.assertNotEqual(Store(self.path.with_name("other.db")).instance_id(), instance)

    def test_existing_key_never_claimed_again_regardless_of_status(self):
        review_id = self.claim()
        for status in ("queued", "running", "limited", "done", "failed", "cancelled", "superseded"):
            with self.subTest(status=status):
                self.store.update(review_id, status=status)
                self.assertIsNone(self.claim())
        self.assertEqual(len(self.store.for_mr(REPO, 7)), 1)

    def test_new_head_base_and_target_are_distinct_claims(self):
        original = change()
        ids = [self.claim(original)]
        for item in (replace(original, head_sha="c" * 40), replace(original, base_sha="d" * 40),
                     replace(original, target="release")):
            ids.append(self.claim(item))
        self.assertNotIn(None, ids)
        self.assertEqual(len(set(ids)), 4)

    def test_metadata_model_or_contract_change_does_not_change_dedup_key(self):
        self.claim()
        self.assertIsNone(self.store.claim(
            change(title="Renamed", labels=("security",)), forge="gitlab", path="team/service",
            selection=replace(SELECTION, model="another-model"), contract="auto-review/v2", now=NOW))

    def test_dedup_survives_reopening_sqlite_store(self):
        review_id = self.claim()
        self.store.update(review_id, status="done")
        reopened = Store(self.path)
        self.assertIsNone(reopened.claim(change(), forge="gitlab", path="team/service",
                                         selection=SELECTION, contract=CONTRACT, now=NOW))
        self.assertEqual(reopened.get(review_id)["status"], "done")

    def test_findings_are_isolated_by_attempt(self):
        review_id = self.claim()
        row = dict(finding_id="SR-1", title="Defect", frequency=1, severity=5, score=5,
                   file="src/new.py", side="new", line=11, existing_thread_id=None,
                   body="Body", reasoning="Reason", state="posted", url="https://forge.invalid/n1", remote_id="n1")
        self.store.save_findings(review_id, 1, [row])
        self.store.save_findings(review_id, 2, [{**row, "state": "below", "url": None, "remote_id": None}])
        self.assertEqual(self.store.findings(review_id, 1)[0]["state"], "posted")
        self.assertEqual(self.store.findings(review_id, 2)[0]["state"], "below")

    def test_provider_limit_keeps_later_reset_and_expires_at_boundary(self):
        self.store.set_limit("provider-a", "2026-11-08T12:00:00Z", "weekly limit")
        self.store.set_limit("provider-a", "2026-11-06T12:00:00Z", "shorter limit")
        self.assertEqual(self.store.limits(NOW)["provider-a"]["until"], "2026-11-08T12:00:00Z")
        self.assertEqual(self.store.limits("2026-11-08T12:00:00Z"), {})
