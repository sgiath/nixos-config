#!/usr/bin/env bash
# video_to_evidence.sh — turn a video, screen recording, or video URL into reviewable
# evidence: a speech transcript (local whisper.cpp) plus periodic frames for on-screen text.
#
# Usage:
#   video_to_evidence.sh <video-path-or-url> [--interval SECONDS] [--out DIR] [--model PATH] [--language LANG]
#     [--cookies-from-browser BROWSER[+KEYRING][:PROFILE][::CONTAINER] | --cookies FILE]
#
# The input may be a local file OR a video URL (e.g. a loom.com share link). URLs are
# downloaded with yt-dlp into <out> before processing.
#
# Defaults: --interval 4  --out $(mktemp -d)  --language auto
#   --model  $WHISPER_MODEL or /home/sgiath/.local/share/whisper-cpp/ggml-large-v3-turbo.bin
#   whisper binary: $WHISPER_CLI or `whisper-cli` on PATH
# Requires: ffmpeg, ffprobe, whisper-cli (whisper.cpp) with a local GGML model, and yt-dlp
# (only when the input is a URL). Transcription runs offline; no API key.
#
# Writes into <out>:
#   source.*         the downloaded video (only when the input was a URL)
#   audio.wav        16 kHz mono PCM WAV (omitted when the video has no audio track)
#   transcript.txt   whisper.cpp transcript (omitted when there is no audio)
#   frames/*.png     one frame every INTERVAL seconds
# and prints the transcript plus a frames summary to stdout.

set -euo pipefail
umask 077

