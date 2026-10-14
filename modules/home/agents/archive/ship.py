#!/usr/bin/env python3
"""Ship agent session records to the archive (services.agent-archive on Vesta).

Every record is stored verbatim in archive.raw: a JSONL line as written, a
whole file for JSON documents and tool-output artifacts, a SQLite row as a JSON
object. Text that is not valid UTF-8 is stored with replacement characters.

ClickHouse holds the cursors: each run asks it for the furthest position
already stored per (source, generation) and sends only what came after, so a
host that was offline for a week catches up on its next run and there is no
local state to lose. A file's generation is its inode: a tool that rewrites a
session by replacing the file gets the new version shipped in full next to the
old one. Nothing is ever deleted from the archive when a tool prunes its files.
"""

import base64
import glob
import gzip
import json
import os
import socket
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

# One HTTP insert per this much uncompressed JSON.
BATCH_BYTES = 32 * 1024 * 1024
# SQLite rows fetched per query once their order is known.
FETCH_ROWS = 500


@dataclass(frozen=True)
class Jsonl:
    """Append-only JSONL files; one record per complete line."""

    tool: str
    globs: list


@dataclass(frozen=True)
class Files:
    """Files shipped whole, again whenever their mtime changes."""

    tool: str
    globs: list


@dataclass(frozen=True)
class Sqlite:
    """One table of a live SQLite database, read incrementally.

    `path` may be a glob; every matching database is shipped as its own
    source. `position` is a column or expression that grows whenever a row is
    written (or only when it is inserted, when nothing better exists); rows
    are re-read from the last stored value onward. `where` limits the rows
    shipped.
    """

    tool: str
    path: str
    table: str
    key: str
    position: str
    where: str = "1"


