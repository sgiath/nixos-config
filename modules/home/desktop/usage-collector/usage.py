#!/usr/bin/env python3
"""Subscription usage for the Quickshell usage panel.

Codex, Claude and Grok accounts are read through CLIProxyAPI's management
API: its credential list names every logged-in account, and its api-call
forwards a fixed usage GET with that account's token, which the proxy keeps
fresh. Nothing here refreshes, mints or writes credentials. Muse keeps its own
native login (it is not routed through the proxy, and the proxy can only get
its quota by minting a key), read through the usage frame of a minimal
response made with its CLI's key.

Prints one JSON document: {generatedAt, reports: [{provider, metadata,
limits, error?}]}. A limit's `amount.used` is null when the provider names a
window without saying how much of it is used; that is unknown, not zero.
"""

import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

MINUTE_MS = 60 * 1000
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


class ProviderError(Exception):
    """A provider failure whose message is safe to show in the panel."""


def failed(provider, error):
    return {"provider": provider, "metadata": {}, "limits": [], "error": error}


def collect(fetchers, env, timeout=40):
    """Run every `(provider, fetch)` at once; a failure only empties its own report.

    One provider can have several accounts, so results are kept by position.
    """
    results = {}

    def run(index, provider, fetch):
        try:
            results[index] = fetch(env)
        except ProviderError as error:
            results[index] = failed(provider, str(error))
        except Exception as error:
            # Messages of unexpected errors may quote file or response contents.
            results[index] = failed(provider, type(error).__name__)

    threads = [threading.Thread(target=run, args=(i, *fetcher), daemon=True) for i, fetcher in enumerate(fetchers)]
    for thread in threads:
        thread.start()
    deadline = time.monotonic() + timeout
    for thread in threads:
        thread.join(max(0, deadline - time.monotonic()))
    reports = [results.get(i) or failed(provider, "timed out") for i, (provider, _) in enumerate(fetchers)]
    return {"generatedAt": int(time.time() * 1000), "reports": reports}


def window(duration_ms, resets_at):
    minutes = duration_ms // MINUTE_MS
    if minutes % 1440 == 0:
        count, short, unit = minutes // 1440, "d", "day"
    elif minutes % 60 == 0:
        count, short, unit = minutes // 60, "h", "hour"
    else:
        count, short, unit = minutes, "m", "minute"
    return {
        "id": f"{count}{short}",
        "label": f"{count} {unit}{'' if count == 1 else 's'}",
        "durationMs": duration_ms,
        "resetsAt": resets_at,
    }


def percent(used):
    """Amount for a 0..100 percentage; `used=None` keeps the quota unknown."""
    if used is None:
        return {"unit": "percent", "used": None, "limit": 100, "usedFraction": None}
    return {"unit": "percent", "used": used, "limit": 100, "usedFraction": used / 100}


def limit(id, label, win, amount):
    used = amount["usedFraction"]
    status = "unknown" if used is None else "exhausted" if used >= 1 else "ok"
    return {"id": id, "label": label, "window": win, "amount": amount, "status": status}


