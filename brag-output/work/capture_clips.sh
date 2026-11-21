#!/usr/bin/env bash
# Records six gameplay clips with Godot Movie Maker via tools/screenshot.tscn.
# Movie Maker records the 320x180 viewport; each kept frame is nearest-neighbour upscaled 6x to
# 1920x1080 (exactly what the integer viewport stretch would do), so the pixels stay crisp.
# Usage: capture_clips.sh [clip ...]   (default: all). Idempotent: each clip dir is rebuilt.
# Run clips one at a time: parallel Godot instances thrash memory and stall.
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/godot/4.6/godot}"
W="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$W/../.." && pwd)"
export DISPLAY="${DISPLAY:-:0}"
C="$W/clips"; mkdir -p "$C/_stills"

# rec NAME KEEP SKIP harness-args...   (SKIP = warm-up frames dropped from the start)
rec() {
  local name=$1 keep=$2 skip=$3; shift 3
  local d="$C/$name" raw="$C/_raw/$name"
  rm -rf "$d" "$raw"; mkdir -p "$d" "$raw"
  "$GODOT" --path "$P" --write-movie "$raw/f.png" --fixed-fps 30 res://tools/screenshot.tscn -- \
    "$@" --frames $((keep+skip)) --out "$C/_stills" --name "$name" >"$raw/log.txt" 2>&1 || true
  rm -f "$raw"/*.wav
  local i=0 f
  for f in $(ls "$raw"/f*.png | sort | tail -n +$((skip+1)) | head -n "$keep"); do
    i=$((i+1))
    convert "$f" -filter point -resize 600% "$d/$(printf %04d $i).png"
  done
  echo "$name: $i frames"
}

# rec_clear: days:N rolls random weather; retry until the grass is bright (a clear day), max 8 tries.
rec_clear() {
  local t m
  for t in 1 2 3 4 5 6 7 8; do
    rec "$@"
    m=$(convert "$C/$1/0001.png" -crop 200x200+20+800 -format '%[fx:mean>0.35?1:0]' info:)
    [ "$m" = 1 ] && return 0
    echo "$1: rainy roll, retrying ($t)"
  done
}

# rec_noprompt: the player can stand beside an interactable, which shows a prompt over the herd; retry then.
rec_noprompt() {
  local t f m
  for t in 1 2 3 4 5 6 7 8; do
    rec "$@"
    m=0
    for f in 0001 0035 0070; do
      [ -f "$C/$1/$f.png" ] && [ "$(convert "$C/$1/$f.png" -crop 500x60+700+700 -format '%[fx:mean>0.58?1:0]' info:)" = 1 ] && m=1
    done
    [ "$m" = 0 ] && return 0
    echo "$1: prompt on screen, retrying ($t)"
  done
}

clip_storm()   { rec storm   90 240 --setup plants,days:10,storm --pos 204,-118 --zoom 2; }
clip_plants()  { rec_clear plants  90 120 --setup plants,days:10        --pos 204,-118 --zoom 2; }
clip_wheat()   { rec_clear wheat   60 120 --setup plants,days:10        --pos 222,-124 --zoom 3; }
clip_village() { rec village 90 120 --setup noon,village --zoom 1; }
clip_herd()    { rec_noprompt herd    70 120 --setup noon,herd --zoom 2; }
clip_night()   { rec night   90 120 --setup plants,autumn,noon,noon,noon --pos 220,-100 --zoom 1; }

ALL=(storm plants wheat village herd night)
for n in "${@:-${ALL[@]}}"; do "clip_$n"; done

# manifest + contact sheet (only when all clips exist)
python3 - "$C" <<'PY'
import json, os, sys
c = sys.argv[1]; out = {}
for n in ["storm", "plants", "wheat", "village", "herd", "night"]:
    d = os.path.join(c, n)
    if os.path.isdir(d): out[n] = {"count": len([f for f in os.listdir(d) if f.endswith(".png")])}
json.dump(out, open(os.path.join(c, "manifest.json"), "w"), indent=1)
PY
cd "$C"; rm -rf _raw _stills
montage -label '%d' storm/0001.png plants/0001.png wheat/0001.png village/0001.png herd/0001.png night/0001.png \
  -tile 3x2 -geometry 640x360+4+4 -pointsize 18 -background '#222' -fill white contact.jpg 2>/dev/null \
  || echo "contact sheet skipped"
