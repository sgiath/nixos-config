# auto-review

Reviews the merge requests and pull requests that ask for Filip's review, in T3 threads, and posts the findings
that reach a threshold as line comments in his name. One user service (`auto-review.service`) runs the poller and a
local web UI on `127.0.0.1` (port `services.auto-review.port`, default 8787).

It replaces the Spain G2N sprint poller in `~/.agents/local/spain-review/`, which stays there as an archive.

## How a review runs

1. **Discover.** Every poll interval, for each enabled watched repo, list the open MRs/PRs that request review from
   the authenticated user (`glab api user`, `gh api user`), plus open MRs by `include_authors`. Each candidate is
   checked against the repo's rules (below). A candidate that is not eligible yet (draft, pipeline not green) is
   shown as *waiting* and checked again next poll; nothing is stored for it.
2. **Claim.** An eligible candidate becomes a review row keyed by
   `(repo, number, head SHA, merge-base SHA, target branch)`. The key is unique in SQLite, so the same diff is never
   reviewed twice, whatever its status (done, failed, cancelled). A new head or a new base is a new key; queued or
   running reviews of an older key of the same MR are *superseded* and their T3 threads stopped. Only a manual
   *Retry* or *Review again* starts another attempt of an existing key.
3. **Launch.** When a slot is free (`max_concurrent`, the daily launch cap, quiet hours, pause, provider limits), the
   head and target are fetched into the repo's checkout (`refs/auto-review/<number>`), the MR evidence is written to
   `runs/<review id>-<attempt>/` (with CodeRabbit's "Prompt for AI Agents" blocks removed from discussions, since
   the review would hold every finding as a prompt injection over them), and a T3 thread is launched with the repo's reviewer provider, model and effort in
   one call. Its title ends with `(review <database id>.<review id>.<attempt>)`, and a launch whose reply was lost
   adopts the thread carrying that tag instead of creating a second one. The MR/PR is linked to the thread, so T3
   shows its state there and settles the thread when it merges.
4. **Monitor.** Each poll reads the thread. A thread stopped by a provider usage limit becomes *limited* until the
   reset T3 reports (or the reset parsed from the message, with its date). New launches on that provider wait for the
   reset; afterwards the service sends "continue" to the stopped thread itself. Limited time does not count toward
   `review_timeout_minutes`.
5. **Decide.** The agent writes `verdict.json` in its run directory. The verdict must name the review id, attempt,
   head and base it was launched for, so a stale thread cannot satisfy a newer attempt. Scores are recomputed as
   `frequency × severity`; a finding reaches the threshold when the product is at least the repo's threshold.
6. **Post.** Just before writing, the MR is re-read: it must still be open, at the same head and base, and still
   eligible. Each finding at or above the threshold is posted as one inline discussion on its diff line (GitLab) or
   as one review comment on its diff line (GitHub), topped by the note template. A finding the agent ties to an
   existing open thread is not posted again. A finding without a valid diff line is never posted; it is shown in the
   UI as *unanchored*. Nothing is ever posted as a general MR comment. On GitLab, Filip's reviewer state then
   becomes *requested changes* when a posted or already open finding scores at least `request_changes_threshold`,
   else *left comments* when anything was posted (skipped while he has unpublished drafts). GitHub gets no review
   state: a `REQUEST_CHANGES` review needs a top-level body, which would be a general comment.
7. **Approve.** Only under the repo's `approval: when_clean` policy, and only when the verdict is complete, no finding
   reaches the threshold (posted, already open or unanchored), every changed file was read and no prompt injection
   was found. The approval is pinned to the reviewed head SHA.
8. **Settle.** With `auto_settle` on, the T3 thread is settled once its comments are posted, or when the review ends
   with nothing to post. A failed review keeps its thread unsettled.

Dry run stops at step 6: findings are recorded and shown, nothing is written to GitLab or GitHub, except a finding
you post yourself with *Post anyway* in the UI. Pause stops
launching and posting; running threads are still monitored.

## After the comment: replies and fixes

Every comment the service posts is tracked (SQLite `threads`, keyed by its hidden marker) until it is settled.

