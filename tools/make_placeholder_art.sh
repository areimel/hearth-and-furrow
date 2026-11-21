#!/usr/bin/env bash
# Regenerates every file in graphics/placeholder/ from the sources already in the repo.
# Idempotent: run from anywhere, output is byte-stable for identical inputs.
#   tools/make_placeholder_art.sh            build all
#   tools/make_placeholder_art.sh --contact  also write a labelled review sheet
#                                            (x6, point filter) to $CONTACT (default /tmp/hf/art/contact.png)
#
# Sources (see ASSET_LICENSES.md):
#   NA  = graphics/Ninja Adventure - Asset Pack (CC0)
#   COURSE = graphics/plants, graphics/icons (course art, licence unverified)
# Never read from graphics/Sprout Lands (non-commercial). Everything here is a derived
# work: crop/tile, recolour, composite, or tiny pixel art drawn below. No hand-edited PNGs.
# Requires ImageMagick 6/7 `convert`. Every output is 8-bit RGBA, exact size, no antialiasing.
set -euo pipefail
cd "$(dirname "$0")/.."

NA="graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack"
OUT="graphics/placeholder"
CONTACT="${CONTACT:-/tmp/hf/art/contact.png}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Copy to a space-free path so tile() can be word-split safely.
TE="$WORK/TilesetElement.png"
cp "$NA/Backgrounds/Tilesets/TilesetElement.png" "$TE"
mkdir -p "$OUT"
GENERATED=()

# ---------------------------------------------------------------- helpers
# save <name> <convert-args...>: run convert, write OUT/<name>.png as 8-bit RGBA.
save() {
	local name="$1"; shift
	convert "$@" -strip "PNG32:$OUT/$name.png"
	GENERATED+=("$name.png")
}

# tile <col> <row> [w h]: crop from TilesetElement (16px grid) onto a w*16 x h*16 canvas.
tile() { echo "$TE" -crop "$((${3:-1} * 16))x$((${4:-1} * 16))+$(($1 * 16))+$(($2 * 16))" +repage; }

