#!/usr/bin/env python3
"""Subscription usage for the Quickshell usage panel.

Asks each native agent app for its own quota: Codex through `codex
app-server`, Claude through the CLI's `get_usage` control request, Grok
through the billing endpoint its CLI uses. Credentials stay with the apps:
nothing here refreshes or writes them, so an expired login shows up as that
provider's error until its app renews it.

Prints one JSON document: {generatedAt, reports: [{provider, metadata,
limits, error?}]}. A limit's `amount.used` is null when the provider names a
window without saying how much of it is used; that is unknown, not zero.
"""

import json
import os
import re
import select
import subprocess
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


class ProviderError(Exception):
    """A provider failure whose message is safe to show in the panel."""


class Session:
    """A child speaking JSON lines on stdio, abandoned at one shared deadline."""

    def __init__(self, command, env, timeout, cwd=None):
        self.command, self.env, self.cwd = command, env, cwd
        self.name = os.path.basename(command[0])
        self.deadline = time.monotonic() + timeout
        self.buffer = b""

    def __enter__(self):
        try:
            self.process = subprocess.Popen(
                self.command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                env=self.env,
                cwd=self.cwd,
            )
        except FileNotFoundError:
            raise ProviderError(f"{self.name} not found") from None
        return self

    def __exit__(self, *exc):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    pass  # Stuck in uninterruptible I/O; leave it rather than hang the panel.
        self.process.stdin.close()
        self.process.stdout.close()

    def send(self, message):
        try:
            self.process.stdin.write(json.dumps(message).encode() + b"\n")
            self.process.stdin.flush()
        except BrokenPipeError:
            raise ProviderError(f"{self.name} exited") from None

    def receive(self, match):
        """First message `match` accepts; anything else on the stream is skipped."""
        stdout = self.process.stdout
        while True:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                if isinstance(message, dict) and match(message):
                    return message
            remaining = self.deadline - time.monotonic()
            if remaining <= 0 or not select.select([stdout], [], [], remaining)[0]:
                raise ProviderError(f"{self.name} timed out")
            chunk = os.read(stdout.fileno(), 65536)
            if not chunk:
                raise ProviderError(f"{self.name} exited")
            self.buffer += chunk


def failed(provider, error):
    return {"provider": provider, "metadata": {}, "limits": [], "error": error}


def collect(fetchers, env, timeout=40):
    """Run every `(provider, fetch)` at once; a failure only empties its own report."""
    results = {}

    def run(provider, fetch):
        try:
            results[provider] = fetch(env)
        except ProviderError as error:
            results[provider] = failed(provider, str(error))
        except Exception as error:
            # Messages of unexpected errors may quote file or response contents.
            results[provider] = failed(provider, type(error).__name__)

    threads = [threading.Thread(target=run, args=fetcher, daemon=True) for fetcher in fetchers]
    for thread in threads:
        thread.start()
    deadline = time.monotonic() + timeout
    for thread in threads:
        thread.join(max(0, deadline - time.monotonic()))
    reports = [results.get(provider) or failed(provider, "timed out") for provider, _ in fetchers]
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


def codex_report(account, limits):
    """`account/read` and `account/rateLimits/read` results from `codex app-server`."""
    info = account.get("account") or {}
    buckets = limits.get("rateLimitsByLimitId") or {}
    if not buckets and limits.get("rateLimits"):
        buckets = {"codex": limits["rateLimits"]}
    rows = []
    for limit_id, bucket in buckets.items():
        for slot in ("primary", "secondary"):
            entry = bucket.get(slot)
            mins = number((entry or {}).get("windowDurationMins"))
            if not mins:
                continue
            resets = number(entry.get("resetsAt"))
            win = window(int(mins) * MINUTE_MS, int(resets * 1000) if resets else 0)
            if limit_id == "codex":
                id, label = f"openai-codex:{slot}", win["label"]
            else:
                id = f"openai-codex:{slug(limit_id)}:{slot}"
                label = f"{bucket.get('limitName') or limit_id} {win['label']}"
            rows.append(limit(id, label, win, percent(number(entry.get("usedPercent")))))
    return {
        "provider": "openai-codex",
        "metadata": {"email": info.get("email"), "planType": info.get("planType")},
        "limits": rows,
    }


