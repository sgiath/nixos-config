#!/usr/bin/env python3
"""Subscription usage for the Quickshell usage panel.

Codex and Claude accounts are read straight from CLIProxyAPI's credential
listing (`quota` and `model_quotas`, passively captured from upstream response
headers) so active accounts never touch upstream usage endpoints. Only when
the proxy has no unexpired observation (for instance an idle account after a
restart) does it fall back to `api-call`, backed by a local cache and 429
backoff so Anthropic's `/api/oauth/usage` is not hammered.

Gemini (Antigravity) and Grok accounts are not passively observed by the
proxy, so each uses one fixed `api-call` with the account's token, which the
proxy keeps fresh. Nothing here refreshes, mints or writes credentials. Muse
keeps its own native login (it is not routed through the proxy, and the proxy
can only get its quota by minting a key), read through the usage frame of a
minimal response made with its CLI's key.

Prints one JSON document: {generatedAt, reports: [{provider, metadata,
limits, error?}]}. A limit's `amount.used` is null when the provider names a
window without saying how much of it is used; that is unknown, not zero.
"""

import email.utils
import json
import math
import os
import re
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

MINUTE_MS = 60 * 1000
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)

FALLBACK_TTL_MS = 30 * MINUTE_MS
FALLBACK_STALE_MAX_MS = 6 * 60 * MINUTE_MS
FALLBACK_BACKOFF_MIN_MS = 15 * MINUTE_MS
FALLBACK_BACKOFF_MAX_MS = 60 * MINUTE_MS
CACHE_RETENTION_MS = 7 * 1440 * MINUTE_MS


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
    if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
        return value
    return None


def parse_float(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value) if math.isfinite(value) else None
    if isinstance(value, str):
        try:
            parsed = float(value.strip())
        except ValueError:
            return None
        return parsed if math.isfinite(parsed) else None
    return None


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def now_ms():
    return int(time.time() * 1000)


def iso_ms(value):
    try:
        dt = datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return 0
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return (dt - EPOCH) // timedelta(milliseconds=1)


def account_email(account):
    return account.get("email") or account.get("label")


def observations(account):
    """Passive `(observed_ms, model_id, lowercase_signals)` snapshots from a credential entry."""
    found = []

    def add(obs, model_id):
        if not isinstance(obs, dict):
            return
        raw = obs.get("signals")
        if not isinstance(raw, dict) or not raw:
            return
        signals = {k.lower(): v for k, v in raw.items() if isinstance(k, str)}
        if signals:
            found.append((iso_ms(obs.get("observed_at")), model_id, signals))

    add(account.get("quota"), None)
    model_quotas = account.get("model_quotas")
    if isinstance(model_quotas, dict):
        for model_id, obs in model_quotas.items():
            if isinstance(model_id, str):
                add(obs, model_id)
    return found


def latest_observed_ms(account):
    return max((obs_ms for obs_ms, _, _ in observations(account)), default=0)


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


CODEX_BASE = re.compile(r"^x-codex-(primary|secondary)-(used-percent|window-minutes|reset-at|reset-after-seconds)$")
CODEX_SCOPED = re.compile(r"^x-codex-([a-z0-9-]+)-(primary|secondary)-(used-percent|window-minutes|reset-at|reset-after-seconds)$")
CODEX_LIMIT_NAME = re.compile(r"^x-codex-([a-z0-9-]+)-limit-name$")


