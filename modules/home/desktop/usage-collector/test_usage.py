import json
import sys
import tempfile
import time
import unittest
from pathlib import Path

import usage

WEEK_MS = 7 * 24 * 60 * 60 * 1000


class CodexReportTest(unittest.TestCase):
    def test_normalizes_native_rate_limit_buckets(self):
        account = {
            "account": {"type": "chatgpt", "email": "me@example.com", "planType": "pro"},
            "requiresOpenaiAuth": True,
        }
        bucket = {
            "limitId": "codex",
            "limitName": None,
            "primary": {"usedPercent": 6, "windowDurationMins": 10080, "resetsAt": 1792305018},
            "secondary": {"usedPercent": 100, "windowDurationMins": 300, "resetsAt": 1792000000},
        }
        limits = {"rateLimits": bucket, "rateLimitsByLimitId": {"codex": bucket}}

        report = usage.codex_report(account, limits)

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


class GrokCredentialTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.env = {"GROK_HOME": str(self.home)}

    def write_auth(self, entries):
        (self.home / "auth.json").write_text(json.dumps(entries))

    def test_reads_the_default_grok_login_from_grok_home(self):
        self.write_auth(
            {
                "https://custom.example::other": {"auth_mode": "oidc", "key": "custom-token", "email": "x@example.com"},
                "https://auth.x.ai::b1a00492-073a-47ea-816f-4c329264a828": {
                    "auth_mode": "oidc",
                    "key": "default-token",
                    "email": "me@example.com",
                },
            }
        )

        self.assertEqual(usage.grok_credential(self.env), ("default-token", "me@example.com"))

    def test_never_falls_back_to_another_deployment_or_override(self):
        self.write_auth({"https://custom.example::other": {"auth_mode": "oidc", "key": "custom-token"}})
        with self.assertRaises(usage.ProviderError):
            usage.grok_credential(self.env)

        self.write_auth({"https://accounts.x.ai/sign-in": {"auth_mode": "oidc", "key": "default-token"}})
        with self.assertRaises(usage.ProviderError):
            usage.grok_credential({**self.env, "XAI_API_KEY": "different-api-account"})
        with self.assertRaises(usage.ProviderError):
            usage.grok_credential({**self.env, "GROK_CLI_CHAT_PROXY_BASE_URL": "https://proxy.example"})
        (self.home / "config.toml").write_text('[endpoints]\nchat = "https://proxy.example"\n')
        with self.assertRaises(usage.ProviderError):
            usage.grok_credential(self.env)


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

    def test_a_silent_app_is_abandoned_at_its_deadline(self):
        start = time.monotonic()
        with self.assertRaisesRegex(usage.ProviderError, "timed out"):
            with usage.Session([sys.executable, "-c", "import time; time.sleep(30)"], {}, timeout=0.5) as session:
                session.send({"id": 1, "method": "initialize"})
                session.receive(lambda message: message.get("id") == 1)
        self.assertLess(time.monotonic() - start, 5)
        self.assertIsNotNone(session.process.returncode)


if __name__ == "__main__":
    unittest.main()
