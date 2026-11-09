"""Mock subprocess boundary: these tests can never write to either forge.

GitHub thread_id is the GraphQL review-thread node ID. reply() reads that node
and uses its first comment's databaseId, never the newest reply's ID.
"""
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from auto_review.forge.gitlab import GitLab
from auto_review.forge.github import GitHub


class ThreadForgeTest(unittest.TestCase):
    def capture(self, result):
        calls = []
        def run(cmd, **kwargs):
            payload = None
            if '--input' in cmd:
                payload = json.loads(Path(cmd[cmd.index('--input')+1]).read_text())
            calls.append((cmd, payload))
            return json.dumps(result)
        return calls, run

    def test_gitlab_reply_posts_note_under_discussion(self):
        forge = GitLab()
        self.assertTrue(callable(getattr(forge, 'reply', None)), 'GitLab.reply is required')
        calls, run = self.capture({'id': 123, 'body':'Reply'})
        with patch('auto_review.forge.gitlab.run', side_effect=run):
            receipt = forge.reply('team/service',7,'discussion-1','Reply')
        cmd, payload = calls[0]
        self.assertEqual(cmd[cmd.index('--method')+1], 'POST')
        self.assertIn('projects/team%2Fservice/merge_requests/7/discussions/discussion-1/notes',cmd)
        self.assertEqual(payload, {'body':'Reply'})
        self.assertEqual(receipt.id,'123')

    def test_gitlab_resolve_puts_resolved_true(self):
        forge = GitLab()
        self.assertTrue(callable(getattr(forge, 'resolve', None)), 'GitLab.resolve is required')
        calls, run = self.capture({})
        with patch('auto_review.forge.gitlab.run',side_effect=run):
            forge.resolve('team/service',7,'discussion-1')
        cmd, payload = calls[0]
        self.assertEqual(cmd[cmd.index('--method')+1], 'PUT')
        self.assertIn('projects/team%2Fservice/merge_requests/7/discussions/discussion-1',cmd)
        self.assertEqual(payload, {'resolved':True})

    def test_github_reply_uses_root_comment_database_id(self):
        forge = GitHub()
        self.assertTrue(callable(getattr(forge, 'reply', None)), 'GitHub.reply is required')
        calls=[]
        def run(cmd, **kwargs):
            payload=json.loads(Path(cmd[cmd.index('--input')+1]).read_text()) if '--input' in cmd else None
            calls.append((cmd,payload))
            if 'graphql' in cmd:
                return json.dumps({'data':{'node':{'comments':{'nodes':[{'databaseId':101}]}}}})
            return json.dumps({'id':202,'html_url':'https://forge.invalid/#202'})
        with patch('auto_review.forge.github.run',side_effect=run):
            receipt=forge.reply('owner/repo',7,'PRRT_node','Reply')
        posts=[(c,p) for c,p in calls if 'repos/owner/repo/pulls/7/comments/101/replies' in c]
        self.assertEqual(len(posts),1)
        self.assertEqual(posts[0][1],{'body':'Reply'})
        self.assertEqual(receipt.id,'202')

    def test_github_resolve_uses_graphql_thread_node_id(self):
        forge=GitHub()
        self.assertTrue(callable(getattr(forge,'resolve',None)), 'GitHub.resolve is required')
        calls,run=self.capture({'data':{'resolveReviewThread':{'thread':{'id':'PRRT_node','isResolved':True}}}})
        with patch('auto_review.forge.github.run',side_effect=run):
            forge.resolve('owner/repo',7,'PRRT_node')
        command=' '.join(calls[0][0])
        payload=json.dumps(calls[0][1])
        self.assertIn('graphql',command)
        self.assertIn('resolveReviewThread',command+payload)
        self.assertIn('PRRT_node',command+payload)