def codex_signals_report(account, now=None):
    """Build a Codex report from CLIProxyAPI's passive `X-Codex-*` observations.

    Returns None when the proxy has no unexpired window for the account.
    """
    now = now_ms() if now is None else now
    obs_list = observations(account)
    if not obs_list:
        return None

    plan_type, plan_at = None, -1
    merged = {}  # row_id -> (rank, obs_ms, name, fields)
    for obs_ms, _, signals in obs_list:
        plan = signals.get("x-codex-plan-type")
        if isinstance(plan, str) and plan.strip() and obs_ms >= plan_at:
            plan_type, plan_at = plan.strip(), obs_ms

        limit_names = {}
        buckets = {}  # (ns, slot) -> {field: value}
        for key, value in signals.items():
            if m := CODEX_LIMIT_NAME.match(key):
                if isinstance(value, str) and value.strip():
                    limit_names[m.group(1)] = value.strip()
            elif m := CODEX_BASE.match(key):
                buckets.setdefault((None, m.group(1)), {})[m.group(2)] = value
            elif m := CODEX_SCOPED.match(key):
                ns = m.group(1)
                if ns != "credits":
                    buckets.setdefault((ns, m.group(2)), {})[m.group(3)] = value

        for (ns, slot), fields in buckets.items():
            if ns is None:
                row_id, name = f"openai-codex:{slot}", None
            else:
                name = limit_names.get(ns) or ns.removeprefix("additional-").replace("-", " ").title()
                if not slug(name):
                    continue
                row_id = f"openai-codex:{slug(name)}:{slot}"
            mins = parse_float(fields.get("window-minutes"))
            rank = (obs_ms, 1 if mins and mins > 0 else 0, 1 if "used-percent" in fields else 0)
            if row_id not in merged or rank > merged[row_id][0]:
                merged[row_id] = (rank, obs_ms, name, fields)

    if plan_type is None:
        id_token = account.get("id_token")
        if isinstance(id_token, dict) and isinstance(id_token.get("plan_type"), str):
            plan_type = id_token["plan_type"].strip() or None

    def order_key(row_id):
        if row_id == "openai-codex:primary":
            return (0, row_id)
        if row_id == "openai-codex:secondary":
            return (1, row_id)
        return (2, row_id)

    limits = []
    for row_id in sorted(merged, key=order_key):
        _, obs_ms, name, fields = merged[row_id]
        mins = parse_float(fields.get("window-minutes"))
        if not mins or mins <= 0:
            continue
        duration = int(mins) * MINUTE_MS
        reset_s = parse_float(fields.get("reset-at"))
        reset_after = parse_float(fields.get("reset-after-seconds"))
        if reset_s and reset_s > 0:
            resets_at = int(reset_s * 1000)
        elif reset_after and reset_after > 0 and obs_ms > 0:
            resets_at = obs_ms + int(reset_after * 1000)
        else:
            resets_at = 0
        if resets_at > 0 and resets_at <= now:
            continue
        if resets_at == 0 and (obs_ms <= 0 or now - obs_ms >= duration):
            continue
        used = parse_float(fields.get("used-percent"))
        win = window(duration, resets_at)
        label = win["label"] if name is None else f"{name} {win['label']}"
        limits.append(limit(row_id, label, win, percent(used)))

    if not limits:
        return None
    return {
        "provider": "openai-codex",
        "metadata": {"email": account_email(account), "planType": plan_type},
        "limits": limits,
    }


# Claude


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


CLAUDE_SIGNAL = re.compile(r"^anthropic-ratelimit-unified-(5h|7d(?:_[a-z0-9_]+)?)-(utilization|reset|status)$")
CLAUDE_MODEL_FAMILY = re.compile(r"^claude-([a-z]+)(?:-|$)")


def claude_scoped_name(suffix, model_id):
    if suffix == "oi":
        if isinstance(model_id, str) and (m := CLAUDE_MODEL_FAMILY.match(model_id.lower())):
            return m.group(1).title()
        return "Overage Included"
    return suffix.replace("_", " ").title()


