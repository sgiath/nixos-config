---
name: davinci-resolve
description: Create, organize, edit, grade, and verify DaVinci Resolve projects through its scripting API or MCP connector, including Linux media compatibility and playback problems. Use for work in Resolve, not generic video conversion without a Resolve target.
---

# DaVinci Resolve

Use the live Resolve tools and their documentation. Search Executor's
`davinci_resolve` integration when no direct connector is exposed; describe the
chosen tool and use `action_help`, capability probes, or `api_truth` for fragile
operations. Read collection instructions and machine-local notes before editing.

## Identify the working state

- Read the Resolve and connector versions, current project, current timeline
  name and ID, media paths, timeline settings, and playback frame rate.
- Set frame rate and resolution before importing media or building timelines
  where possible. Timeline rate and `timelinePlaybackFrameRate` are separate.
  A timeline at the source rate can still preview steadily at the wrong speed.
- Build event bins and timelines from the active manifest and ordered playlists.
  Historical inventories can include deleted media or superseded names.
- Export a `.drp` checkpoint before a substantial pass. A project export does
  not bundle the source media; retain its referenced media alongside it.
- Respect an instruction to edit the current timeline. A duplicate can support
  a requested comparison, but do not keep creating user-facing alternatives.

For Linux audio, playback settings, and waveform recovery, read
[Linux media and playback](references/linux-media-and-playback.md).

## Keep edits and checkpoints distinct

Connector mutations can auto-archive the preceding timeline as
`<name>_archived_vNN`; the largest suffix is not the finished result. Where the
live connector supports it, group one logical pass with
`timeline_versioning.begin_run` / `end_run`. Keep checkpoints in a backup bin,
then explicitly open the working timeline and read its name and ID back.
Re-query IDs after a project reload rather than treating saved IDs as permanent.

Item indexes are 0-based; track indexes are 1-based. Node indexes are 1-based.
Timeline item positions use record frames; source ranges use the media's own
rate. Marker frames are relative to timeline start, even when the UI timecode
starts at `01:00:00:00`. Confirm the convention for each action before calculating
cuts, source offsets, or chapters.

Avoid reconstructing a graded timeline merely to trim it: re-appending pool
clips can lose grades, Fusion work, fades, and other timeline-item state. Prefer
native edits that retain items. After a split or ripple delete, re-query items
and check aligned video/audio source ranges, retained content, gaps, and grades.
Resolve 21.1 exposed native `SetFades` and `AddTransition`; check the installed
version rather than assuming older API limitations. Read fades/transitions back.

## Grade from rendered evidence

Inspect representative lighting and damaged shots before choosing treatment.
Automatic color balance is shot-specific and can introduce casts or excessive
brightness. Keep useful ambient lighting and intentional looks such as night
vision. Test on one shot, inspect its result, then review exceptions after a batch.

Use `grade_evidence_base` / node-graph probes to inspect existing corrections and
their scope. Select the actual Color-page clip or timeline node before UI input;
a shortcut can do nothing when the wrong panel has focus. A changed DRX file or
successful call alone does not prove that pixels changed.

- Use Color-page `gallery_stills.grab_and_export` at matching timecodes for
  before/after evidence, or extract frames from an actual Resolve render.
  Source thumbnails and ffmpeg contact sheets help inspect footage but do not
  show Resolve grades, Fusion output, or transitions.
- Gallery export needs the Color page and writes a companion `.drx`.
  `cleanup:false` retains proof files; `delete_after:true` removes the temporary
  Gallery still. `ExportLUT` also needs the Color page on the observed build.
  LUT comparison checks primary color transforms, not temporal noise reduction,
  stabilization, or every effect; use rendered evidence for those claims.
- `safe_apply_drx` replaces the target graph; its grade modes do not append.
  Back up the grade first, pass the target track/item explicitly, and follow its
  dry-run and confirmation-token protocol. Use `safe_set_cdl` for adjustments to
  an existing node when appropriate.
- A timeline-level noise-reduction node must be connected between input and
  output. Start gently, compare faces and motion, and measure playback cost.
  Verify a comparison timeline's original grades and rendered pixels remain
  unchanged; duplication alone does not establish isolation.

## Check sound and deliver the working project

Audio items, waveform visibility, and audible decoded sound are separate checks.
Measure/listen to retained source ranges before adjusting levels. A quiet room or
off-camera speech can be valuable content; do not infer a recording gap from a
mis-aimed image. Check existing restoration before adding more hum/hiss reduction.
Avoid raising quiet ambience indiscriminately or normalizing split pieces of one
continuous recording independently when that would create a gain jump.

For native audio normalization, discover the installed modes and option types;
do not guess property names or enum values. Distinguish measured source loudness,
predicted gain, native-call success, and verified output loudness.

Finish with the intended timeline open, useful zoom, and the prior page restored
unless the task calls for another view. Verify the requested visual/audio behavior,
clip order and source ranges, offline-media status, and playhead advance against
wall time. Save, export the updated checkpoint, and check archive integrity.
Report the working timeline name and any remaining unverified result.
