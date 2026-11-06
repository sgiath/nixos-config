This is a Neo MR. Also read, as they are at the target-branch start commit:

- `AGENTS.md`, plus the `AGENTS.md` of every app the diff touches.
- The review protocol `.agents/skills/mr-review/SKILL.md` (`.cursor/rules/mr-review.mdc` only points to it). Follow its Linear context, rules-by-changed-path (read the `.cursor/rules` files it lists) and trace/invariant phases. Replace its MR collection with the files in the run directory, its severity labels with the scoring below, and its posting phases with the verdict file. Skip its branch-name check.
