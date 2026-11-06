import http.server
import json
import tempfile
import threading
import unittest
from pathlib import Path

import usage

WEEK_MS = 7 * 24 * 60 * 60 * 1000


class CodexReportTest(unittest.TestCase):
    def test_normalizes_wham_usage_windows(self):
        body = {
            "plan_type": "pro",
            "rate_limit": {
                "primary_window": {"used_percent": 6, "limit_window_seconds": 604800, "reset_at": 1792305018},
                "secondary_window": {"used_percent": 100, "limit_window_seconds": 18000, "reset_at": 1792000000},
            },
            "additional_rate_limits": None,
        }

        report = usage.codex_report("me@example.com", body)

        self.assertEqual(report["provider"], "openai-codex")
        self.assertEqual(report["metadata"], {"email": "me@example.com", "planType": "pro"})
        self.assertEqual(
            report["limits"],
            [
                {
                    "id": "openai-codex:primary",
                    "label": "7 days",
                    "window": {"id": "7d", "label": "7 days", "durationMs": WEEK_MS, "resetsAt": 1792305018000},
                    "amount": {"unit": "percent", "used": 6, "limit": 100, "usedFraction": 0.06},
                    "status": "ok",
                },
                {
                    "id": "openai-codex:secondary",
                    "label": "5 hours",
                    "window": {"id": "5h", "label": "5 hours", "durationMs": 5 * 3600000, "resetsAt": 1792000000000},
                    "amount": {"unit": "percent", "used": 100, "limit": 100, "usedFraction": 1.0},
                    "status": "exhausted",
                },
            ],
        )


class ClaudeReportTest(unittest.TestCase):
    def test_keeps_reported_windows_and_never_turns_null_into_zero(self):
        account = {"email": "me@example.com", "subscriptionType": "Claude Max"}
        response = {
            "subscription_type": "max",
            "rate_limits_available": True,
            "rate_limits": {
                # Absent top-level bucket: the `limits` session row stands in.
                "five_hour": None,
                "seven_day": {"utilization": 2, "resets_at": "2026-10-19T10:00:00+00:00"},
                "seven_day_opus": None,
                "limits": [
                    {"kind": "session", "percent": 8, "resets_at": "2026-10-12T21:50:00+00:00", "is_active": True},
                    {"kind": "weekly_all", "percent": 2, "resets_at": "2026-10-19T10:00:00+00:00", "is_active": False},
                    {
                        "kind": "weekly_scoped",
                        "percent": 0,
                        "resets_at": "2026-10-19T10:00:00+00:00",
                        "scope": {"model": {"id": None, "display_name": "Fable"}, "surface": None},
                        "is_active": False,
                    },
                ],
                "model_scoped": [
                    {"display_name": "Fable", "utilization": 0, "resets_at": "2026-10-19T10:00:00+00:00"},
                    {"display_name": "Nimbus", "utilization": None, "resets_at": "2026-10-19T10:00:00+00:00"},
                ],
            },
        }

        report = usage.claude_report(account, response)

        self.assertEqual(report["provider"], "anthropic")
        self.assertEqual(report["metadata"], {"email": "me@example.com", "planType": "max"})
        rows = {row["id"]: row for row in report["limits"]}
        self.assertEqual(list(rows), ["anthropic:5h", "anthropic:7d", "anthropic:7d:fable", "anthropic:7d:nimbus"])
        self.assertEqual(rows["anthropic:5h"]["label"], "Claude 5 Hour")
        self.assertEqual(rows["anthropic:5h"]["window"]["durationMs"], 5 * 3600000)
        self.assertEqual(rows["anthropic:5h"]["window"]["resetsAt"], 1791841800000)
        self.assertEqual(rows["anthropic:5h"]["amount"]["usedFraction"], 0.08)
        self.assertEqual(rows["anthropic:7d"]["label"], "Claude 7 Day")
        self.assertEqual(rows["anthropic:7d"]["amount"]["usedFraction"], 0.02)
        self.assertEqual(rows["anthropic:7d:fable"]["label"], "Claude 7 Day (Fable)")
        self.assertEqual(rows["anthropic:7d:fable"]["window"], {"id": "7d", "label": "7 days", "durationMs": WEEK_MS, "resetsAt": 1792404000000})
        self.assertEqual(rows["anthropic:7d:fable"]["amount"]["usedFraction"], 0)
        self.assertEqual(rows["anthropic:7d:fable"]["status"], "ok")
        self.assertIsNone(rows["anthropic:7d:nimbus"]["amount"]["used"])
        self.assertEqual(rows["anthropic:7d:nimbus"]["status"], "unknown")

    def test_unavailable_rate_limits_are_an_error_not_an_empty_quota(self):
        report = usage.claude_report({}, {"rate_limits_available": False, "rate_limits": None})

        self.assertEqual(report["limits"], [])
        self.assertIn("error", report)