def number(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


# Codex


def codex_report(email, usage):
    """Body of chatgpt.com/backend-api/wham/usage for one account."""

    def rows(rate, id_prefix, name):
        out = []
        for slot in ("primary", "secondary"):
            entry = (rate or {}).get(f"{slot}_window")
            seconds = number((entry or {}).get("limit_window_seconds"))
            if not seconds:
                continue
            resets = number(entry.get("reset_at"))
            win = window(int(seconds) * 1000, int(resets * 1000) if resets else 0)
            label = win["label"] if name is None else f"{name} {win['label']}"
            out.append(limit(f"{id_prefix}:{slot}", label, win, percent(number(entry.get("used_percent")))))
        return out

    limits = rows(usage.get("rate_limit"), "openai-codex", None)
    for extra in usage.get("additional_rate_limits") or []:
        name = (extra.get("limit_name") or extra.get("metered_feature")) if isinstance(extra, dict) else None
        if isinstance(name, str) and slug(name):
            limits += rows(extra.get("rate_limit"), f"openai-codex:{slug(name)}", name)
    return {
        "provider": "openai-codex",
        "metadata": {"email": email, "planType": usage.get("plan_type")},
        "limits": limits,
    }


# Claude


def iso_ms(value):
    try:
        return (datetime.fromisoformat(value) - EPOCH) // timedelta(milliseconds=1)
    except (TypeError, ValueError):
        return 0


# Account-wide buckets: `get_usage` key, the `limits[]` kind that mirrors it,
# window and the label the panel has always shown.
CLAUDE_SHARED = [
    ("five_hour", "session", 5 * 60 * MINUTE_MS, "5h", "Claude 5 Hour"),
    ("seven_day", "weekly_all", 7 * 1440 * MINUTE_MS, "7d", "Claude 7 Day"),
]


def claude_report(account, response):
    """`account` ({email}) and `response` ({rate_limits_available, rate_limits,
    subscription_type}), where `rate_limits` is the body of
    api.anthropic.com/api/oauth/usage (optionally with `model_scoped`).
    Null buckets are omitted, never zero; `is_active` only marks the binding
    limit, so inactive scoped rows stay.
    """
    report = {
        "provider": "anthropic",
        "metadata": {"email": account.get("email"), "planType": response.get("subscription_type")},
        "limits": [],
    }
    rates = response.get("rate_limits")
    if not response.get("rate_limits_available") or not isinstance(rates, dict):
        report["error"] = "rate limits unavailable"
        return report
    listed = [entry for entry in rates.get("limits") or [] if isinstance(entry, dict)]

    for key, kind, duration, suffix, label in CLAUDE_SHARED:
        top = rates.get(key) if isinstance(rates.get(key), dict) else None
        mirror = next((entry for entry in listed if entry.get("kind") == kind), None)
        if top is None and mirror is None:
            continue
        used = number((top or {}).get("utilization"))
        resets = iso_ms((top or {}).get("resets_at"))
        if used is None and mirror is not None:
            used = number(mirror.get("percent"))
            resets = resets or iso_ms(mirror.get("resets_at"))
        report["limits"].append(limit(f"anthropic:{suffix}", label, window(duration, resets), percent(used)))

    scoped = {}
    for entry in listed:
        name = ((entry.get("scope") or {}).get("model") or {}).get("display_name")
        if entry.get("kind") == "weekly_scoped" and isinstance(name, str):
            scoped.setdefault(name, (number(entry.get("percent")), entry.get("resets_at")))
    for entry in rates.get("model_scoped") or []:
        name = entry.get("display_name") if isinstance(entry, dict) else None
        if isinstance(name, str):
            scoped.setdefault(name, (number(entry.get("utilization")), entry.get("resets_at")))
    for name, (used, resets) in scoped.items():
        win = window(7 * 1440 * MINUTE_MS, iso_ms(resets))
        report["limits"].append(limit(f"anthropic:7d:{slug(name)}", f"Claude 7 Day ({name})", win, percent(used)))
    return report


# Grok

GROK_PRODUCTS = {"GrokBuild": "Grok Build", "Api": "API"}


def grok_report(email, billing):
    """Weekly credits view of the billing endpoint.

    xAI omits `creditUsagePercent` (and product rows) until something is
    metered, so a missing percentage is unknown rather than zero.
    """
    report = {"provider": "xai-oauth", "metadata": {"email": email, "planType": None}, "limits": []}
    config = billing.get("config") if isinstance(billing, dict) else None
    period = (config or {}).get("currentPeriod")
    if not isinstance(period, dict) or "WEEK" not in str(period.get("type", "")).upper():
        # FIXME: only the weekly SuperGrok credits view is read. An account
        # billed monthly (positive `monthlyLimit` on `/v1/billing` without
        # `format`) shows this error; read that view once such an account exists.
        report["error"] = "no weekly billing period"
        return report
    win = window(7 * 1440 * MINUTE_MS, iso_ms(period.get("end")))

    def row(id, label, value):
        used = number(value)
        return limit(id, label, win, percent(used if used is not None and 0 <= used <= 100 else None))

    report["limits"].append(row("xai-oauth:credits:1w", "SuperGrok Weekly Credits", config.get("creditUsagePercent")))
    for item in config.get("productUsage") or []:
        product = str(item.get("product") or "").strip() if isinstance(item, dict) else ""
        if slug(product):
            label = f"{GROK_PRODUCTS.get(product, product)} (Weekly)"
            report["limits"].append(row(f"xai-oauth:product:{slug(product)}:1w", label, item.get("usagePercent")))
    return report


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """A bearer token must not follow a redirect to another host."""

    def redirect_request(self, *args):
        return None


# CLIProxyAPI

CLIPROXY_URL = "https://cliproxy.sgiath.dev"
CLIPROXY_KEY_FILE = "/run/secrets/cliproxyapi_management"

# Proxy provider -> (report provider, fixed usage GET, its headers, report).
# Only these URLs are ever sent through api-call: it attaches the account's
# token to whatever it is given.
USAGE = {
    "codex": (
        "openai-codex",
        "https://chatgpt.com/backend-api/wham/usage",
        {"Authorization": "Bearer $TOKEN$", "Accept": "application/json"},
        lambda email, body: codex_report(email, body),
    ),
    "claude": (
        "anthropic",
        "https://api.anthropic.com/api/oauth/usage",
        {"Authorization": "Bearer $TOKEN$", "Accept": "application/json", "anthropic-beta": "oauth-2025-04-20"},
        lambda email, body: claude_report({"email": email}, {"rate_limits_available": True, "rate_limits": body}),
    ),
    "xai": (
        "xai-oauth",
        "https://cli-chat-proxy.grok.com/v1/billing?format=credits",
        {"Authorization": "Bearer $TOKEN$", "Accept": "application/json", "X-XAI-Token-Auth": "xai-grok-cli"},
        lambda email, body: grok_report(email, body),
    ),
}


class CLIProxy:
    """CLIProxyAPI's management API, authenticated with the management key."""

    def __init__(self, env):
        self.url = (env.get("CLIPROXY_MANAGEMENT_URL") or CLIPROXY_URL).rstrip("/")
        path = env.get("CLIPROXY_MANAGEMENT_KEY_FILE") or CLIPROXY_KEY_FILE
        try:
            self.key = Path(path).read_text().strip()
        except OSError:
            raise ProviderError("no cliproxy management key") from None

    def request(self, path, body=None):
        request = urllib.request.Request(
            self.url + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {self.key}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=20) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise ProviderError(f"cliproxy HTTP {error.code}") from None
        except (urllib.error.URLError, OSError):
            raise ProviderError("cliproxy unreachable") from None

    def accounts(self):
        """(proxy provider, email, auth_index) of every enabled login with a usage reader."""
        files = self.request("/v8/management/credentials").get("files") or []
        return [
            (f["provider"], f.get("email") or f.get("label"), f["auth_index"])
            for f in files
            if isinstance(f, dict) and f.get("provider") in USAGE and isinstance(f.get("auth_index"), str) and not f.get("disabled")
        ]

    def usage(self, provider, auth_index):
        _, url, headers, _ = USAGE[provider]
        reply = self.request("/v8/management/requests/api-call", {"auth_index": auth_index, "method": "GET", "url": url, "header": headers})
        status = reply.get("status_code")
        if status in (401, 403):
            raise ProviderError("login expired")
        if status != 200:
            raise ProviderError(f"usage HTTP {status}")
        return json.loads(reply.get("body") or "null") or {}


def cliproxy_fetchers(env):
    """One fetcher per proxied account; a failed listing keeps one failed card per provider."""

    def unavailable(error):
        def fetch(env):
            raise ProviderError(error)

        return fetch

    try:
        proxy = CLIProxy(env)
        accounts = proxy.accounts()
    except ProviderError as error:
        return [(USAGE[p][0], unavailable(str(error))) for p in USAGE]

    def fetcher(provider, email, auth_index):
        return lambda env: USAGE[provider][3](email, proxy.usage(provider, auth_index))

    return [(USAGE[p][0], fetcher(p, email, index)) for p, email, index in accounts]


# Muse

# Meta has no read-only quota endpoint: usage arrives only as the
# `response.subscription_usage` frame closing a model stream (or from minting a
# new API key, which this must not do). So each refresh pays for the cheapest
# response the API accepts, and may start a 5-hour window while idle.
MUSE_BASE = "https://api.meta.ai/v1"
MUSE_PROBE = {"model": "muse-spark-1.2-contributor", "input": "Reply with: ok", "max_output_tokens": 16, "store": False, "stream": True}


def muse_credential(env):
    """(API key, base URL, email) the Muse CLI would use."""
    # The CLI lets this override its account login.
    if env.get("META_API_KEY", "").strip():
        return env["META_API_KEY"].strip(), MUSE_BASE, None
    config = Path(env.get("XDG_CONFIG_HOME", "").strip() or Path(env.get("HOME", "~"), ".config")).expanduser()
    try:
        entry = json.loads((config / "muse" / "auth.json").read_text())["providers"]["meta"]
    except (FileNotFoundError, KeyError):
        raise ProviderError("not logged in") from None
    key = entry.get("api_key")
    if not isinstance(key, str) or not key.strip():
        raise ProviderError("not logged in")
    return key.strip(), entry.get("api_base_url") or MUSE_BASE, entry.get("user_email")


def muse_subscription(lines):
    """The `subscription` of the stream's `response.subscription_usage` frame."""
    for line in lines:
        if not line.startswith(b"data:"):
            continue
        try:
            frame = json.loads(line[5:])
        except ValueError:
            continue
        if isinstance(frame, dict) and frame.get("type") == "response.subscription_usage":
            return frame.get("subscription") or {}
    raise ProviderError("no subscription usage")


def muse_report(email, subscription):
    report = {"provider": "meta-muse", "metadata": {"email": email, "planType": None}, "limits": []}
    current = subscription.get("window") or {}
    mins = number(current.get("window_duration_mins"))
    if mins:
        win = window(int(mins) * MINUTE_MS, int(number(current.get("resets_at")) or 0) * 1000)
        report["limits"].append(limit(f"meta-muse:{win['id']}", win["label"], win, percent(number(current.get("used_percent")))))
    weekly = subscription.get("weekly") or {}
    if weekly:
        win = window(7 * 1440 * MINUTE_MS, int(number(weekly.get("resets_at")) or 0) * 1000)
        report["limits"].append(limit("meta-muse:7d", win["label"], win, percent(number(weekly.get("used_percent")))))
    return report


def muse_fetch(env):
    """Reads the frame from the smallest response the Muse API will stream."""
    key, base, email = muse_credential(env)
    request = urllib.request.Request(
        base.rstrip("/") + "/responses",
        data=json.dumps(MUSE_PROBE).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json", "Accept": "text/event-stream"},
    )
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=20) as response:
            return muse_report(email, muse_subscription(response))
    except urllib.error.HTTPError as error:
        # The CLI re-mints its key on the next run after a 401.
        if error.code in (401, 403):
            raise ProviderError("login expired") from None
        # FIXME: a spent quota is refused with 429 and no usage frame, so the
        # card shows this error instead of which window is spent. Parse the
        # error body's reset time once a real 429 body has been captured.
        raise ProviderError("quota exhausted" if error.code == 429 else f"responses HTTP {error.code}") from None
    except (urllib.error.URLError, OSError):
        raise ProviderError("responses unreachable") from None


def main():
    env = dict(os.environ)
    fetchers = cliproxy_fetchers(env) + [("meta-muse", muse_fetch)]
    json.dump(collect(fetchers, env), sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
