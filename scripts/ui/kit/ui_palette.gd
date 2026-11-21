class_name UIPalette extends RefCounted
## Single source of UI colours. scenes/ui/game_theme.tres is generated from these
## values by tools/build_theme.gd; scripts that need a colour (toasts, hearts...)
## read it from here instead of hardcoding.

const PARCHMENT := Color("e8d5a8")
const PARCHMENT_DARK := Color("c9ad77")
const PARCHMENT_LIGHT := Color("f4e8c8")
const WOOD_DARK := Color("3b2616")
const WOOD := Color("6b4423")
const WOOD_LIGHT := Color("8f6234")
const INK := Color("2a1a0e")
const INK_DISABLED := Color("8a7556")
const RUST := Color("8a3a1c")
const GOLD := Color("f2c14e")
const MOSS := Color("5d8a3a")
const CRIMSON := Color("b03a2e")
const SHADOW := Color(0, 0, 0, 0.35)
## Cool tones for weather and winter icons.
const SKY := Color("6f9bb8")
const SLATE := Color("5a6470")