- **Watching.** Each poll reads the MRs that have an `open` or `disputed` thread. A thread someone resolved on the
  forge becomes `resolved_elsewhere` and is no longer watched; a closed or merged MR closes its threads. Filip's own
  replies only count as seen. A reply by anyone else queues one `follow_up` review at the MR's current head
  (`kind: follow_up`, keyed by the reply note ids, so the same reply never queues twice), unless a review of that MR
  is active. Follow-ups do not need the review request; they share the queue, limits, pause, quiet hours, cancel and
  retry with reviews, and a new head supersedes them.
- **Judging.** A follow-up (`prompts/follow_up.md`) only judges threads; every review of a new head also judges
  them (`prompts/threads.md` in both). The run directory gets `mr/own_threads.json` (open/disputed threads with all
  their notes) and `mr/settled_threads.json`; the verdict's `threads` must judge each listed thread once as
  `fixed`, `answered`, `open` or `disputed`, with reasoning and, except for `open`, a reply in Filip's voice.
- **Acting.** `fixed`/`answered`: the reply is posted in the thread (short note on top, hidden reply marker so a lost
  answer is not posted twice), then the thread is resolved; from then on the thread counts as fixed, and a later
  finding tied to it is `settled` (not posted, not blocking). `open`: nothing is written. `disputed`: nothing is
  written; the review ends `needs_attention`, Filip is notified, and the UI's *your decision* section shows the
  reasoning and the proposed reply, which he can send (thread stays open), accept the author's answer (resolve; it
  counts as fixed) or keep open. A failed reply or resolve leaves the thread open and the review `needs_attention`.
- **Approving.** An open or disputed thread blocks approval of any review of the MR. After a follow-up or an accepted
  answer settles threads, the latest finished review is reconsidered: if it is at the current head, read every file,
  found no injection, and each of its findings reaching the threshold now sits in a settled thread, it is approved
  under `approval: when_clean`, or the MR is marked reviewed under `never` (clearing an earlier *requested
  changes* on GitLab). An open thread scoring at least `request_changes_threshold` keeps requesting changes.
- Dry run records the judgments' reasoning and writes nothing.

## Settings and which one wins

Nix (`services.auto-review.settings`) writes the defaults to a read-only file in the store. The UI writes only the
fields you change to `$XDG_STATE_HOME/auto-review/overrides.json`. **A field set in the UI wins over the Nix value**;
resetting it in the UI removes the override and the Nix value applies again. Repos merge by id: a repo defined in Nix
can be disabled or adjusted in the UI but not deleted; a repo added in the UI exists only in the overrides file.
Nix changes take effect when Home Manager restarts the service.

| Setting | Default | Meaning |
| --- | --- | --- |
| `paused` | `false` | No launches, no posts. |
| `dry_run` | `false` | Review, but write nothing to GitLab/GitHub (*Post anyway* still posts). |
| `poll_interval_seconds` | `60` | Time between polls (minimum 15). |
| `threshold` | `5` | Minimum `frequency × severity` that gets posted. |
| `request_changes_threshold` | `30` | Minimum score of a posted or already open finding that requests changes (GitLab). |
| `auto_settle` | `true` | Settle the T3 thread after posting or when nothing is posted. |
| `note_template` | see `auto_review/note.py` | Top of every posted comment; variables below. |
| `reviewer` | `codex` / `gpt-6.1-sol` / `high` | Provider instance, model, effort. |
| `max_concurrent` | `3` | Reviews running at once. |
| `max_launches_per_day` | `null` | Launch cap per local day; `null` is unlimited. |
| `review_timeout_minutes` | `120` | Active running time before a review fails. |
| `timezone` | `Europe/Prague` | Local time for quiet hours and the daily launch cap. |
| `quiet_hours` | off, `22:00`–`07:00` | No launches or posts inside the window (may cross midnight). |
| `notify` | desktop on, no ntfy | Where failures and needs-attention reviews are announced. |

Per repo (`repos.<id>`, id is `gitlab:<path>` or `github:<owner>/<repo>`):

