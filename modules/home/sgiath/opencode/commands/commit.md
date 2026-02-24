---
description: git commit and push
model: openrouter/z-ai/glm-4.7
subtask: true
---

commit and push

## Atomic Commits

If changes span multiple concerns, create **separate commits** for each. Each commit should:
- Do one thing, describable in one short sentence
- Be as small as possible but complete
- Not break tests (green suite)

Group related file changes together; split unrelated changes into separate commits.

## Message Format

Prefix with type:
docs: / feat: / bug: / ci: / ignore: / wip:

Explain WHY from user perspective, not WHAT. Be specific - avoid generic messages like "improved agent experience".

if there are changes do a git pull --rebase
if there are conflicts DO NOT FIX THEM. notify me and I will fix them

## GIT DIFF

!`git diff`

## GIT DIFF --cached

!`git diff --cached`

## GIT STATUS --short

!`git status --short`
