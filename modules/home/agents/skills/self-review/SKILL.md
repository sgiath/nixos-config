---
name: self-review
description: "Manual only: run an author's AI self-review of a finished GitLab MR and automatically publish one inline code discussion per finding, with AI attribution, model, and disposition. Invoke explicitly as $self-review or /self-review; ordinary MR review requests do not activate it."
---

# Self-review

Make the author's AI review visible so teammates can see what was checked, what
remains open, and what was fixed or dismissed without repeating the same review.
This is a personal workflow, not a change to the team's approval policy.

## Invocation and scope

Run only when explicitly invoked as `$self-review`, `/self-review`, or requested by name.
Accept an MR URL/IID; otherwise use the current branch's MR. `update` refreshes finding
dispositions; `fresh` requests a new full review even for an already-reviewed diff.

Invocation authorizes automatically creating or updating inline finding comments on
the selected MR. Do not ask again before publishing. It does not authorize source edits,
commits, pushes, approvals, merges, resolving teammates' threads, or changing hooks.
If fixes are also requested, follow the repository's implementation workflow and
update the finding comments after verifying the resulting MR commit.

## Steps

1. **Resolve the MR and identity.** Read repository/app instructions. Use the repository's
   `.agents/skills/gitlab-access/SKILL.md` (or the installed skill) and `PAGER=cat glab`.
   Fetch MR metadata, the authenticated user, all notes, and relevant discussions.
   Verify host, project, IID, URL, author, and source/target branches. This workflow is
   for the user's own MRs: if the author differs from the authenticated user, clarify
   whose MR is intended before posting an author self-review. Register the MR with
   `link_pull_request` when the host provides that tool.

2. **Capture provenance.** Record UTC time, immutable source head SHA, diff base SHA,
   and target branch SHA. Read the exact MR diff and matching files; do not review a
   different local checkout or include uncommitted changes. Obtain provider, exact model
   identifier, reasoning effort, and harness from runtime metadata when exposed. Record unknown
   fields as `not exposed`; never infer them from a model catalog or previous session.
   Read existing self-reviews and author-hook reports, their commit coverage, findings,
   and subsequent dispositions. Keep review SHAs, timestamp, and coverage in hidden
   metadata for reuse; do not publish a visible provenance or assessment section.

3. **Avoid duplicate reviews.** If a complete review covers the same head and base,
   reuse it and update dispositions instead of running another full review, unless
   `fresh` was requested. Attribute reused findings to the original report and model;
   distinguish the updating model from the reviewing model in hidden metadata. For a changed diff, review
   the delta and its interactions with previously reviewed code, carry forward unresolved
   findings, and record each pass's coverage in hidden metadata. A changed base or incomplete coverage may
   require a full review. Do not treat a report without commit coverage as proof that
   this diff was checked. `update` verifies dispositions against the current code; if
   changes need review, identify them explicitly rather than imply they were reviewed.

4. **Use the existing review standard.** Locate and read `mr-review/SKILL.md` in the
   repository's `.agents/skills/` or installed skills. Follow its context gathering,
   Linear lookup, rule loading, correctness checks, and trace/invariant pass, including
   changed-to-unchanged code interactions. This skill replaces its posting opt-in and
   report format with explicit posting authorization and the format below. If that
   standard is unavailable, explain the missing dependency instead of silently using
   a weaker review. Report evidence-backed findings by severity, with stable IDs,
   a precise diff-line anchor, triggering inputs, consequences, and remedies.
   Deduplicate existing findings. State unavailable context and tests actually run;
   never present CI status as local testing.

5. **Record dispositions.** Findings are `open`, `fixed`, or `dismissed`. `fixed` needs
   evidence in the current MR code and relevant verification, with a commit link when
   available. A promise to fix stays `open`. `dismissed` needs a specific reason and
   attribution: distinguish the author's explicit decision from an AI finding withdrawn
   after checking evidence. Preserve the original finding and its history. Do not invent
   the author's acceptance or rationale. Keep disposition updates in the finding's own
   comment. Include domain/product questions only when they explain that finding;
   put broader review questions and verification summaries in the final chat response.

6. **Publish automatically, one inline comment per finding.** Re-fetch the MR's diff
   refs and discussions immediately before writing. If the diff changed, verify the
   finding and anchor against the new diff before posting. Create a separate positioned
   discussion for each new finding; never bundle findings or post a general MR note.
   Update an existing owned inline finding note in place rather than add a new comment
   on each invocation. Preserve its stable ID, original assessment, dispositions, and
   review provenance. Deduplicate against teammates' findings; do not repost their
   already-fixed issues as new self-review findings. Legacy `self-review:v1` summaries
   can supply prior evidence, but are not inline finding comments: publish still-open
   findings separately on valid diff lines without editing or deleting the old summary.
   Leave teammates' comments intact. Re-read each saved discussion and return its link.
   On an ambiguous write failure, fetch discussions before retrying to avoid duplicates.
   If there are no findings, say so in the final chat response and post nothing to GitLab.

## GitLab inline discussion mechanics

Use the verified numeric project ID and MR IID. Pass `--hostname <verified-host>`
when the MR's host differs from the CLI default. Fetch notes and discussions with pagination:

