# Extraction and interpretation

Run script paths relative to the skill directory, not this reference directory.

## 1-2. Extract transcript + frames

Run the bundled script (path is relative to this skill's directory). It accepts a **`loom.com`/video URL or a local file** — URLs are downloaded with yt-dlp first — then transcribes locally with whisper.cpp (`whisper-cli`), no API key. Defaults: one frame every 4s and a temp output dir:

```bash
scripts/video_to_evidence.sh "https://www.loom.com/share/<id>"   # a Loom link (or any yt-dlp-supported URL)
scripts/video_to_evidence.sh "<path/to/video.mp4>"               # or a local file
```

Useful flags: `--interval SECONDS` (raise it for long videos to cap the frame count), `--out DIR`, `--model PATH` (whisper GGML model; defaults to `$WHISPER_MODEL` or the local large-v3-turbo model), `--language LANG` (default `auto`). Override the binary with `$WHISPER_CLI`. The script prints the transcript and the frames directory path.

### Private videos and browser login

Use the account already granted access to the video. The script forwards authentication options to yt-dlp; it does not automate passwords or MFA:

```bash
scripts/video_to_evidence.sh "https://www.loom.com/share/<id>" \
  --cookies-from-browser "chrome+gnomekeyring:Default"
```

This Chrome profile and explicit Secret Service keyring were verified on the local Linux desktop. Plain `chrome:Default` fails to decrypt its `v11` session cookies under Hyprland; yt-dlp can then misleadingly report `No video formats found`. `+gnomekeyring` selects Secret Service, including the configured pass-secret-service provider. It does not require installing GNOME.

On another machine, use the browser/profile that is logged into Loom: for example `chromium+gnomekeyring:Default`, `chrome+gnomekeyring:Profile 1`, or `firefox`. yt-dlp accepts `BROWSER[+KEYRING][:PROFILE][::CONTAINER]`; quote the whole specification, especially profiles with spaces. Browser cookies are read at runtime without exporting a cookie file. The browser profile and its unlocked keyring must be available on the machine running the script; a remote/headless host does not inherit the desktop session.

If the user already supplies a Netscape-format cookie file, use `--cookies "/path/to/cookies.txt"` instead. These options are mutually exclusive and require a URL. yt-dlp may update a supplied cookie file, so keep it outside the repository with mode `0600`. Never paste cookie values into chat, logs, Nix configuration, or the store. Generated evidence files use private permissions.

If cookies cannot be decrypted, check the profile and keyring rather than suppressing warnings or repeatedly retrying. If the session is missing/expired or the account lacks access, ask the user to sign into Loom in that browser profile and open the exact link, then rerun. Access may require Amee to share with that account. Do not try other accounts or change the video's sharing settings. A video password is a separate access mechanism; browser cookies do not replace it.

The [yt-dlp authentication options](https://github.com/yt-dlp/yt-dlp#authentication-options) document supported browsers and profile syntax.

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
- **Transcription is local (whisper.cpp).** `whisper-cli` must be on `PATH` (or set `$WHISPER_CLI`), and the GGML model file must exist (`$WHISPER_MODEL` or `--model`). If the model is missing, transcription fails — use the manual ffmpeg frame extraction below and label the missing narration, or point `--model` at a model you have. The script has no frames-only flag and stops on a missing model before extracting frames.
- **No file-size or length limit.** Local whisper handles any length; long videos just take longer (GPU-accelerated via Vulkan/Metal/CUDA when the build supports it, otherwise CPU). whisper.cpp needs 16 kHz mono WAV, which the script already produces — do not feed it opus/mp3 re-encoded to save space.
- **Always clean up** the temp workspace when finished.

## Manual fallback (no script)

If the script is unavailable or you are debugging, the underlying commands are:

```bash
mkdir -p frames
yt-dlp -o "video.%(ext)s" "https://www.loom.com/share/<id>"                         # only for URL inputs (Loom, etc.)
ffmpeg -y -i "video.mp4" -vn -ac 1 -ar 16000 -c:a pcm_s16le audio.wav              # 16 kHz mono WAV (what whisper.cpp needs)
whisper-cli -m "$WHISPER_MODEL" -f audio.wav -l auto -np -nt -otxt -of transcript   # writes transcript.txt
ffmpeg -y -i "video.mp4" -vf "fps=1/4" frames/frame_%03d.png                        # one frame every 4 seconds
```
