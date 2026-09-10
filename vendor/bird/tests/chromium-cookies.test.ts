import { createCipheriv, createHash, pbkdf2Sync } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { extractCookiesFromChromium } from '../src/lib/chromium-cookies.js';

const empty = { authToken: null, ct0: null, cookieHeader: null, source: null };
const key = pbkdf2Sync('peanuts', 'saltysalt', 1, 16, 'sha1');
const COOKIE_SECRET_LEAK = /fixture-secret|older-valid-auth|valid-csrf|injected|SQLITE|decrypt|bad decrypt/;
const SQLITE_LOCK_LEAK = /SQLITE|locked/;
const CORRUPT_DATABASE_LEAK = /fixture-secret|SQLITE|not a database/;

function encrypt(value: string | Buffer, host: string | null = '.x.com', padding = true): Buffer {
  const cipher = createCipheriv('aes-128-cbc', key, Buffer.alloc(16, 0x20));
  cipher.setAutoPadding(padding);
  const payload = Buffer.concat([
    host === null ? Buffer.alloc(0) : createHash('sha256').update(host).digest(),
    Buffer.from(value),
  ]);
  return Buffer.concat([Buffer.from('v10'), cipher.update(payload), cipher.final()]);
}

describe.skipIf(process.platform !== 'linux')('native Chromium cookies', () => {
  let directory: string;
  const databases: DatabaseSync[] = [];

  function database(path = join(directory, 'Cookies'), version = 24): DatabaseSync {
    mkdirSync(dirname(path), { recursive: true });
    const db = new DatabaseSync(path);
    databases.push(db);
    db.exec(
      'CREATE TABLE meta (key TEXT, value TEXT); CREATE TABLE cookies (host_key TEXT, name TEXT, value TEXT, encrypted_value BLOB, path TEXT, expires_utc INTEGER, last_access_utc INTEGER)',
    );
    db.prepare('INSERT INTO meta VALUES (?, ?)').run('version', String(version));
    return db;
  }

  function insert(
    db: DatabaseSync,
    name: string,
    value: string | Buffer,
    options: {
      host?: string;
      path?: string;
      expires?: number;
      accessed?: number;
    } = {},
  ): void {
    db.prepare('INSERT INTO cookies VALUES (?, ?, ?, ?, ?, ?, ?)').run(
      options.host ?? '.x.com',
      name,
      typeof value === 'string' ? value : '',
      typeof value === 'string' ? Buffer.alloc(0) : value,
      options.path ?? '/',
      options.expires ?? 0,
      options.accessed ?? 1,
    );
  }

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), 'bird-chromium-'));
    vi.stubEnv('XDG_CONFIG_HOME', directory);
  });

  afterEach(() => {
    for (const db of databases.splice(0)) {
      db.close();
    }
    vi.unstubAllEnvs();
    rmSync(directory, { recursive: true, force: true });
  });

  it('reads committed WAL cookies while the writer stays open, never uncommitted credentials', async () => {
    const db = database();
    db.exec('PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0');
    insert(db, 'auth_token', encrypt('committed-auth'));
    insert(db, 'ct0', encrypt('committed-csrf', 'x.com'), { host: 'x.com' });
    expect(existsSync(join(directory, 'Cookies-wal'))).toBe(true);
    db.exec('BEGIN IMMEDIATE');
    insert(db, 'auth_token', encrypt('uncommitted-auth'), { accessed: 2 });
    expect((await extractCookiesFromChromium(directory)).cookies.cookieHeader).toBe(
      'auth_token=committed-auth; ct0=committed-csrf',
    );
    db.exec('COMMIT');
    expect((await extractCookiesFromChromium(directory)).cookies.cookieHeader).toBe(
      'auth_token=uncommitted-auth; ct0=committed-csrf',
    );
    // A surviving reader transaction would prevent a complete checkpoint.
    expect(db.prepare('PRAGMA wal_checkpoint(TRUNCATE)').get()?.busy).toBe(0);
  });

  it('filters host, name, path and expiry before choosing newest eligible cookies', async () => {
    const db = database();
    insert(db, 'auth_token', 'old-auth');
    insert(db, 'auth_token', 'new-auth', { accessed: 2 });
    insert(db, 'ct0', 'csrf', { expires: Math.trunc((Date.now() / 1000 + 11_644_473_600 + 3600) * 1_000_000) });
    insert(db, 'auth_token', 'expired', { expires: 1, accessed: 20 });
    insert(db, 'auth_token', 'wrong-domain', { host: '.twitter.com', accessed: 21 });
    insert(db, 'auth_token', 'wrong-subdomain', { host: 'evil.x.com', accessed: 22 });
    insert(db, 'ct0', 'wrong-path', { path: '/settings', accessed: 23 });
    insert(db, 'irrelevant', encrypt('bad', 'wrong-host'), { accessed: 24 });
    insert(db, 'auth_token', Buffer.from('v11older-secret'), { accessed: 0 });
    const result = await extractCookiesFromChromium(directory);
    expect(result.cookies.cookieHeader).toBe('auth_token=new-auth; ct0=csrf');
    expect(result.warnings).toEqual([]);
  });

  it.each([
    [
      'non-ASCII version prefix',
      Buffer.concat([Buffer.from([0xf6, 0xb1, 0xb0]), encrypt('fixture-secret').subarray(3)]),
    ],
    ['unsupported encryption', Buffer.from('v11fixture-secret')],
    ['wrong host digest', encrypt('fixture-secret', 'other.x.com')],
    ['invalid UTF8', encrypt(Buffer.from([0xc3, 0x28]))],
    ['invalid padding', encrypt(Buffer.alloc(16, 0), '.x.com', false)],
    ['truncated ciphertext', Buffer.from('v10fixture-secret')],
    ['empty', encrypt('')],
    ['header injection', encrypt('fixture-secret; injected=yes')],
    ['control injection', 'fixture-secret\r\nAuthorization: injected'],
    ['header whitespace', 'fixture-secret value'],
  ])('fails the entire pair for %s without exposing data or falling back', async (_label, badValue) => {
    const db = database();
    insert(db, 'auth_token', 'older-valid-auth');
    insert(db, 'ct0', 'valid-csrf', { accessed: 3 });
    insert(db, 'auth_token', badValue, { accessed: 2 });
    const result = await extractCookiesFromChromium(directory);
    expect(result.cookies).toEqual(empty);
    expect(result.warnings).not.toEqual([]);
    expect(JSON.stringify(result)).not.toMatch(COOKIE_SECRET_LEAK);
    db.exec('BEGIN EXCLUSIVE; COMMIT');
  });

  it('supports pre-v24 v10 cookies without a host digest', async () => {
    const db = database(join(directory, 'Cookies'), 23);
    insert(db, 'auth_token', encrypt('legacy-auth', null));
    insert(db, 'ct0', encrypt('legacy-csrf', null));
    expect((await extractCookiesFromChromium(directory)).cookies.cookieHeader).toBe(
      'auth_token=legacy-auth; ct0=legacy-csrf',
    );
  });

  it('resolves default, named, explicit and tilde paths and prefers Network/Cookies', async () => {
    const legacy = database(join(directory, 'chromium', 'Default', 'Cookies'));
    insert(legacy, 'auth_token', 'legacy');
    insert(legacy, 'ct0', 'legacy');
    const path = join(directory, 'chromium', 'Default', 'Network', 'Cookies');
    const db = database(path);
    insert(db, 'auth_token', 'network-auth');
    insert(db, 'ct0', 'network-csrf');
    for (const profile of [undefined, 'Default', dirname(dirname(path)), path, `~/${relative(homedir(), path)}`]) {
      const result = await extractCookiesFromChromium(profile);
      expect(result.cookies.cookieHeader).toBe('auth_token=network-auth; ct0=network-csrf');
      expect(result.cookies.source).toBe(`Chromium (${path})`);
    }
  });

  it('never creates a missing database and never returns a partial pair', async () => {
    const missing = join(directory, 'missing', 'Cookies');
    expect((await extractCookiesFromChromium(missing)).cookies).toEqual(empty);
    expect(existsSync(dirname(missing))).toBe(false);
    const db = database();
    insert(db, 'auth_token', 'partial-secret');
    const result = await extractCookiesFromChromium(directory);
    expect(result.cookies).toEqual(empty);
    expect(JSON.stringify(result)).not.toContain('partial-secret');
    expect(result.warnings).not.toEqual([]);
  });

  it('bounds lock waiting and releases failed readers without leaking SQLite messages', async () => {
    const db = database();
    db.exec('BEGIN EXCLUSIVE');
    const result = await extractCookiesFromChromium(directory, 1);
    expect(result.cookies).toEqual(empty);
    expect(result.warnings).not.toEqual([]);
    expect(JSON.stringify(result)).not.toMatch(SQLITE_LOCK_LEAK);
    db.exec('COMMIT');
    insert(db, 'auth_token', 'after-lock');
    insert(db, 'ct0', 'after-lock');
    expect((await extractCookiesFromChromium(directory)).cookies.cookieHeader).toBe(
      'auth_token=after-lock; ct0=after-lock',
    );
  });

  it('does not expose corrupt database content in diagnostics', async () => {
    writeFileSync(join(directory, 'Cookies'), 'fixture-secret-invalid-database');
    const result = await extractCookiesFromChromium(directory);
    expect(result.cookies).toEqual(empty);
    expect(result.warnings).not.toEqual([]);
    expect(JSON.stringify(result)).not.toMatch(CORRUPT_DATABASE_LEAK);
  });
});