def codex_fetch(env):
    """Asks `codex app-server`, which reads and renews Codex's own login (CODEX_HOME)."""
    with Session(["codex", "app-server", "--listen", "stdio://"], env, timeout=20) as codex:

        def call(id, method, params=None):
            codex.send({"id": id, "method": method, **({} if params is None else {"params": params})})
            reply = codex.receive(lambda message: message.get("id") == id and "method" not in message)
            if "error" in reply:
                raise ProviderError(f"{method}: {str((reply['error'] or {}).get('message'))[:120]}")
            return reply.get("result") or {}

        call(1, "initialize", {"clientInfo": {"name": "sgiath_usage", "version": "1.0"}})
        codex.send({"method": "initialized"})
        account = call(2, "account/read", {"refreshToken": False})
        if not account.get("account"):
            raise ProviderError("not logged in")
        return codex_report(account, call(3, "account/rateLimits/read"))


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
    """The `account` from the CLI's initialize response and its `get_usage` response.

    `rate_limits` matches the body of api.anthropic.com/api/oauth/usage plus
    `model_scoped`. Null buckets are omitted, never zero; `is_active` only
    marks the binding limit, so inactive scoped rows stay.
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


# Control-protocol session only: no prompt is sent, so nothing reaches a model.
CLAUDE_COMMAND = [
    "claude",
    "--print",
    "--input-format",
    "stream-json",
    "--output-format",
    "stream-json",
    "--verbose",
    "--no-session-persistence",
    "--settings",
    '{"disableAllHooks":true}',
    "--strict-mcp-config",
    "--mcp-config",
    '{"mcpServers":{}}',
    "--tools",
    "",
]
CLAUDE_ENV = {
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
    "ENABLE_CLAUDEAI_MCP_SERVERS": "false",
    "CLAUDE_CODE_AUTO_CONNECT_IDE": "0",
    "CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL": "1",
}


def claude_fetch(env):
    """Asks the Claude CLI over its stream-json control protocol (`get_usage`)."""
    env = {key: value for key, value in env.items() if key not in ("CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT")}
    with tempfile.TemporaryDirectory() as cwd, Session(CLAUDE_COMMAND, env | CLAUDE_ENV, 20, cwd) as claude:

        def control(id, request):
            claude.send({"type": "control_request", "request_id": id, "request": request})
            reply = claude.receive(
                lambda message: message.get("type") == "control_response"
                and (message.get("response") or {}).get("request_id") == id
            )["response"]
            if reply.get("subtype") != "success":
                raise ProviderError(f"{request['subtype']}: {str(reply.get('error'))[:120]}")
            return reply.get("response") or {}

        init = control("init", {"subtype": "initialize"})
        return claude_report(init.get("account") or {}, control("usage", {"subtype": "get_usage", "skip_behaviors": True}))


# Grok

GROK_BILLING = "https://cli-chat-proxy.grok.com/v1/billing?format=credits"
GROK_DEFAULT_LOGINS = ["https://auth.x.ai::b1a00492-073a-47ea-816f-4c329264a828", "https://accounts.x.ai/sign-in"]
# Settings that point the CLI at another account or endpoint; its default
# grok.com login would then not be the account the CLI actually uses.
GROK_OVERRIDES = [
    "GROK_OIDC_ISSUER",
    "GROK_OIDC_CLIENT_ID",
    "GROK_OAUTH2_ISSUER",
    "GROK_OAUTH2_CLIENT_ID",
    "GROK_OAUTH2_PRINCIPAL_TYPE",
    "GROK_OAUTH2_PRINCIPAL_ID",
    "GROK_AUTH_PROVIDER_COMMAND",
    "GROK_LOCAL_AUTH",
    "GROK_CLI_CHAT_PROXY_BASE_URL",
    "GROK_MODELS_BASE_URL",
    "GROK_CONFIG",
    "GROK_CONFIG_PATH",
]
GROK_OVERRIDE_SECTION = re.compile(r"""^\s*(?:\[\[?\s*)?["']?(?:auth|grok_com_config|endpoints)["']?\s*[.\]=]""", re.M)
GROK_PRODUCTS = {"GrokBuild": "Grok Build", "Api": "API"}


def grok_credential(env):
    """(access token, email) of the default grok.com login, as the CLI stores it."""
    # The CLI then uses the API key's account, not the grok.com login.
    if env.get("XAI_API_KEY", "").strip():
        raise ProviderError("grok uses an API key")
    if any(env.get(name, "").strip() for name in GROK_OVERRIDES):
        raise ProviderError("custom grok deployment")
    home = Path(env.get("GROK_HOME", "").strip() or Path(env.get("HOME", "~"), ".grok")).expanduser()
    configs = [home / "config.toml", home / "managed_config.toml", home / "requirements.toml"]
    for config in configs + [Path("/etc/grok/managed_config.toml"), Path("/etc/grok/requirements.toml")]:
        if config.is_file() and GROK_OVERRIDE_SECTION.search(config.read_text()):
            raise ProviderError("custom grok deployment")
    contents = env.get("GROK_AUTH", "").strip()
    if not contents:
        try:
            contents = (home / "auth.json").read_text()
        except FileNotFoundError:
            raise ProviderError("not logged in") from None
    entries = json.loads(contents)
    entry = next((entries[key] for key in GROK_DEFAULT_LOGINS if isinstance(entries.get(key), dict)), None)
    token = (entry or {}).get("key")
    if entry is None or entry.get("auth_mode") == "api_key" or not isinstance(token, str) or not token.strip():
        raise ProviderError("not logged in")
    return token.strip(), entry.get("email")


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
    """The bearer token must not follow a redirect to another host."""

    def redirect_request(self, *args):
        return None


def grok_fetch(env):
    token, email = grok_credential(env)
    request = urllib.request.Request(
        GROK_BILLING,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json", "X-XAI-Token-Auth": "xai-grok-cli"},
    )
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=15) as response:
            body = json.load(response)
    except urllib.error.HTTPError as error:
        raise ProviderError("login expired" if error.code in (401, 403) else f"billing HTTP {error.code}") from None
    except (urllib.error.URLError, OSError):
        raise ProviderError("billing unreachable") from None
    return grok_report(email, body)


def main():
    fetchers = [("openai-codex", codex_fetch), ("anthropic", claude_fetch), ("xai-oauth", grok_fetch)]
    json.dump(collect(fetchers, dict(os.environ)), sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