| Setting | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Watch this repo. |
| `checkout` | required | Local clone the review reads from git objects. |
| `t3_project` | required | T3 project the review threads start in. |
| `context` | `""` | Repo-specific review instructions inserted into the brief. |
| `threshold` | `null` (global) | Per-repo threshold. |
| `request_changes_threshold` | `null` (global) | Per-repo request-changes threshold. |
| `reviewer` | `null` (global) | Per-repo provider/model/effort. |
| `approval` | `when_clean` | `never` or `when_clean`. |
| `rules.review_requested` | `true` | Review MRs that request your review. |
| `rules.include_authors` | `[]` | Also review every open MR by these authors. |
| `rules.exclude_authors` | `[]` | Never review MRs by these authors. |
| `rules.require_labels` | `[]` | Review only MRs carrying all of these labels. |
| `rules.exclude_labels` | `[]` | Skip MRs carrying any of these labels. |
| `rules.skip_drafts` | `true` | Wait while the MR is a draft. |
| `rules.wait_for_pipeline` | `true` | Wait until the head pipeline/checks succeed. |

Your own MRs are never reviewed.

Note template variables: `{reviewer}` (your username on that forge), `{provider}`, `{model}`, `{effort}`,
`{harness}`, `{repo}`, `{number}`, `{head_sha}`, `{head_short}`, `{finding_id}`, `{title}`, `{frequency}`,
`{severity}`, `{score}`, `{threshold}`, `{disposition}`. Unknown `{names}` are left as typed and listed by the
preview. A hidden marker is always appended after the body; the service uses it to find its own comments.

## Files

- `$XDG_STATE_HOME/auto-review/state.db`: reviews, findings, events (SQLite).
- `$XDG_STATE_HOME/auto-review/overrides.json`: UI settings.
- `$XDG_STATE_HOME/auto-review/runs/<id>-<attempt>/`: MR evidence, brief, verdict for one attempt; never reused.

Credentials: none of its own. GitLab goes through the `glab` login and GitHub through `gh` with `GH_TOKEN`, which the
unit's `with-api-keys` wrapper reads from sops. Review threads need full-access mode, which a `t3 auth session issue`
bearer cannot start, stop or settle; so the service signs in to T3's MCP endpoint the way T3's own environment links
do: `t3 auth pairing create` mints a 5-minute one-time pairing code, and the OAuth pairing-code decision exchanges it
for a full-access MCP bearer (T3 fixes its lifetime at 30 days). The bearer exists only in the service's memory; it is
rotated every 12 hours and revoked on rotation and at shutdown, and sessions a crashed run left behind (client name
`auto-review …`) are revoked at the next start. No token is written to disk or to the log.

## Commands

- `auto-review serve --defaults FILE`: the service.
- `auto-review import-legacy DIR`: import the Spain poller's reviewed heads as done reviews.

## HTTP API

All responses are JSON. Mutating requests must send `Content-Type: application/json`; requests whose `Host` is not
`127.0.0.1:<port>` or `localhost:<port>`, or whose `Origin` is another site, are refused with 403. Actions that call
GitLab, GitHub or T3 run on the worker; they answer `202 {"accepted": true}` and the result shows up in the next
`GET`. Errors answer `{"error": "message"}` with status 400, 404 or 409.

Timestamps are ISO 8601 UTC strings (`2026-11-05T22:08:00Z`); durations are seconds.

### `GET /api/status`

```json
{
  "now": "2026-11-05T22:08:00Z",
  "paused": false,
  "dry_run": false,
  "poll": {"last_at": "…", "next_at": "…", "last_error": null, "running": false},
  "identities": {"gitlab": "filip.vavera1", "github": "sgiath"},
  "limits": [{"provider": "codex", "until": "…", "reason": "weekly limit"}],
  "quiet": {"enabled": false, "active": false, "until": null},
  "budget": {"running": 1, "max_concurrent": 3, "launched_today": 4, "max_launches_per_day": null},
  "counts": {"queued": 2, "running": 1, "limited": 0, "failed": 1, "waiting": 3}
}
```

### `GET /api/settings`

`{"effective": Settings, "defaults": Settings, "overrides": PartialSettings}`. `Settings` is the table above as JSON:
global keys at the top level and `repos` as an object keyed by repo id; each repo also carries `forge` and `path`.

### `PATCH /api/settings`

Body: a partial settings object, deep-merged into the overrides. A `null` value removes that override (the Nix
default applies again). `{"repos": {"<id>": null}}` removes a UI-added repo, or every override of a Nix repo. A new
repo needs `forge`, `path`, `checkout` and `t3_project`. Answers `200` with the same shape as `GET /api/settings`,
or `400 {"error", "field"}` naming the invalid field.

