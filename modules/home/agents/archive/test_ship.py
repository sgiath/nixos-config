import gzip
import json
import os
import sqlite3
import tempfile
import threading
import time
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import ship


class FakeClickHouse:
    """Answers the cursor query from the rows it has accepted."""

    def __init__(self):
        self.rows = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                if self.headers.get("Content-Encoding") == "gzip":
                    body = gzip.decompress(body)
                query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                if "query" in query and query["query"][0].startswith("INSERT"):
                    fake.rows += [json.loads(line) for line in body.splitlines()]
                    out = b""
                else:
                    host = query["param_host"][0]
                    cursors = {}
                    for row in fake.rows:
                        if row["host"] == host:
                            at = (row["source"], row["generation"])
                            old = cursors.get(at)
                            if old is None or row["position"] >= old[0]:
                                cursors[at] = (row["position"], row["key"])
                    out = "".join(
                        f"{source}\t{generation}\t{position}\t{key}\n"
                        for (source, generation), (position, key) in cursors.items()
                    ).encode()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(out)

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()


class JsonlTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.file = self.home / "s.jsonl"

    def records(self, cursor):
        return list(ship.jsonl_records(self.file, cursor))

    def test_ships_complete_lines_only(self):
        self.file.write_bytes(b'{"a":1}\n{"b":2}\n{"c":')
        self.assertEqual(
            self.records(None),
            [("1", 8, '{"a":1}'), ("2", 16, '{"b":2}')],
        )

    def test_resumes_after_cursor(self):
        self.file.write_bytes(b'{"a":1}\n{"b":2}\n{"c":3}\n')
        self.assertEqual(self.records((8, "1")), [("2", 16, '{"b":2}'), ("3", 24, '{"c":3}')])
        self.assertEqual(self.records((24, "3")), [])


class SqliteTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        db = sqlite3.connect(self.home / "a.db")
        db.execute("CREATE TABLE message (id TEXT PRIMARY KEY, time_updated INTEGER, data TEXT, blob BLOB)")
        db.executemany(
            "INSERT INTO message VALUES (?, ?, ?, ?)",
            [("m1", 100, '{"x":1}', None), ("m2", 200, '{"x":2}', b"\x00\xff")],
        )
        db.commit()
        db.close()
        self.source = ship.Sqlite("opencode", "a.db", "message", key="id", position="time_updated")

    def test_rows_become_json_objects(self):
        records = list(ship.sqlite_records(self.home / "a.db", self.source, None))
        self.assertEqual([(k, p) for k, p, _ in records], [("m1", 100), ("m2", 200)])
        self.assertEqual(
            json.loads(records[1][2]),
            {"id": "m2", "time_updated": 200, "data": '{"x":2}', "blob": {"base64": "AP8="}},
        )

    def test_resends_rows_at_the_cursor_version(self):
        # Rows written in the same tick as the cursor may have arrived after
        # it was read; replacement in ClickHouse absorbs the repeat.
        records = list(ship.sqlite_records(self.home / "a.db", self.source, (200, "m2")))
        self.assertEqual([k for k, _, _ in records], ["m2"])


class ShipTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        (self.home / "p").mkdir()
        (self.home / "p" / "a.jsonl").write_bytes(b'{"a":1}\n{"b":2}\n')
        self.clickhouse = FakeClickHouse()
        self.addCleanup(self.clickhouse.close)
        self.sources = [ship.Jsonl("claude", ["p/*.jsonl"])]
        self.inserts = 0

    def ship(self):
        client = ship.ClickHouse(self.clickhouse.url)
        insert = client.insert

        def counted(rows):
            self.inserts += 1
            insert(rows)

        client.insert = counted
        return ship.ship(self.home, "ceres", self.sources, client)

    def rows(self, source):
        return [r for r in self.clickhouse.rows if r["source"] == source]

    def test_ships_new_records_once(self):
        self.ship()
        self.ship()
        self.assertEqual(
            [(r["host"], r["tool"], r["source"], r["key"]) for r in self.clickhouse.rows],
            [("ceres", "claude", "p/a.jsonl", "1"), ("ceres", "claude", "p/a.jsonl", "2")],
        )
        with open(self.home / "p" / "a.jsonl", "ab") as f:
            f.write(b'{"c":3}\n')
        self.ship()
        self.assertEqual([r["key"] for r in self.clickhouse.rows], ["1", "2", "3"])
        self.assertEqual(self.clickhouse.rows[-1]["record"], '{"c":3}')

    def test_reships_a_replaced_file_as_a_new_generation(self):
        self.ship()
        replacement = self.home / "p" / "a.jsonl.tmp"
        replacement.write_bytes(b'{"title":"renamed"}\n{"b":2}\n')
        replacement.replace(self.home / "p" / "a.jsonl")
        self.ship()
        rows = self.rows("p/a.jsonl")
        self.assertEqual(len({r["generation"] for r in rows}), 2)
        self.assertEqual([r["record"] for r in rows[2:]], ['{"title":"renamed"}', '{"b":2}'])

    def test_ships_whole_files_again_when_they_change(self):
        doc = self.home / "p" / "s.json"
        doc.write_text('{"items":[]}')
        self.sources = [ship.Files("codex", ["p/*.json"])]
        self.ship()
        self.ship()
        doc.write_text('{"items":[1]}')
        os.utime(doc, ns=(doc.stat().st_mtime_ns + 10**9,) * 2)
        self.ship()
        self.assertEqual([r["record"] for r in self.rows("p/s.json")], ['{"items":[]}', '{"items":[1]}'])

    def test_ships_every_database_a_glob_matches(self):
        for name in ("a", "b"):
            (self.home / "ws" / name).mkdir(parents=True)
            db = sqlite3.connect(self.home / "ws" / name / "state.vscdb")
            db.execute("CREATE TABLE ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value TEXT)")
            db.executemany("INSERT INTO ItemTable VALUES (?, ?)", [("aiService.prompts", "[]"), ("secret", "x")])
            db.commit()
            db.close()
        self.sources = [
            ship.Sqlite("cursor", "ws/*/state.vscdb", "ItemTable", key="key", position="rowid", where="key LIKE 'aiService.%'")
        ]
        self.ship()
        self.assertEqual(
            sorted((r["source"], r["key"]) for r in self.clickhouse.rows if r["key"] != "read"),
            [("ws/a/state.vscdb#ItemTable", "aiService.prompts"), ("ws/b/state.vscdb#ItemTable", "aiService.prompts")],
        )

    def test_skips_databases_this_user_cannot_read(self):
        # Root-only stores are archived by a root run of the same shipper.
        db = sqlite3.connect(self.home / "a.db")
        db.execute("CREATE TABLE kv (key TEXT PRIMARY KEY)")
        db.commit()
        db.close()
        (self.home / "a.db").chmod(0)
        self.addCleanup((self.home / "a.db").chmod, 0o600)
        self.sources.append(ship.Sqlite("hermes", "a.db", "kv", key="key", position="rowid"))
        self.ship()
        self.assertEqual({r["source"] for r in self.clickhouse.rows}, {"p/a.jsonl"})

    def test_skips_a_database_unchanged_since_it_was_read(self):
        db = sqlite3.connect(self.home / "a.db")
        db.execute("CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT)")
        db.executemany("INSERT INTO kv VALUES (?, ?)", [("bubbleId:1", "{}"), ("secret:token", "x")])
        db.commit()
        db.close()
        old = time.time_ns() - 10**10
        os.utime(self.home / "a.db", ns=(old, old))
        self.sources = [ship.Sqlite("cursor", "a.db", "kv", key="key", position="rowid", where="key LIKE 'bubbleId:%'")]
        self.ship()
        self.assertEqual([r["key"] for r in self.rows("a.db#kv")], ["bubbleId:1"])
        inserts = self.inserts
        self.ship()
        self.assertEqual(self.inserts, inserts)


class DiscoverTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())

    def store(self, rel, content=b'{"type":"session"}\n'):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def database(self, rel, table, rows=0):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        db = sqlite3.connect(path)
        db.execute(f"CREATE TABLE {table} (id TEXT)")
        db.executemany(f"INSERT INTO {table} VALUES (?)", [(str(i),) for i in range(rows)])
        db.commit()
        db.close()

    def test_reports_session_stores_no_source_covers(self):
        self.store(".newagent/sessions/2026/a.jsonl")
        self.store(".newagent/sessions/2026/b.jsonl")
        self.store(".known/sessions/c.jsonl")
        self.database(".otheragent/state.db", "sessions", rows=1)
        sources = [ship.Jsonl("known", [".known/sessions/**/*.jsonl"])]
        self.assertEqual(
            ship.discover(self.home, sources, ignored=[]),
            {".newagent/sessions/2026": 2, ".otheragent/state.db": 1},
        )

    def test_waits_until_a_store_holds_data(self):
        # A tool installed but never used is reported once it stores something.
        self.store(".unused/sessions/a.jsonl", b"")
        self.database(".unused/state.db", "sessions")
        self.assertEqual(ship.discover(self.home, [], ignored=[]), {})

    def test_skips_ignored_paths_and_unrelated_files(self):
        self.store(".tool/sessions/debug.jsonl")
        self.store(".tool/data/export.jsonl")  # not in a session-like directory
        self.database(".tool/cache.db", "entries", rows=1)  # no session-like table
        ignored = [(".tool/sessions/**", "debug traces, not conversations")]
        self.assertEqual(ship.discover(self.home, [], ignored=ignored), {})


if __name__ == "__main__":
    unittest.main()