```bash
PAGER=cat glab api user
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>'
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/notes' --paginate
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/discussions' --paginate
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/versions' --paginate
```

`--paginate` prints one JSON array per page back to back; merge them with `jq -s add` before parsing. This glab
has no `--jq` flag; pipe to `jq` instead.

Use the current MR's `diff_refs` and matching diff version to obtain the exact
`base_sha`, `start_sha`, and `head_sha`. GitLab's `start_sha` is the diff start commit,
not a substitute for the merge base or a freshly fetched target branch SHA. Fetch
that version's diff to select the finding's path and line:

```bash
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/versions/<version-id>'
```

Anchor to the smallest relevant diff line where the issue occurs. Use `new_line` for
added lines, `old_line` for removed lines, and both for context lines using the hunk's
actual old/new numbering. Include both `old_path` and `new_path` from the diff,
including renames. Do not invent a line number or attach to unrelated code just to
make publication succeed. If the underlying issue is outside the diff, use a relevant
changed call site only when it demonstrates the issue and explain the connection.
If no valid relevant anchor exists, keep the finding in chat as unpublished.

Write each exact Markdown body to a temporary UTF-8 file outside the repository,
then use an available serializer to produce the JSON payload in another temporary
file. Do not interpolate generated prose into shell commands. A new inline finding
requires a `position` object; for example, an added-line payload has this shape
(replace every placeholder and the example line number with verified values):

```json
{
  "body": "<one finding, beginning with the attribution note below>",
  "position": {
    "position_type": "text",
    "base_sha": "<diff_refs.base_sha>",
    "start_sha": "<diff_refs.start_sha>",
    "head_sha": "<diff_refs.head_sha>",
    "old_path": "<diff old_path>",
    "new_path": "<diff new_path>",
    "new_line": 42
  }
}
```

Create a new positioned discussion, or update the body of its existing owned finding
note using a payload containing only `body`:

```bash
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/discussions' --method POST --header 'Content-Type: application/json' --input /absolute/path/payload.json
PAGER=cat glab api 'projects/<project-id>/merge_requests/<iid>/discussions/<discussion-id>/notes/<note-id>' --method PUT --header 'Content-Type: application/json' --input /absolute/path/body-payload.json
```

Choose POST or PUT for each finding; do not run both. Never use `glab mr note` or
POST to the MR `/notes` endpoint as a fallback. On an invalid position, refresh
the diff refs and anchor and retry once; if it still fails, report the unpublished
finding and concrete error in chat. Do not silently downgrade to an unpositioned
discussion. Existing inline discussions can remain attached to their original diff
version after a push; update their dispositions there instead of creating duplicates.

Re-fetch each saved discussion. Verify the note ID, authenticated author, exact body,
and `position` with `position_type: text`, expected paths, line, and diff SHAs before
claiming success. Link it as `<MR web_url>#note_<note-id>` and clean up temporary files.
If publication fails, return the finding and concrete failure; do not claim it was posted.

## Published finding comment

Begin every comment with this note, using the actual author, model, effort, and
harness. For the supplied Codex runtime it renders exactly as:

```markdown
> [!NOTE]
> Automated review published on behalf of @filip.vavera1
> The assessment and checks below are AI-generated
> Review model: **gpt-6.1-sol** / **high** / Codex harness

**SR-1 · Should fix · open — <short issue title>**

<Triggering input or reachable path, the evidence, and its concrete consequence.>

<Suggested remedy, or verified fix / attributed dismissal with relevant evidence.>

<Optional verification or question specific to this finding; omit when unnecessary.>

<!-- self-review:v2 finding=SR-1 -->
<!-- self-review-metadata: <serialized JSON with review SHAs, UTC time, coverage, original model/effort/harness, and disposition history> -->
```

The model name and effort in the example are not defaults: substitute the session's
actual values, including the actual harness (e.g. Claude Code). Use `not exposed`
for unavailable metadata. When reusing an assessment, retain its original reviewing
model in the attribution note and record updater provenance in hidden metadata.
Do not add visible Reviewed diff, Reviewed at, Assessment, global scope/verification,
or review-history sections. Keep only the finding's evidence and disposition visible.
Hidden metadata records actual coverage, including incomplete publication; a single
posted finding is not by itself evidence that the whole diff was reviewed.

Use `write-as-sgiath` if available for prose
written on the author's behalf, without claiming he personally performed the checks.
An assessment in a comment never constitutes GitLab approval. Do not declare docs,
scenarios, or tests exempt from human review without an explicit team policy.

## Deterministic Gates

- Explicit invocation only; publish without another permission prompt.
- Verify MR identity, author, reviewed diff, and model provenance before posting.
- Reuse same-diff coverage; disclose stale, partial, and unavailable evidence.
- Apply the existing `mr-review` trace/invariant pass to newly reviewed scope.
- Preserve finding IDs, evidence, dispositions, and previous review provenance.
- One finding per owned inline note; update it in place and start it with the attribution note.
- Never post a general summary or an unpositioned finding; no findings means no GitLab comment.
- Verify each saved discussion's body and diff position before claiming publication succeeded.
