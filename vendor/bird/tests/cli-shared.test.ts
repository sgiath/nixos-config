import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CookieExtractionResult } from '../src/lib/cookies.js';

const profiles = vi.hoisted(() => new Map<string | undefined, CookieExtractionResult>());
vi.mock('../src/lib/chromium-cookies.js', () => ({
  extractCookiesFromChromium: async (profile?: string) =>
    profiles.get(profile) ?? {
      cookies: { authToken: null, ct0: null, cookieHeader: null, source: null },
      warnings: [],
    },
}));
vi.mock('@steipete/sweet-cookie', () => ({
  getCookies: async () => ({
    cookies: [
      { name: 'auth_token', value: 'other_auth', domain: 'x.com' },
      { name: 'ct0', value: 'other_ct0', domain: 'x.com' },
    ],
    warnings: [],
  }),
}));

import { createProgram } from '../src/cli/program.js';
import { createCliContext } from '../src/cli/shared.js';

const chromiumCredentials: CookieExtractionResult = {
  cookies: {
    authToken: 'chromium_auth',
    ct0: 'chromium_ct0',
    cookieHeader: 'auth_token=chromium_auth; ct0=chromium_ct0',
    source: 'Chromium',
  },
  warnings: [],
};

describe('cli shared', () => {
  let tempHome: string;

  beforeEach(() => {
    tempHome = mkdtempSync(join(tmpdir(), 'bird-home-'));
    vi.stubEnv('HOME', tempHome);
    for (const key of ['AUTH_TOKEN', 'TWITTER_AUTH_TOKEN', 'CT0', 'TWITTER_CT0']) {
      vi.stubEnv(key, undefined);
    }
    vi.spyOn(process, 'cwd').mockReturnValue(tempHome);
    profiles.clear();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
    rmSync(tempHome, { recursive: true, force: true });
  });

  it('accepts Chromium CLI selection and prefers --chrome-profile-dir over --chrome-profile', async () => {
    profiles.set('/tmp/Chromium Profile', chromiumCredentials);
    const ctx = createCliContext([]);
    const program = createProgram(ctx);
    program.parseOptions([
      '--cookie-source',
      'chromium',
      '--chrome-profile',
      'Default',
      '--chrome-profile-dir',
      '/tmp/Chromium Profile',
    ]);
    const result = await ctx.resolveCredentialsFromOptions(program.opts());
    expect(result.cookies.cookieHeader).toBe('auth_token=chromium_auth; ct0=chromium_ct0');
  });

  it('accepts Chromium config and lets explicit CLI browser order override it', async () => {
    profiles.set('/tmp/Chromium Profile', chromiumCredentials);
    const configDir = join(tempHome, '.config', 'bird');
    mkdirSync(configDir, { recursive: true });
    writeFileSync(
      join(configDir, 'config.json5'),
      '{ chromeProfileDir: "/tmp/Chromium Profile", cookieSource: ["chromium", "chrome"] }',
    );
    const ctx = createCliContext([]);
    expect((await ctx.resolveCredentialsFromOptions({})).cookies.authToken).toBe('chromium_auth');
    const program = createProgram(ctx);
    program.parseOptions(['--cookie-source', 'chrome', '--cookie-source', 'chromium']);
    expect((await ctx.resolveCredentialsFromOptions(program.opts())).cookies.authToken).toBe('other_auth');
  });

  it('uses the credential resolver platform default when CLI and config omit sources', async () => {
    profiles.set(undefined, chromiumCredentials);
    const ctx = createCliContext([]);
    expect((await ctx.resolveCredentialsFromOptions({})).cookies.authToken).toBe(
      process.platform === 'linux' ? 'chromium_auth' : 'other_auth',
    );
  });
});
