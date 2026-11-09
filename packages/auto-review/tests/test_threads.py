import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from auto_review.settings import CONTRACT
from auto_review.store import Store
from auto_review.verdict import load, VerdictError
from tests.fakes import BASE, HEAD, NOW, REPO, SELECTION, change, raw_verdict, raw_finding
from tests.thread_case import ThreadCase

# Frozen pre-feature schema: migration must not inherit a changed production SCHEMA.
OLD_REVIEWS = '''CREATE TABLE reviews (
id INTEGER PRIMARY KEY, repo TEXT NOT NULL, forge TEXT NOT NULL, path TEXT NOT NULL, number INTEGER NOT NULL,
head_sha TEXT NOT NULL, base_sha TEXT NOT NULL, target TEXT NOT NULL,
attempt INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL, outcome TEXT, title TEXT, url TEXT, author TEXT,
provider TEXT, model TEXT, effort TEXT, contract TEXT NOT NULL, thread_id TEXT, thread_url TEXT, run_id TEXT,
queued_at TEXT, started_at TEXT, running_since TEXT, active_seconds INTEGER NOT NULL DEFAULT 0,
finished_at TEXT, limited_until TEXT, error TEXT, summary TEXT, not_reviewed TEXT, injection_attempts TEXT,
dry_run INTEGER NOT NULL DEFAULT 0, approved INTEGER NOT NULL DEFAULT 0, settled INTEGER NOT NULL DEFAULT 0,
source TEXT NOT NULL DEFAULT 'auto', diff_refs TEXT, UNIQUE(repo,number,head_sha,base_sha,target));'''


class ThreadStoreTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name) / 'state.db'

    def claim(self, store, **fields):
        return store.claim(change(), forge='gitlab', path='team/service', selection=SELECTION,
                           contract=CONTRACT, now=NOW, **fields)

    def test_old_unique_migration_preserves_ids_and_defaults_review(self):
        with sqlite3.connect(self.path) as db:
            db.executescript(OLD_REVIEWS)
            db.execute("INSERT INTO reviews (id,repo,forge,path,number,head_sha,base_sha,target,status,contract) "
                       "VALUES (42,?,'gitlab','team/service',7,?,?,'main','done',?)", (REPO,HEAD,BASE,CONTRACT))
        store = Store(self.path)
        row = store.get(42)
        self.assertEqual(row.get('kind'), 'review', 'old rows must migrate to kind=review')
        self.assertEqual(row.get('trigger'), '')
        self.assertIsNone(self.claim(store))
        follow = self.claim(store, kind='follow_up', trigger='note-2')
        self.assertIsNotNone(follow, 'old UNIQUE must be replaced, not retained alongside the new key')
        self.assertEqual(Store(self.path).get(42)['status'], 'done')

    def test_follow_up_claim_deduplicates_trigger_but_not_diff_key(self):
        store = Store(self.path)
        self.claim(store)
        first = self.claim(store, kind='follow_up', trigger='note-2')
        self.assertIsNotNone(first)
        self.assertIsNone(self.claim(store, kind='follow_up', trigger='note-2'))
        self.assertIsNotNone(self.claim(store, kind='follow_up', trigger='note-3'))


class ThreadVerdictTest(unittest.TestCase):
    def parse(self, entries, ids=('thread-1',)):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'mr').mkdir()
            (root/'mr/own_threads.json').write_text(json.dumps([{'thread_id': i} for i in ids]))
            (root/'verdict.json').write_text(json.dumps(raw_verdict(threads=entries)))
            return load(root/'verdict.json', review_id=1, attempt=1, head_sha=HEAD, base_sha=BASE)

    def test_judgments_match_own_thread_ids_exactly(self):
        entry = dict(thread_id='thread-1', status='open', reasoning='Still present.', reply='')
        for entries in ([], [dict(entry, thread_id='unknown')], [entry, entry]):
            with self.subTest(entries=entries), self.assertRaises(VerdictError):
                self.parse(entries)

    def test_fixed_answered_and_disputed_require_reply(self):
        for status in ('fixed', 'answered', 'disputed'):
            with self.subTest(status=status), self.assertRaises(VerdictError):
                self.parse([dict(thread_id='thread-1', status=status, reasoning='Checked.')])

    def test_unknown_thread_judgment_status_rejected(self):
        with self.assertRaises(VerdictError):
            self.parse([dict(thread_id='thread-1', status='accepted', reasoning='Checked.', reply='Yes.')])