# Paths are relative to $HOME unless absolute; missing or unreadable ones are
# skipped, so one list serves every host. Root-only stores (the static Hermes
# migration copy on Vesta) are archived by running this once as root.
# Credential tables and files are never listed.
SOURCES = [
    Jsonl(
        "claude",
        [
            ".claude/projects/**/*.jsonl",
            ".claude-remote/projects/**/*.jsonl",
            # The only record of prompts older than the 30-day transcript cleanup.
            ".claude/history.jsonl",
            ".claude-remote/history.jsonl",
        ],
    ),
    Files("claude", [".claude/projects/**/*.meta.json", ".claude-remote/projects/**/*.meta.json"]),
    # Written by the oh-my-opencode plugin, not by Claude Code.
    Jsonl("opencode-hooks", [".claude/transcripts/*.jsonl"]),
    Jsonl(
        "codex",
        [
            ".codex/sessions/**/*.jsonl",
            ".codex-remote/sessions/**/*.jsonl",
            ".codex/history.jsonl",
            ".codex-remote/history.jsonl",
            ".codex/session_index.jsonl",
            ".codex-remote/session_index.jsonl",
        ],
    ),
    # 2025 rollouts: one JSON document per session.
    Files("codex", [".codex/sessions/*.json", ".codex-remote/sessions/*.json"]),
    *(
        Sqlite("codex", f"{root}/state_5.sqlite", "threads", "id", "COALESCE(updated_at_ms, updated_at * 1000)")
        for root in (".codex", ".codex-remote")
    ),
    # The `event` table repeats every update of these projections; skipped.
    *(
        Sqlite("opencode", db, table, "id", "time_updated")
        for db in (".local/share/opencode/opencode.db", ".local/share/opencode/opencode-local.db")
        for table in ("project", "session", "session_v2", "message", "part", "session_message")
    ),
    # The default profile, named profiles (`omp --profile`), and the security
    # review runs each profile keeps per repository.
    Jsonl(
        "omp",
        [
            f"{root}/{store}/**/*.jsonl"
            for root in (".omp", ".omp/profiles/*")
            for store in ("agent/sessions", "security/*/sessions")
        ],
    ),
    # Full tool outputs; transcripts truncate them.
    Files(
        "omp",
        [f"{root}/agent/sessions/**/*.{ext}" for root in (".omp", ".omp/profiles/*") for ext in ("log", "md")],
    ),
    # oh-my-pi's per-message stats index; it outlives session files deleted since.
    *(
        Sqlite("omp", db, table, "id", "id")
        for db in (".omp/stats.db", ".omp/profiles/*/stats.db")
        for table in ("messages", "user_messages", "tool_calls")
    ),
    # Sessions, and the memory agent's captures (its own format, kept raw).
    Jsonl("omo", [".omo/agent/sessions/**/*.jsonl", ".omo/memory/agents/*/runtime/transcripts/**/*.jsonl"]),
    Jsonl("pi", [".pi/agent/sessions/**/*.jsonl"]),
    Jsonl("prime", [".prime/agent/sessions/**/*.jsonl", ".prime/agent/session-artifacts/**/*.jsonl"]),
    # Every thread, run, message and tool item as T3 recorded it.
    Sqlite("t3", ".t3/userdata/statev2.sqlite", "orchestration_events", "sequence", "sequence"),
    # Conversation keys only; the rest of the store holds editor state and tokens.
    # Keys are written with REPLACE, so a changed row gets a new rowid.
    Sqlite(
        "cursor",
        ".config/Cursor/User/globalStorage/state.vscdb",
        "cursorDiskKV",
        "key",
        "rowid",
        "key LIKE 'composerData:%' OR key LIKE 'bubbleId:%' OR key LIKE 'messageRequestContext:%'",
    ),
    Sqlite("cursor", ".config/Cursor/User/globalStorage/state.vscdb", "composerHeaders", "composerId", "lastUpdatedAt"),
    # Cursor CLI agent runs.
    Jsonl("cursor", [".cursor/projects/*/agent-transcripts/**/*.jsonl"]),
    # Per-project prompt and generation history, the only record of some
    # 2025 conversations whose messages are gone from the global store.
    Sqlite(
        "cursor",
        ".config/Cursor/User/workspaceStorage/*/state.vscdb",
        "ItemTable",
        "key",
        "rowid",
        "key IN ('aiService.prompts', 'aiService.generations', 'composer.composerData')",
    ),
    Jsonl("grok", [".grok/sessions/**/*.jsonl"]),
    Files("grok", [".grok/sessions/**/summary.json"]),
    Jsonl("muse", [".local/share/muse/sessions/**/*.jsonl"]),
    Jsonl("fx", [".fx/sessions/**/*.jsonl"]),
    Sqlite("goose", ".local/share/goose/sessions/sessions.db", "sessions", "id", "CAST(strftime('%s', updated_at) AS INTEGER) * 1000"),
    Sqlite("goose", ".local/share/goose/sessions/sessions.db", "messages", "id", "id"),
    Sqlite("goose", ".local/share/goose/sessions/sessions.db", "usage_ledger", "id", "id"),
    # FIXME: Hermes has no update stamps: messages and sessions are shipped as
    # first seen (or ended), later compaction edits are not. Reconcile changed
    # sessions if the edited versions turn out to matter.
    *(
        source
        for db in (".hermes/state.db", "hermes/.hermes/state.db", "/var/lib/hermes-migration/state/.hermes/state.db")
        for source in (
            Sqlite("hermes", db, "sessions", "id", "CAST(COALESCE(ended_at, started_at) * 1000 AS INTEGER)"),
            Sqlite("hermes", db, "messages", "id", "id"),
            Sqlite(
                "hermes",
                db,
                "session_model_usage",
                "session_id || '|' || model || '|' || ifnull(billing_provider, '') || '|' || ifnull(billing_base_url, '')"
                " || '|' || ifnull(billing_mode, '') || '|' || ifnull(task, '')",
                "CAST(last_seen * 1000 AS INTEGER)",
            ),
        )
    ),
    Jsonl("openclaw", [".openclaw-old/agents/main/sessions/*.jsonl*"]),
    Sqlite(
        "openclaw",
        ".openclaw/agents/main/agent/openclaw-agent.sqlite",
        "transcript_events",
        "session_id || ':' || seq",
        "created_at",
    ),
]


