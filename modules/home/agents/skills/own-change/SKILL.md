---
name: own-change
disable-model-invocation: true
description: "Manual only: invoke /skill:own-change or explicitly request own-change to implement a change in a new worktree, commit and publish it, then babysit all required PRs until merge-ready. Never auto-trigger."
---

# Own a change through merge readiness

## Manual invocation only

Run ONLY when the user invokes /skill:own-change or explicitly asks to use own-change. Never select this skill automatically for a generic implementation, bug-fix, commit or PR request. Do not invoke it just because its description or another document mentions it. Preserve disable-model-invocation: true in this skill's frontmatter when maintaining it.

The invocation authorizes creating a task worktree/branch, implementing the requested change, committing all intended task work, pushing, creating PRs, and running skill://babysit-pr until merge-ready. It does not authorize merging, enabling auto-merge, deployment, destructive cleanup, inclusion of unrelated work or bypassing repository protections.

## 1. Establish scope and isolate work

- Resolve the requested behavior and acceptance criteria from the user's request, repository conventions, ticket and supplied context. If no change was supplied and context cannot establish one, ask what to implement rather than inventing scope.
- Inspect the current repository, branch, dirty state, relevant remotes and base. Record and preserve existing user changes; never stash/reset/clean the main checkout just to start. If the requested change depends on existing uncommitted work, isolate only the relevant work safely without removing the original; ask only when ownership/scope cannot be established.
- Read skill://worktrunk. Fetch the intended remote base and create a NEW task branch and worktree with wt switch --create <task-branch> --base <verified-base> --no-cd --format json. Default to the verified current remote default branch for independent work; use the intended parent when the user requests a stacked change. Do not branch from unrelated local commits accidentally.
- Use the returned worktree path for every edit, command and delegated assignment; separate tool calls do not inherit wt's directory change. Do not guess the path, use --clobber or bypass hook approval. Read skill://parallel-pr-worktrees-elixir for core_v2/Elixir setup, verify the selected apps' environment and avoid copying stale build paths or racing dependency setup.
- Make a task list through implementation, behavioral verification, publication and PR babysitting. Record the source checkout, new worktree, branch and base. On resuming this already-started workflow, reuse its recorded task worktree rather than creating another one.

## 2. Implement and verify the complete change

- Follow repository patterns and relevant domain skills. Keep the implementation direct and scoped. Include all affected consumers, cross-app configuration, migrations and necessary companion-repository changes; no unfinished compatibility shim or isolated server change with missing clients.
- Delegate genuinely independent slices where useful, with exact worktree/path ownership and shared contracts. The main agent remains responsible for integration, correctness and final verification. Do not let delegates mutate the original checkout.
- Run the scenario that proves the change: reproduce and confirm a bug fix; exercise the actual UI for visual changes; exercise new API/CLI behavior and applicable project gates. Keep regression tests for plausible observable failures, not tests that merely mirror implementation. Do not claim unrun local e2e or production checks.
- After behavior is proven, complete in-scope documentation/changelog/generated-artifact updates according to repository conventions and remove throwaway scaffolding. Review the complete change for missed callers, unnecessary complexity, accidental user edits and secrets.

## 3. Commit and publish

- Read skill://conventional-commit. Commit EVERYTHING intended for this change, including related tests, required lock/schema changes and documentation, in coherent commits. 'Everything' does not include secrets, ignored dependency/build caches, machine-local files or unrelated user/concurrent-agent work. Account for any intentionally uncommitted files.
- Push the task branch explicitly to the verified remote with upstream tracking. Search for an existing open PR for the exact head repository/branch before creation; an API error is not evidence no PR exists.
- Create a non-draft PR using the repository template, explicit base/head, clear rationale and actual verification results. Assign the authenticated user (gh pr create --assignee @me). For companion PRs, describe dependencies and safe merge order without deploying or merging them.

## 4. Babysit until ready

Read and execute skill://babysit-pr on the PR. Do not merely mention it in the handoff, start a detached watcher, or stop after submitting the PR. For required companion PRs, apply the same loop to each and ensure the complete change is ready in its documented merge order.

The babysit-pr skill owns the CI/review state machine: wait for all CI including reviewer jobs, read every review conversation, fix failures, reply with evidence, resolve addressed concerns, push and repeat for the current head. Follow its full finish gate, including mergeability, required approvals and unchanged head SHA.

Stay with the task while work remains actionable. Do not declare completion at implementation, commit, PR creation, first green check or first completed review round. Required human approvals, unavailable access or a genuine external decision can block completion; report the exact unmet condition instead of claiming readiness. Do not fabricate approval or bypass protections to satisfy the goal.

## Delivery

Return the PR URL(s), worktree/branch, concise change summary, verification/CI result, review status and merge readiness. On an external blocker, include what is needed to resume. Leave branches/worktrees available for review and leave PRs open. The user decides when to merge.
