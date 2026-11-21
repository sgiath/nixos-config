import http.server
import json
import tempfile
import threading
import unittest
from pathlib import Path

import usage

HOUR_MS = 60 * 60 * 1000
WEEK_MS = 7 * 24 * HOUR_MS


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
                    "window": {"id": "5h", "label": "5 hours", "durationMs": 5 * HOUR_MS, "resetsAt": 1792000000000},
                    "amount": {"unit": "percent", "used": 100, "limit": 100, "usedFraction": 1.0},
                    "status": "exhausted",
                },
            ],
        )

    def test_reads_passive_codex_signals_including_scoped_limits(self):
        now = 1795200000000
        account = {
            "provider": "codex",
            "email": "me@example.com",
            "quota": {
                "observed_at": "2026-11-20T18:37:15.929039293Z",
                "signals": {
                    "X-Codex-Plan-Type": "pro",
                    "X-Codex-Primary-Window-Minutes": "10080",
                    "X-Codex-Primary-Used-Percent": "59",
                    "X-Codex-Primary-Reset-At": "1795468176",
                    "X-Codex-Secondary-Window-Minutes": "0",
                    "X-Codex-Secondary-Used-Percent": "0",
                },
            },
            "model_quotas": {
                "gpt-5.3-codex-spark": {
                    "observed_at": "2026-11-20T18:30:00Z",
                    "signals": {
                        "X-Codex-Primary-Window-Minutes": "10080",
                        "X-Codex-Primary-Used-Percent": "55",
                        "X-Codex-Primary-Reset-At": "1795468176",
                        "X-Codex-Bengalfox-Limit-Name": "GPT-5.3-Codex-Spark",
                        "X-Codex-Bengalfox-Primary-Window-Minutes": "300",
                        "X-Codex-Bengalfox-Primary-Used-Percent": "35",
                        "X-Codex-Bengalfox-Primary-Reset-After-Seconds": "3600",
                    },
                }
            },
        }

        report = usage.codex_signals_report(account, now=now)

        self.assertEqual(report["provider"], "openai-codex")
        self.assertEqual(report["metadata"], {"email": "me@example.com", "planType": "pro"})
        rows = {row["id"]: row for row in report["limits"]}
        self.assertEqual(list(rows), ["openai-codex:primary", "openai-codex:gpt-5-3-codex-spark:primary"])
        self.assertEqual(rows["openai-codex:primary"]["amount"]["usedFraction"], 0.59)
        self.assertEqual(rows["openai-codex:primary"]["window"]["resetsAt"], 1795468176000)
        self.assertEqual(rows["openai-codex:gpt-5-3-codex-spark:primary"]["label"], "GPT-5.3-Codex-Spark 5 hours")
        self.assertEqual(rows["openai-codex:gpt-5-3-codex-spark:primary"]["amount"]["usedFraction"], 0.35)
        self.assertEqual(
            rows["openai-codex:gpt-5-3-codex-spark:primary"]["window"]["resetsAt"],
            usage.iso_ms("2026-11-20T18:30:00Z") + 3600 * 1000,
        )

    def test_expired_passive_codex_signals_return_none(self):
        account = {
            "provider": "codex",
            "email": "me@example.com",
            "quota": {
                "observed_at": "2026-11-10T00:00:00Z",
                "signals": {
                    "X-Codex-Primary-Window-Minutes": "10080",
                    "X-Codex-Primary-Used-Percent": "80",
                    "X-Codex-Primary-Reset-At": "1795000000",
                },
            },
        }

        self.assertIsNone(usage.codex_signals_report(account, now=1795000000000))


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
        self.assertEqual(rows["anthropic:5h"]["window"]["durationMs"], 5 * HOUR_MS)
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

    def test_reads_passive_claude_signals_merging_model_quotas_and_ignoring_overage(self):
        now = 1795200000000
        account = {
            "provider": "claude",
            "email": "work@example.com",
            "quota": {
                "observed_at": "2026-11-20T18:37:15.393905554Z",
                "signals": {
                    "Anthropic-Ratelimit-Unified-5h-Reset": "1795208400",
                    "Anthropic-Ratelimit-Unified-5h-Status": "allowed",
                    "Anthropic-Ratelimit-Unified-5h-Utilization": "0.89",
                    "Anthropic-Ratelimit-Unified-7d-Reset": "1795719600",
                    "Anthropic-Ratelimit-Unified-7d-Status": "allowed",
                    "Anthropic-Ratelimit-Unified-7d-Utilization": "0.47",
                    "Anthropic-Ratelimit-Unified-Overage-Reset": "1796083200",
                    "Anthropic-Ratelimit-Unified-Overage-Status": "allowed_warning",
                    "Anthropic-Ratelimit-Unified-Overage-Utilization": "0.97",
                },
            },
            "model_quotas": {
                "claude-fable-5-2": {
                    "observed_at": "2026-11-20T18:34:56.290548541Z",
                    "signals": {
                        "Anthropic-Ratelimit-Unified-5h-Reset": "1795208400",
                        "Anthropic-Ratelimit-Unified-5h-Utilization": "0.88",
                        "Anthropic-Ratelimit-Unified-7d-Reset": "1795719600",
                        "Anthropic-Ratelimit-Unified-7d-Utilization": "0.47",
                        "Anthropic-Ratelimit-Unified-7d_oi-Reset": "1795719600",
                        "Anthropic-Ratelimit-Unified-7d_oi-Status": "allowed",
                        "Anthropic-Ratelimit-Unified-7d_oi-Utilization": "0.22",
                    },
                },
                "claude-sonnet-5-5": {
                    "observed_at": "2026-11-20T18:35:00Z",
                    "signals": {
                        "Anthropic-Ratelimit-Unified-7d_sonnet-Reset": "1795719600",
                        "Anthropic-Ratelimit-Unified-7d_sonnet-Status": "rejected",
                    },
                },
            },
        }

        report = usage.claude_signals_report(account, now=now)

        self.assertEqual(report["provider"], "anthropic")
        self.assertEqual(report["metadata"], {"email": "work@example.com", "planType": None})
        rows = {row["id"]: row for row in report["limits"]}
        self.assertEqual(list(rows), ["anthropic:5h", "anthropic:7d", "anthropic:7d:fable", "anthropic:7d:sonnet"])
        self.assertEqual(rows["anthropic:5h"]["amount"]["usedFraction"], 0.89)
        self.assertEqual(rows["anthropic:5h"]["window"]["resetsAt"], 1795208400000)
        self.assertEqual(rows["anthropic:7d"]["amount"]["usedFraction"], 0.47)
        self.assertEqual(rows["anthropic:7d:fable"]["label"], "Claude 7 Day (Fable)")
        self.assertEqual(rows["anthropic:7d:fable"]["amount"]["usedFraction"], 0.22)
        self.assertEqual(rows["anthropic:7d:sonnet"]["label"], "Claude 7 Day (Sonnet)")
        self.assertEqual(rows["anthropic:7d:sonnet"]["amount"]["usedFraction"], 1.0)
        self.assertEqual(rows["anthropic:7d:sonnet"]["status"], "exhausted")

    def test_passive_claude_signals_drop_expired_windows(self):
        account = {
            "provider": "claude",
            "email": "work@example.com",
            "quota": {
                "observed_at": "2026-11-20T18:00:00Z",
                "signals": {
                    "Anthropic-Ratelimit-Unified-5h-Reset": "1795208400",
                    "Anthropic-Ratelimit-Unified-5h-Utilization": "0.89",
                    "Anthropic-Ratelimit-Unified-7d-Reset": "1795719600",
                    "Anthropic-Ratelimit-Unified-7d-Utilization": "0.47",
                },
            },
        }

        # After 5h rolled over, 7d stays valid.
        report = usage.claude_signals_report(account, now=1795210000000)
        self.assertEqual([r["id"] for r in report["limits"]], ["anthropic:7d"])

        # After 7d also rolled over, passive signals are exhausted -> None.
        self.assertIsNone(usage.claude_signals_report(account, now=1795720000000))