def claude_signals_report(account, now=None):
    """Build a Claude report from CLIProxyAPI's passive `Anthropic-Ratelimit-Unified-*` signals.

    Merges `quota` and every `model_quotas` entry by newest `observed_at` per
    window so model-scoped buckets (like `7d_oi` on Fable) stay visible even
    when a later request used another model. Returns None when no unexpired
    window is present.
    """
    now = now_ms() if now is None else now
    obs_list = observations(account)
    if not obs_list:
        return None

    merged = {}  # win_key -> (rank, obs_ms, model_id, fields)
    for obs_ms, model_id, signals in obs_list:
        by_window = {}
        for key, value in signals.items():
            if m := CLAUDE_SIGNAL.match(key):
                by_window.setdefault(m.group(1), {})[m.group(2)] = value
        for win_key, fields in by_window.items():
            rank = (obs_ms, 1 if model_id else 0, 1 if "utilization" in fields else 0)
            if win_key not in merged or rank > merged[win_key][0]:
                merged[win_key] = (rank, obs_ms, model_id, fields)

    def order_key(win_key):
        if win_key == "5h":
            return (0, win_key)
        if win_key == "7d":
            return (1, win_key)
        return (2, win_key)

    limits = []
    for win_key in sorted(merged, key=order_key):
        _, obs_ms, model_id, fields = merged[win_key]
        duration = 5 * 60 * MINUTE_MS if win_key == "5h" else 7 * 1440 * MINUTE_MS
        reset_s = parse_float(fields.get("reset"))
        resets_at = int(reset_s * 1000) if reset_s and reset_s > 0 else 0
        if resets_at > 0 and resets_at <= now:
            continue
        if resets_at == 0 and (obs_ms <= 0 or now - obs_ms >= duration):
            continue
        util = parse_float(fields.get("utilization"))
        status = str(fields.get("status") or "").strip().lower()
        if util is not None and util >= 0:
            used = round(util * 100, 6)
        elif status == "rejected":
            used = 100
        else:
            used = None
        if win_key == "5h":
            row_id, label = "anthropic:5h", "Claude 5 Hour"
        elif win_key == "7d":
            row_id, label = "anthropic:7d", "Claude 7 Day"
        else:
            name = claude_scoped_name(win_key.removeprefix("7d_"), model_id)
            row_id, label = f"anthropic:7d:{slug(name)}", f"Claude 7 Day ({name})"
        limits.append(limit(row_id, label, window(duration, resets_at), percent(used)))

    if not limits:
        return None
    return {
        "provider": "anthropic",
        "metadata": {"email": account_email(account), "planType": None},
        "limits": limits,
    }


# Gemini (Antigravity)

ANTIGRAVITY_WINDOWS = {
    "5h": (5 * 60 * MINUTE_MS, "5 Hour"),
    "five-hour": (5 * 60 * MINUTE_MS, "5 Hour"),
    "five_hour": (5 * 60 * MINUTE_MS, "5 Hour"),
    "daily": (1440 * MINUTE_MS, "24 Hour"),
    "day": (1440 * MINUTE_MS, "24 Hour"),
    "1d": (1440 * MINUTE_MS, "24 Hour"),
    "24h": (1440 * MINUTE_MS, "24 Hour"),
    "weekly": (7 * 1440 * MINUTE_MS, "7 Day"),
    "week": (7 * 1440 * MINUTE_MS, "7 Day"),
    "7d": (7 * 1440 * MINUTE_MS, "7 Day"),
    "1w": (7 * 1440 * MINUTE_MS, "7 Day"),
}


def antigravity_report(email, summary):
    """Body of daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary."""
    report = {"provider": "google-gemini", "metadata": {"email": email, "planType": None}, "limits": []}
    groups = summary.get("groups") if isinstance(summary, dict) else None
    if not isinstance(groups, list) or not groups:
        report["error"] = "no quota groups"
        return report

    for group in groups:
        if not isinstance(group, dict):
            continue
        raw_name = str(group.get("displayName") or group.get("display_name") or "").strip()
        group_name = re.sub(r"\s+models$", "", raw_name, flags=re.IGNORECASE) or raw_name
        rows = []
        for bucket in group.get("buckets") or []:
            if not isinstance(bucket, dict):
                continue
            win_spec = ANTIGRAVITY_WINDOWS.get(str(bucket.get("window") or "").strip().lower())
            if win_spec is None:
                continue
            duration, win_label = win_spec
            resets = iso_ms(bucket.get("resetTime") or bucket.get("reset_time"))
            remaining = number(bucket.get("remainingFraction"))
            if remaining is None:
                remaining = number(bucket.get("remaining_fraction"))
            used = round((1.0 - remaining) * 100, 6) if remaining is not None and 0 <= remaining <= 1 else None
            win = window(duration, resets)
            bucket_id = str(bucket.get("bucketId") or bucket.get("bucket_id") or "").strip()
            row_id = f"google-gemini:{slug(bucket_id)}" if slug(bucket_id) else f"google-gemini:{slug(group_name) or 'quota'}:{win['id']}"
            label = f"{group_name} {win_label}" if group_name else win_label
            rows.append((duration, limit(row_id, label, win, percent(used))))
        rows.sort(key=lambda item: item[0])
        report["limits"].extend(row for _, row in rows)

    if not report["limits"]:
        report["error"] = "no quota buckets"
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


# Fallback cache for passive-observation providers (never stores credentials).


