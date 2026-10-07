---
name: worktrunk
description: "Use for wt worktree operations, hooks, aliases, configuration, commit generation, or troubleshooting."
---

# Worktrunk

Use `wt <command> --help` for installed command options. Reference docs are synced from [worktrunk.dev](https://worktrunk.dev); local permission rules below take precedence over upstream examples.

Inside T3, prefer native worktree handoff or an explicit workspace strategy on a requested new thread; `wt switch`
does not update T3's thread binding. Use this skill for terminal workflows, configuration/troubleshooting, companion
checkouts without a native operation, or authorized cleanup when T3 has no removal tool. Verify setup independently:
T3 project setup scripts do not imply Worktrunk hooks ran. Check dirty state and live owners before removal; a linked
or watched thread can still depend on its checkout. These rules also take precedence over handoff examples below.

## Boundaries

- User config (`~/.config/worktrunk/config.toml`): edit only with consent. An explicit request for the specific change already grants consent; do not ask again. Advice-only requests do not authorize edits. Otherwise propose the change and ask first. Preserve structure and comments. Do not install tools for the user.
- Project config (`.config/wt.toml`): versioned team automation may be edited within the requested task. Check commands exist; flag destructive, network-dependent, or privileged hooks before adding them.
- Hook/alias approval is a trust decision. If non-interactive approval fails, ask the user to run `wt config approvals add`; do not bypass it with `--yes`. One-shot `--yes` is for explicitly accepted CI-style execution.
- Outside T3, background agent handoffs require an explicit request, supported multiplexer, and project/prompt authorization. Do not use Claude `Agent { isolation: "worktree" }` for these terminal handoffs; pre-create with `wt switch --create` so branch, path, and hooks agree.

## Choose a reference

- [Configuration workflows](references/workflows.md): config scope, commit generation, hook edits, approvals, and authorized handoffs.
- [Config](references/config.md), [hooks](references/hook.md), [aliases/extensions](references/extending.md).
- Commands: [switch](references/switch.md), [merge](references/merge.md), [list](references/list.md), [remove](references/remove.md), [step](references/step.md).
- [LLM commits](references/llm-commits.md), [shell integration](references/shell-integration.md), [troubleshooting](references/troubleshooting.md), [tips](references/tips-patterns.md), [agent integration](references/claude-code.md).

Start config inspection with `wt config show`; create initial user config with `wt config create` only after consent.