class AntigravityReportTest(unittest.TestCase):
    def test_normalizes_quota_summary_groups_and_converts_remaining_to_used(self):
        summary = {
            "groups": [
                {
                    "displayName": "Gemini Models",
                    "buckets": [
                        {
                            "bucketId": "gemini-weekly",
                            "displayName": "Weekly Limit Remaining",
                            "window": "weekly",
                            "resetTime": "2026-11-27T17:14:37Z",
                            "remainingFraction": 0.9928834,
                        },
                        {
                            "bucketId": "gemini-5h",
                            "displayName": "Five Hour Limit Remaining",
                            "window": "5h",
                            "resetTime": "2026-11-20T22:14:37Z",
                            "remainingFraction": 0,
                        },
                    ],
                },
                {
                    "displayName": "Claude and GPT models",
                    "buckets": [
                        {
                            "bucketId": "3p-weekly",
                            "window": "weekly",
                            "resetTime": "2026-11-27T18:37:52Z",
                            "remainingFraction": 1,
                        },
                        {
                            "bucketId": "3p-5h",
                            "window": "5h",
                            "resetTime": "2026-11-20T23:37:52Z",
                        },
                    ],
                },
            ]
        }

        report = usage.antigravity_report("me@gmail.com", summary)

        self.assertEqual(report["provider"], "google-gemini")
        self.assertEqual(report["metadata"], {"email": "me@gmail.com", "planType": None})
        rows = {row["id"]: row for row in report["limits"]}
        self.assertEqual(
            list(rows),
            ["google-gemini:gemini-5h", "google-gemini:gemini-weekly", "google-gemini:3p-5h", "google-gemini:3p-weekly"],
        )
        self.assertEqual(rows["google-gemini:gemini-5h"]["label"], "Gemini 5 Hour")
        self.assertEqual(rows["google-gemini:gemini-5h"]["window"]["durationMs"], 5 * HOUR_MS)
        self.assertEqual(rows["google-gemini:gemini-5h"]["amount"]["usedFraction"], 1.0)
        self.assertEqual(rows["google-gemini:gemini-5h"]["status"], "exhausted")
        self.assertEqual(rows["google-gemini:gemini-weekly"]["label"], "Gemini 7 Day")
        self.assertEqual(rows["google-gemini:gemini-weekly"]["window"]["durationMs"], WEEK_MS)
        self.assertAlmostEqual(rows["google-gemini:gemini-weekly"]["amount"]["usedFraction"], 0.0071166, places=6)
        self.assertEqual(rows["google-gemini:gemini-weekly"]["status"], "ok")
        self.assertEqual(rows["google-gemini:3p-5h"]["label"], "Claude and GPT 5 Hour")
        self.assertIsNone(rows["google-gemini:3p-5h"]["amount"]["used"])
        self.assertEqual(rows["google-gemini:3p-5h"]["status"], "unknown")
        self.assertEqual(rows["google-gemini:3p-weekly"]["label"], "Claude and GPT 7 Day")
        self.assertEqual(rows["google-gemini:3p-weekly"]["amount"]["usedFraction"], 0.0)

    def test_empty_summary_is_an_error(self):
        report = usage.antigravity_report("me@gmail.com", {"groups": []})

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

    def serve(self, routes, cache_file=None):
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
        tmp = Path(tempfile.mkdtemp())
        key = tmp / "key"
        key.write_text("management-key\n")
        env = {
            "CLIPROXY_MANAGEMENT_URL": f"http://127.0.0.1:{server.server_port}",
            "CLIPROXY_MANAGEMENT_KEY_FILE": str(key),
        }
        if cache_file is not None:
            env["SGIATH_USAGE_CACHE"] = str(cache_file)
        return env, requests

    def test_passive_accounts_skip_api_call_and_antigravity_posts_quota_summary(self):
        future = int(usage.now_ms() / 1000) + 3600
        files = [
            {
                "provider": "claude",
                "email": "work@example.com",
                "auth_index": "a1",
                "quota": {
                    "observed_at": "2026-11-20T18:30:00Z",
                    "signals": {
                        "Anthropic-Ratelimit-Unified-7d-Utilization": "0.42",
                        "Anthropic-Ratelimit-Unified-7d-Reset": str(future),
                    },
                },
            },
            {"provider": "claude", "email": "me@example.com", "auth_index": "a2", "quota": {"signals": {}}},
            {"provider": "codex", "email": "me@example.com", "auth_index": "c1", "disabled": True},
            {"provider": "antigravity", "email": "me@gmail.com", "auth_index": "g1", "project_id": "aicode-consumers"},
            {"provider": "meta", "email": "me@example.com", "auth_index": "m1"},
        ]
        claude_fallback = {"seven_day": {"utilization": 19.0, "resets_at": "2099-11-09T10:00:00+00:00"}}
        ag_summary = {
            "groups": [
                {
                    "displayName": "Gemini Models",
                    "buckets": [
                        {"bucketId": "gemini-weekly", "window": "weekly", "resetTime": "2099-11-27T17:14:37Z", "remainingFraction": 0.9},
                    ],
                }
            ]
        }

        def routes(path, body):
            if path == "/v8/management/credentials":
                return 200, {"files": files}
            if body["auth_index"] == "g1":
                return 200, {"status_code": 200, "body": json.dumps(ag_summary)}
            return 200, {"status_code": 200, "body": json.dumps(claude_fallback)}

        env, requests = self.serve(routes)
        reports = usage.collect(usage.cliproxy_fetchers(env), env)["reports"]

        self.assertEqual(
            [(r["provider"], r["metadata"]["email"]) for r in reports],
            [("anthropic", "work@example.com"), ("anthropic", "me@example.com"), ("google-gemini", "me@gmail.com")],
        )
        self.assertEqual(reports[0]["limits"][0]["amount"]["usedFraction"], 0.42)
        self.assertEqual(reports[1]["limits"][0]["amount"]["usedFraction"], 0.19)
        self.assertAlmostEqual(reports[2]["limits"][0]["amount"]["usedFraction"], 0.1, places=6)
        self.assertTrue(all(auth == "Bearer management-key" for _, _, auth, _ in requests))

        # a1 used passive signals (zero api-call); only idle a2 and antigravity g1 used api-call.
        calls = {body["auth_index"]: body for _, path, _, body in requests if path == "/v8/management/requests/api-call"}
        self.assertEqual(sorted(calls), ["a2", "g1"])
        self.assertEqual(calls["a2"]["method"], "GET")
        self.assertEqual(calls["a2"]["url"], "https://api.anthropic.com/api/oauth/usage")
        self.assertTrue(calls["a2"]["header"]["User-Agent"].startswith("claude-cli/"))
        self.assertEqual(calls["g1"]["method"], "POST")
        self.assertEqual(calls["g1"]["url"], "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")
        self.assertEqual(json.loads(calls["g1"]["data"]), {"project": "aicode-consumers"})

    def test_fallback_cache_avoids_repeated_calls_and_rides_out_429(self):
        cache_file = Path(tempfile.mkdtemp()) / "fallback.json"
        files = [{"provider": "claude", "email": "me@example.com", "auth_index": "a2", "quota": {"signals": {}}}]
        state = {"status": 200, "body": {"seven_day": {"utilization": 54.0, "resets_at": "2099-11-09T10:00:00+00:00"}}, "header": {}}

        def routes(path, body):
            if path == "/v8/management/credentials":
                return 200, {"files": files}
            return 200, {"status_code": state["status"], "header": state["header"], "body": json.dumps(state["body"])}

        env, requests = self.serve(routes, cache_file=cache_file)
        proxy = usage.CLIProxy(env)
        cache = usage.FallbackCache(cache_file)
        t0 = 1795200000000

        # First call populates the cache.
        r1 = usage.fetch_cliproxy_account(proxy, cache, files[0], now=t0)
        self.assertEqual(r1["limits"][0]["amount"]["usedFraction"], 0.54)
        self.assertEqual(sum(1 for _, p, _, _ in requests if "api-call" in p), 1)

        # Within TTL: served from cache with no api-call.
        r2 = usage.fetch_cliproxy_account(proxy, cache, files[0], now=t0 + 5 * usage.MINUTE_MS)
        self.assertEqual(r2["limits"][0]["amount"]["usedFraction"], 0.54)
        self.assertEqual(sum(1 for _, p, _, _ in requests if "api-call" in p), 1)

        # Past TTL with upstream 429: backs off and returns the last known unexpired limits.
        state.update({"status": 429, "header": {"Retry-After": ["1200"]}, "body": {"error": "rate_limit"}})
        r3 = usage.fetch_cliproxy_account(proxy, cache, files[0], now=t0 + 35 * usage.MINUTE_MS)
        self.assertEqual(r3["limits"][0]["amount"]["usedFraction"], 0.54)
        self.assertEqual(sum(1 for _, p, _, _ in requests if "api-call" in p), 2)

        # During backoff window: does not hit upstream again.
        r4 = usage.fetch_cliproxy_account(proxy, cache, files[0], now=t0 + 45 * usage.MINUTE_MS)
        self.assertEqual(r4["limits"][0]["amount"]["usedFraction"], 0.54)
        self.assertEqual(sum(1 for _, p, _, _ in requests if "api-call" in p), 2)

        # Uncached account hitting 429 raises ProviderError.
        fresh = {"provider": "claude", "email": "other@example.com", "auth_index": "a9", "quota": {"signals": {}}}
        with self.assertRaisesRegex(usage.ProviderError, "usage HTTP 429"):
            usage.fetch_cliproxy_account(proxy, cache, fresh, now=t0 + 45 * usage.MINUTE_MS)

    def test_an_expired_login_or_unreachable_proxy_keeps_the_cards(self):
        files = [{"provider": "xai", "email": "me@example.com", "auth_index": "x1"}]
        env, _ = self.serve(lambda path, body: (200, {"files": files}) if "credentials" in path else (200, {"status_code": 401, "body": "{}"}))
        self.assertEqual(usage.collect(usage.cliproxy_fetchers(env), env)["reports"], [usage.failed("xai-oauth", "login expired")])

        down = {"CLIPROXY_MANAGEMENT_URL": "http://127.0.0.1:9", "CLIPROXY_MANAGEMENT_KEY_FILE": env["CLIPROXY_MANAGEMENT_KEY_FILE"]}
        reports = usage.collect(usage.cliproxy_fetchers(down), down)["reports"]
        self.assertEqual(reports, [usage.failed(p, "cliproxy unreachable") for p in ("openai-codex", "anthropic", "google-gemini", "xai-oauth")])


if __name__ == "__main__":
    unittest.main()
