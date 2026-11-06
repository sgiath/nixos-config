"""Copy CLIProxyAPI usage records into ClickHouse (archive.cliproxy).

CLIProxyAPI keeps one record per upstream execution in an in-memory queue
(at most an hour) that a GET pops. This reads it, keeps only allowlisted
metadata (the records also carry the client key, upstream keys, upstream
error bodies and response headers, which must never be stored), labels each
account by its credential name and inserts the batch. A batch that cannot be
inserted is retried before anything else is popped, so a ClickHouse outage
costs nothing until the queue's retention runs out. Records still queued when
CLIProxyAPI restarts are lost.
"""

import hashlib
import json
import os
import socket
import sys
import time
import urllib.error
import urllib.request

PROXY = "http://127.0.0.1:8317"
CLICKHOUSE = "http://127.0.0.1:8124/"
BATCH = 500
POLL = 1.0
LABELS_EVERY = 300
MAX_STRING = 512
HOST = socket.gethostname()

# Top-level fields kept as they are: strings (bounded), booleans, integers.
SCALARS = {
    "timestamp", "request_id", "trace_id", "execution_id",
    "auth_index", "auth_type", "provider", "executor_type", "access_provider", "is_native_key",
    "alias", "model", "response_model", "endpoint", "user_agent",
    "session_id", "parent_session_id", "node_kind", "is_fork", "is_compaction",
    "stream", "generate", "failed", "latency_ms", "ttft_ms", "accounting_version",
    "reasoning_effort", "service_tier", "effective_service_tier",
    "response_service_tier", "upstream_service_tier",
    "speed", "inference_geo", "web_search_requests",
}
# Never stored, and not reported as unknown.
SECRET = {
    "api_key", "source", "access_token_sha256", "response_headers",
    "client_ip", "resolved_client_ip", "x_forwarded_for",
}
# Nested objects whose numeric/boolean leaves (and these string leaves) are kept.
NESTED = {"tokens", "token_breakdown", "cache_details", "tool_usage_details"}
NESTED_STRINGS = {"schema_version", "quality", "mode", "ttl", "retention", "type", "model"}

unknown = set()


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def scalar(value):
    if isinstance(value, bool) or isinstance(value, int):
        return value
    if isinstance(value, str):
        return value[:MAX_STRING]
    return None


def numbers(obj, path):
    out = {}
    for key, value in obj.items():
        if isinstance(value, dict):
            inner = numbers(value, f"{path}.{key}")
            if inner:
                out[key] = inner
        elif isinstance(value, (bool, int, float)):
            out[key] = value
        elif isinstance(value, str) and key in NESTED_STRINGS:
            out[key] = value[:MAX_STRING]
        else:
            note(f"{path}.{key}")
    return out


def note(name):
    if name not in unknown:
        unknown.add(name)
        log(f"cliproxy-usage: dropping unknown field {name}")


def clean(record):
    out = {}
    for key, value in record.items():
        if key in SECRET:
            continue
        if key in SCALARS:
            if (v := scalar(value)) is not None:
                out[key] = v
        elif key in NESTED and isinstance(value, dict):
            out[key] = numbers(value, key)
        elif key == "iterations" and isinstance(value, list):
            out[key] = [numbers(i, key) for i in value if isinstance(i, dict)]
        elif key == "fail" and isinstance(value, dict):
            # The upstream error body stays behind.
            out["fail"] = {k: scalar(value[k]) for k in ("status_code", "code") if scalar(value.get(k)) is not None}
        else:
            note(key)
    return out


def management_key():
    with open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "management")) as f:
        return f.read().strip()


def get(path, key):
    req = urllib.request.Request(PROXY + path, headers={"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.load(resp)


def labels(key):
    """auth_index -> credential name/label, from the credential listing."""
    found = {}

    def walk(node):
        if isinstance(node, dict):
            if isinstance(node.get("auth_index"), str):
                name = node.get("label") or node.get("name") or node.get("id")
                if isinstance(name, str):
                    found[node["auth_index"]] = name[:MAX_STRING]
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(get("/v8/management/credentials", key))
    return found


def insert(rows):
    body = "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in rows).encode()
    req = urllib.request.Request(
        CLICKHOUSE + "?query=" + urllib.request.quote("INSERT INTO archive.cliproxy (host, event_id, record) FORMAT JSONEachRow"),
        data=body,
        headers={"X-ClickHouse-User": "archive"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        resp.read()


def row(record, names):
    record = clean(record)
    # Same record, same id: a retried insert replaces rather than duplicates.
    event_id = hashlib.sha256(json.dumps([HOST, record], sort_keys=True).encode()).hexdigest()
    if (name := names.get(record.get("auth_index", ""))) is not None:
        record["credential"] = name
    return {"host": HOST, "event_id": event_id, "record": json.dumps(record, sort_keys=True)}


def main():
    key = management_key()
    names, names_at = {}, 0.0
    pending = []
    down = None  # what is unreachable, for logging transitions only
    total, reported = 0, time.monotonic()
    log("cliproxy-usage: started")
    while True:
        try:
            if not pending:
                if time.monotonic() - names_at > LABELS_EVERY:
                    names, names_at = labels(key), time.monotonic()
                batch = get(f"/v8/management/observability/usage/queue?count={BATCH}", key)
                if not isinstance(batch, list):
                    raise ValueError("usage queue did not return a list")
                if any(r.get("auth_index") not in names for r in batch if isinstance(r, dict)):
                    # The batch is already popped: a failed refresh only
                    # leaves the new account unlabelled.
                    try:
                        names, names_at = labels(key), time.monotonic()
                    except (urllib.error.URLError, OSError, ValueError):
                        pass
                pending = [row(r, names) for r in batch if isinstance(r, dict)]
            if pending:
                insert(pending)
                total += len(pending)
                pending = []
            if down:
                log(f"cliproxy-usage: {down} reachable again")
                down = None
        except (urllib.error.URLError, OSError, ValueError) as e:
            what = "ClickHouse" if pending else "CLIProxyAPI"
            if down != what:
                log(f"cliproxy-usage: {what} unavailable ({type(e).__name__}); retrying")
                down = what
            time.sleep(10)
            continue
        if total and time.monotonic() - reported > 3600:
            log(f"cliproxy-usage: {total} records in the last hour")
            total, reported = 0, time.monotonic()
        if not pending:
            time.sleep(POLL)


if __name__ == "__main__":
    main()
