This is a Tiger MR. Tiger is Remote's platform; for payroll it sends legal entities, employees and payroll runs to Neo and takes Neo's results back. Also read, as they are at the target-branch start commit:

- `AGENTS.md` and `apps/tiger/AGENTS.md`.
- For each changed path, every `AGENTS.md`, `BUGBOT.md` and `.cursor/BUGBOT.md` in its directory or a parent directory up to `apps/tiger/`, including `apps/tiger/test/AGENTS.md` for tests. List them with `git ls-tree -r --name-only <start sha> -- apps/tiger | rg 'AGENTS.md|BUGBOT.md'`. The BUGBOT files are Tiger's review rules.

Tiger's general review instructions (`apps/tiger/.cursor/MR-review-instructions.mdc`) are written for frontend code and its `cm-mr-review` skill for Contractor Management: use neither unless the MR is in that area. Check the change against its Linear issue, then trace callers, callees, sibling integrations and the tests.

When the MR talks to Neo, check requests, responses, webhook events and result names against Neo's merged code: `git -C ~/develop/remote/neo-payroll/neo show origin/main:<path>` (run `git -C ~/develop/remote/neo-payroll/neo fetch --quiet origin main` first). For a Neo change that is not merged yet, find the open Neo MR with `glab mr list -R remote-com/neo-payroll/neo --search <issue>` and read it.
