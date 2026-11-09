import json
from dataclasses import replace

from auto_review.engine import ActionError
from tests.fakes import REPO, change, raw_finding
from tests.thread_case import ThreadCase


class FollowUpPollTest(ThreadCase):
    def test_new_author_reply_queues_one_follow_up_without_review_request(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        self.engine.tick()
        rows = self.follow_ups()
        self.assertEqual(len(rows), 1, 'new reply must queue even after reviewer request is cleared')
        self.assertEqual(rows[0]['head_sha'], change().head_sha)
        self.assertIn('author-2', rows[0]['trigger'])
        self.engine.tick()
        self.assertEqual(len(self.follow_ups()), 1, 'same reply must not queue twice')

    def test_filips_own_reply_does_not_queue(self):
        self.posted()
        self.author_reply('sgiath')
        self.engine.tick()
        self.assertEqual(self.follow_ups(), [])

    def test_active_review_defers_reply_until_finished(self):
        self.posted()
        current = self.next_review()
        self.author_reply()
        self.engine.tick()
        self.assertEqual(self.follow_ups(), [])
        self.judgment(current, 'open', reply='')
        # A reply arriving after the bundled snapshot still needs a fresh judgment.
        self.engine.tick()
        self.assertEqual(len(self.follow_ups()), 1, 'reply arriving during review must remain pending')

    def test_external_resolution_stops_watching(self):
        self.posted()
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.tracked()['status'], 'resolved_elsewhere')
        self.assertEqual(self.follow_ups(), [])

    def test_merged_change_closes_watched_threads(self):
        self.posted()
        self.forge.add(change(state='merged', review_requested=False))
        self.engine.tick()
        self.assertEqual(self.tracked()['status'], 'closed')


class FollowUpIntegrationTest(ThreadCase):
    def launch_follow_up(self):
        original, _ = self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        self.until(lambda: any(r['status']=='running' for r in self.follow_ups()), 'follow-up should launch')
        row = next(r for r in self.follow_ups() if r['status']=='running')
        message = self.t3.launches[-1]['message']
        self.assertIn('own_threads.json', message)
        self.assertIn('write-as-sgiath', message)
        self.assertIn('"findings": []', message)
        self.assertIn('read-only', message.lower())
        data = json.loads((self.engine.run_dir(row)/'mr/own_threads.json').read_text())
        self.assertEqual(data[0]['thread_id'], 'note-1')
        self.assertEqual(data[0]['newest_note_id'], 'author-2')
        self.assertEqual(data[0]['notes'][-1]['author'], 'alice')
        return original, row['id']

    def test_follow_up_answers_then_reconsiders_latest_review_for_approval(self):
        self.config['repos'][REPO]['approval'] = 'when_clean'
        original, follow_up = self.launch_follow_up()
        self.judgment(follow_up, 'answered', findings=[])
        self.assertEqual(self.tracked()['status'], 'answered')
        self.assertEqual(len(self.forge.approvals), 1)
        self.assertEqual(self.forge.approvals[0][1].head_sha, self.row(original)['head_sha'])
        self.assertTrue(self.row(original)['approved'])
        self.assertEqual(len(self.forge.posts), 1)

    def test_follow_up_with_open_thread_does_not_approve(self):
        self.config['repos'][REPO]['approval'] = 'when_clean'
        _, follow_up = self.launch_follow_up()
        self.judgment(follow_up, 'open', reply='', findings=[])
        self.assertEqual(self.forge.approvals, [])

    def test_follow_up_settlement_under_never_clears_requested_changes(self):
        self.config['repos'][REPO]['approval'] = 'never'
        _, follow_up = self.launch_follow_up()
        before = len(self.forge.marked)
        self.judgment(follow_up, 'fixed', findings=[])
        self.assertGreater(len(self.forge.marked), before)
        self.assertEqual(self.forge.approvals, [])


class ThreadActionsTest(ThreadCase):
    def disputed(self):
        self.posted()
        self.set_status('disputed')
        return self.key()

    def test_accept_resolves_with_optional_reply_and_reconsiders(self):
        self.config['repos'][REPO]['approval'] = 'when_clean'
        key = self.disputed()
        self.engine.accept_thread(key, 'This explanation covers it.')
        self.assertEqual(self.tracked()['status'], 'accepted')
        self.assertEqual(len(self.forge.replies), 1)
        self.assertIn('This explanation covers it.', self.forge.replies[0][-1])
        self.assertEqual(len(self.forge.resolutions), 1)
        self.assertEqual(len(self.forge.approvals), 1)

    def test_accept_without_reply_only_resolves(self):
        key = self.disputed()
        self.engine.accept_thread(key, None)
        self.assertEqual(self.tracked()['status'], 'accepted')
        self.assertEqual(self.forge.replies, [])
        self.assertEqual(len(self.forge.resolutions), 1)

    def test_accept_does_not_approve_a_new_unreviewed_head(self):
        self.config['repos'][REPO]['approval'] = 'when_clean'
        key = self.disputed()
        self.forge.add(change(head_sha='c' * 40, review_requested=False))
        self.engine.accept_thread(key, None)
        self.assertEqual(self.tracked()['status'], 'accepted')
        self.assertEqual(self.forge.approvals, [], 'a settled old review cannot approve an unreviewed head')

    def test_reply_posts_text_and_reopens_tracking(self):
        key = self.disputed()
        self.engine.reply_thread(key, 'Please handle this case.')
        self.assertIn('Please handle this case.', self.forge.replies[0][-1])
        self.assertEqual(self.forge.resolutions, [])
        self.assertEqual(self.tracked()['status'], 'open')

    def test_dismiss_writes_nothing_and_reopens_tracking(self):
        key = self.disputed()
        self.engine.dismiss_thread(key)
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])
        self.assertEqual(self.tracked()['status'], 'open')

    def test_non_disputed_actions_refused(self):
        self.posted()
        key = self.key()
        for action, args in (('accept_thread', (key,None)), ('reply_thread', (key,'Reply')), ('dismiss_thread',(key,))):
            with self.subTest(action=action), self.assertRaises(ActionError):
                getattr(self.engine, action)(*args)
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])

    def test_paused_accept_and_reply_refused(self):
        key = self.disputed()
        self.config['paused'] = True
        for action, args in (('accept_thread',(key,None)), ('reply_thread',(key,'Reply'))):
            with self.subTest(action=action), self.assertRaises(ActionError):
                getattr(self.engine, action)(*args)
        self.assertEqual(self.forge.replies + self.forge.resolutions, [])
