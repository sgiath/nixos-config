---
name: video-evidence
description: Turn a video, screen recording, or Loom link into reviewable evidence and act on it. Downloads video URLs with yt-dlp, then extracts a speech transcript (local whisper.cpp) plus periodic frames, and synthesizes the spoken narration with on-screen text into concrete findings. Use this immediately whenever you encounter a loom.com link or any video URL, or when the user provides or points to a video / screen recording / Loom / .mp4 / .mov as feedback, a bug repro, a walkthrough, or a demo and wants you to watch it, understand it, transcribe it, or extract what it shows — or when you cannot read a video file directly and need its audio and frames.
compatibility: Requires ffmpeg, ffprobe, whisper-cli (whisper.cpp) with a local GGML model (set via $WHISPER_MODEL or --model), and yt-dlp for downloading loom.com/video URLs. Transcription runs offline; no API key.
---

Turn a video the user gives you — a `loom.com` link, another video URL, or a local screen recording / `.mp4`/`.mov` — into evidence you can reason over, then act on it. You cannot read a video file directly; get it locally (URLs download with yt-dlp) and derive two signals from it:

- **Transcript** (spoken narration) — usually the primary signal. It carries *what the person wants and why*: the feedback, the ask, the intent.
- **Frames** (on-screen stills) — the concrete proof. They pin down exact UI text, numbers, states, and errors the narration refers to but does not spell out (for example "it only created one variant").

Neither alone is enough. The narration tells you the point; the frames confirm the specifics. Cross-check one against the other.

## Workflow

- [ ] 1. Get the video: pass a `loom.com`/video URL or a local file path to the script (URLs download via yt-dlp). Do **not** try to open or Read the binary.
- [ ] 2. Run the bundled script to get a transcript + frames.
- [ ] 3. Read the transcript and extract every concrete ask/decision.
- [ ] 4. Inspect a spread of frames with your multimodal/image tool, then zoom in where the transcript points.
- [ ] 5. Synthesize both into concrete findings/requirements, then do the work.
- [ ] 6. Delete the temp workspace.

## 1-2. Extract transcript + frames

Run the bundled script (path is relative to this skill's directory). It accepts a **`loom.com`/video URL or a local file** — URLs are downloaded with yt-dlp first — then transcribes locally with whisper.cpp (`whisper-cli`), no API key. Defaults: one frame every 4s and a temp output dir:

```bash
scripts/video_to_evidence.sh "https://www.loom.com/share/<id>"   # a Loom link (or any yt-dlp-supported URL)
scripts/video_to_evidence.sh "<path/to/video.mp4>"               # or a local file
```

Useful flags: `--interval SECONDS` (raise it for long videos to cap the frame count), `--out DIR`, `--model PATH` (whisper GGML model; defaults to `$WHISPER_MODEL` or the local large-v3-turbo model), `--language LANG` (default `auto`). Override the binary with `$WHISPER_CLI`. The script prints the transcript and the frames directory path.

## 3. Read the transcript

Treat the transcript as the primary account of what the user wants. Extract every concrete ask, correction, and decision — not a vague summary. Screen-recording speech is casual and unpunctuated, so read for intent, not literal wording.

## 4. Inspect frames

Look at a spread of frames first (skip through them), then zoom into the moments the transcript calls out. Use your multimodal/image tool with a **specific goal** and ask it to **quote exact on-screen text**: labels, values, counts, error messages, URLs. This is where objective evidence lives — the exact number created, the precise wording shown, the actual error — which the narration usually paraphrases or omits.

## 5. Synthesize

Combine the two: the transcript says *what and why*, the frames say *exactly what was on screen*. Reconcile them into a concrete list of findings or requirements, and note where a claim is confirmed by a frame versus only spoken. Then act on it — this is input for real work, not a summarization exercise.

## 6. Clean up

Delete the temp workspace the script created (it prints the path) once you are done.

## Gotchas

- **You cannot read a video file directly.** Read/file tools cannot decode `.mp4`/`.mov`; always derive audio + frames first with the script (ffmpeg).
- **Loom links and video URLs go straight to the script.** Pass the `loom.com` URL (or any yt-dlp-supported URL) as the input — the script downloads it with yt-dlp into the workspace, so do not download it separately. `yt-dlp` must be installed for URL inputs.
- **Loom / exported filenames contain odd characters.** They often include a bracketed id and a Unicode slash `⧸` (U+29F8, not `/`) where the title had `A/B`. Match with a glob (e.g. `ls *"Test Draft"*.mp4`) and always quote the path — do not retype the name by hand.
- **The transcript is the primary signal, not the frames.** The spoken feedback is where the actual ask lives; frames confirm specifics. Do both, but read the transcript first.
- **Target frames; do not dump them all.** Analyze a spread plus the transcript's hotspots and demand exact quotes. Reading every frame wastes context for little gain.
- **Transcription is local (whisper.cpp).** `whisper-cli` must be on `PATH` (or set `$WHISPER_CLI`), and the GGML model file must exist (`$WHISPER_MODEL` or `--model`). If the model is missing, transcription fails — run frames-only and rely on on-screen text, or point `--model` at a model you have.
- **No file-size or length limit.** Local whisper handles any length; long videos just take longer (GPU-accelerated via Vulkan/Metal/CUDA when the build supports it, otherwise CPU). whisper.cpp needs 16 kHz mono WAV, which the script already produces — do not feed it opus/mp3 re-encoded to save space.
- **Always clean up** the temp workspace when finished.

## Manual fallback (no script)

If the script is unavailable or you are debugging, the underlying commands are:

```bash
yt-dlp -o "video.%(ext)s" "https://www.loom.com/share/<id>"                         # only for URL inputs (Loom, etc.)
ffmpeg -y -i "video.mp4" -vn -ac 1 -ar 16000 -c:a pcm_s16le audio.wav              # 16 kHz mono WAV (what whisper.cpp needs)
whisper-cli -m "$WHISPER_MODEL" -f audio.wav -l auto -np -nt -otxt -of transcript   # writes transcript.txt
ffmpeg -y -i "video.mp4" -vf "fps=1/4" frames/frame_%03d.png                        # one frame every 4 seconds
```