usage() {
  cat <<'EOF'
video_to_evidence.sh — turn a video, screen recording, or video URL into reviewable
evidence: a speech transcript (local whisper.cpp) plus periodic frames for on-screen text.

Usage:
  video_to_evidence.sh <video-path-or-url> [--interval SECONDS] [--out DIR] [--model PATH] [--language LANG]
    [--cookies-from-browser BROWSER[+KEYRING][:PROFILE][::CONTAINER] | --cookies FILE]

The input may be a local file OR a video URL (e.g. a loom.com share link); URLs are
downloaded with yt-dlp into <out> first.

Authentication for private URLs (use one):
  --cookies-from-browser SPEC  read the logged-in browser session with yt-dlp
                              e.g. chrome+gnomekeyring:Default on this Linux desktop
  --cookies FILE              use a Netscape-format cookie file
No credentials are needed for local files or public URLs.

Defaults: --interval 4  --out $(mktemp -d)  --language auto
  --model  $WHISPER_MODEL or /home/sgiath/.local/share/whisper-cpp/ggml-large-v3-turbo.bin
  whisper binary: $WHISPER_CLI or `whisper-cli` on PATH
Requires: ffmpeg, ffprobe, whisper-cli (whisper.cpp) with a local GGML model, and yt-dlp
for URL inputs. Transcription runs offline; no API key.

Writes into <out>:
  source.*         the downloaded video (only when the input was a URL)
  audio.wav        16 kHz mono PCM WAV (omitted when the video has no audio track)
  transcript.txt   whisper.cpp transcript (omitted when there is no audio)
  frames/*.png     one frame every INTERVAL seconds
and prints the transcript plus a frames summary to stdout.
EOF
}
die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

input=""
interval=4
out=""
language="auto"
cookies_from_browser=""
cookies_file=""
whisper_bin="${WHISPER_CLI:-whisper-cli}"
model="${WHISPER_MODEL:-/home/sgiath/.local/share/whisper-cpp/ggml-large-v3-turbo.bin}"

while [ $# -gt 0 ]; do
  case "$1" in
  --interval)
    interval="${2:?--interval needs a value}"
    shift 2
    ;;
  --out)
    out="${2:?--out needs a value}"
    shift 2
    ;;
  --model)
    model="${2:?--model needs a value}"
    shift 2
    ;;
  --language)
    language="${2:?--language needs a value}"
    shift 2
    ;;
  --cookies-from-browser)
    cookies_from_browser="${2:?--cookies-from-browser needs a value}"
    shift 2
    ;;
  --cookies)
    cookies_file="${2:?--cookies needs a value}"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) die "unknown option: $1" ;;
  *) [ -z "$input" ] && input="$1" && shift || die "unexpected argument: $1" ;;
  esac
done

[ -n "$input" ] || die "a video path or URL is required (run with --help)"
[ -z "$cookies_from_browser" ] || [ -z "$cookies_file" ] || die "use either --cookies-from-browser or --cookies, not both"
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found"
command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found"

is_url=0
case "$input" in
http://* | https://*) is_url=1 ;;
esac
[ "$is_url" -eq 1 ] || [ -f "$input" ] || die "file not found: $input"
if [ -n "$cookies_from_browser$cookies_file" ]; then
  [ "$is_url" -eq 1 ] || die "cookie options require a URL input"
fi
[ -z "$cookies_file" ] || [ -r "$cookies_file" ] || die "cookie file not readable: $cookies_file"

[ -n "$out" ] || out="$(mktemp -d "${TMPDIR:-/tmp}/video-evidence.XXXXXX")"
mkdir -p "$out/frames"

# --- download (URL input, e.g. a loom.com link) ------------------------------
video="$input"
if [ "$is_url" -eq 1 ]; then
  command -v yt-dlp >/dev/null 2>&1 || die "yt-dlp not found (needed to download a URL)"
  download_args=()
  if [ -n "$cookies_from_browser" ]; then
    download_args+=(--cookies-from-browser "$cookies_from_browser")
  elif [ -n "$cookies_file" ]; then
    download_args+=(--cookies "$cookies_file")
  fi
  printf '>> downloading %s with yt-dlp\n' "$input" >&2
  if ! yt-dlp "${download_args[@]}" -o "$out/source.%(ext)s" "$input" >"$out/yt-dlp.log" 2>&1; then
    printf '>> yt-dlp failed; last lines of %s/yt-dlp.log:\n' "$out" >&2
    tail -n 20 "$out/yt-dlp.log" >&2 || true
    printf '>> for a private video, use --cookies-from-browser with the profile logged into the account granted access (see references/extraction.md)\n' >&2
    die "yt-dlp download failed"
  fi
  video="$(find "$out" -maxdepth 1 -type f -name 'source.*' ! -name '*.part' | head -1)"
  [ -n "$video" ] && [ -f "$video" ] || die "yt-dlp produced no output file"
  printf '>> downloaded to %s\n' "$video" >&2
fi

# --- probe -------------------------------------------------------------------
duration="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$video" 2>/dev/null || echo '?')"
has_audio="$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of default=nk=1:nw=1 "$video" 2>/dev/null | head -1 || true)"
printf '>> video: %s\n>> duration=%ss audio=%s out=%s\n' "$video" "$duration" "${has_audio:-none}" "$out" >&2

# --- audio + transcript ------------------------------------------------------
if [ -n "$has_audio" ]; then
  # whisper.cpp expects 16 kHz mono 16-bit PCM WAV.
  ffmpeg -y -i "$video" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$out/audio.wav" >/dev/null 2>&1 || die "audio extraction failed"

  command -v "$whisper_bin" >/dev/null 2>&1 || die "$whisper_bin not found (install whisper.cpp or set \$WHISPER_CLI)"
  [ -f "$model" ] || die "whisper model not found: $model (set \$WHISPER_MODEL or pass --model)"
  printf '>> transcribing locally with %s (%s), language=%s\n' "$whisper_bin" "$(basename "$model")" "$language" >&2

  # -otxt + -of write "<out>/transcript.txt". No size limit; runs offline.
  if ! "$whisper_bin" -m "$model" -f "$out/audio.wav" -l "$language" -np -nt \
    -otxt -of "$out/transcript" >"$out/whisper.log" 2>&1; then
    printf '>> transcription failed; last lines of %s/whisper.log:\n' "$out" >&2
    tail -n 20 "$out/whisper.log" >&2 || true
    die "whisper-cli transcription failed"
  fi
  # whisper.cpp writes one segment per line, often space-indented; trim leading spaces.
  if [ -f "$out/transcript.txt" ]; then
    sed 's/^[[:space:]]*//' "$out/transcript.txt" >"$out/transcript.txt.tmp" && mv "$out/transcript.txt.tmp" "$out/transcript.txt"
  fi
else
  printf '>> no audio track; skipping transcript\n' >&2
fi

# --- frames ------------------------------------------------------------------
ffmpeg -y -i "$video" -vf "fps=1/${interval}" "$out/frames/frame_%03d.png" >/dev/null 2>&1 || die "frame extraction failed"
frame_count="$(find "$out/frames" -name '*.png' | wc -l | tr -d ' ')"

# --- summary -----------------------------------------------------------------
printf '\n===== TRANSCRIPT (%s/transcript.txt) =====\n' "$out"
if [ -f "$out/transcript.txt" ]; then cat "$out/transcript.txt"; else echo '(none - video had no audio)'; fi
printf '\n===== FRAMES =====\n%s frames every %ss in %s/frames\n' "$frame_count" "$interval" "$out"
printf 'Next: inspect a spread of these frames with a multimodal/image tool, then delete %s when done.\n' "$out"
