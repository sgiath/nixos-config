#!/usr/bin/env bash
# Runs fix-video on a synthetic recording with a quiet first audio track and checks
# the sharing copy it writes. Usage: test.sh <fix-video executable>
set -euo pipefail

cmd=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# MPEG-4 video, a quiet tone with a near full-scale click every 3 s as the first
# audio track (linear gain to -16 LUFS would clip, so peaks must be limited) and a
# silent second track. The name has a leading hyphen, quotes and spaces.
src="-take \"one\" 'a'.mp4"
out="-take \"one\" 'a'-fixed.mp4"
ffmpeg -nostdin -v error \
  -f lavfi -i "testsrc2=size=320x240:rate=30:duration=12" \
  -f lavfi -i "aevalsrc='0.03*sin(2*PI*220*t)+0.9*lt(mod(t,3),0.002)*sin(2*PI*1000*t)':s=44100:c=stereo:d=12" \
  -f lavfi -i "anullsrc=r=48000:cl=stereo:d=12" \
  -map 0 -map 1 -map 2 -c:v mpeg4 -bf 2 -q:v 5 -c:a alac -- "$src"
src_hash=$(sha256sum -- "$src")

streams() {
  ffprobe -v error -count_frames -show_entries \
    stream=codec_type,codec_name,pix_fmt,width,height,r_frame_rate,nb_read_frames,sample_rate \
    -of json -- "file:$1"
}
duration() {
  ffprobe -v error -show_entries format=duration -of csv=p=0 -- "file:$1"
}

"$cmd" || fail "first run exited $?"

sha256sum --check --status <<<"$src_hash" || fail "source was modified"
written=$(find . -type f ! -name "$src")
[[ -f "$out" ]] || fail "expected $out, found: ${written:-nothing}"
written_count=$(wc -l <<<"$written")
[[ $written_count -eq 1 ]] || fail "expected one new file, found: $written"
# Check whatever was written so a wrong name does not hide other failures.
result=$(head -n 1 <<<"$written")
[[ -n $result ]] || {
  echo "FAIL: no output to check" >&2
  exit 1
}

# One H.264 yuv420p video stream with the source's size, rate and frame count, and
# one 48 kHz AAC audio stream (the source's first track is 44.1 kHz ALAC).
src_streams=$(streams "$src")
out_streams=$(streams "$result")
jq -e -n --argjson src "$src_streams" --argjson out "$out_streams" '
  ($src.streams[0] | {width, height, r_frame_rate, nb_read_frames}) as $v
  | $v.nb_read_frames == "360"
  and ($out.streams | map(.codec_type)) == ["video", "audio"]
  and ($out.streams[0] | {codec_name, pix_fmt, width, height, r_frame_rate, nb_read_frames})
    == {codec_name: "h264", pix_fmt: "yuv420p"} + $v
  and ($out.streams[1] | [.codec_name, .sample_rate]) == ["aac", "48000"]' >/dev/null ||
  fail "unexpected streams: $out_streams"
src_duration=$(duration "$src")
out_duration=$(duration "$result")
awk -v a="$src_duration" -v b="$out_duration" \
  'BEGIN { exit !((a - b) ^ 2 < 0.05 ^ 2) }' || fail "duration changed"

levels=$(ffmpeg -nostdin -hide_banner -nostats -i "file:$result" -map 0:a:0 \
  -af loudnorm=print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
jq -e '(.input_i | tonumber) >= -16.5 and (.input_i | tonumber) <= -15.5
  and (.input_tp | tonumber) <= -1.3' <<<"$levels" >/dev/null ||
  fail "output levels out of range: $levels"

# A rerun over the shell glob also matches the output; it must not process it again.
out_hash=$(sha256sum -- "$result")
"$cmd" ./*.mp4 || fail "second run exited $?"
files=$(find . -type f)
file_count=$(wc -l <<<"$files")
[[ $file_count -eq 2 ]] || fail "second run added files: $files"
sha256sum --check --status <<<"$out_hash" || fail "second run rewrote $result"

((failures == 0)) || exit 1
summary=$(jq -r '.input_i + " LUFS, " + .input_tp + " dBTP"' <<<"$levels")
echo "PASS: $out at $summary"
