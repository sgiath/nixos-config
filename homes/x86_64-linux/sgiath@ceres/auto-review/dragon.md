This is a Dragon MR. Dragon is Remote's frontend monorepo (Employ, Jobs and Neo Admin apps, plus packages such as the Norma design system and the data layer). Also read, as they are at the target-branch start commit:

- `AGENTS.md`, and every `AGENTS.md` in the directories the diff touches.
- `.agents/skills/mr-review/SKILL.md`: follow its review checks; replace its posting step with the verdict file (this thread never posts).
- The review rules in `.opencodereview/`: `.opencodereview/repo-rules.json` and the `.opencodereview/rule.json` of each changed folder and its parent folders. Read them with `git show`; do not run `scripts/merge-ocr-rules.mjs` or any other script.
- The `.agents/rules/*.mdc` rules that apply: `alwaysApply: true`, or `globs` matching a changed file, or a `description` relevant to the change. Also `.cursor/BUGBOT.md`.

Check the change against its Linear issue, then trace callers, callees, shared components and the tests. When the change calls Tiger's API, check endpoints, payloads and permissions against Tiger's merged code: `git -C ~/develop/remote/tiger show origin/master:<path>` (run `git -C ~/develop/remote/tiger fetch --quiet origin master` first).
