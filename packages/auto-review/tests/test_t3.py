import unittest
from unittest.mock import patch

from auto_review.t3 import T3Client, T3Error
from tests.fakes import SELECTION


class LaunchIdentityTest(unittest.TestCase):
    request_id = "auto-review:db123abc:42:2"
    tag = "(review db123abc.42.2)"

    def launch(self, client):
        return client.launch(project="project-a", title="Review MR 7", message="Review brief",
                             selection=SELECTION, client_request_id=self.request_id)

    def test_adopts_single_thread_with_exact_instance_tag_suffix(self):
        threads = [
            {"threadId": "other-instance", "title": "Review MR 7 (review other.42.2)"},
            {"threadId": "not-a-suffix", "title": f"Review MR 7 {self.tag} follow-up"},
            {"threadId": "existing", "title": f"Review MR 7 {self.tag}",
             "latestRunId": "run-existing", "link": "t3-thread://existing"},
        ]
        client = T3Client()
        with patch.object(client, "_call", return_value={"threads": threads}) as call:
            result = self.launch(client)
        self.assertEqual(result, {"thread_id": "existing", "run_id": "run-existing",
                                  "url": "t3-thread://existing"})
        call.assert_called_once_with("t3_thread_list", {
            "projectId": "project-a", "titleContains": self.tag, "includeSubagents": False, "limit": 100,
        })

    def test_duplicate_instance_tags_raise_instead_of_adopting_or_launching(self):
        client = T3Client()
        threads = [{"threadId": thread_id, "title": f"Review {self.tag}"} for thread_id in ("one", "two")]
        with patch.object(client, "_call", return_value={"threads": threads}) as call:
            with self.assertRaises(T3Error):
                self.launch(client)
        self.assertEqual(call.call_count, 1)
        self.assertEqual(call.call_args.args[0], "t3_thread_list")

    def test_no_matching_tag_launches_with_instance_tag_appended_to_title(self):
        client = T3Client()
        responses = {
            "t3_thread_list": {"threads": [
                {"threadId": "old", "title": "Review MR 7 (review other.42.2)"},
                {"threadId": "follow-up", "title": f"Review {self.tag} follow-up"},
            ]},
            "orchestrator_capabilities": {"providers": []},
            "t3_thread_launch": {"threadId": "new", "runId": "run-new", "link": "t3-thread://new"},
        }
        with patch.object(client, "_call", side_effect=lambda tool, args: responses[tool]) as call:
            result = self.launch(client)
        self.assertEqual(result, {"thread_id": "new", "run_id": "run-new", "url": "t3-thread://new"})
        [launch] = [c for c in call.call_args_list if c.args[0] == "t3_thread_launch"]
        self.assertEqual(launch.args[1]["title"], f"Review MR 7 {self.tag}")
        self.assertEqual(launch.args[1]["clientRequestId"], self.request_id)
