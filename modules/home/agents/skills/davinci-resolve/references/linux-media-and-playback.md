# Linux media and playback

These observations came from Resolve Studio 21.1.0.0017 and the
`davinci-resolve-mcp` 4.10.4 connector on Linux, in
[the childhood-video thread](t3-thread://v1/c3e43ce5-3fd8-46e1-995a-f7c3480f3e64).
Recheck live capabilities when versions, edition, or platform change.

## Unsupported audio can look imported

The observed installation imported H.264/AAC MP4s and made audio timeline items,
but decoded no sound and drew no waveforms. Counts and project lint passed.
Check the actual codec with ffprobe and test audible Resolve output before batch
import. Prefer the installed version's supported-codec list over assumptions
from another operating system or Resolve edition.

When the video already works, a MOV copy with PCM audio can avoid re-encoding it:

```sh
ffmpeg -hide_banner -loglevel error -n -i "$source_clip" \
  -map 0:v:0 -map 0:a:0 -c:v copy -c:a pcm_s24le \
  -movflags +faststart "$resolve_copy"
```

This is a starting conversion, not proof of equal endpoints. AAC padding can
make decoded audio shorter or longer than its declared duration. Compare stream
start times and endpoints; trim encoder padding or pad a short tail with silence
to the intended endpoint where needed. Preserve sample rate and channel layout.
Verify copied video packet payloads and decoded audio samples, allowing only the
documented endpoint adjustment. Test one representative copy in Resolve first.

Use media-pool replacement to retain existing timeline edits, then verify every
replacement's path, online status, rate, channels, and video/audio positions.
Keep originals and compatible copies; a `.drp` needs the media it references.

## Playback rate and actual speed

On the observed build, API writes to `timelinePlaybackFrameRate` returned false.
Use Project Settings → Master Settings → Playback frame rate when this happens,
then read the setting back through the API. Do not leave this as an unchecked
manual step if native UI control is available. Distinguish steady slow playback
from dropped frames by measuring timeline time advanced over a bounded wall-time
interval. Test decoded sound separately.

## Blank waveforms after replacement

Replacing AAC clips with PCM media left stale blank waveform data even though
sound worked. Check waveform display first. Save and reload the project, then
open affected timelines; waveforms may generate on demand as clips become visible
or are widened by zoom. Regenerate Waveforms was disabled for the tested selection,
so do not assume that command is always available. Avoid deleting unrelated caches.

## Native UI and process detection

In a Nix FHS environment, `runtime_mode` reported no running Resolve despite a
live GUI and functioning API. Check both before launching another instance.
On Hyprland/XWayland, compositor screenshot coordinates and X11 input coordinates
can differ. Discover the current window with `xdotool search` and
`getwindowgeometry`; use window-relative input and compositor geometry for `grim`.
Never reuse window IDs or screen offsets from a prior session. Inspect the current
panel and selection before a shortcut or click, then verify the resulting state.

`timeline_frame.capture` failed with `AddRenderJob returned nothing` in this
session. Color-page Gallery export provided native rendered proof instead;
switch to that route when render-job capture fails and it meets the task's needs.
