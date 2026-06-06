---
name: conventional-commit
description: Write Conventional Commit messages and create atomic git commits. Use whenever Codex is asked to make a commit, commit everything in a repo, split work into commits, draft a commit message, review a commit message, or run git commit.
---

# Conventional Commit

Follow the Conventional Commits format:

```text
<type>(<scope>): <subject>

[body]

[footer]
```

Read the full spec only for edge cases: [specs.md](./reference/specs.md).

## Commit Everything Workflow

When the user asks to "commit everything", "commit this repo", or similar:

1. Inspect all changes with `git status --short` and `git diff`. Include untracked files.
2. Group changes by logical intent, not by file list. Prefer multiple commits when the diff contains separable changes.
3. Stage deliberately for each group with pathspecs or `git add -p`; avoid accidentally staging unrelated leftovers.
4. Before each commit, verify the staged diff with `git diff --cached`.
5. Run relevant tests/checks when practical. If not practical, still make progress and report what was not run.
6. Commit each group with a Conventional Commit message.
7. Finish by reporting created commits and remaining uncommitted changes, if any.

Ask before committing suspicious files such as secrets, huge generated artifacts, local machine state, or files that appear unrelated to the user's request.

## Atomic Commits

Make each commit the smallest complete, meaningful unit of change:

- One concern per commit: do not mix feature work, bug fixes, formatting churn, dependency updates, docs, or generated files unless they are inseparable.
- Each commit should leave the project coherent and buildable as far as the repo allows.
- Split broad work into reviewable commits with subjects that each clearly describe one change.
- Do not rewrite, revert, or discard user changes unless explicitly asked.

Useful split examples:

- `fix(auth): reject expired session tokens`
- `test(auth): cover expired session handling`
- `docs(readme): document login configuration`
- `chore(deps): update lockfile for auth dependency`

## Message Rules

Use one of these types unless the repo clearly uses another convention:

- `feat`: user-facing feature or capability
- `fix`: bug fix
- `docs`: documentation only
- `test`: tests only
- `refactor`: behavior-preserving code change
- `perf`: performance improvement
- `style`: formatting or lint-only change
- `build`: build system, packaging, dependencies, lockfiles
- `ci`: CI configuration
- `chore`: maintenance that does not fit the above

Choose a short lowercase scope from the touched package, module, command, service, or feature. Omit scope only when no useful scope exists.

Subject rules:

- Use imperative mood: `add`, `fix`, `remove`, `update`.
- Keep it concise and specific.
- Do not end with a period.
- Do not use vague subjects like `update files`, `misc changes`, or `fix stuff`.

Body rules:

- Include a body when the reason, tradeoff, migration, or risk is not obvious from the subject.
- Wrap body lines at a readable width.
- Explain why the change was made and any important behavior impact.

Footer rules:

- For breaking changes, use `!` in the header and include a `BREAKING CHANGE:` footer when helpful.
- If a Shortcut ticket is clearly present in the user request, branch name, task text, or existing context, include `Fixes sc-12345`.
- Do not invent Shortcut IDs. If no Shortcut ticket is mentioned anywhere, omit the footer.

## Final Check

Before running `git commit`, confirm:

- The staged diff contains exactly one logical change.
- The message starts with `type(scope): subject` or `type: subject`.
- The type matches the change.
- The scope is useful and not overly broad.
- Any Shortcut or breaking-change footer is real and correctly formatted.