# sprite <name> <<EOF ... EOF : tiny pixel art. Lines "x = #rrggbb" define the palette
# ('.' is always transparent), a line "---" starts the rows. Art is centred on 16x16
# (or the explicit canvas given as $2, e.g. 16x32 - bottom aligned).
sprite() {
	local name="$1" canvas="${2:-16x16}" line y=0 w=0 h=0 inrows=0
	declare -A pal
	local rows=()
	while IFS= read -r line; do
		if [[ "$line" == "---" ]]; then inrows=1; continue; fi
		[[ -z "$line" ]] && continue
		if ((inrows)); then rows+=("$line"); else pal["${line:0:1}"]="${line#*= }"; fi
	done
	h=${#rows[@]}; w=${#rows[0]}
	local f="$WORK/$name.txt"
	printf '# ImageMagick pixel enumeration: %d,%d,255,srgba\n' "$w" "$h" >"$f"
	local x c hex
	for ((y = 0; y < h; y++)); do
		for ((x = 0; x < w; x++)); do
			c="${rows[y]:x:1}"
			if [[ "$c" == "." ]]; then
				printf '%d,%d: (0,0,0,0)\n' "$x" "$y" >>"$f"
			else
				hex="${pal[$c]#\#}"
				printf '%d,%d: (%d,%d,%d,255)\n' "$x" "$y" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" >>"$f"
			fi
		done
	done
	local grav=center
	[[ "$canvas" != 16x16 ]] && grav=south
	save "$name" "txt:$f" -background none -gravity "$grav" -extent "$canvas"
}

# recolour: swap OLD NEW [OLD NEW ...] - exact-match, simultaneous (a new colour may equal
# another pair's old colour). Goes via unique temporaries.
swap() {
	local a=() b=() i=0 t
	while (($#)); do
		t=$(printf '#01%02x%02x' $((i / 256)) $((i % 256)))
		a+=(-fill "$t" -opaque "$1"); b+=(-fill "$2" -opaque "$t")
		i=$((i + 1)); shift 2
	done
	echo "${a[@]}" "${b[@]}"
}

# canvas16 / canvas1632: centre or bottom-align onto a transparent canvas.
c16="-background none -gravity center -extent 16x16"
c1632="-background none -gravity south -extent 16x32"

# ================================================================ 1. CROP SHEETS
# 64x32 = 4 frames of 16x32 (last = ripe); data/crops.gd rows set frames = 4.
PL="graphics/plants"

# wheat: row points at graphics/plants/wheat.png directly (course art); nothing generated.

# barley: wheat sheet, heads/stalks recoloured pale silver-straw, leaves a cooler green.
save crop_barley $PL/wheat.png \
	$(swap '#a96456' '#8c8a64' '#cd865c' '#c9c8a0' '#e9bb55' '#e6e2b8' '#ffe756' '#ffffff' \
		'#44b14b' '#4fae78' '#8fd62f' '#8fd68a')

# peas: tomato sheet, red fruit -> pale green pods, brown stems -> tendrils.
save crop_peas $PL/tomato.png \
	$(swap '#f35c23' '#d6ef6e' '#c6441d' '#9ac93a' '#ff875c' '#f4ffb0' '#884335' '#7a5c30')

# beans: tomato sheet, purple flowers/pods first, then a darker bean-green foliage grade.
save crop_beans $PL/tomato.png \
	$(swap '#f35c23' '#8e4aa8' '#c6441d' '#5e2f78' '#ff875c' '#d9a8ee' '#884335' '#3b2a1a') \
	-modulate 88,105,100

# flax: corn sheet, blue-green stems, yellow cob -> blue flowers.
save crop_flax $PL/corn.png \
	$(swap '#f5f93a' '#7fb4ff' '#e4c94b' '#4a86e0' '#c0934a' '#2f5fb0' '#a96456' '#2f5fb0' '#ffffff' '#d6e8ff') \
	-modulate 100,92,108

# cabbage: pumpkin sheet, orange fruit -> pale blue-green heads with darker veins.
save crop_cabbage $PL/pumpkin.png \
	$(swap '#f38823' '#b6e6b0' '#c65f1d' '#7cc29a' '#f5b32c' '#e2f8d6' '#924732' '#3f8f7a' \
		'#c8e935' '#d8f5d0' '#f5f93a' '#ffffff' '#a96456' '#3f8f7a' '#c0934a' '#7cc29a' '#e4c94b' '#e2f8d6')

# ================================================================ 2. ANIMAL
# sheep: Cow sheet (32x16, same layout). Wool white -> cream, dirty-grey patches -> darker
# cream, pink/orange face -> dark brown face. Black outline kept.
save animal_sheep "$NA/Actor/Animals/Cow/SpriteSheetWhite.png" \
	$(swap '#f2eaf1' '#efe3c4' '#5f7160' '#cdbf98' '#f2ad7d' '#5b463d' '#d3a2c0' '#7a6256' '#4e484a' '#8e7a5a')

# ================================================================ 3. ITEM ICONS (16x16)
IT="$NA/Items"

# barley: course wheat icon mirrored and recoloured silver-straw so it differs from wheat.
save barley graphics/icons/wheat.png -flop \
	$(swap '#a96456' '#8c8a64' '#cd865c' '#c9c8a0' '#e9bb55' '#e6e2b8' '#ffe756' '#ffffff') $c16

# peas: three NA Seed1 discs (8x8) recoloured green, stacked as a small pyramid.
pea="$WORK/pea.png"
convert "$IT/Food/Seed1.png" $(swap '#ffad5d' '#b8ee6a' '#f38c4c' '#5fae3a') "$pea"
save peas -size 16x16 xc:none \( "$pea" \) -geometry +0+7 -composite \
	\( "$pea" \) -geometry +8+7 -composite \( "$pea" \) -geometry +4+1 -composite

# beans: three kidney beans (NA Seed3 shapes redrawn) in a purple-brown shade.
sprite beans <<'EOF'
k = #141b1b
b = #7a3f56
B = #a85a74
l = #d38ca4
---
.kkkkk..kkkkk...
kBllBbk.kBllBbk.
kBBbbbk.kBBbbbk.
.kbbbk...kbbbk..
..kkk.....kkk...
.....kkkkk......
....kBllBbk.....
....kBBbbbk.....
.....kbbbk......
......kkk.......
EOF

# flax: bundle of green stems with pale-blue flowers (drawn).
sprite flax <<'EOF'
k = #141b1b
g = #3f8f5a
G = #6fc26a
f = #7fb4ff
F = #d6e8ff
t = #a96456
---
.f..F..f.
fFf.f.fFf
.f.kgk.f.
..kGgGk..
.kGgGgGk.
.kgGkGgk.
..kgkgk..
..kGkGk..
..ktttk..
..kttk...
...kk....
EOF

# cabbage: course pumpkin icon recoloured to a pale cabbage head with dark outer leaves.
save cabbage graphics/icons/pumpkin.png \
	$(swap '#f38823' '#b6e6b0' '#c65f1d' '#7cc29a' '#f5b32c' '#e2f8d6' '#924732' '#2f7a63') $c16

# egg: drawn.
sprite egg <<'EOF'
k = #4a3526
H = #ffffff
W = #f4ead0
S = #d8c8a0
---
......kkkk......
.....kHHWWk.....
....kHHWWWWk....
...kHWWWWWWWk...
...kHWWWWWWWk...
...kWWWWWWWWk...
...kWWWWWWWSk...
...kWWWWWWSSk...
....kWWWWSSk....
.....kSSSSk.....
......kkkk......
EOF

# fleece: drawn wool cloud.
sprite fleece <<'EOF'
k = #4a4034
H = #ffffff
W = #f0e6c8
S = #c9bb94
---
...kkk..kkk...
..kHWWkkWWWk..
.kHWWWWWWWWWk.
kHWWHWWWWWWWWk
kWHWWWWWWWWSWk
kWWWWWWWWWSSWk
.kWWWWWWSSSWk.
..kSWWSSSSWk..
...kkkkkkkk...
EOF

# clay: drawn terracotta lump.
sprite clay <<'EOF'
k = #4a2a1a
C = #b8704a
L = #d89868
D = #8c5236
---
....kkkkkk....
..kkCCCCCCkk..
.kCCLLCCCCCCk.
kCCLCCCCCCCCCk
kCCCCCCCCDCCCk
kCCCCCCCDDCCCk
.kCCCCDDDDCCk.
..kkDDDDDDkk..
....kkkkkk....
EOF

# blackberry: drawn cluster with a leaf.
sprite blackberry <<'EOF'
k = #141b1b
P = #5a2d82
H = #a478d0
g = #3f8f5a
G = #6fc26a
---
.....kGGk...
....kGGgk...
..kk.kggk.kk
.kPHkkkkkkPHk
.kPPkPHkkPPk.
kPHkkPPkPHkk.
kPPkPHkkPPkk.
.kkkkPPkkkk..
...kPHkkPHk..
...kPPkkPPk..
....kk..kk...
EOF

# flour: drawn tied sack with a wheat mark.
sprite flour <<'EOF'
k = #4a4a52
O = #e66a3a
W = #f2eee0
H = #ffffff
S = #c4bfae
F = #d9a441
---
....kkkk....
...kOOOOk...
....kkkk....
..kkWWWWkk..
.kWWWHWWWWk.
kWWWWWWWWWWk
kWWWWFFWWWSk
kWWWWWWWWWSk
kWWWWWWWWSSk
.kSSSSSSSSk.
..kkkkkkkk..
EOF

# malt: drawn heap of toasted grains.
sprite malt <<'EOF'
k = #4a2a10
A = #c8842a
h = #f0c060
D = #8c5a1a
---
.....kkkk.....
...kkAAhAkk...
..kAAhAAAAAk..
.kAAAAkAAAAAk.
kAhAAAAAAkAAAk
kAAAAkAAAAAAAk
kDAAAAAAAAAADk
.kkDDDDDDDDkk.
..kkkkkkkkkk..
EOF

# barm: NA MilkPot (jar) with the milk recoloured to a frothy tan.
save barm "$IT/Potion/MilkPot.png" $(swap '#abc2bc' '#d9a441') $c16

# flax_fibre: drawn tied hank of pale strands.
sprite flax_fibre <<'EOF'
k = #4a4034
F = #e8dcb0
f = #c9b888
t = #a96456
---
..k.k..k.k..
.kFkFkkFkFk.
.kFFkFFkFFk.
..kFFFFFFk..
..kttttttk..
..kttttttk..
..kFFFFFFk..
.kFFkfFkFFk.
.kFkFkkFkFk.
..k.k..k.k..
EOF

# linen_thread: drawn spool.
sprite linen_thread <<'EOF'
k = #4a3526
R = #a3754e
T = #e9e2cf
t = #bdb59c
---
.kkkkkkkkkk.
kRRRRRRRRRRk
.kkTTTTTTkk.
..kTtTTtTk..
..kTTTtTTk..
..kTtTTtTk..
..kTTTTTTk..
.kkkkkkkkkk.
kRRRRRRRRRRk
.kkkkkkkkkk.
EOF

# bread: drawn round loaf.
sprite bread <<'EOF'
k = #4a2a14
B = #d58a3c
L = #f0b866
D = #a8602a
---
....kkkkkkkk....
..kkBBBLBBBBkk..
.kBBBBBBBBBLBBk.
kBBLBBBBBBBBBBBk
kBBBBBBBBBBBBBBk
kDBBBBBBBBBBBBDk
.kDDBBBBBBBBDDk.
..kkDDDDDDDDkk..
....kkkkkkkk....
EOF

# butter: drawn block.
sprite butter <<'EOF'
k = #5a4a1a
L = #fff4b0
Y = #f2d65c
S = #c9a93c
---
.kkkkkkkkkkkk.
kLLLLLLLLLLLLk
kLLLLLLLLLLLLk
kkkkkkkkkkkkkk
kYYYYYYYYYYYYk
kYYYYYYYYYYYYk
kYYLLYYYYYYYYk
kYYYYYYYYYYYYk
kSSSSSSSSSSSSk
.kkkkkkkkkkkk.
EOF

# cheese: drawn wedge with holes.
sprite cheese <<'EOF'
k = #5a3a10
Y = #f6d860
o = #d9a23a
O = #f2c04a
d = #b07a28
---
......kkkkkk....
....kkYYYYYYkk..
..kkYYYYoYYYYYkk
.kYYYYYYYYYYYYYk
kkkkkkkkkkkkkkkk
kOOOOOOOOOOOOOOk
kOOdOOOOOOOdOOOk
kOOOOOOdOOOOOOkk
kkkkkkkkkkkkkkk.
EOF

# ale: drawn tankard.
sprite ale <<'EOF'
k = #4a2a14
F = #fff6dc
A = #d9902a
H = #f2c060
w = #a3754e
---
.kkkkkkkkkk....
kFFFFFFFFFFk...
kFHFFFFFFFFk...
kAAAAAAAAAAkkkk
kAAAAAAAAAAk..k
kAHAAAAAAAAk..k
kAAAAAAAAAAkkkk
kAAAAAAAAAAk...
kAAAAAAAAAAk...
.kkkkkkkkkk....
EOF

# linen: drawn folded bolt with a blue selvedge stripe.
sprite linen <<'EOF'
k = #4a4a52
L = #f2eee0
S = #d2ccb6
B = #5a82c8
---
..kkkkkkkkkkkk..
.kLLLLLLLLLLLLk.
kLLLLLLLLLLLLLLk
kLSLLLLLLLLLLSLk
kBBBBBBBBBBBBBBk
kLLLLLLLLLLLLLLk
kLLLLLLLLLLLLLLk
.kSSSSSSSSSSSSk.
..kkkkkkkkkkkk..
EOF

# fishing_rod_iron_shod: NA fishing rod, line and hook recoloured to bright steel, tip band added.
save fishing_rod_iron_shod "$IT/Weapons/Fishing Rod/Sprite.png" \
	$(swap '#f2eaf1' '#ffffff' '#abc2bc' '#9aa6b4' '#eecf9b' '#b6c2d0' '#ffad5d' '#d4dde8') $c16

# ================================================================ 4. STATIONS
# Base of every sprite sits on the bottom edge. Tiles come from NA TilesetElement.

# threshing_floor: hay tile (14,5) + a drawn flail (handle and swingle).
save threshing_floor $(tile 14 5) +antialias \
	-fill '#141b1b' -draw 'line 2,13 11,3' -draw 'line 3,13 12,3' -draw 'rectangle 10,1 14,3' \
	-fill '#a3754e' -draw 'line 3,12 10,4' -fill '#c9955c' -draw 'rectangle 11,2 13,2'

# quern: drawn millstones (two grey discs, hole, wooden handle).
sprite quern <<'EOF'
k = #141b1b
g = #abc2bc
G = #8f9fa0
d = #5f7160
w = #a3754e
---
........kkkk...
.......kwwwk...
..kkkkkkkwkkk..
.kgggggggkwkgk.
kgggggkkkgwgggk
kGgggkdddkgggGk
kGGgggkkkgggGGk
.kGGGGGGGGGGGk.
.kkkkkkkkkkkkk.
kgggggggggggggk
kGGGGGGGGGGGGGk
kdddddddddddddk
.kkkkkkkkkkkkk.
EOF

# bread_oven: dome oven tile (12,0) straight from the tileset.
save bread_oven $(tile 12 0)

# churn: barrel tile (4,0) in pale staves + drawn plunger (16x32).
save churn $(tile 4 0) $(swap '#e46d3a' '#d8b87a' '#ffad5d' '#f0dca8' '#965340' '#8a6a44') $c1632 +antialias \
	-fill '#141b1b' -draw 'rectangle 6,0 9,19' -draw 'rectangle 3,0 12,3' \
	-fill '#e8d9a8' -draw 'rectangle 7,2 8,18' -draw 'rectangle 4,1 11,2'

# cheese_press: slatted crate (0,0) in cheese-yellow wood, drawn stone weight, screw and bar (16x32).
save cheese_press $(tile 0 0) $(swap '#e46d3a' '#d9a23a' '#ffad5d' '#f2d060' '#965340' '#7a5428') $c1632 +antialias \
	-fill '#141b1b' -draw 'rectangle 4,8 11,16' -draw 'rectangle 6,1 9,8' -draw 'rectangle 2,0 13,2' \
	-fill '#abc2bc' -draw 'rectangle 5,9 10,15' -fill '#8f9fa0' -draw 'rectangle 5,13 10,15' \
	-fill '#a3754e' -draw 'rectangle 7,2 8,7' -draw 'rectangle 3,1 12,1'

# malting_floor: hay tile (14,5) sprouted green inside a drawn wooden frame.
save malting_floor $(tile 14 5) $(swap '#f1c471' '#a8c860' '#ffe18d' '#d4e88c') +antialias \
	-fill none -stroke '#141b1b' -strokewidth 1 -draw 'rectangle 0,2 15,15' \
	-stroke '#a3754e' -draw 'rectangle 1,3 14,14' \
	-stroke none -fill '#f0f8b0' -draw 'point 4,7' -draw 'point 8,6' -draw 'point 11,9' -draw 'point 6,11' -draw 'point 12,5'

# brewing_vat: big tub (2,1) in dark oak with amber ale and foam pixels.
save brewing_vat $(tile 2 1) $(swap '#bd7959' '#6e4e34' '#d2b37d' '#d89a2c') +antialias \
	-fill '#fff6dc' -draw 'point 5,5' -draw 'point 7,6' -draw 'point 10,5' -draw 'point 8,8' -draw 'point 11,8' -draw 'point 6,9'

# retting_tub: water tub (5,0) in weathered wood, drawn flax stalks (blue flowers) rising from it.
save retting_tub $(tile 5 0) $(swap '#e46d3a' '#b88a5a') $c1632 +antialias \
	-fill '#2f7a4a' -draw 'line 4,19 3,6' -draw 'line 8,19 8,3' -draw 'line 11,19 12,6' \
	-fill '#7fb4ff' -draw 'point 3,5' -draw 'point 2,6' -draw 'point 8,2' -draw 'point 7,3' -draw 'point 12,5' -draw 'point 13,6'

# distaff: drawn pole with a wool/flax tuft on a little stool (16x32).
sprite distaff 16x32 <<'EOF'
k = #141b1b
w = #a3754e
W = #5f3a2a
F = #e8dcb0
f = #c9b888
---
.......kkk......
......kFFFk.....
.....kFfFFFk....
.....kFFfFFk....
.....kfFFFFk....
......kFFfk.....
.......kkk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
.......kwk......
..kkkkkkwkkkkk..
.kwwwwwwwwwwwwk.
.kwwwwwwwwwwwwk.
.kkkkkkkkkkkkkk.
..kWk......kWk..
..kWk......kWk..
..kWk......kWk..
..kkk......kkk..
EOF

# loom: drawn upright frame with warp threads and a woven cloth strip (16x32).
convert -size 16x32 xc:none +antialias \
	-fill '#141b1b' -draw 'rectangle 0,2 3,31' -draw 'rectangle 12,2 15,31' \
	-draw 'rectangle 0,0 15,5' -draw 'rectangle 0,13 15,15' -draw 'rectangle 0,26 15,28' \
	-fill '#a3754e' -draw 'rectangle 1,2 2,30' -draw 'rectangle 13,2 14,30' \
	-draw 'rectangle 1,1 14,4' -draw 'rectangle 1,14 14,14' -draw 'rectangle 1,27 14,27' \
	-fill '#e8e0cc' -draw 'line 5,5 5,13' -draw 'line 7,5 7,13' -draw 'line 9,5 9,13' -draw 'line 11,5 11,13' \
	-fill '#c0463a' -draw 'rectangle 4,16 11,17' -draw 'rectangle 4,20 11,21' \
	-fill '#e8e0cc' -draw 'rectangle 4,18 11,19' -draw 'rectangle 4,22 11,25' \
	-strip "PNG32:$OUT/loom.png"
GENERATED+=(loom.png)

# workbench: clothed table tile (14,0) with green cloth, plus a drawn needle and shears.
save workbench $(tile 14 0) $(swap '#e0394c' '#4f8f5a') +antialias \
	-fill '#141b1b' -draw 'line 5,6 9,4' -fill '#d4dde8' -draw 'point 6,5' -draw 'point 7,5' -draw 'point 8,4'

# ================================================================ review sheet
if [[ "${1:-}" == "--contact" ]]; then
	mkdir -p "$(dirname "$CONTACT")"
	args=()
	for f in "${GENERATED[@]}"; do
		convert "$OUT/$f" -filter point -resize 600% "$WORK/x6_$f"
		args+=(-label "$f" "$WORK/x6_$f")
	done
	montage "${args[@]}" -background '#5a6a78' -fill white -pointsize 14 -geometry '384x200+6+6' -tile 5x "$CONTACT"
fi
echo "generated ${#GENERATED[@]} files in $OUT"
