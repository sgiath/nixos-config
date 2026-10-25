# GitLab MR monitoring in T3

Use the repository's GitLab skills for publication, review policy, CI diagnosis and allowed actions. T3's
`link_pull_request`, `watch_pull_request`, `list_thread_pull_requests` and `unwatch_pull_request` accept full
GitLab MR URLs, including nested groups. The GitHub `pr-state` helper and `gh` commands do not support GitLab.
Authenticate `glab` on the machine running the T3 server, including remote environments.

## Choose the coverage

- For notifications about an open MR's aggregate pipeline, new comments and merge conflicts, use T3's
  persistent watcher. It survives the agent ending its turn and keeps the thread in Working.
- For hung or missing pipelines, individual jobs, manual gates, or a task that continues through merge to
  default-branch CI, use the repository's richer monitor from the outset. T3 ends its watch at merge and
  does not monitor the default branch. Do not run duplicate monitors for the same coverage.
- An explicitly invoked repository workflow keeps its required coverage and stop boundary. Do not replace
  a multi-day or post-merge babysit with T3's open-MR watch merely because registration succeeds.

## Use the T3 watcher

1. Link every task-owned MR by full URL. Read existing discussions, current pipeline/jobs and head revision
   with the repository's GitLab tooling first; old comments do not trigger a wake.
2. Call `watch_pull_request`, confirm `watching: true`, and re-read the state to catch changes during arming.
   Handle any missed work, then end the turn. Subagents return URLs, heads and pending work to their parent;
   only the owning top-level thread watches. Do not disturb another thread's watch.
3. On a wake, re-fetch the MR, its current revision, pipeline/jobs and full discussions. Treat the notification
   as a prompt to inspect, not as evidence that every reviewer finished or the MR is merge-ready. Verify all
   repository readiness gates independently, including approvals and unresolved discussions.
4. If T3 reports that it stopped watching, inspect why and re-arm once when work remains. If registration or
   reads fail again, use the repository monitor and report the failure; do not repeatedly re-arm a broken watch.
5. Before handing readiness or an external blocker back to the user, unwatch every task-owned MR. A pending
   pipeline is a waiting state, not a reason to unwatch. A settled or archived thread must be active before
   starting another watch; respect deliberate user settlement.

## Limits that affect correctness

- GitLab currently supplies one check named `Pipeline` from `head_pipeline`, rather than individual job or
  required-check results. `manual` and `scheduled` map to neutral, and skipped/neutral checks can produce a
  passed notification. Confirm actual pipeline/job states; a blocked manual gate is not green CI. Establish
  that the pipeline covers the intended revision, accounting for merged-results pipelines.
- Missing pipelines have no guaranteed wake on GitLab. An unchanged running pipeline has no stall alarm.
  Approval system notes are filtered out, and reactions are not watcher events. Do not rely on these to
  resume an agent. Read approvals directly before declaring readiness.
- The server sweeps every two minutes, but quiet GitLab MRs can be reread at ten-minute intervals. Your own
  account's comments do not wake it. Incomplete or truncated conversation reads can suppress comment wakes;
  paginate the GitLab conversations yourself when checking readiness.
- Watching stops on merge/close, Stop, settlement/archive, eight consecutive failed reads, or ten consecutive
  comment-only wakes. Rate limiting pauses reads. Registration success establishes that a watch is armed,
  not that future notifications or post-merge coverage have been verified.

<!-- FIXME: Revisit the richer-monitor requirement when GitLab exposes per-job checks and approval events to
     T3, and its watcher provides missing/stalled-pipeline alarms and a post-merge continuation. -->

## Evidence

Checked 2026-10-25 against the running `0.1.3-nightly.20261025.3655` server, upstream commit
`e9d61252f6fd8369b80fe8f7e07209cbbb7221d9`. A live private GitLab MR linked, returned title/branches/state,
armed with `watching: true`, and disarmed with `wasWatching: true`; the temporary link was removed. This
verified registration and reading, not an end-to-end notification after a new GitLab event.

- [T3 source-control documentation](https://github.com/pingdotgg/t3code/blob/e9d61252f6fd/docs/user/source-control.md)
- [GitLab provider capabilities](https://github.com/pingdotgg/t3code/blob/e9d61252f6fd/packages/source-control-gitlab/src/server/GitLabPullRequestProvider.ts)
- [Pipeline and note normalization](https://github.com/pingdotgg/t3code/blob/e9d61252f6fd/packages/source-control-gitlab/src/server/gitLabMergeRequestJson.ts)
- [Watcher events and limits](https://github.com/pingdotgg/t3code/blob/e9d61252f6fd/apps/server/src/orchestration-v2/pullRequestWatch.ts)
- [Polling, read failures and lifecycle](https://github.com/pingdotgg/t3code/blob/e9d61252f6fd/apps/server/src/orchestration-v2/PullRequestWatchReactor.ts)
