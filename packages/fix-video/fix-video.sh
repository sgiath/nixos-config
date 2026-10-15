usage() {
  cat <<'EOF'
Usage: fix-video [PATH...]

Makes a sharing copy of each screen recording: the first video track is re-encoded
as H.264 (libx264, preset veryfast, CRF 16, yuv420p) at the source resolution and
frame rate, and the first audio track is leveled to -16 LUFS (loudness range 7 LU,
limiter at -2.2 dBTP so the encoded peak stays below -1.3 dBTP) with two-pass
ffmpeg loudnorm and encoded as AAC 256 kb/s, 48 kHz. Loud peaks are limited
instead of clipped. Other audio tracks, subtitles and data streams are dropped;
metadata and chapters are kept. Each result is written next to its source as
NAME-fixed.mp4 (moov atom first for streaming); the source is never modified.

PATH is a video file or a directory searched recursively; the default is the
current directory. Supported inputs: .mp4, .mov, .mkv. File names starting
with '-' need './' or a preceding '--'.

Skipped: *-fixed.* outputs themselves, sources whose output already exists,
files without audio and silent audio (below -70 LUFS).
EOF
}

target="I=-16:TP=-2.2:LRA=7"

work=$(mktemp -d)
log=$work/ffmpeg.log
partial=""
cleanup() {
  [[ -z $partial ]] || rm -f -- "$partial"
  rm -rf -- "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

error() {
  echo "fix-video: $*" >&2
}

# run_ffmpeg LABEL DURATION_US ARGS...: runs ffmpeg with stderr in $log, showing
# percent progress on a terminal. The run is bounded to 5 minutes plus ten times the
# media duration, far above what a veryfast x264 encode needs.
run_ffmpeg() {
  local label=$1 duration_us=$2
  shift 2
  local limit=$((300 + 10 * duration_us / 1000000)) status=0
  timeout --foreground "$limit" ffmpeg -nostdin -hide_banner -nostats -progress pipe:1 "$@" 2>"$log" |
    while IFS='=' read -r key value; do
      if [[ -t 2 && $key == out_time_us && $value =~ ^[0-9]+$ ]]; then
        printf '\r  %s %3d%%' "$label" $((value * 100 / duration_us)) >&2
      fi
    done || status=$?
  [[ -t 2 ]] && printf '\r\033[K' >&2
  if ((status == 124)); then
    error "ffmpeg $label timed out after ${limit}s"
  elif ((status != 0)); then
    error "ffmpeg $label failed (exit $status):"
    tail -n 5 "$log" | sed 's/^/  /' >&2
  fi
  return "$status"
}

# loudnorm prints its measurement as the last JSON object in the log.
loudnorm_json() {
  sed -n '/^{/,/^}/p' "$log"
}

fixed=0
skipped=0
failed=0

# fix SOURCE: writes SOURCE's sharing copy; returns 1 on failure.
fix() {
  local src=$1 dir base stem ext out probe duration_us measured gain result
  dir=$(dirname -- "$src")
  base=$(basename -- "$src")
  stem=${base%.*}
  ext=${base##*.}
  case ${ext,,} in
    mp4 | mov | mkv) ;;
    *)
      error "$src: unsupported container .$ext (supported: .mp4, .mov, .mkv)"
      return 1
      ;;
  esac
  out=$dir/$stem-fixed.mp4
  if [[ ${stem,,} == *-fixed ]]; then
    echo "  skipped: already a fixed output"
    skipped=$((skipped + 1))
    return 0
  fi
  if [[ -e $out ]]; then
    echo "  skipped: $out already exists"
    skipped=$((skipped + 1))
    return 0
  fi

  if ! probe=$(ffprobe -v error -select_streams a:0 -show_entries stream=index \
    -show_entries format=duration -of json -- "file:$src" 2>&1); then
    error "$src: cannot read media: $probe"
    return 1
  fi
  duration_us=$(jq -r '.format.duration // empty | tonumber * 1000000 | floor' <<<"$probe")
  if [[ $(jq '.streams // [] | length' <<<"$probe") == 0 ]]; then
    echo "  skipped: no audio track"
    skipped=$((skipped + 1))
    return 0
  fi
  if [[ -z $duration_us ]] || ((duration_us <= 0)); then
    error "$src: container reports no duration"
    return 1
  fi

  run_ffmpeg measuring "$duration_us" -i "file:$src" -map 0:a:0 \
    -af "loudnorm=$target:print_format=json" -f null - || return 1
  measured=$(loudnorm_json)
  if [[ $(jq -r .input_i <<<"$measured") == -inf ]]; then
    echo "  skipped: audio is silent (below -70 LUFS)"
    skipped=$((skipped + 1))
    return 0
  fi
  gain=$(jq -r '"measured_I=\(.input_i):measured_TP=\(.input_tp):measured_LRA=\(.input_lra):measured_thresh=\(.input_thresh):offset=\(.target_offset)"' <<<"$measured")

  # Hidden temporary output in the same directory, renamed into place only after
  # ffmpeg succeeds, so an interrupted run never leaves a partial NAME-fixed file.
  partial=$(mktemp -p "$dir" ".$stem-fixed.XXXXXX") || return 1
  # 0:V excludes cover art. loudnorm resamples to 192 kHz internally; aresample
  # brings it down to 48 kHz.
  run_ffmpeg encoding "$duration_us" -i "file:$src" -map 0:V:0 -map 0:a:0 \
    -c:v libx264 -preset veryfast -crf 16 -threads 8 -pix_fmt yuv420p \
    -af "loudnorm=$target:$gain:linear=true:print_format=json,aresample=48000" \
    -c:a aac -b:a 256k -f mp4 -movflags +faststart -y "file:$partial" || return 1
  result=$(loudnorm_json)

  if ! mv --update=none-fail -T -- "$partial" "$out"; then
    error "$src: $out appeared while encoding; leaving it untouched"
    return 1
  fi
  partial=""
  jq -r --arg out "$out" \
    '"  \(.input_i) LUFS, \(.input_tp) dBTP -> \(.output_i) LUFS (\(.normalization_type)): \($out)"' \
    <<<"$result"
  fixed=$((fixed + 1))
}

paths=()
while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      paths+=("$@")
      break
      ;;
    -*)
      error "unknown option $1 (see --help)"
      exit 2
      ;;
    *) paths+=("$1") ;;
  esac
  shift
done
((${#paths[@]})) || paths=(.)

files=()
for path in "${paths[@]}"; do
  [[ $path == -* ]] && path=./$path
  if [[ -d $path ]]; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find "$path" -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' \) \
      ! -iname '*-fixed.*' -print0 | sort -z)
  elif [[ -f $path ]]; then
    files+=("$path")
  else
    error "$path: no such file or directory"
    failed=$((failed + 1))
  fi
done

total=${#files[@]}
if ((total == 0 && failed == 0)); then
  echo "No .mp4, .mov or .mkv files to fix."
  exit 0
fi

index=0
for file in "${files[@]}"; do
  index=$((index + 1))
  echo "[$index/$total] $file"
  if ! fix "$file"; then
    [[ -z $partial ]] || rm -f -- "$partial"
    partial=""
    failed=$((failed + 1))
  fi
done

echo "Fixed $fixed, skipped $skipped, failed $failed in ${SECONDS}s."
((failed == 0))
