---
name: x-bird-vesta
description: Read and search X using Bird’s native live Chromium cookie source or Hermes’s bird-vesta SSH wrapper.
---

# X access through Bird

Prefer local `bird --cookie-source chromium`, implemented natively in `/home/sgiath/nixos/vendor/bird/src/lib/chromium-cookies.ts` and packaged by `packages/bird/default.nix`. It reads only X authentication cookies through read-only SQLite transactions (including committed live WAL), decrypts Linux v10 cookies in memory, validates schema-24+ host digests and rejects expired/invalid cookies. Chromium can remain open. No cookie copies, Python wrapper, credential environment injection, or SSH needed. Other encryption versions fail explicitly; do not weaken Chromium settings. Linux defaults to this source before other browsers unless credentials/source order were explicitly supplied.

Use `bird --cookie-source chromium --plain --timeout 20000 search "from:OpenAI" -n 5 --json` or `bird --cookie-source chromium --plain --timeout 20000 read TWEET_ID --json`. `--chrome-profile-dir PATH` selects a profile directory or cookie DB; `--chrome-profile "Profile 2"` selects a name. Default is $XDG_CONFIG_HOME/chromium/Default (normally ~/.config/chromium/Default), preferring Network/Cookies over Cookies. The former bird-chromium command and --profile-dir flag were removed.

Until the system is rebuilt, run `nix shell /home/sgiath/nixos#bird -c bird --cookie-source chromium ...`, or build with `nix build /home/sgiath/nixos#bird --no-link --print-out-paths` and invoke bin/bird from that output. Native Node CLI, Bun binary and Nix package whoami verified locally as @sgiath with credential environment variables unset.

Existing remote alternative: `ssh -o BatchMode=yes -o ConnectTimeout=10 sgiath@vesta.local 'bird-vesta --plain --timeout 20000 search "from:OpenAI" -n 5 --json'`. Substitute `whoami`, `read TWEET_ID --json`, or `help COMMAND` as needed. Hermes’s wrapper loads runtime SOPS credentials on Vesta; never copy or print them. Its user-tweets command has custom behavior: inspect modules/nixos/services/hermes-bird-vesta.sh before use.

Quote user inputs safely, including remote shell quoting. Keep queries bounded. Never run Bird check in tool output: it prints cookie prefixes. Read/search access does not authorize posting, replies, follows, bookmark modifications, or other account writes.