class GrokReportTest(unittest.TestCase):
    PERIOD = {
        "type": "USAGE_PERIOD_TYPE_WEEKLY",
        "start": "2026-10-10T10:00:00+00:00",
        "end": "2026-10-17T10:00:00+00:00",
    }

    def test_missing_percentage_keeps_period_with_unknown_usage(self):
        billing = {"config": {"currentPeriod": self.PERIOD, "isUnifiedBillingUser": True, "onDemandUsed": {"val": 0}}}

        report = usage.grok_report("me@example.com", billing)

        self.assertEqual(report["provider"], "xai-oauth")
        self.assertEqual(report["metadata"], {"email": "me@example.com", "planType": None})
        [credits] = report["limits"]
        self.assertEqual(credits["id"], "xai-oauth:credits:1w")
        self.assertEqual(credits["label"], "SuperGrok Weekly Credits")
        self.assertEqual(credits["window"]["durationMs"], WEEK_MS)
        self.assertEqual(credits["window"]["resetsAt"], 1792231200000)
        self.assertIsNone(credits["amount"]["used"])
        self.assertIsNone(credits["amount"]["usedFraction"])
        self.assertEqual(credits["status"], "unknown")

    def test_reported_percentages_include_products_sharing_the_period(self):
        billing = {
            "config": {
                "currentPeriod": self.PERIOD,
                "creditUsagePercent": 40,
                "productUsage": [{"product": "GrokBuild", "usagePercent": 75}, {"product": "GrokChat"}],
            }
        }

        rows = {row["id"]: row for row in usage.grok_report(None, billing)["limits"]}

        self.assertEqual(list(rows), ["xai-oauth:credits:1w", "xai-oauth:product:grokbuild:1w", "xai-oauth:product:grokchat:1w"])
        self.assertEqual(rows["xai-oauth:credits:1w"]["amount"]["usedFraction"], 0.4)
        self.assertEqual(rows["xai-oauth:product:grokbuild:1w"]["label"], "Grok Build (Weekly)")
        self.assertEqual(rows["xai-oauth:product:grokbuild:1w"]["amount"]["usedFraction"], 0.75)
        self.assertEqual(rows["xai-oauth:product:grokbuild:1w"]["window"]["resetsAt"], 1792231200000)
        self.assertEqual(rows["xai-oauth:product:grokchat:1w"]["status"], "unknown")

    def test_billing_without_a_weekly_period_is_an_error(self):
        report = usage.grok_report(None, {"config": {"monthlyLimit": {"val": 0}}})

        self.assertEqual(report["limits"], [])
        self.assertIn("error", report)


class MuseReportTest(unittest.TestCase):
    def test_reads_the_subscription_frame_that_ends_a_response_stream(self):
        stream = [
            b"event: response.created\n",
            b'data: {"type":"response.created","response":{"status":"in_progress"}}\n',
            b"\n",
            b"event: response.subscription_usage\n",
            b'data: {"subscription":{"tier":"2768","weekly":{"resets_at":1792368000,"used_percent":1},'
            b'"window":{"resets_at":1791927345,"used_percent":104,"window_duration_mins":300}},'
            b'"type":"response.subscription_usage"}\n',
        ]

        report = usage.muse_report("me@example.com", usage.muse_subscription(stream))

        self.assertEqual(report["provider"], "meta-muse")
        self.assertEqual(report["metadata"], {"email": "me@example.com", "planType": None})
        rows = {row["id"]: row for row in report["limits"]}
        self.assertEqual(list(rows), ["meta-muse:5h", "meta-muse:7d"])
        self.assertEqual(rows["meta-muse:5h"]["label"], "5 hours")
        self.assertEqual(rows["meta-muse:5h"]["window"]["resetsAt"], 1791927345000)
        self.assertEqual(rows["meta-muse:5h"]["amount"]["usedFraction"], 1.04)
        self.assertEqual(rows["meta-muse:5h"]["status"], "exhausted")
        self.assertEqual(rows["meta-muse:7d"]["window"], {"id": "7d", "label": "7 days", "durationMs": WEEK_MS, "resetsAt": 1792368000000})
        self.assertEqual(rows["meta-muse:7d"]["amount"]["usedFraction"], 0.01)

    def test_a_stream_without_the_frame_is_an_error(self):
        with self.assertRaises(usage.ProviderError):
            usage.muse_subscription([b"event: response.completed\n", b'data: {"type":"response.completed"}\n'])


