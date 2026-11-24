import json
from dataclasses import replace

from auto_review.checkout import HeadMoved
from auto_review.engine import ActionError
from auto_review.models import Note, Thread
from auto_review.t3 import T3Error
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

    def test_external_resolution_acknowledges_and_approves(self):
        review_id, _ = self.posted()
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.tracked()['status'], 'resolved_elsewhere')
        self.assertEqual(self.follow_ups(), [])
        self.assertEqual(len(self.forge.approvals), 1)
        self.assertTrue(self.row(review_id)['approved'])

    def test_external_resolution_under_never_clears_requested_changes(self):
        self.config['repos'][REPO]['approval'] = 'never'
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=6, severity=5)])
        before = len(self.forge.marked)
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.tracked()['status'], 'resolved_elsewhere')
        self.assertGreater(len(self.forge.marked), before)
        self.assertEqual(self.forge.approvals, [])

    def test_external_resolution_waits_until_all_own_comments_are_resolved(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'), raw_finding(id='SR-2', line=12)])
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.forge.approvals, [])
        self.forge.discussions[key][1] = replace(self.forge.discussions[key][1], resolved=True)
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)

    def test_external_resolution_approves_with_other_reviewers_resolved_thread(self):
        key = ('team/service', 7)
        self.forge.discussions[key] = [Thread('other-1', True, (Note('bot', 'Seen earlier.', 'b1'),), 'src/new.py', 11)]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'),
                                         raw_finding(id='SR-2', existing_thread_id='other-1')])
        self.assertEqual(self.states(review_id), {'SR-1': 'posted', 'SR-2': 'already_resolved'})
        self.forge.discussions[key] = [replace(t, resolved=True) for t in self.forge.discussions[key]]
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)

    def test_external_resolution_checks_other_reviewers_thread_state(self):
        key = ('team/service', 7)
        self.forge.discussions[key] = [Thread('other-1', False, (Note('bot', 'Still open.', 'b1'),), 'src/new.py', 11)]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'),
                                         raw_finding(id='SR-2', existing_thread_id='other-1')])
        self.assertEqual(self.states(review_id), {'SR-1': 'posted', 'SR-2': 'already_open'})
        # Resolving only sgiath's comment leaves the other reviewer's thread open: wait in deferred.
        self.forge.discussions[key] = [replace(t, resolved=True) if t.id != 'other-1' else t
                                       for t in self.forge.discussions[key]]
        self.engine.tick()
        self.assertEqual(self.forge.approvals, [])
        self.assertEqual(self.store.deferred(), [(REPO, 7)])
        # Once the other reviewer's thread resolves later, the next poll approves.
        self.forge.discussions[key] = [replace(t, resolved=True) for t in self.forge.discussions[key]]
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)
        self.assertEqual(self.store.deferred(), [])

    def test_review_with_only_third_party_already_open_approves_once_resolved(self):
        key = ('team/service', 7)
        self.forge.discussions[key] = [Thread('other-1', False, (Note('bot', 'Open.', 'b1'),), 'src/new.py', 11)]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1', existing_thread_id='other-1')])
        self.assertEqual(self.states(review_id), {'SR-1': 'already_open'})
        self.assertEqual(self.forge.approvals, [])
        self.assertEqual(self.store.deferred(), [(REPO, 7)])
        self.forge.discussions[key] = [replace(t, resolved=True) for t in self.forge.discussions[key]]
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)
        self.assertEqual(self.store.deferred(), [])

    def test_external_resolution_under_never_waits_out_unpublished_drafts(self):
        self.config['repos'][REPO]['approval'] = 'never'
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(frequency=6, severity=5)])
        drafts = [True]
        original = self.forge.mark_reviewed

        def mark(path, item):
            if drafts[0]:
                return 'you have unpublished drafts'
            return original(path, item)

        self.forge.mark_reviewed = mark
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.forge.marked, [])
        self.assertEqual(self.store.deferred(), [(REPO, 7)])
        drafts[0] = False
        self.engine.tick()
        self.assertEqual(len(self.forge.marked), 1)
        self.assertEqual(self.store.deferred(), [])

    def test_external_resolution_does_not_orphan_launching_follow_up(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        launch = self.t3.launch
        find = getattr(self.t3, 'find', None)

        def lost(**kwargs):
            launch(**kwargs)
            raise T3Error('response lost')

        def find_down(**kwargs):
            raise T3Error('t3 unavailable')

        self.t3.launch = lost
        self.t3.find = find_down
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups())
        self.assertEqual(self.row(follow_up)['status'], 'launching')
        self.assertIsNone(self.row(follow_up)['thread_id'])
        # Resolve on the forge while launch recovery is still failing (row stays launching with no thread_id).
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'launching',
                         'must not drop a launching follow-up before adopting its T3 thread')
        self.assertEqual(len(self.forge.approvals), 1)
        # Once T3 answers on retry, relaunch adopts the started thread, stops it, and supersedes the follow-up.
        self.t3.launch = launch
        if find is not None:
            self.t3.find = find
        else:
            del self.t3.find
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'superseded')
        self.assertIsNotNone(self.row(follow_up)['thread_id'])
        self.assertEqual(len(self.t3.stops), 1)

    def test_moved_head_with_lost_follow_up_launch_stops_adopted_thread(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        launch = self.t3.launch

        def lost(**kwargs):
            launch(**kwargs)
            raise T3Error('response lost')

        self.t3.launch = lost
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups())
        self.assertEqual(self.row(follow_up)['status'], 'launching')
        # Author pushes a new head and resolves the thread while launch response was lost.
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.forge.add(change(head_sha='c' * 40, review_requested=False, reviewers=()))
        self.t3.launch = launch
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'failed')
        self.assertIsNotNone(self.row(follow_up)['thread_id'])
        self.assertEqual(len(self.t3.stops), 1)

    def test_moved_head_with_transient_find_error_does_not_drop_launching_follow_up(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        launch, find = self.t3.launch, self.t3.find

        def lost(**kwargs):
            launch(**kwargs)
            raise T3Error('response lost')

        self.t3.launch = lost
        self.t3.find = lambda **kwargs: (_ for _ in ()).throw(T3Error('t3 unavailable'))
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups())
        self.forge.add(change(head_sha='c' * 40, review_requested=False, reviewers=()))
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'launching',
                         'scan must not supersede a launching follow-up before adoption')
        self.t3.launch, self.t3.find = launch, find
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'failed')
        self.assertIsNotNone(self.row(follow_up)['thread_id'])
        self.assertEqual(len(self.t3.stops), 1)

    def test_head_moved_during_fetch_adopts_and_stops_launching_follow_up(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        launch = self.t3.launch

        def lost(**kwargs):
            launch(**kwargs)
            raise T3Error('response lost')

        self.t3.launch = lost
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups())
        self.t3.launch = launch
        self.fetch.error = HeadMoved('head moved during fetch')
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'superseded')
        self.assertIsNotNone(self.row(follow_up)['thread_id'])
        self.assertEqual(len(self.t3.stops), 1)

    def test_discovery_new_head_does_not_orphan_launching_follow_up(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        launch, find = self.t3.launch, self.t3.find

        def lost(**kwargs):
            launch(**kwargs)
            raise T3Error('response lost')

        self.t3.launch = lost
        self.t3.find = lambda **kwargs: (_ for _ in ()).throw(T3Error('t3 unavailable'))
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups())
        # Author pushes a new head and requests review while T3 lookup still fails.
        self.forge.add(change(head_sha='c' * 40, review_requested=True))
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'launching',
                         'discovery must not supersede a launching follow-up before adoption')
        self.t3.launch, self.t3.find = launch, find
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'failed')
        self.assertIsNotNone(self.row(follow_up)['thread_id'])
        self.assertEqual(len(self.t3.stops), 1)

    def test_reopened_thread_with_reply_queues_follow_up_while_another_thread_is_open(self):
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'), raw_finding(id='SR-2', line=12)])
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        statuses = {t['thread_id']: t['status'] for t in self.tracking()}
        self.assertEqual(statuses, {'note-1': 'resolved_elsewhere', 'note-2': 'open'})
        # Author reopens note-1 and adds a reply while note-2 stays open.
        t0 = self.forge.discussions[key][0]
        self.forge.discussions[key][0] = replace(t0, resolved=False,
                                                 notes=t0.notes + (Note('alice', 'Wait, still broken', 'author-2'),))
        self.engine.tick()
        statuses = {t['thread_id']: t['status'] for t in self.tracking()}
        self.assertEqual(statuses['note-1'], 'open')
        self.assertEqual(len(self.follow_ups()), 1)
        self.assertIn('author-2', self.follow_ups()[0]['trigger'])

    def test_external_resolution_approves_when_other_reviewers_open_thread_also_resolved(self):
        key = ('team/service', 7)
        self.forge.discussions[key] = [Thread('other-1', False, (Note('bot', 'Open.', 'b1'),), 'src/new.py', 11)]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'),
                                         raw_finding(id='SR-2', existing_thread_id='other-1')])
        self.forge.discussions[key] = [replace(t, resolved=True) for t in self.forge.discussions[key]]
        self.engine.tick()
        self.assertEqual(len(self.forge.approvals), 1)

    def test_external_resolution_blocks_if_other_reviewers_resolved_thread_was_reopened(self):
        key = ('team/service', 7)
        self.forge.discussions[key] = [Thread('other-1', True, (Note('bot', 'Resolved.', 'b1'),), 'src/new.py', 11)]
        review_id = self.start()
        self.finish(review_id, findings=[raw_finding(id='SR-1'),
                                         raw_finding(id='SR-2', existing_thread_id='other-1')])
        self.forge.discussions[key] = [
            replace(t, resolved=False) if t.id == 'other-1' else replace(t, resolved=True)
            for t in self.forge.discussions[key]
        ]
        self.engine.tick()
        self.assertEqual(self.forge.approvals, [])

    def test_external_resolution_supersedes_running_follow_up_and_approves(self):
        self.posted()
        self.author_reply()
        self.forge.add(change(review_requested=False, reviewers=()))
        self.engine.tick()
        follow_up = next(r['id'] for r in self.follow_ups() if r['status'] == 'running')
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.engine.tick()
        self.assertEqual(self.row(follow_up)['status'], 'superseded')
        self.assertEqual(len(self.t3.stops), 1)
        self.assertEqual(len(self.forge.approvals), 1)

    def test_external_resolution_on_new_head_does_not_queue_empty_follow_up(self):
        self.posted()
        key = ('team/service', 7)
        self.forge.discussions[key][0] = replace(self.forge.discussions[key][0], resolved=True)
        self.forge.add(change(head_sha='c' * 40, review_requested=False, reviewers=()))
        self.engine.tick()
        self.assertEqual(self.tracked()['status'], 'resolved_elsewhere')
        self.assertEqual(self.follow_ups(), [])
        self.assertEqual(self.forge.approvals, [])

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
