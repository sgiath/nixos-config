"""Thread feature fixtures; SQL avoids prescribing new Store method names.

Persisted thread key is (repo, number, marker). own_threads.json uses thread_id,
newest_note_id, and notes carrying id/author/body. Engine actions take that key.
"""
import json
from dataclasses import replace

from auto_review.models import Note, Posted
from tests.engine_case import EngineCase
from tests.fakes import REPO, change, raw_finding


class ThreadCase(EngineCase):
    def setUp(self):
        super().setUp()
        self.forge.replies, self.forge.resolutions = [], []

        def reply(path, number, thread_id, body):
            self.forge.replies.append((path, number, thread_id, body))
            self.journal.append(('reply', thread_id))
            return Posted('', 'reply-1', 'https://forge.invalid/#reply-1')

        def resolve(path, number, thread_id):
            self.forge.resolutions.append((path, number, thread_id))
            self.journal.append(('resolve', thread_id))
            key = (path, number)
            self.forge.discussions[key] = [replace(t, resolved=True) if t.id == thread_id else t
                                           for t in self.forge.discussions[key]]
        self.forge.reply, self.forge.resolve = reply, resolve

    def posted(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding()])
        thread = self.forge.discussions[('team/service', 7)][0]
        return review_id, thread

    def tracking(self):
        names = {r[0] for r in self.store._db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertIn('threads', names, 'posted findings must have persistent tracked threads')
        return [dict(r) for r in self.store._db.execute('SELECT * FROM threads ORDER BY marker')]

    def tracked(self):
        rows = self.tracking()
        self.assertEqual(len(rows), 1)
        return rows[0]

    def set_status(self, status):
        self.tracked()
        self.store._db.execute('UPDATE threads SET status=?', (status,))

    def key(self):
        t = self.tracked()
        return (t['repo'], t['number'], t['marker'])

    def author_reply(self, author='alice'):
        key = ('team/service', 7)
        t = self.forge.discussions[key][0]
        self.forge.discussions[key][0] = replace(t, notes=t.notes + (Note(author, 'Explanation', 'author-2'),))

    def next_review(self):
        return self.start(change(head_sha='c' * 40))

    def judgment(self, review_id, status, reply='The current head addresses this.', **fields):
        thread = self.forge.discussions[('team/service', 7)][0]
        return self.finish(review_id, threads=[dict(thread_id=thread.id, status=status,
                           reasoning='Checked the current implementation.', reply=reply)], **fields)

    def follow_ups(self):
        return [r for r in self.rows() if r.get('kind') == 'follow_up']
