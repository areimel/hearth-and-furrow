#!/usr/bin/env bash
# rec.sh NAME KEEP SKIP "godot-harness-args..."   (records raw 320x180 viewport frames, trims, nearest-upscales 6x to 1920x1080)
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/godot/4.6/godot}"
W="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$W/../.." && pwd)"
NAME=$1; KEEP=$2; SKIP=$3; shift 3
D="$W/clips/$NAME"; RAW="$W/clips/_raw/$NAME"
rm -rf "$D" "$RAW"; mkdir -p "$D" "$RAW" "$W/clips/_stills"
DISPLAY="${DISPLAY:-:0}" "$GODOT" --path "$P" --write-movie "$RAW/f.png" --fixed-fps 30 res://tools/screenshot.tscn -- \
  "$@" --frames $((KEEP+SKIP)) --out "$W/clips/_stills" --name "$NAME" >"$RAW/log.txt" 2>&1 || true
rm -f "$RAW"/*.wav
i=0
for f in $(ls "$RAW"/f*.png | sort | tail -n +$((SKIP+1)) | head -n "$KEEP"); do
  i=$((i+1)); n=$(printf %04d $i)
  convert "$f" -filter point -resize 600% "$D/$n.png"
done
echo "$NAME $i frames"