class CollectTest(unittest.TestCase):
    def test_failed_providers_keep_their_card_without_leaking_details(self):
        codex = {"provider": "openai-codex", "metadata": {}, "limits": [{"id": "openai-codex:primary"}]}

        def logged_out(env):
            raise usage.ProviderError("not logged in")

        def broken(env):
            raise KeyError("secret-token")

        result = usage.collect([("openai-codex", lambda env: codex), ("anthropic", logged_out), ("xai-oauth", broken)], {})

        self.assertIsInstance(result["generatedAt"], int)
        self.assertEqual(
            result["reports"],
            [
                codex,
                {"provider": "anthropic", "metadata": {}, "limits": [], "error": "not logged in"},
                {"provider": "xai-oauth", "metadata": {}, "limits": [], "error": "KeyError"},
            ],
        )



class CLIProxyTest(unittest.TestCase):
    """Against a local stand-in for CLIProxyAPI's management API."""

    def serve(self, routes):
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.reply(None)

            def do_POST(self):
                self.reply(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))

            def reply(self, body):
                requests.append((self.command, self.path, self.headers.get("Authorization"), body))
                status, payload = routes(self.path, body)
                self.send_response(status)
                self.end_headers()
                self.wfile.write(json.dumps(payload).encode())

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        key = Path(tempfile.mkdtemp()) / "key"
        key.write_text("management-key\n")
        env = {"CLIPROXY_MANAGEMENT_URL": f"http://127.0.0.1:{server.server_port}", "CLIPROXY_MANAGEMENT_KEY_FILE": str(key)}
        return env, requests

    def test_every_account_gets_a_card_from_its_fixed_usage_url(self):
        files = [
            {"provider": "claude", "email": "work@example.com", "auth_index": "a1"},
            {"provider": "claude", "email": "me@example.com", "auth_index": "a2"},
            {"provider": "codex", "email": "me@example.com", "auth_index": "c1", "disabled": True},
            {"provider": "meta", "email": "me@example.com", "auth_index": "m1"},
        ]
        claude = {"seven_day": {"utilization": 19.0, "resets_at": "2026-11-09T10:00:00+00:00"}}

        def routes(path, body):
            if path == "/v8/management/credentials":
                return 200, {"files": files}
            return 200, {"status_code": 200, "body": json.dumps(claude)}

        env, requests = self.serve(routes)
        reports = usage.collect(usage.cliproxy_fetchers(env), env)["reports"]

        self.assertEqual([(r["provider"], r["metadata"]["email"]) for r in reports], [("anthropic", "work@example.com"), ("anthropic", "me@example.com")])
        self.assertEqual(reports[0]["limits"][0]["amount"]["usedFraction"], 0.19)
        self.assertTrue(all(auth == "Bearer management-key" for _, _, auth, _ in requests))
        calls = [body for _, path, _, body in requests if path == "/v8/management/requests/api-call"]
        self.assertEqual(sorted(c["auth_index"] for c in calls), ["a1", "a2"])
        self.assertTrue(all(c["url"] == "https://api.anthropic.com/api/oauth/usage" and c["method"] == "GET" for c in calls))

    def test_an_expired_login_or_unreachable_proxy_keeps_the_cards(self):
        files = [{"provider": "xai", "email": "me@example.com", "auth_index": "x1"}]
        env, _ = self.serve(lambda path, body: (200, {"files": files}) if "credentials" in path else (200, {"status_code": 401, "body": "{}"}))
        self.assertEqual(usage.collect(usage.cliproxy_fetchers(env), env)["reports"], [usage.failed("xai-oauth", "login expired")])

        down = {"CLIPROXY_MANAGEMENT_URL": "http://127.0.0.1:9", "CLIPROXY_MANAGEMENT_KEY_FILE": env["CLIPROXY_MANAGEMENT_KEY_FILE"]}
        reports = usage.collect(usage.cliproxy_fetchers(down), down)["reports"]
        self.assertEqual(reports, [usage.failed(p, "cliproxy unreachable") for p in ("openai-codex", "anthropic", "xai-oauth")])


if __name__ == "__main__":
    unittest.main()
