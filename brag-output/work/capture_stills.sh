#!/usr/bin/env bash
# Capture the launch-video stills: 7 Godot screens at 320x180 raw, upscaled x6 to 1920x1080.
# Idempotent: rerunning overwrites the same files. Run from anywhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"                      # brag-output/work -> project root
GODOT="${GODOT:-$HOME/.local/share/godot/4.6/godot}"
RAW="$HERE/stills_raw"
OUT="$HERE/stills"
mkdir -p "$RAW" "$OUT"

# name:setup pairs (--setup steps are comma-separated; title is its own step)
SHOTS=(
  "title:title"
  "thresh:crafting:threshing_floor"
  "quern:crafting:quern"
  "oven:crafting:bread_oven"
  "alewife:dialogue:alewife"
  "mayday:festival:may_day"
  "shop:shop:chandler"
)

for spec in "${SHOTS[@]}"; do
  name="${spec%%:*}"
  setup="${spec#*:}"
  "$GODOT" --path "$PROJECT" res://tools/screenshot.tscn -- \
    --out "$RAW" --setup "$setup" --frames 120 --name "$name" --upscale 6 \
    > "$RAW/$name.log" 2>&1
  cp "$RAW/${name}_x6.png" "$OUT/$name.png"
  identify -format '%f %wx%h\n' "$OUT/$name.png"
done

# Contact sheet: 4x2 tiles, 480px wide each, labelled with the file name.
cd "$OUT"
montage -label '%f' -tile 4x2 -geometry 480x270+6+6 -background '#202020' -fill white \
  -font DejaVu-Sans -pointsize 22 \
  title.png thresh.png quern.png oven.png alewife.png mayday.png shop.png contact.jpg
identify contact.jpg
