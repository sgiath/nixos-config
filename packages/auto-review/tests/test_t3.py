import unittest
from unittest.mock import patch

from auto_review.t3 import T3Client, T3Error
from auto_review.models import Selection
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

    def test_opencode_effort_goes_in_its_variant_option(self):
        client = T3Client()
        opencode = {"providerInstanceId": "opencode", "canRunChildTask": True, "models": [
            {"id": "cliproxy/claude-opus-5-5", "options": [{"id": "variant", "values": ["low", "high"]}]},
        ]}
        responses = {
            "t3_thread_list": {"threads": []},
            "orchestrator_capabilities": {"providers": [opencode]},
            "t3_thread_launch": {"threadId": "new"},
        }
        selection = Selection("opencode", "cliproxy/claude-opus-5-5", "high")
        with patch.object(client, "_call", side_effect=lambda tool, args: responses[tool]) as call:
            client.launch(project="project-a", title="Review MR 7", message="Review brief",
                          selection=selection, client_request_id=self.request_id)
            catalog = client.catalog()
        [launch] = [c for c in call.call_args_list if c.args[0] == "t3_thread_launch"]
        self.assertEqual(launch.args[1]["modelSelection"]["options"], [{"id": "variant", "value": "high"}])
        self.assertEqual(catalog[0]["models"][0]["efforts"], ["low", "high"])


class LinkTest(unittest.TestCase):
    def test_link_attaches_review_url_and_accepts_already_linked_response(self):
        client = T3Client()
        for already_linked in (False, True):
            with self.subTest(already_linked=already_linked):
                with patch.object(client, "_call", return_value={"alreadyLinked": already_linked}) as call:
                    self.assertIsNone(client.link("thread-7", "https://forge.invalid/7"))
                call.assert_called_once_with("link_pull_request", {
                    "threadId": "thread-7", "url": "https://forge.invalid/7",
                })
