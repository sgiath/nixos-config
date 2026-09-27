---
name: setup-notes
disable-model-invocation: true
description: "Manual only: invoke /skill:setup-notes to set up the Agent Notes system (`.agents/notes/` proposals and decision records) in a repository that lacks it, or to migrate an existing planning/ADR tree into it. Never auto-trigger."
---

# Set up Agent Notes

Agent Notes are durable proposals and decision records under `.agents/notes/`, organized as `{lifecycle}/{class}/yyyy-mm-dd-topic.md`. The rules live in the repository itself (`.agents/notes/README.md`), so any agent working there follows them without this skill. This skill only installs the system.

Templates are in `references/` next to this file:

| Template                | Installs to                              |
| ----------------------- | ---------------------------------------- |
| `notes-README.md`       | `.agents/notes/README.md`                |
| `notes-AGENTS.md`       | `.agents/notes/AGENTS.md`                |
| `implemented-AGENTS.md` | `.agents/notes/implemented/AGENTS.md`    |
| `archived-AGENTS.md`    | `.agents/notes/archived/AGENTS.md`       |

## 1. Inspect the repository

- Find the repository root (`git rev-parse --show-toplevel`). In a monorepo, notes live at the root unless the user asks for a per-app tree (e.g. `ai/.agents/notes/`); a per-app README says the notes are for that app.
- If `.agents/notes/` already exists, do not overwrite it. Compare it with the templates, report differences, and change only what the user asks.
- Look for existing planning or decision trees: `docs/tasks/`, `docs/adr/`, `docs/decisions/`, `docs/rfcs/`, `plans/`, `TODO.md`, `.agents/research/`, loose notes. Note them for step 4.
- Find the canonical product documentation: usually `docs/`, else the root `README.md`, else per-app READMEs. This fills the `{{DOCS_*}}` placeholders.
- Check that `.agents/` is not gitignored (`git check-ignore -v .agents/notes/README.md`). If it is, fix the ignore rule; notes must be committed.

## 2. Create the tree

```text
.agents/notes/
├── AGENTS.md
├── README.md
├── proposed/.gitkeep
├── implemented/AGENTS.md
├── rejected/.gitkeep
└── archived/AGENTS.md
```

- Copy the four templates verbatim, then replace the placeholders in `README.md`:
  - `{{PROJECT}}`: the project name, e.g. `Crazy Egg Core V2`.
  - `{{DOCS_LINK}}`: relative link from `.agents/notes/` to the canonical docs, e.g. `../../docs/` or `../../README.md`.
  - `{{DOCS_LABEL}}`: the same path as inline code, e.g. `` `docs/` ``.
- Do not create class directories (`feature/`, `bug-fix/`, `simplification/`, `architecture/`, `process/`, `testing/`) up front. They appear with their first note.
- No `INDEX.md`; the filesystem tree is the inventory.
- Keep the six classes, the four lifecycles, and the section formats unchanged unless the user asks otherwise. Consistency across repositories is the point.

## 3. Wire it into the root agent instructions

Append this section to the repository's root `AGENTS.md` (create the file if missing; if `CLAUDE.md` is a separate file rather than a symlink to `AGENTS.md`, add it there too). Adjust `canonical docs` to name the actual docs location. The lifecycle rule must be in the root file: agents always load it, but they only read `.agents/notes/AGENTS.md` and `README.md` when they open the notes tree, which an agent working from a ticket often never does.

```markdown
## Agent notes

`.agents/notes/` contains durable proposals and decision records. Notes preserve rationale, alternatives, consequences, and required verification; they are not canonical product reference. Follow `.agents/notes/README.md` for lifecycle, classification, format, supersession, and archive rules.

Before implementing anything, search `.agents/notes/proposed/` for a note that covers the work. The commit that implements it also moves the note to `implemented/`, rewritten in the implemented format, with links to it repaired; a partial implementation moves the shipped part and leaves the rest proposed. Never record progress inside a proposed note, and never move a note in a separate follow-up commit.

Before writing or changing canonical docs, read the relevant active Agent Notes and implementation code. If implementation and notes diverge, report the divergence and clarify before documenting behavior.
```

If the root instructions already contain a WHERE TO LOOK or structure table, add a `.agents/notes/` row instead of duplicating the description.

## 4. Migrate existing planning trees (only if found in step 1)

Ask before migrating; it moves and rewrites files the user wrote. When approved:

- Shipped work whose rationale is still current: rewrite into `implemented/{class}/` with the implemented format, verified against the code.
- Shipped work that is only history: `git mv` into `archived/{class}/yyyy-mm-dd-topic.md`, add `Status: implemented` and `Archived: YYYY-MM-DD` under the title, and otherwise leave the content as it was. Do not invent rationale that was not recorded.
- Unfinished work: extract into `proposed/{class}/` notes in the proposed format. Unchecked boxes left in archived files are not a backlog.
- Declined ideas that still prevent a plausible mistake: `rejected/{class}/` with `Status: rejected - <reason>`.
- Dates are when the topic was first proposed: use the file's own date, else `git log --diff-filter=A --format=%as -- <file> | tail -1`.
- Repair every link to moved files, then remove the emptied old tree.

## 5. Finish

- `git add .agents/notes` and the edited root instruction files.
- Check that every relative link in the new files resolves and that no `{{…}}` placeholder remains (`grep -rn '{{' .agents/notes`).
- Commit only if the user asked, e.g. `docs(agents): add agent notes system`.
