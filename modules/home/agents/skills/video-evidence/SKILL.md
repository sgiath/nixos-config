---
name: video-evidence
description: "Use to understand or transcribe a user-provided Loom link, video URL, or local screen recording as task evidence."
---

# Video evidence

Extract speech and still frames with the bundled [script](scripts/video_to_evidence.sh); file-reading tools do not decode video. Pass Loom/video URLs directly to the script (yt-dlp downloads them), or pass a quoted local path.

```bash
scripts/video_to_evidence.sh "https://www.loom.com/share/<id>"
scripts/video_to_evidence.sh "<path/to/video.mp4>"
```

For private Looms requiring the user's account, reuse the logged-in browser session. On the local Linux desktop, Chrome's `Default` profile works with `--cookies-from-browser "chrome+gnomekeyring:Default"`. Use it directly when the user says the video is private; otherwise retry with it if downloading fails with an access error or `No video formats found`. Read [authenticated extraction](references/extraction.md#private-videos-and-browser-login) for other profiles, cookie files, and login failures. Do not print or save browser cookie values.

Read the transcript for concrete asks, corrections, and decisions. Inspect a spread of frames, then narration hotspots; quote exact visible labels, values, counts, and errors. Distinguish spoken claims from frame-confirmed evidence and note unavailable audio rather than inventing it. Act within the user's requested task.

Read [extraction options and fallback](references/extraction.md) for flags, model/binary settings, odd filenames, long recordings, and manual commands. Transcription is local, with no API key.

Delete the generated temporary workspace when finished, not the user's source video. For a user-supplied output directory, remove only generated artifacts rather than unrelated contents.