# --discover looks for agent session stores that SOURCES misses: JSONL files
# under a session-like directory, and SQLite databases with a session-like
# table, once they hold data (an installed but unused tool is not reported).
# Every hit must be added to SOURCES or listed in IGNORED with a reason.
SESSION_DIRS = {"sessions", "session", "projects", "transcripts", "chats", "conversations", "history", "threads"}
SESSION_TABLES = {"session", "sessions", "message", "messages", "conversation", "conversations", "chat", "chats"}
# Trees not searched at all: large and not agent state. Project checkouts
# under develop/ hold repository data, not tool homes.
PRUNE = {".cache", ".git", "node_modules", ".nix-defexpr", ".nix-profile", ".npm", ".cargo", ".rustup", "go"}
PRUNE_PATHS = {
    "develop",
    "Downloads",
    "Pictures",
    "Videos",
    "Music",
    ".t3/worktrees",
    ".local/share/Steam",
    ".local/share/Trash",
    # Repositories OpenCode cloned and its git snapshots of worktrees.
    ".local/share/opencode/repos",
    ".local/share/opencode/snapshot",
}
IGNORED = [
    (".ao/data/ao.db", "AO app projection; its sessions are the OMP and Codex sessions archived natively"),
    (".config/Cursor/User/globalStorage/conversation-search.db", "search index derived from state.vscdb"),
    (".local/share/muse/session-index.db", "index derived from the session logs"),
    (".ipython/profile_default/history.sqlite", "IPython history, not an agent"),
    (".local/share/gajim/*.db", "XMPP client"),
    (".local/share/fractal/**", "Matrix client"),
]


def _is_session_db(path):
    if path.suffix not in (".db", ".sqlite", ".sqlite3", ".vscdb"):
        return False
    try:
        with open(path, "rb") as f:
            if f.read(16) != b"SQLite format 3\0":
                return False
        db = _connect(path)
        try:
            tables = [name for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")]
            return any(
                db.execute(f'SELECT 1 FROM "{name}" LIMIT 1').fetchone()
                for name in tables
                if name.lower() in SESSION_TABLES
            )
        finally:
            db.close()
    except (OSError, sqlite3.Error):
        return False


def discover(home, sources, ignored=IGNORED):
    """{store: files} for session-like stores under $HOME that no source covers."""
    covered = set()
    for source in sources:
        covered.update(_files(home, [source.path] if isinstance(source, Sqlite) else source.globs))
    found = {}
    for root, dirs, files in os.walk(home):
        rel_root = Path(root).relative_to(home)
        dirs[:] = [d for d in dirs if d not in PRUNE and str(rel_root / d) not in PRUNE_PATHS]
        for name in files:
            path = Path(root) / name
            rel = rel_root / name
            if path in covered or any(rel.full_match(pattern) for pattern, _ in ignored):
                continue
            if name.endswith(".jsonl") and SESSION_DIRS & set(rel.parts[:-1]) and path.stat().st_size:
                store = str(rel.parent)
            elif _is_session_db(path):
                store = str(rel)
            else:
                continue
            found[store] = found.get(store, 0) + 1
    return found


def jsonl_records(path, cursor):
    """Yield (line number, end offset, line) for complete lines past `cursor`."""
    offset, line = (cursor[0], int(cursor[1])) if cursor else (0, 0)
    with open(path, "rb") as f:
        f.seek(offset)
        for raw in f:
            if not raw.endswith(b"\n"):
                break  # still being written
            offset += len(raw)
            line += 1
            yield str(line), offset, raw.rstrip(b"\r\n").decode("utf-8", "replace")


def _json_value(value):
    if isinstance(value, bytes):
        return {"base64": base64.b64encode(value).decode()}
    return value


def _connect(path):
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=10)
    db.text_factory = lambda b: b.decode("utf-8", "replace")
    db.execute("PRAGMA query_only=ON")
    return db