def cache_path(env):
    if "SGIATH_USAGE_CACHE" in env:
        raw = env["SGIATH_USAGE_CACHE"].strip()
        return Path(raw).expanduser() if raw else None
    xdg = env.get("XDG_CACHE_HOME", "").strip()
    if xdg:
        return Path(xdg).expanduser() / "sgiath-usage" / "fallback.json"
    home = env.get("HOME", "").strip()
    if home:
        return Path(home).expanduser() / ".cache" / "sgiath-usage" / "fallback.json"
    return None


def prune_expired(report, now):
    """Drop windows whose reset time has already passed; None when every original window expired."""
    if not isinstance(report, dict) or report.get("error"):
        return None
    limits = report.get("limits")
    if not isinstance(limits, list):
        return None
    kept = []
    for row in limits:
        if not isinstance(row, dict):
            continue
        resets = number((row.get("window") or {}).get("resetsAt"))
        if resets and 0 < resets <= now:
            continue
        kept.append(row)
    if limits and not kept:
        return None
    return {**report, "limits": kept}


def retry_after_ms(headers, now):
    """Parse an upstream Retry-After header from CLIProxyAPI's api-call reply."""
    if not isinstance(headers, dict):
        return None
    raw = None
    for key, values in headers.items():
        if isinstance(key, str) and key.lower() == "retry-after":
            raw = values[0] if isinstance(values, list) and values else values
            break
    if not isinstance(raw, str) or not raw.strip():
        return None
    seconds = parse_float(raw)
    if seconds is not None:
        return max(0, int(seconds * 1000))
    try:
        dt = email.utils.parsedate_to_datetime(raw.strip())
    except (TypeError, ValueError):
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return max(0, (dt - EPOCH) // timedelta(milliseconds=1) - now)


class FallbackCache:
    """Thread-safe JSON cache of non-secret usage reports and 429 backoff windows."""

    def __init__(self, path):
        self.path = path
        self._lock = threading.Lock()
        self._data = self._load()

    def _load(self):
        if self.path is None:
            return {}
        try:
            raw = json.loads(self.path.read_text())
        except (OSError, ValueError):
            return {}
        return raw if isinstance(raw, dict) else {}

    def _save(self, now):
        if self.path is None:
            return
        pruned = {
            k: v
            for k, v in self._data.items()
            if isinstance(v, dict)
            and (
                (number(v.get("fetchedAt")) or 0) > now - CACHE_RETENTION_MS
                or (number(v.get("backoffUntil")) or 0) > now
            )
        }
        self._data = pruned
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".fallback-")
            try:
                os.fchmod(fd, 0o600)
                with os.fdopen(fd, "w") as handle:
                    json.dump(self._data, handle)
                os.replace(tmp, self.path)
            except BaseException:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
                raise
        except OSError:
            pass

    def get(self, auth_index):
        with self._lock:
            entry = self._data.get(auth_index)
            return dict(entry) if isinstance(entry, dict) else {}

    def put(self, auth_index, report, fetched_at, now):
        with self._lock:
            self._data[auth_index] = {"fetchedAt": fetched_at, "backoffUntil": 0, "report": report}
            self._save(now)

    def backoff(self, auth_index, until, now):
        with self._lock:
            entry = dict(self._data.get(auth_index) or {})
            entry["backoffUntil"] = until
            self._data[auth_index] = entry
            self._save(now)


# CLIProxyAPI

CLIPROXY_URL = "https://cliproxy.sgiath.dev"
CLIPROXY_KEY_FILE = "/run/secrets/cliproxyapi_management"
CLAUDE_USER_AGENT = "claude-cli/2.1.329 (external, cli)"
ANTIGRAVITY_USER_AGENT = "antigravity/hub/2.33.0 (aidev_client; os_type=darwin; arch=arm64; cl=1023160026)"

