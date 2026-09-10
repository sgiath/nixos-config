import { createDecipheriv, createHash, pbkdf2Sync } from 'node:crypto';
import { stat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { isAbsolute, join, resolve } from 'node:path';
import type { CookieExtractionResult } from './cookies.js';

const COOKIE_OCTETS = /^[\x21\x23-\x2b\x2d-\x3a\x3c-\x5b\x5d-\x7e]+$/;

interface CookieRow {
  host_key: string;
  name: 'auth_token' | 'ct0';
  value: string;
  encrypted_value: Uint8Array;
}

interface CookieDatabase {
  exec(sql: string): unknown;
  prepare(sql: string): { all(...params: number[]): unknown[] };
  close(): void;
}

async function isFile(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isFile();
  } catch {
    return false;
  }
}

async function cookieDatabasePath(profile?: string): Promise<string> {
  const root = join(process.env.XDG_CONFIG_HOME || join(homedir(), '.config'), 'chromium');
  let directory = join(root, 'Default');
  if (profile) {
    const expanded =
      profile === '~' ? homedir() : profile.startsWith('~/') ? join(homedir(), profile.slice(2)) : profile;
    directory =
      isAbsolute(expanded) || expanded.includes('/') || expanded === '.' || expanded === '..'
        ? resolve(expanded)
        : join(root, expanded);
    // A bare existing filename is also an explicit database path.
    if (await isFile(resolve(expanded))) {
      return resolve(expanded);
    }
  }
  if (await isFile(directory)) {
    return directory;
  }
  const network = join(directory, 'Network', 'Cookies');
  return (await isFile(network)) ? network : join(directory, 'Cookies');
}

async function openDatabase(path: string): Promise<CookieDatabase> {
  if (process.versions.bun) {
    // Keep the runtime-specific import dynamic: Node does not resolve bun:sqlite.
    const moduleName = 'bun:sqlite';
    const { Database } = await import(moduleName);
    return new Database(path, { readonly: true });
  }
  // Bun 1.3 cannot load node:sqlite; this import must stay behind the runtime branch.
  const { DatabaseSync } = await import('node:sqlite');
  return new DatabaseSync(path, { readOnly: true });
}

function cookieValue(row: CookieRow, version: number, key: Buffer): string | null {
  let value = row.value;
  if (row.encrypted_value?.length) {
    const encrypted = Buffer.from(
      row.encrypted_value.buffer,
      row.encrypted_value.byteOffset,
      row.encrypted_value.byteLength,
    );
    // FIXME: Support keyring-backed Linux v11 cookies; only v10 uses the peanuts key.
    if (encrypted[0] !== 0x76 || encrypted[1] !== 0x31 || encrypted[2] !== 0x30) {
      return null;
    }
    const decipher = createDecipheriv('aes-128-cbc', key, Buffer.alloc(16, 0x20));
    let decoded = Buffer.concat([decipher.update(encrypted.subarray(3)), decipher.final()]);
    if (version >= 24) {
      const digest = createHash('sha256').update(row.host_key).digest();
      if (!decoded.subarray(0, 32).equals(digest)) {
        return null;
      }
      decoded = decoded.subarray(32);
    }
    value = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(decoded);
  }
  // RFC 6265 cookie-octet excludes controls, whitespace and header delimiters.
  return typeof value === 'string' && COOKIE_OCTETS.test(value) ? value : null;
}

export async function extractCookiesFromChromium(
  profile?: string,
  timeoutMs?: number,
): Promise<CookieExtractionResult> {
  const empty = { authToken: null, ct0: null, cookieHeader: null, source: null };
  if (process.platform !== 'linux') {
    return { cookies: empty, warnings: ['Native Chromium cookie extraction is supported on Linux only.'] };
  }
  let db: CookieDatabase | undefined;
  try {
    const path = await cookieDatabasePath(profile);
    if (!(await isFile(path))) {
      return { cookies: empty, warnings: ['Chromium cookie database not found in the selected profile.'] };
    }
    db = await openDatabase(path);
    const timeout =
      timeoutMs !== undefined && Number.isFinite(timeoutMs)
        ? Math.min(2_147_483_647, Math.max(0, Math.trunc(timeoutMs)))
        : 5_000;
    db.exec(`PRAGMA busy_timeout = ${timeout}`);
    // A real read transaction sees committed WAL data and keeps meta/cookies consistent.
    // Do not copy the database or use immutable mode: Chromium may still be writing.
    db.exec('BEGIN');
    const meta = db.prepare("SELECT value FROM meta WHERE key = 'version'").all() as Array<{ value: unknown }>;
    const version = Number(meta[0]?.value);
    if (!Number.isSafeInteger(version) || version < 0 || meta[0]?.value === null || meta[0]?.value === '') {
      return { cookies: empty, warnings: ['Chromium cookie database has an unsupported schema.'] };
    }
    const rows = db
      .prepare(
        "SELECT host_key, name, value, encrypted_value FROM cookies WHERE host_key IN ('.x.com', 'x.com') " +
          "AND name IN ('auth_token', 'ct0') AND path = '/' AND (expires_utc = 0 OR expires_utc > ?) " +
          'ORDER BY last_access_utc DESC',
      )
      .all(Math.trunc((Date.now() / 1000 + 11_644_473_600) * 1_000_000)) as CookieRow[];
    const key = pbkdf2Sync('peanuts', 'saltysalt', 1, 16, 'sha1');
    const values: Partial<Record<CookieRow['name'], string>> = {};
    let invalid = false;
    for (const row of rows) {
      if (values[row.name]) {
        continue;
      }
      try {
        const value = cookieValue(row, version, key);
        if (value === null) {
          invalid = true;
        } else {
          values[row.name] = value;
        }
      } catch {
        invalid = true;
      }
      if (invalid) {
        break;
      }
    }
    const warnings = invalid
      ? ['Some Chromium X cookies are invalid or use unsupported encryption (Linux v10 only).']
      : [];
    if (invalid || !values.auth_token || !values.ct0) {
      warnings.push('Missing or expired X cookies in Chromium. Log into x.com in the selected profile.');
      return { cookies: empty, warnings };
    }
    return {
      cookies: {
        authToken: values.auth_token,
        ct0: values.ct0,
        cookieHeader: `auth_token=${values.auth_token}; ct0=${values.ct0}`,
        source: `Chromium (${path})`,
      },
      warnings,
    };
  } catch {
    return {
      cookies: empty,
      warnings: ['Could not read Chromium cookies. Check the selected profile and database access.'],
    };
  } finally {
    // Closing rolls back the read transaction, including on schema/decryption failures.
    db?.close();
  }
}
