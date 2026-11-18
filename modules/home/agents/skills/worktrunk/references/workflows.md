# Configuration and handoffs

## Two Types of Configuration

Worktrunk uses two separate config files with different scopes and behaviors:

### User Config (`~/.config/worktrunk/config.toml`)

- **Scope**: Personal preferences for the individual developer
- **Location**: `~/.config/worktrunk/config.toml` (never checked into git)
- **Contains**: LLM integration, worktree path templates, command settings, user hooks, approved commands
- **Permission model**: An explicit user request for the specific config change counts as consent; do not ask again. Advice-only requests do not authorize edits. Otherwise propose the change and obtain consent first
- **See**: `references/config.md` for detailed guidance

### Project Config (`.config/wt.toml`)

- **Scope**: Team-wide automation shared by all developers
- **Location**: `<repo>/.config/wt.toml` (checked into git)
- **Contains**: Hooks for worktree lifecycle (pre-start, pre-merge, etc.)
- **Permission model**: Proactive (create directly, changes are reversible via git)
- **See**: `references/hook.md` for detailed guidance

## Determining Which Config to Use

When a user asks for configuration help, determine which type based on:

**User config indicators**:

- "set up LLM" or "configure commit generation"
- "change where worktrees are created"
- "customize commit message templates"
- Affects only their environment

**Project config indicators**:

- "set up hooks for this project"
- "automate npm install"
- "run tests before merge"
- Affects the entire team

**Both configs may be needed**: For example, setting up commit message generation requires user config, but automating quality checks requires project config.

## Core Workflows

### Setting Up Commit Message Generation (User Config)

Most common request. See `references/llm-commits.md` for supported tools and exact command syntax.

1. **Detect available tools**

   ```bash
   which claude codex llm aichat 2>/dev/null
   ```

2. If none are installed, show supported options from the reference; do not install one.

3. **Determine config change** - Get the exact command from `references/llm-commits.md`

   ```toml
   [commit.generation]
   command = "..."  # see reference/llm-commits.md for tool-specific commands
   ```

   If the user already explicitly requested this specific change, proceed without another confirmation. Otherwise show the proposal and ask: "Should I add this to your config?"

4. **Apply the authorized change**
   - Check if config exists: `wt config show`
   - If not, guide through `wt config create`
   - Read, modify, write preserving structure

5. **Suggest testing**
   ```bash
   wt step commit --show-prompt | head  # verify prompt builds
   # Run wt merge only when merging is authorized.
   ```

### Setting Up Project Hooks (Project Config)

Common request for workflow automation. Follow discovery process:

1. **Detect project type**

   ```bash
   ls package.json Cargo.toml pyproject.toml
   ```

2. **Identify available commands**
   - For npm: Read `package.json` scripts
   - For Rust: Common cargo commands
   - For Python: Check pyproject.toml

3. **Design appropriate hooks**
   - Dependencies (fast, must complete) → `pre-start`
   - Tests/linting (must pass) → `pre-commit` or `pre-merge`
   - Long builds, dev servers → `post-start`
   - Terminal/IDE updates → `post-switch`
   - Deployment → `post-merge`
   - Cleanup tasks → `pre-remove`

4. **Validate commands work**

   ```bash
   npm run lint  # verify exists
   which cargo   # verify tool exists
   ```

5. **Create `.config/wt.toml`**

   ```toml
   # Install dependencies when creating worktrees
   pre-start = "npm install"

   # Validate code quality before committing
   [pre-commit]
   lint = "npm run lint"
   typecheck = "npm run typecheck"

   # Run tests before merging
   pre-merge = "npm test"
   ```

6. **Add comments explaining choices**

7. **Suggest testing**
   ```bash
   wt switch --create test-hooks
   ```

**See `references/hook.md` for complete details.**

### Adding Hooks to Existing Config

When users want to add automation to an existing project:

1. Read `.config/wt.toml` with the file-reading tool.

2. **Determine hook type** - When should this run?
   - Creating worktree (blocking) → `pre-start`
   - Creating worktree (background) → `post-start`
   - Every switch → `post-switch`
   - Before committing → `pre-commit`
   - Before merging → `pre-merge`
   - After merging → `post-merge`
   - Before removal → `pre-remove`

3. **Handle format conversion if needed**

   Single command to named table:

   ```toml
   # Before
   pre-start = "npm install"

   # After (adding db:migrate)
   [pre-start]
   install = "npm install"
   migrate = "npm run db:migrate"
   ```

4. **Preserve existing structure and comments**

### Validation Before Adding Commands

Before adding hooks, validate:

```bash
# Verify command exists
which npm
which cargo

# For npm, verify script exists
npm run lint --dry-run

# For shell commands, check syntax
bash -n -c "if [ true ]; then echo ok; fi"
```

**Dangerous patterns** - Warn users before creating hooks with:

- Destructive commands: `rm -rf`, `DROP TABLE`
- External dependencies: `curl http://...`
- Privilege escalation: `sudo`

## Permission Models

### User Config: Conservative

- **Edit only with consent** - A specific explicit change request is sufficient; do not add another approval checkpoint. For advice-only or otherwise unauthorized changes, show the proposal and obtain consent first
- **Never install tools** - Provide commands for users to run themselves
- **Preserve structure** - Keep existing comments and organization
- **Validate first** - Ensure TOML is valid before writing

### Project Config: Proactive

- **Create directly** - Changes are versioned, easily reversible
- **Validate commands** - Check commands exist before adding
- **Explain choices** - Add comments documenting why hooks exist
- **Warn on danger** - Flag destructive operations before adding

## Common Tasks Reference

### User Config Tasks

- Set up commit message generation → `references/llm-commits.md`
- Customize worktree paths → `references/config.md#worktree-path-template`
- Custom commit templates → `references/llm-commits.md#templates`
- Configure command defaults → `references/config.md#command-settings`
- Set up personal hooks → `references/config.md#user-hooks`

### Project Config Tasks

- Set up hooks for new project → `references/hook.md`
- Add hook to existing config → `references/hook.md#configuration`
- Use template variables → `references/hook.md#template-variables`
- Add dev server URL to list → `references/config.md#dev-server-url`

## Key Commands

```bash
# View all configuration
wt config show

# Create initial user config
wt config create

# LLM setup guide
wt config --help
```

## Loading Additional Documentation

Load **reference files** for detailed configuration, hook specifications, and troubleshooting.

Find specific sections with grep:

```bash
grep -A 20 "## Setup" references/llm-commits.md
grep -A 30 "### pre-start" references/hook.md
grep -A 20 "## Warning Messages" references/shell-integration.md
```

## Hook Approvals in Non-Interactive Sessions

Project hooks and project aliases prompt for approval on first run, so an untrusted `.config/wt.toml` can't silently execute arbitrary commands. Agents running `wt merge`, `wt switch`, or other commands that trigger hooks will hit an error like:

```
▲ cargo-difftest needs approval to execute 1 command:
○ post-merge install:
  cargo install --path .
✗ Cannot prompt for approval in non-interactive environment
↳ To skip prompts in CI/CD, add --yes; to pre-approve commands, run wt config approvals add
```

Two resolutions exist - pick based on who the agent is running for:

- **`wt config approvals add`** - interactive prompt that stores approvals to `~/.config/worktrunk/approvals.toml`. Run once per project; persists across invocations until the command template changes or the project moves. This is the right choice when the human owns the trust decision.
- **`--yes`** / `-y` - bypasses approval for a single invocation. Appropriate for CI/CD where hook contents are controlled by the pipeline itself.

**When invoked as an agent, stop and escalate to the user** - pre-approval is a security decision about whether this project's hooks should be trusted to run arbitrary commands on their machine. Tell the user to run `wt config approvals add` (or review and re-run with `--yes` if they accept the CI-style one-shot bypass). Don't reach for `--yes` on the user's behalf just to unblock the command.

## Advanced: Agent Handoffs

When the user requests spawning a worktree with an agent in a background session ("spawn a worktree for...", "hand off to another agent"), use the appropriate pattern for their terminal multiplexer. Substitute `<agent-cli>` with the CLI you are running as: `claude` for Claude Code, `'opencode run'` for OpenCode.

**tmux** (check `$TMUX` env var):

```bash
tmux new-session -d -s <branch-name> "wt switch --create <branch-name> -x <agent-cli> -- '<task description>'"
```

**Requirements** (all must be true):

- User explicitly requests spawning/handoff
- User is in a supported multiplexer (tmux or Zellij)
- The user's project instructions (`CLAUDE.md` or `AGENTS.md`) or an explicit prompt authorize this pattern

**Do not use this pattern** for normal worktree operations.
…
**Do not** use `Agent { isolation: "worktree" }` for this. Claude Code passes its internal agent ID as `name` to the `WorktreeCreate` hook, so `wt` creates the worktree as `worktrunk.agent-<id>` on a throwaway branch. If the sub-Agent then creates a feature branch on top, you end up with non-canonical paths, orphan branches, and post-start hooks fired against the wrong branch. Pre-creating with `wt switch --create` keeps path, branch, and hook target aligned.
