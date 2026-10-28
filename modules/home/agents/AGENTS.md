Think independently, speak candidly, and treat the user as a peer.

## Preferences

- Prefer boring, direct code and deletion over speculative abstractions or dependencies. 
  For internal API replacements, migrate callers and remove the old path rather than 
  keeping a compatibility layer; preserve required external compatibility.
- Avoid stopgaps meant to be replaced. If a deliberate simplification has a known ceiling, 
  leave a `FIXME:` naming the limitation and what would justify changing it. If the repository's
  lint rejects FIXME tags, use its documented form for known limitations instead.
- Keep implementation modules around 500 lines or less when a cohesive split exists; test 
  files may be longer.
- For bug fixes and new behavior, write the test first, run it and see it fail, then implement;
  report the red run. A regression test counts only after you have seen it fail without the fix.
- Use `verified-work` for substantial implementation or investigation: choose verifiable steps before changing
  behavior, and own their handoffs through the requested outcome. If a required reproduction or verification
  gate cannot be established or met, ask me how to proceed; do not silently weaken it or proceed past it.
  In an unattended scheduled run, the task prompt's authorization replaces asking me: record the blocker with its
  evidence and options, and continue with independent work.
- Follow `verified-work` model routing. Codex with `gpt-6.1-sol` does all work before and around a production
  change: code exploration, research, investigation, reproduction including the failing test, throwaway tests and
  scripts, production-data probes, screenshots and verification. Claude with Opus 5.5 (`claude-opus-5-5`) starts
  only when the cause is established and the reproduction and verification commands are ready; it then decides
  where and how to fix the production code and writes it. Updates to existing UIs that do not require a new
  design count as production code. An Opus thread delegates the other phases to Codex instead of doing them
  itself. A task-specific choice overrides this.
- When a complicated fix or PR needs an independent review, use Codex with `gpt-6.1-sol` at `high`
  reasoning effort on the `fast` service tier for its thorough review, including production-code correctness
  and design judgments. Production implementation remains with Opus.
- Always use the `fast` service tier for Codex with `gpt-6.1-sol`, including delegated tasks. Scheduled tasks are
  the exception: they and the threads and delegates they start use the default tier, and Claude without fast mode.
- Adversarial security reviews go to Codex `gpt-daybreak-blue-latest`. If a review round is refused on cybersecurity
  grounds, record the refusal and skip that round: do not reword the brief, retry another model, or block the work
  on it. A required security review that was refused is reported as skipped, not passed.
- Use Claude with `fable-5-1` at `xhigh` reasoning effort sparingly, for creating and designing new UIs or
  substantial redesigns where its visual and UX judgment adds value, including animations and transitions.
  Limit its work to the design and implementation that requires those choices. Routine UI updates, bug fixes,
  investigation, testing, screenshots, review and verification follow the general routing above; UI involvement
  alone is not a reason to use Fable or spawn a Fable subagent.
- Long-running jobs should expose start, useful progress, completion, and diagnosable 
  failures without noisy routine logging.
- Every wait has a timeout. Wait on builds and downloads with one blocking command or a monitor that
  fires only on completion, failure or a threshold; do not post status turns that report nothing new.
- Stop processes by the PID you recorded at launch or by `/proc/<pid>/cmdline`; never `pkill` or
  `kill $(pgrep -f …)`, which also matches your own shell.
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
- A checkout may hold other sessions' uncommitted edits. Stage explicit paths; never `checkout`, `restore`,
  `add -A` or `commit -a` paths you did not change, and undo formatter rewrites only in files your own
  command touched.

## Pull and merge requests

- Attach review comments to a relevant line or range, or reply to an existing thread; 
  no floating general review comments.
- Assign the authenticated user when creating a PR or MR.

## Tool use and MCPs

Prefer directly exposed host tools (including T3 and local Blender tools) and their live documentation.
Every other integration, including Slack, lives in `executor`: discover it with executor's tool search instead of
looking for a direct tool, and search there before declaring a capability unavailable.

When I ask to use Whiteboard, use the installed dev.fast Whiteboard application through its `whiteboard`
CLI or MCP tools and load the `whiteboard` skill. Do not substitute a custom website, HTML preview, or
another visualization tool unless I explicitly ask for one. If Whiteboard is unavailable, explain the
blocker before choosing another tool.

I especially like Whiteboard's native Flow feature. Prefer it when explaining processes, user journeys,
control flow, or branching behavior. Use clear steps and labeled branches, show relevant failure and
retry paths, and link steps to the underlying code when useful.

Never use Codegraph when working on Elixir, including Elixir code in mixed-language repositories.
Use `rg` and read the source directly instead; Codegraph does not support Elixir.

The shell is zsh: an unquoted `$VAR` does not word-split and an unmatched glob aborts the command. Use arrays
(`files=(a.ex b.ex); mix credo $files`) or `${=VAR}`, and quote glob arguments such as `--include='*.ex'`.

When creating T3 threads or scheduled tasks, set reasoning effort high, runtime full access and an explicit
`workspaceStrategy` on the repository's actual default branch (check it; not every repository uses `main`),
then read the stored thread or task back to confirm. Scheduled tasks start a fresh thread per run
(`bindToCurrentThread=false`) unless I ask for runs to continue a thread; T3 then stores a `main`-based worktree
that the scheduler tools cannot change, so in a repository without `main` check the stored workspace afterwards.

Machine-local facts about a repository (local services, ports, environment quirks) live in
`~/.agents/local/<repository>.md`. Read it when it exists, and record such facts there rather than in a
harness-specific memory.

CrazyEgg AWS: bare `aws` (default credential chain) is already an MFA session; I never need to run anything for
it. `awsp` does not exist here, so ignore repository docs that ask for `awsp crazyegg`, and never pass
`--profile crazyegg` (long-term keys, denied without MFA). An AccessDenied with "no identity-based policy allows"
means the session is older than 8 h: run `systemctl --user start aws-secrets`, then retry before reporting a
blocker (`~/nixos/modules/home/work/aws.nix`).

## Writing density

Use plain, literal language. Avoid decorative metaphors and phrases that display the writer rather than convey
the idea; say what you mean directly.

## Scope

Implement the requested behavior completely. Fix unrelated issues only when they block it; otherwise record a
small finding as a `FIXME:` at the affected code, or a multi-file/architectural finding in `.agents/notes/proposed/`.
For ambiguity, implement the reading best supported by the request and surrounding code, state the assumption,
and avoid building alternate interpretations.

Run whatever tests you need to verify a change, but keep them throwaway by default. Commit a test only when it
exercises production code and adds a meaningful guarantee that part of the system keeps working: no tests for CI
scripts or scratch tooling, and none that mirror the implementation or merely prove work was done. Keep committed
tests sized like neighboring tests, roughly one focused test per behavior.

A reviewer finding that narrows an explicit decision by me or a stakeholder is a question for me, not a must-fix.

## Agent notes

Before implementing, search `.agents/notes/proposed/` for relevant notes. Move implemented notes to `implemented/`
in the implementing commit/PR, rewrite them in the implemented format and repair links. Split partial implementation;
do not record progress in proposed notes or move them in a separate follow-up commit. In a repository without
`.agents/notes/`, or whose lint rejects markdown there, report such findings instead of writing notes.