### `POST /api/note-preview`

Body `{"template": "…"}`; renders it with a sample finding. Answers `{"markdown": "…", "unknown": ["foo"]}`.

### `GET /api/catalog`

Provider instances, models and efforts T3 offers, for the reviewer pickers:
`[{"provider": "codex", "label": "Codex", "models": [{"id": "gpt-6.1-sol", "label": "gpt-6.1-sol", "efforts": ["low", "medium", "high", "xhigh", "max", "ultra"]}]}]`.

### `GET /api/reviews?view=active|history|failed&repo=<id>&limit=50&before=<id>`

`active`: queued, launching, running, limited, deciding, posting (oldest first). `history`: done, cancelled,
superseded (newest first). `failed`: failed (newest first). Each item:

```json
{
  "id": 42, "attempt": 1,
  "repo": "gitlab:remote-com/neo-payroll/neo", "forge": "gitlab", "number": 7627,
  "title": "…", "url": "https://gitlab.com/…/merge_requests/7627", "author": "someone",
  "head_sha": "…40 hex…", "base_sha": "…", "target": "main",
  "status": "running", "outcome": null,
  "reviewer": {"provider": "codex", "model": "gpt-6.1-sol", "effort": "high"},
  "thread_url": "t3-thread://…", "dry_run": false,
  "queued_at": "…", "started_at": "…", "finished_at": null, "elapsed_seconds": 512,
  "limited_until": null, "error": null,
  "counts": {"posted": 0, "would_post": 0, "below": 0, "already_open": 0, "unanchored": 0, "not_posted": 0},
  "approved": false, "settled": false
}
```

`status` is one of `queued`, `launching`, `running`, `limited`, `deciding`, `posting`, `done`, `failed`,
`cancelled`, `superseded`. `outcome` (when done) is `clean`, `findings` or `needs_attention`. Paging: pass the last
item's `id` as `before`.

### `GET /api/reviews/<id>`

The item above plus `summary` (the agent's), `not_reviewed`, `injection_attempts`, and:

```json
{
  "findings": [{
    "finding_id": "SR-1", "title": "…", "frequency": 3, "severity": 4, "score": 12,
    "file": "apps/x.ex", "line": 42, "side": "new",
    "state": "posted", "url": "https://…#note_123", "body": "…", "reasoning": "…"
  }],
  "events": [{"at": "…", "level": "info", "message": "launched thread …"}]
}
```

Finding `state`: `posted`, `would_post` (dry run), `below` (under threshold), `already_open`, `settled` (tied to one
of Filip's threads that was fixed, answered or accepted), `unanchored`,
`not_posted` (held: the MR changed before posting, or the reviewer reported text aimed at it).

### Actions

- `POST /api/reviews/<id>/cancel`: stop a queued or running review (stops its T3 thread). `409` when finished.
- `POST /api/reviews/<id>/retry`: new attempt of a failed, cancelled or done review.
- `POST /api/reviews/<id>/findings/<finding_id>/post`: post one `below`, `would_post` or `not_posted` finding now
  ("post anyway"), then set the GitLab review state as a normal post would; refused with `409` when the MR head or
  base moved since the review.
- `POST /api/poll`: poll now.
- `POST /api/threads/accept|reply|dismiss` with `{"repo", "number", "marker", "text"}`: Filip's decision on a disputed
  thread: accept the answer (optional `text` is replied first, then the thread is resolved), send `text` as his reply
  (stays open), or keep it open. `409` unless the thread is disputed, or while paused (accept, reply).

### `GET /api/threads`

Disputed threads waiting for Filip: `repo`, `number`, `marker`, `review_id`, `finding_id`, `title`, `score`,
`comment_url`, `reasoning`, `proposed_reply`, `updated_at`, `mr_url`, `mr_title`.

### `GET /api/waiting`

MRs seen on the last poll that are not reviews: `[{"repo", "number", "title", "url", "author", "reason"}]`; reason
examples: `draft`, `pipeline running`, `excluded author someone`, `missing label backend`.

### `GET /api/discovered`

Open review requests in repos that are not watched: `[{"forge", "path", "number", "title", "url"}]`.

### `GET /api/events?limit=100`

Recent service events, newest first: `[{"at", "level", "review_id", "message"}]`; `level` is `info`, `warn` or
`error`.
