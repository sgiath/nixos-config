This is a Remote Labs MR. `remote-vibed-labs` is a monorepo and Labs is its `apps/labs/` app, where each LabApp is a small internal tool. Also read, as they are at the target-branch start commit:

- `.cursor/bugbot.md`: Labs' review rules. Read the documents it names: `AGENTS.md`, `apps/labs/AGENTS.md`, the `apps/labs/docs/rules/*.md` file of every rule group the diff touches, `apps/labs/docs/frontend-code-guidelines.md` when the diff touches `apps/labs/frontend/src/` (apply its reviewer grep patterns to the diff), and each other document it lists when the diff touches that document's area.
- For each changed LabApp, every `AGENTS.md` and `README.md` in its directories.

Labs' `review-remote-labs` skill runs scripts, starts subagents and posts to the MR: do not use it. Check the change against its Linear issue, then trace callers, callees and the tests. LabApps that drive Neo are checked against Neo's merged code: `git -C ~/develop/remote/neo-payroll/neo show origin/main:<path>`.
