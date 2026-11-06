"""Shared engine fixture using real persistence and decision logic."""

import tempfile
import unittest
from pathlib import Path

from auto_review.engine import Engine
from auto_review.models import Selection
from auto_review.settings import CONTRACT
from auto_review.store import Store
from tests.fakes import Clock, Fetch, Forge, Notify, REPO, T3, change, configuration


class EngineCase(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.runs = self.root / "runs"
        self.runs.mkdir()
        self.clock, self.journal = Clock(), []
        self.config = configuration(self.root / "checkout")
        self.store = Store(self.root / "state.db")
        self.forge = Forge(self.journal)
        self.github = Forge(self.journal, name="github")
        self.t3 = T3(self.runs, self.journal)
        self.fetch, self.notify = Fetch(self.journal), Notify(self.journal)
        self.engine = Engine(self.store, lambda: self.config,
                             {"gitlab": self.forge, "github": self.github}, self.t3,
                             self.fetch, self.runs, self.notify, self.clock)

    def row(self, review_id):
        row = self.store.get(review_id)
        self.assertIsNotNone(row)
        return row

    def rows(self, item=None):
        item = item or change()
        return self.store.for_mr(item.repo, item.number)

    def claim(self, item=None):
        item = item or change()
        repo = self.config["repos"][item.repo]
        selected = repo["reviewer"] or self.config["reviewer"]
        return self.store.claim(item, forge=repo["forge"], path=repo["path"],
                                selection=Selection(**selected), contract=CONTRACT, now=self.clock.iso())

    def until(self, predicate, description):
        """Bounded ticks allow implementations to persist intermediate states."""
        for _ in range(6):
            if predicate():
                return
            self.engine.tick()
        self.assertTrue(predicate(), description)

    def start(self, item=None):
        item = item or change()
        forge = self.forge if item.repo.startswith("gitlab:") else self.github
        forge.add(item)
        self.until(lambda: any(r["head_sha"] == item.head_sha and r["status"] == "running"
                               for r in self.rows(item)), "review should launch")
        return next(r["id"] for r in self.rows(item) if r["head_sha"] == item.head_sha and r["status"] == "running")

    def complete(self, review_id, **fields):
        self.t3.complete(self.row(review_id), **fields)

    def finish(self, review_id, **fields):
        self.complete(review_id, **fields)
        self.until(lambda: self.row(review_id)["status"] == "done", "completed review should finish")
        return self.row(review_id)

    def states(self, review_id):
        row = self.row(review_id)
        return {f["finding_id"]: f["state"] for f in self.store.findings(review_id, row["attempt"])}

    def other_repo(self, provider="provider-b"):
        from copy import deepcopy

        repo_id = "github:owner/other"
        repo = deepcopy(self.config["repos"][REPO])
        repo.update(forge="github", path="owner/other", t3_project="project-b",
                    reviewer={"provider": provider, "model": "other-model", "effort": "high"})
        self.config["repos"][repo_id] = repo
        return change(repo=repo_id, number=9)