def sqlite_records(path, source, cursor):
    """Yield (key, position, row as JSON) for rows at or past `cursor`.

    Rows sharing the cursor's position are sent again: ones written in the same
    tick may have arrived after it was read, and replacement absorbs repeats.
    The order is read first and rows fetched in chunks, so large tables are
    never sorted whole.
    """
    db = _connect(path)
    try:
        where = f"({source.where}) AND {source.position} >= ?"
        start = cursor[0] if cursor else 0
        select = f"SELECT {{rowid}} AS _rowid, {source.key} AS _key, {source.position} AS _position, * FROM {source.table}"
        try:
            order = [
                rowid
                for (rowid,) in db.execute(
                    f"SELECT rowid FROM {source.table} WHERE {where} ORDER BY {source.position}, rowid", (start,)
                )
            ]
            ordered = True
            queries = [
                (f"{select.format(rowid='rowid')} WHERE rowid IN ({','.join('?' * len(chunk))})", chunk)
                for chunk in (order[i : i + FETCH_ROWS] for i in range(0, len(order), FETCH_ROWS))
            ]
        except sqlite3.OperationalError:  # WITHOUT ROWID table
            ordered = False
            queries = [(f"{select.format(rowid='NULL')} WHERE {where} ORDER BY _position", (start,))]
        for query, params in queries:
            rows = db.execute(query, params)
            columns = [d[0] for d in rows.description][3:]
            if ordered:
                rank = {rowid: i for i, rowid in enumerate(params)}
                rows = sorted(rows, key=lambda row: rank[row[0]])
            for _rowid, key, position, *values in rows:
                record = dict(zip(columns, map(_json_value, values)))
                yield str(key), int(position), json.dumps(record, ensure_ascii=False)
    finally:
        db.close()


class ClickHouse:
    def __init__(self, url, user="archive"):
        self.url = url.rstrip("/")
        self.user = user

    def _post(self, params, body):
        request = urllib.request.Request(
            f"{self.url}/?{urllib.parse.urlencode(params)}",
            data=gzip.compress(body, compresslevel=3),
            headers={"X-ClickHouse-User": self.user, "Content-Encoding": "gzip"},
        )
        with urllib.request.urlopen(request, timeout=600) as response:
            return response.read().decode()

    def cursors(self, host):
        """{(source, generation): (position, key)} for the furthest record stored."""
        out = self._post(
            {
                "query": "SELECT source, generation, max(position), argMax(key, position)"
                " FROM archive.raw WHERE host = {host:String} GROUP BY source, generation FORMAT TSV",
                "param_host": host,
            },
            b"",
        )
        cursors = {}
        for line in out.splitlines():
            source, generation, position, key = line.split("\t")
            cursors[source, generation] = (int(position), key)
        return cursors

    def insert(self, rows):
        body = b"".join(json.dumps(row, ensure_ascii=False).encode() + b"\n" for row in rows)
        self._post(
            {
                "query": "INSERT INTO archive.raw (host, tool, source, generation, key, position, record)"
                " FORMAT JSONEachRow"
            },
            body,
        )


def _name(home, path):
    """Source name: relative to $HOME when inside it."""
    try:
        return str(path.relative_to(home))
    except ValueError:
        return str(path)


def _files(home, patterns):
    for pattern in patterns:
        root, pattern = (Path("/"), pattern[1:]) if pattern.startswith("/") else (home, pattern)
        for rel in sorted(glob.glob(pattern, root_dir=root, recursive=True)):
            path = root / rel
            if path.is_file():
                yield path


def _mtime_ms(path):
    """Last write to a SQLite database, including its WAL."""
    paths = [path, path.with_name(path.name + "-wal")]
    return max(p.stat().st_mtime_ns for p in paths if p.exists()) // 1_000_000


class _Shipment:
    def __init__(self, host, clickhouse):
        self.host, self.clickhouse = host, clickhouse
        self.batch, self.size, self.sent = [], 0, {}

    def add(self, tool, source, generation, key, position, record):
        self.batch.append(
            {
                "host": self.host,
                "tool": tool,
                "source": source,
                "generation": generation,
                "key": key,
                "position": position,
                "record": record,
            }
        )
        self.size += len(record)
        self.sent[tool] = self.sent.get(tool, 0) + 1
        if self.size >= BATCH_BYTES:
            self.flush()

    def flush(self):
        if self.batch:
            self.clickhouse.insert(self.batch)
            self.batch, self.size = [], 0


def _ship_jsonl(home, source, cursors, out):
    for path in _files(home, source.globs):
        name, stat = _name(home, path), path.stat()
        generation = str(stat.st_ino)
        cursor = cursors.get((name, generation))
        if cursor and stat.st_size <= cursor[0]:
            if stat.st_size < cursor[0]:
                # FIXME: truncated in place (same inode) below what was shipped;
                # the rewritten content is not shipped. No surveyed tool does this.
                print(f"{name}: shrank below shipped offset {cursor[0]}, skipped", file=sys.stderr)
            continue
        for key, position, record in jsonl_records(path, cursor):
            out.add(source.tool, name, generation, key, position, record)


