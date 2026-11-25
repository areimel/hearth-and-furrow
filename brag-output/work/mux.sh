#!/usr/bin/env bash
# Encode rendered frames + music into the launch video and a poster JPG.
#
# Usage: brag-output/work/mux.sh [POSTER_FRAME]        (default 220)
# Env overrides (for testing or alternate inputs):
#   FRAMES_DIR  folder with 0000.png..0639.png   (default W/frames)
#   AUDIO       audio file                       (default W/music.wav)
#   OUT         video output                     (default W/../brag.mp4; poster is the same name with .jpg)
#   CHECKS_DIR  check frame output               (default W/checks)
#   FRAMES      frame count                      (default 640)
set -euo pipefail

W="$(cd "$(dirname "$0")" && pwd)"
POSTER="${1:-${POSTER:-220}}"
FRAMES="${FRAMES:-640}"
FRAMES_DIR="${FRAMES_DIR:-$W/frames}"
AUDIO="${AUDIO:-$W/music.wav}"
OUT="${OUT:-$W/../brag.mp4}"
POSTER_OUT="${OUT%.mp4}.jpg"
CHECKS_DIR="${CHECKS_DIR:-$W/checks}"
FPS=30
DURATION="$(awk -v f="$FRAMES" -v r="$FPS" 'BEGIN { printf "%.6f", f / r }')"

command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || { echo "ffmpeg/ffprobe not found" >&2; exit 1; }
[ -f "$AUDIO" ] || { echo "missing audio: $AUDIO" >&2; exit 1; }
for ((i = 0; i < FRAMES; i++)); do
  f="$(printf '%s/%04d.png' "$FRAMES_DIR" "$i")"
  [ -f "$f" ] || { echo "missing frame: $f" >&2; exit 1; }
done
POSTER_SRC="$(printf '%s/%04d.png' "$FRAMES_DIR" "$POSTER")"
[ -f "$POSTER_SRC" ] || { echo "missing poster frame: $POSTER_SRC" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

echo "poster frame $POSTER -> ${POSTER_OUT}"
ffmpeg -v error -y -i "$POSTER_SRC" -frames:v 1 -vf format=rgb24 -q:v 2 "$POSTER_OUT"

# Temp sequence: frame 0 is replaced by the poster frame, so frame count and sync are unchanged.
SEQ="$(mktemp -d "${TMPDIR:-/tmp}/brag-seq.XXXXXX")"
trap 'rm -rf "$SEQ"' EXIT
for ((i = 0; i < FRAMES; i++)); do
  src="$(printf '%s/%04d.png' "$FRAMES_DIR" "$i")"
  [ "$i" -eq 0 ] && src="$POSTER_SRC"
  ln -s "$(readlink -f "$src")" "$(printf '%s/%04d.png' "$SEQ" "$i")"
done

echo "encoding $FRAMES frames at ${FPS}fps + audio -> $OUT"
ffmpeg -v error -y \
  -framerate "$FPS" -start_number 0 -i "$SEQ/%04d.png" \
  -i "$AUDIO" \
  -map 0:v:0 -map 1:a:0 \
  -frames:v "$FRAMES" \
  -vf "format=rgb24,scale=out_color_matrix=bt709:out_range=tv,format=yuv420p" \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -c:v libx264 -preset slow -crf 16 -profile:v high \
  -c:a aac -b:a 192k -af "apad" -t "$DURATION" \
  -movflags +faststart \
  "$OUT"

echo "verify:"
NB_FRAMES="$(ffprobe -v error -count_frames -select_streams v:0 \
  -show_entries stream=nb_read_frames -of csv=p=0 "$OUT")"
VDUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")"
echo "  video frames (nb_read_frames): $NB_FRAMES"
echo "  container duration: $VDUR s (expected $DURATION)"
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,sample_rate,duration \
  -of default=nw=1 "$OUT" | sed 's/^/  audio /'
[ "$NB_FRAMES" = "$FRAMES" ] || { echo "frame count mismatch" >&2; exit 1; }
ffprobe -v error -show_entries stream=codec_type -of csv=p=0 "$OUT" | grep -q audio || { echo "no audio stream" >&2; exit 1; }

mkdir -p "$CHECKS_DIR"
for t in 1.5 4 7 10 13 16 20; do
  ffmpeg -v error -y -ss "$t" -i "$OUT" -frames:v 1 -q:v 2 "$CHECKS_DIR/t$t.jpg"
done
echo "check frames written to $CHECKS_DIR: t1.5 t4 t7 t10 t13 t16 t20 (.jpg)"
echo "done: $OUT, $POSTER_OUT"