class ThreadPublishingTest(ThreadCase):
    def test_normal_post_creates_tracked_thread(self):
        review_id, thread = self.posted()
        row = self.tracked()
        self.assertEqual((row['review_id'], row['finding_id'], row['status']), (review_id, 'SR-1', 'open'))
        self.assertIn(row['thread_id'], (None, thread.id))

    def test_marker_recovery_creates_one_tracked_thread(self):
        review_id = self.start()
        self.forge.fail_after = 1
        self.finish(review_id, findings=[raw_finding()])
        self.assertEqual(len(self.forge.posts), 1)
        self.assertEqual(self.tracked()['status'], 'open')

    def test_post_anyway_creates_tracked_thread(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(severity=4)])
        self.engine.post_anyway(review_id, 'SR-1')
        self.assertEqual(self.tracked()['finding_id'], 'SR-1')
        self.assertEqual(len(self.forge.posts), 1)

    def test_startup_backfills_posted_findings(self):
        review_id, _ = self.posted()
        # Emulate a legacy DB, where findings exist but tracking has never run.
        self.store._db.execute('DROP TABLE IF EXISTS threads')
        reopened = Store(self.root/'state.db')
        tables = {r[0] for r in reopened._db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertIn('threads', tables, 'startup must create and backfill thread tracking')
        rows = reopened._db.execute('SELECT review_id,status FROM threads').fetchall()
        self.assertEqual([tuple(r) for r in rows], [(review_id, 'open')])

    def test_fixed_judgment_replies_then_resolves(self):
        self.posted()
        review_id = self.next_review()
        self.judgment(review_id, 'fixed')
        self.assertEqual(len(self.forge.replies), 1, 'fixed thread needs its explanation reply')
        body = self.forge.replies[0][-1]
        self.assertTrue(body.startswith('> [!NOTE]\n'), body)
        self.assertIn('The current head addresses this.', body)
        self.assertEqual(len(self.forge.resolutions), 1)
        self.assertLess(self.journal.index(('reply', 'note-1')), self.journal.index(('resolve', 'note-1')))
        self.assertEqual(self.tracked()['status'], 'fixed')

    def test_answered_judgment_replies_and_resolves(self):
        self.posted()
        self.author_reply()
        self.judgment(self.next_review(), 'answered')
        self.assertEqual(len(self.forge.replies), 1, 'answered thread needs its explanation reply')
        self.assertEqual(len(self.forge.resolutions), 1)
        self.assertEqual(self.tracked()['status'], 'answered')

    def test_open_judgment_only_advances_seen_note(self):
        self.posted()
        self.author_reply()
        self.judgment(self.next_review(), 'open', reply='')
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])
        self.assertEqual(self.tracked()['status'], 'open')
        self.engine.tick()
        self.assertEqual(self.follow_ups(), [], 'a judged reply is not judged again')

    def test_disputed_judgment_notifies_without_writing(self):
        self.posted()
        self.author_reply()
        row = self.judgment(self.next_review(), 'disputed', reply='Please handle the missing case.')
        self.assertEqual(row['outcome'], 'needs_attention')
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])
        self.assertEqual(self.tracked()['status'], 'disputed')
        self.assertEqual(self.tracked()['proposed_reply'], 'Please handle the missing case.')
        self.assertTrue(self.notify.calls)
        self.assertIn('Checked the current implementation.', str(self.notify.calls))

    def test_dry_run_records_judgment_without_forge_writes(self):
        self.posted()
        self.config['dry_run'] = True
        row = self.judgment(self.next_review(), 'fixed')
        self.assertTrue(row['dry_run'])
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])
        self.assertIn('Checked the current implementation.', self.tracked()['reasoning'])

    def test_answered_or_accepted_finding_is_settled_and_approvable(self):
        for status in ('answered', 'accepted'):
            with self.subTest(status=status):
                if not self.forge.posts:
                    self.posted()
                self.set_status(status)
                self.config['repos'][REPO]['approval'] = 'when_clean'
                item = change(head_sha=('c' if status == 'answered' else 'd') * 40)
                review_id = self.start(item)
                self.finish(review_id, findings=[raw_finding(existing_thread_id='note-1')])
                self.assertEqual(self.states(review_id)['SR-1'], 'settled')
                self.assertTrue(self.row(review_id)['approved'])
        self.assertEqual(len(self.forge.posts), 1)

    def test_open_tracked_thread_blocks_otherwise_clean_review(self):
        self.posted()
        self.config['repos'][REPO]['approval'] = 'when_clean'
        self.judgment(self.next_review(), 'open', reply='')
        self.assertEqual(self.forge.approvals, [], 'clean new findings do not erase an open owned thread')