def _ship_files(home, source, cursors, out):
    for path in _files(home, source.globs):
        name, stat = _name(home, path), path.stat()
        generation = str(stat.st_ino)
        cursor = cursors.get((name, generation))
        if cursor and cursor[0] == stat.st_mtime_ns:
            continue
        record = path.read_bytes().decode("utf-8", "replace")
        out.add(source.tool, name, generation, "0", stat.st_mtime_ns, record)


def _ship_database(home, path, sources, cursors, out):
    """Every listed table of one database, then a marker of when it was read.

    The marker lets the next run skip a database nobody wrote to since; large
    ones (OpenCode's) have no index on their update stamps.
    """
    name = _name(home, path)
    marker = cursors.get((f"{name}#", ""))
    if marker and _mtime_ms(path) < marker[0]:
        return
    read_at = time.time_ns() // 1_000_000
    db = _connect(path)
    try:
        tables = {table for (table,) in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    finally:
        db.close()
    for source in sources:
        source_name = f"{name}#{source.table}"
        if source.table not in tables:
            continue
        for key, position, record in sqlite_records(path, source, cursors.get((source_name, ""))):
            out.add(source.tool, source_name, "", key, position, record)
    out.add(sources[0].tool, f"{name}#", "", "read", read_at, "")


def ship(home, host, sources, clickhouse):
    """Send everything past the stored cursors; return {tool: records sent}.

    A source that cannot be read is reported and skipped; the others still
    ship. Raises SystemExit after the run if any source failed.
    """
    cursors = clickhouse.cursors(host)
    out = _Shipment(host, clickhouse)
    failed = []

    databases = {}
    for source in sources:
        if isinstance(source, Sqlite):
            for path in _files(home, [source.path]):
                databases.setdefault(path, []).append(source)

    work = [
        (s.tool, s.globs, lambda s=s: (_ship_jsonl if isinstance(s, Jsonl) else _ship_files)(home, s, cursors, out))
        for s in sources
        if not isinstance(s, Sqlite)
    ] + [
        (dbs[0].tool, str(path), lambda path=path, dbs=dbs: _ship_database(home, path, dbs, cursors, out))
        for path, dbs in databases.items()
        if os.access(path, os.R_OK)
    ]
    for tool, what, run in work:
        try:
            run()
        except (OSError, sqlite3.Error) as error:
            print(f"{tool} {what}: {error}", file=sys.stderr)
            failed.append(what)
    out.flush()
    if failed:
        raise SystemExit(f"{len(failed)} sources failed; shipped {out.sent}")
    return out.sent


def report_uncovered():
    """Fail, and post to ntfy, when a session store is neither shipped nor ignored."""
    host = socket.gethostname()
    print(f"looking for unarchived agent sessions on {host}")
    found = discover(Path.home(), SOURCES)
    if not found:
        print("every session store is archived or ignored")
        return
    stores = "\n".join(f"~/{store} ({files} files)" for store, files in sorted(found.items()))
    print(f"not archived:\n{stores}", file=sys.stderr)
    request = urllib.request.Request(
        os.environ.get("AGENT_ARCHIVE_NTFY", "https://ntfy.sgiath.dev/agent-archive"),
        data=f"{stores}\n\nAdd them to SOURCES or IGNORED in modules/home/agents/archive/ship.py.".encode(),
        headers={"Title": f"Unarchived agent sessions on {host}"},
    )
    try:
        urllib.request.urlopen(request, timeout=30).close()
    except OSError as error:
        print(f"ntfy: {error}", file=sys.stderr)
    raise SystemExit(f"{len(found)} session stores are not archived")


def main():
    if sys.argv[1:] == ["--discover"]:
        report_uncovered()
        return
    url = os.environ.get("AGENT_ARCHIVE_URL", "https://clickhouse.sgiath.dev")
    host = socket.gethostname()
    started = time.monotonic()
    print(f"shipping {host} to {url}")
    sent = ship(Path.home(), host, SOURCES, ClickHouse(url))
    summary = ", ".join(f"{tool} {count}" for tool, count in sorted(sent.items())) or "nothing new"
    print(f"shipped {summary} in {time.monotonic() - started:.0f}s")


if __name__ == "__main__":
    main()
