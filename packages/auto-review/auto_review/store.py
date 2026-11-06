"""SQLite state: reviews (one row per diff key), their findings per attempt, provider limits and events."""

import json
import sqlite3
import secrets
import threading
import weakref
from pathlib import Path

from .models import Change, Selection

ACTIVE = ("queued", "launching", "running", "limited", "deciding", "posting")
FINISHED = ("done", "failed", "cancelled", "superseded")
VIEWS = {"active": ACTIVE, "history": ("done", "cancelled", "superseded"), "failed": ("failed",)}

SCHEMA = """
CREATE TABLE IF NOT EXISTS reviews (
  id INTEGER PRIMARY KEY,
  repo TEXT NOT NULL, forge TEXT NOT NULL, path TEXT NOT NULL, number INTEGER NOT NULL,
  head_sha TEXT NOT NULL, base_sha TEXT NOT NULL, target TEXT NOT NULL,
  attempt INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL, outcome TEXT,
  title TEXT, url TEXT, author TEXT,
  provider TEXT, model TEXT, effort TEXT, contract TEXT NOT NULL,
  thread_id TEXT, thread_url TEXT, run_id TEXT,
  queued_at TEXT, started_at TEXT, running_since TEXT, active_seconds INTEGER NOT NULL DEFAULT 0,
  finished_at TEXT, limited_until TEXT, error TEXT, summary TEXT, not_reviewed TEXT, injection_attempts TEXT,
  dry_run INTEGER NOT NULL DEFAULT 0, approved INTEGER NOT NULL DEFAULT 0, settled INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'auto', diff_refs TEXT,
  UNIQUE (repo, number, head_sha, base_sha, target)
);
CREATE INDEX IF NOT EXISTS reviews_status ON reviews (status);
CREATE INDEX IF NOT EXISTS reviews_mr ON reviews (repo, number);
CREATE TABLE IF NOT EXISTS findings (
  review_id INTEGER NOT NULL REFERENCES reviews (id), attempt INTEGER NOT NULL, finding_id TEXT NOT NULL,
  title TEXT, frequency INTEGER, severity INTEGER, score INTEGER, file TEXT, side TEXT, line INTEGER,
  existing_thread_id TEXT, body TEXT, reasoning TEXT, state TEXT NOT NULL, url TEXT, remote_id TEXT,
  PRIMARY KEY (review_id, attempt, finding_id)
);
CREATE TABLE IF NOT EXISTS launches (review_id INTEGER NOT NULL, attempt INTEGER NOT NULL, at TEXT NOT NULL,
  PRIMARY KEY (review_id, attempt));
CREATE TABLE IF NOT EXISTS limits (provider TEXT PRIMARY KEY, until TEXT NOT NULL, reason TEXT);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY, at TEXT NOT NULL, level TEXT NOT NULL, review_id INTEGER, message TEXT NOT NULL
);
"""
JSON_COLUMNS = ("diff_refs", "not_reviewed", "injection_attempts")
BOOL_COLUMNS = ("dry_run", "approved", "settled")
FINDING_COLUMNS = (
    "finding_id", "title", "frequency", "severity", "score", "file", "side", "line", "existing_thread_id",
    "body", "reasoning", "state", "url", "remote_id",
)


