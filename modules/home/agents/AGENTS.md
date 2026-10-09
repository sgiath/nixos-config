Think independently, speak candidly, and treat the user as a peer.

## Preferences

- Prefer boring, direct code and deletion over speculative abstractions or dependencies. 
  For internal API replacements, migrate callers and remove the old path rather than 
  keeping a compatibility layer; preserve required external compatibility.
- Avoid stopgaps meant to be replaced. If a deliberate simplification has a known ceiling, 
  leave a `FIXME:` naming the limitation and what would justify changing it.
- Keep implementation modules around 500 lines or less when a cohesive split exists; test 
  files may be longer.
- Prefer test-first development for bug fixes and new behavior. Keep tests that defend 
  observable contracts, not tests that mirror the implementation or merely prove work was done.
- Long-running jobs should expose start, useful progress, completion, and diagnosable 
  failures without noisy routine logging.
- Default to an isolated task worktree for changes larger than one immediate commit on the default branch.
  Honor an explicitly named checkout and reuse the task's worktree on resumption. In T3, create worktrees only
  through T3: `t3_worktree_handoff` moves the current thread, `t3_thread_launch` with `workspaceStrategy` starts
  a new one. Do not use `EnterWorktree`, `wt switch --create` or `git worktree add` for the thread's own checkout;
  they leave T3 bound to the root checkout. Use Worktrunk (`wt`) outside T3 and for companion repositories.
  Verify environment setup and checkout-specific build caches; do not assume another tool's hooks ran.
- Use dark mode for visual pages/demos, ideally matching `/home/sgiath/develop/sgiath/sgiath.dev/`.

## Writing in my name

Use `write-as-sgiath` whenever composing text in my name, including messages, PR descriptions and emails.
Apply it to my authored text, not your own explanations.

## Commits

- Always sign commits with my configured key. Never disable signing with `--no-gpg-sign`,
  `-c commit.gpgsign=false`, or any other override, including in non-interactive shells. If signing
  fails or hangs, stop and report it instead of committing unsigned.

## Pull and merge requests

- Attach review comments to a relevant line or range, or reply to an existing thread; 
  no floating general review comments.
- Assign the authenticated user when creating a PR or MR.

## Tool use and MCPs

Prefer directly exposed host tools (including T3 and local Blender tools) and their live documentation.
Search `executor` first for other integrations before declaring a capability unavailable.

Never use Codegraph when working on Elixir, including Elixir code in mixed-language repositories.
Use `rg` and read the source directly instead; Codegraph does not support Elixir.

## Writing density

Use plain, literal language. Avoid decorative metaphors and phrases that display the writer rather than convey
the idea; say what you mean directly.

## Scope

Implement the requested behavior completely. Fix unrelated issues only when they block it; otherwise record a
small finding as a `FIXME:` at the affected code, or a multi-file/architectural finding in `.agents/notes/proposed/`.
For ambiguity, implement the reading best supported by the request and surrounding code, state the assumption,
and avoid building alternate interpretations.

Scratch verification need not be kept. Commit tests when requested or customary for this kind of change in the
repository; keep them sized like neighboring tests, roughly one focused test per behavior. Do not turn scratch
checks into permanent test files.

## Agent notes

Before implementing, search `.agents/notes/proposed/` for relevant notes. Move implemented notes to `implemented/`
in the implementing commit/PR, rewrite them in the implemented format and repair links. Split partial implementation;
do not record progress in proposed notes or move them in a separate follow-up commit.
