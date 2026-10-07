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
- Reuse a task worktree already prepared by T3, an invoking driver or an earlier turn. Verify its branch/base
  and task ownership before editing. Otherwise create a new task branch/worktree from the verified remote default
  branch for independent work, or the intended local parent for a requested stack; avoid unrelated local commits.
- In T3, inspect `t3_worktree_status`. When this thread is in the root checkout, call `t3_worktree_handoff` with
  the explicit branch/base and a continuation prompt carrying the task, acceptance criteria and remaining steps.
  Use `startFromOrigin:true` for an upstream base and `false` for a local stack parent. This is the last tool call
  of the turn; continue in the rebound workspace next turn. Handoff cannot move an already-attached thread: if
  it belongs to another task, report the binding conflict rather than creating an invisible shell workspace.
  Separate top-level threads require the user's request or an invoking workflow that authorizes them.
- Outside T3, or for a companion repository without a native workspace operation, read skill://worktrunk and use
  `wt switch --create <task-branch> --base <verified-base> --no-cd --format json`. Use the returned absolute path
  for every command and delegated assignment; shell directory changes do not persist across tool calls.
- Read repository environment/worktree instructions and available setup skills. T3 runs registered project setup,
  not necessarily Worktrunk hooks: verify setup completion, required ignored configuration, direnv, dependencies
  and selected apps' environment before testing. Follow repository cache-copy rules; do not copy stale formatter
  descriptors or race dependency setup. Do not guess paths, use `--clobber` or bypass hook approval.
- Make a task list through implementation, behavioral verification, publication and PR babysitting. Record the source checkout, new worktree, branch and base. On resuming this already-started workflow, reuse its recorded task worktree rather than creating another one.

## 2. Implement and verify the complete change

- Follow repository patterns and relevant domain skills. Keep the implementation direct and scoped. Include all affected consumers, cross-app configuration, migrations and necessary companion-repository changes; no unfinished compatibility shim or isolated server change with missing clients.
- Delegate genuinely independent slices where useful, with exact worktree/path ownership and shared contracts. The main agent remains responsible for integration, correctness and final verification. Do not let delegates mutate the original checkout.
- Run the scenario that proves the change: reproduce and confirm a bug fix; exercise the actual UI for visual changes; exercise new API/CLI behavior and applicable project gates.
- For UI verification in T3, prefer its collaborative preview: inspect status, open if needed, and use
  snapshot-provided locators and focused interaction tools. Use evaluation only where the tool's contract
  supports it. Diagnose a failed call and correct actionable arguments before switching tools; use a fallback
  when the preview tools are absent or explicitly unavailable. Keep regression tests for plausible observable
  failures, not tests that merely mirror implementation. Do not claim unrun local e2e or production checks.
- After behavior is proven, complete in-scope documentation/changelog/generated-artifact updates according to repository conventions and remove throwaway scaffolding. Review the complete change for missed callers, unnecessary complexity, accidental user edits and secrets.

## 3. Commit and publish

- Read skill://conventional-commit. Commit EVERYTHING intended for this change, including related tests, required lock/schema changes and documentation, in coherent commits. 'Everything' does not include secrets, ignored dependency/build caches, machine-local files or unrelated user/concurrent-agent work. Account for any intentionally uncommitted files.
- Call skill://pr to publish or update every task PR. Pass the verified worktree, branch/base, existing commit/push
  authorization, actual verification and companion dependencies. It owns duplicate detection, repository policy,
  publication, assignment and T3 registration. Do not repeat PR creation here.

## 4. Babysit until ready

Read and execute skill://babysit-pr on every required PR and companion. In T3, a successful persistent watch followed
by ending the turn is a waiting state of this workflow. Resume from the recorded PRs on a notification; do not
recreate the worktree or PRs. Subagents return monitoring ownership to their parent as babysit-pr requires.

The babysit-pr skill owns the CI/review state machine: wait for all CI including reviewer jobs, read every review conversation, fix failures, reply with evidence, resolve addressed concerns, push and repeat for the current head. Follow its full finish gate, including mergeability, required approvals and unchanged head SHA.

Stay with the task while work remains actionable. Yield to T3 when waiting for CI/review; do not declare completion
at implementation, PR creation, first green check or first review round. Required human approvals, unavailable access
or a genuine external decision can block completion; unwatch before handing back and report the exact unmet condition.
Do not fabricate approval or bypass protections to satisfy the goal.

## Delivery

Return the PR URL(s), worktree/branch, concise change summary, verification/CI result, review status and merge readiness. On an external blocker, include what is needed to resume. Leave branches/worktrees available for review and leave PRs open. The user decides when to merge.