class Store:
    """Thread-safe: every method takes the store's lock. Rows come back as plain dicts with the columns below.

    reviews: id, repo, forge, path, number, head_sha, base_sha, target, attempt, status, outcome, title, url,
    author, provider, model, effort, contract, thread_id, thread_url, run_id, queued_at, started_at,
    running_since, active_seconds, finished_at, limited_until, error, dry_run, approved, settled, source,
    diff_refs (dict); UNIQUE (repo, number, head_sha, base_sha, target).
    findings: review_id, attempt, finding_id, title, frequency, severity, score, file, side, line,
    existing_thread_id, body, reasoning, state, url, remote_id.
    """

    def __init__(self, path: Path):
        self._lock = threading.RLock()
        self._db = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        weakref.finalize(self, self._db.close)
        self._db.row_factory = sqlite3.Row
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.execute("PRAGMA synchronous=NORMAL")
        self._db.executescript(SCHEMA)

    def instance_id(self) -> str:
        """A random id of this database, created once: T3 thread titles carry it, so a thread started for review 1
        of this database is never mistaken for review 1 of another (a test run, a rebuilt state)."""
        with self._lock:
            self._db.execute("INSERT OR IGNORE INTO meta VALUES ('instance', ?)", (secrets.token_hex(4),))
            return self._db.execute("SELECT value FROM meta WHERE key = 'instance'").fetchone()[0]

    def claim(self, change: Change, *, forge: str, path: str, selection: Selection, contract: str, now: str) -> int | None:
        """Insert a `queued` review for `change.key`; None when that key already has a row, whatever its status."""
        with self._lock:
            cursor = self._db.execute(
                "INSERT OR IGNORE INTO reviews (repo, forge, path, number, head_sha, base_sha, target, status, title,"
                " url, author, provider, model, effort, contract, queued_at, diff_refs)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (change.repo, forge, path, change.number, change.head_sha, change.base_sha, change.target,
                 change.title, change.url, change.author, selection.provider, selection.model, selection.effort,
                 contract, now, json.dumps(change.diff_refs)),
            )
            return cursor.lastrowid if cursor.rowcount else None

    def get(self, review_id: int) -> dict | None:
        with self._lock:
            row = self._db.execute("SELECT * FROM reviews WHERE id = ?", (review_id,)).fetchone()
        return _review(row) if row else None

    def update(self, review_id: int, **fields) -> None:
        if not fields:
            return
        values = [json.dumps(v) if k in JSON_COLUMNS else v for k, v in fields.items()]
        assignments = ", ".join(f"{name} = ?" for name in fields)
        with self._lock:
            self._db.execute(f"UPDATE reviews SET {assignments} WHERE id = ?", (*values, review_id))

    def in_status(self, *statuses: str) -> list[dict]:
        """Reviews in these statuses, oldest id first."""
        marks = ", ".join("?" for _ in statuses)
        with self._lock:
            rows = self._db.execute(f"SELECT * FROM reviews WHERE status IN ({marks}) ORDER BY id", statuses).fetchall()
        return [_review(r) for r in rows]

    def for_mr(self, repo: str, number: int) -> list[dict]:
        with self._lock:
            rows = self._db.execute(
                "SELECT * FROM reviews WHERE repo = ? AND number = ? ORDER BY id", (repo, number)
            ).fetchall()
        return [_review(r) for r in rows]

    def list(self, view: str, *, repo: str | None = None, limit: int = 50, before: int | None = None) -> list[dict]:
        """`active` oldest first; `history` (done, cancelled, superseded) and `failed` newest first."""
        statuses = VIEWS[view]
        sql = f"SELECT * FROM reviews WHERE status IN ({', '.join('?' for _ in statuses)})"
        params: list = list(statuses)
        if repo:
            sql += " AND repo = ?"
            params.append(repo)
        if before is not None:
            sql += " AND id > ?" if view == "active" else " AND id < ?"
            params.append(before)
        sql += " ORDER BY id" + ("" if view == "active" else " DESC") + " LIMIT ?"
        params.append(limit)
        with self._lock:
            rows = self._db.execute(sql, params).fetchall()
        return [_review(r) for r in rows]

    def save_findings(self, review_id: int, attempt: int, rows: list[dict]) -> None:
        """Replace this attempt's findings."""
        with self._lock:
            self._db.execute("BEGIN")
            try:
                self._db.execute("DELETE FROM findings WHERE review_id = ? AND attempt = ?", (review_id, attempt))
                for row in rows:
                    self._db.execute(
                        f"INSERT INTO findings (review_id, attempt, {', '.join(FINDING_COLUMNS)})"
                        f" VALUES (?, ?, {', '.join('?' for _ in FINDING_COLUMNS)})",
                        (review_id, attempt, *(row.get(c) for c in FINDING_COLUMNS)),
                    )
                self._db.execute("COMMIT")
            except BaseException:
                self._db.execute("ROLLBACK")
                raise

    def findings(self, review_id: int, attempt: int) -> list[dict]:
        with self._lock:
            rows = self._db.execute(
                "SELECT * FROM findings WHERE review_id = ? AND attempt = ? ORDER BY rowid", (review_id, attempt)
            ).fetchall()
        return [dict(r) for r in rows]

    def update_finding(self, review_id: int, attempt: int, finding_id: str, **fields) -> None:
        assignments = ", ".join(f"{name} = ?" for name in fields)
        with self._lock:
            self._db.execute(
                f"UPDATE findings SET {assignments} WHERE review_id = ? AND attempt = ? AND finding_id = ?",
                (*fields.values(), review_id, attempt, finding_id),
            )

    def record_launch(self, review_id: int, attempt: int, now: str) -> None:
        with self._lock:
            self._db.execute("INSERT OR IGNORE INTO launches VALUES (?, ?, ?)", (review_id, attempt, now))

    def launches_since(self, since: str) -> int:
        """Attempts started at or after `since` (UTC ISO)."""
        with self._lock:
            return self._db.execute("SELECT count(*) FROM launches WHERE at >= ?", (since,)).fetchone()[0]

    def set_limit(self, provider: str, until: str, reason: str) -> None:
        """Keep the later of the stored and the new `until`."""
        with self._lock:
            self._db.execute(
                "INSERT INTO limits VALUES (?, ?, ?) ON CONFLICT (provider) DO UPDATE SET"
                " reason = CASE WHEN excluded.until > until THEN excluded.reason ELSE reason END,"
                " until = max(until, excluded.until)",
                (provider, until, reason),
            )

    def clear_limit(self, provider: str) -> None:
        with self._lock:
            self._db.execute("DELETE FROM limits WHERE provider = ?", (provider,))

    def limits(self, now: str) -> dict[str, dict]:
        """Unexpired limits by provider: {"until", "reason"}; expired ones are dropped."""
        with self._lock:
            self._db.execute("DELETE FROM limits WHERE until <= ?", (now,))
            rows = self._db.execute("SELECT * FROM limits").fetchall()
        return {r["provider"]: {"until": r["until"], "reason": r["reason"]} for r in rows}

    def event(self, level: str, message: str, *, review_id: int | None = None, now: str) -> None:
        with self._lock:
            self._db.execute(
                "INSERT INTO events (at, level, review_id, message) VALUES (?, ?, ?, ?)", (now, level, review_id, message)
            )
            # FIXME: events are capped by count; a per-age retention would need a setting nobody has asked for.
            self._db.execute("DELETE FROM events WHERE id <= (SELECT max(id) FROM events) - 5000")

    def events(self, *, limit: int = 100, review_id: int | None = None) -> list[dict]:
        sql, params = "SELECT at, level, review_id, message FROM events", []
        if review_id is not None:
            sql += " WHERE review_id = ?"
            params.append(review_id)
        with self._lock:
            rows = self._db.execute(sql + " ORDER BY id DESC LIMIT ?", (*params, limit)).fetchall()
        return [dict(r) for r in rows]

    def import_legacy(self, row: dict) -> bool:
        """Insert a finished review from the old poller; False when its key exists."""
        columns = list(row)
        with self._lock:
            cursor = self._db.execute(
                f"INSERT OR IGNORE INTO reviews ({', '.join(columns)}) VALUES ({', '.join('?' for _ in columns)})",
                [json.dumps(row[c]) if c in JSON_COLUMNS else row[c] for c in columns],
            )
            return bool(cursor.rowcount)


def _review(row: sqlite3.Row) -> dict:
    data = dict(row)
    for name in JSON_COLUMNS:
        data[name] = json.loads(data[name]) if data[name] else ({} if name == "diff_refs" else [])
    for name in BOOL_COLUMNS:
        data[name] = bool(data[name])
    return data