# Proxy provider -> config for reading limits. Only these fixed URLs are ever
# sent through api-call: it attaches the account's token to whatever it is given.
USAGE = {
    "codex": {
        "provider": "openai-codex",
        "passive": codex_signals_report,
        "method": "GET",
        "url": "https://chatgpt.com/backend-api/wham/usage",
        "headers": {"Authorization": "Bearer $TOKEN$", "Accept": "application/json"},
        "parse": lambda account, body: codex_report(account_email(account), body),
    },
    "claude": {
        "provider": "anthropic",
        "passive": claude_signals_report,
        "method": "GET",
        "url": "https://api.anthropic.com/api/oauth/usage",
        "headers": {
            "Authorization": "Bearer $TOKEN$",
            "Accept": "application/json",
            "User-Agent": CLAUDE_USER_AGENT,
            "anthropic-beta": "oauth-2025-04-20",
        },
        "parse": lambda account, body: claude_report({"email": account_email(account)}, {"rate_limits_available": True, "rate_limits": body}),
    },
    "antigravity": {
        "provider": "google-gemini",
        "passive": None,
        "method": "POST",
        "url": "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
        "headers": {
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": ANTIGRAVITY_USER_AGENT,
        },
        "data": lambda account: json.dumps({"project": account["project_id"].strip()})
        if isinstance(account.get("project_id"), str) and account["project_id"].strip()
        else "{}",
        "parse": lambda account, body: antigravity_report(account_email(account), body),
    },
    "xai": {
        "provider": "xai-oauth",
        "passive": None,
        "method": "GET",
        "url": "https://cli-chat-proxy.grok.com/v1/billing?format=credits",
        "headers": {"Authorization": "Bearer $TOKEN$", "Accept": "application/json", "X-XAI-Token-Auth": "xai-grok-cli"},
        "parse": lambda account, body: grok_report(account_email(account), body),
    },
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
        """Enabled credential entries with a usage reader."""
        files = self.request("/v8/management/credentials").get("files") or []
        return [
            f
            for f in files
            if isinstance(f, dict) and f.get("provider") in USAGE and isinstance(f.get("auth_index"), str) and not f.get("disabled")
        ]

    def api_call(self, account):
        spec = USAGE[account["provider"]]
        payload = {
            "auth_index": account["auth_index"],
            "method": spec["method"],
            "url": spec["url"],
            "header": spec["headers"],
        }
        if "data" in spec:
            payload["data"] = spec["data"](account)
        return self.request("/v8/management/requests/api-call", payload)


def fetch_cliproxy_account(proxy, cache, account, now=None):
    """Read one CLIProxyAPI account, preferring passive observations over api-call."""
    now = now_ms() if now is None else now
    spec = USAGE[account["provider"]]
    auth_index = account["auth_index"]
    passive = spec["passive"]

    if passive is not None:
        observed = passive(account, now)
        if observed is not None:
            cache.put(auth_index, observed, latest_observed_ms(account) or now, now)
            return observed

        entry = cache.get(auth_index)
        cached = prune_expired(entry.get("report"), now)
        fetched_at = number(entry.get("fetchedAt")) or 0
        backoff_until = number(entry.get("backoffUntil")) or 0
        if cached is not None and now - fetched_at < FALLBACK_TTL_MS:
            return cached
        if now < backoff_until:
            if cached is not None and now - fetched_at < FALLBACK_STALE_MAX_MS:
                return cached
            raise ProviderError("usage HTTP 429")

        reply = proxy.api_call(account)
        status = reply.get("status_code")
        if status == 429:
            delay = retry_after_ms(reply.get("header"), now)
            delay = min(FALLBACK_BACKOFF_MAX_MS, max(FALLBACK_BACKOFF_MIN_MS, delay or 0))
            cache.backoff(auth_index, now + delay, now)
            if cached is not None and now - fetched_at < FALLBACK_STALE_MAX_MS:
                return cached
            raise ProviderError("usage HTTP 429")
        if status in (401, 403):
            raise ProviderError("login expired")
        if status != 200:
            raise ProviderError(f"usage HTTP {status}")
        report = spec["parse"](account, json.loads(reply.get("body") or "null") or {})
        if not report.get("error"):
            cache.put(auth_index, report, now, now)
        return report

    reply = proxy.api_call(account)
    status = reply.get("status_code")
    if status in (401, 403):
        raise ProviderError("login expired")
    if status != 200:
        raise ProviderError(f"usage HTTP {status}")
    return spec["parse"](account, json.loads(reply.get("body") or "null") or {})


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
        return [(USAGE[p]["provider"], unavailable(str(error))) for p in USAGE]

    cache = FallbackCache(cache_path(env))

    def fetcher(account):
        return lambda env: fetch_cliproxy_account(proxy, cache, account)

    return [(USAGE[a["provider"]]["provider"], fetcher(a)) for a in accounts]


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
