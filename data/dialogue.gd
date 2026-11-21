extends RefCounted
## Dialogue registry. One file per villager (data/dialogue_<id>.gd, const LINES) with
## these pool keys, each an Array of Strings:
##   greet_low (0-2 hearts) greet_mid (3-5) greet_high (6+)
##   spring summer autumn winter   season remark
##   rain market                   weather / Saturday remarks
##   forecast_clear forecast_rain forecast_storm   optional, hint tomorrow's weather
##   loved liked neutral disliked already          gift reactions
##   lore                          craft and farming folk knowledge
## A missing pool falls back to FALLBACK. Selection logic lives in DialogueLines.

const BY_NPC: Dictionary = {
	&"reeve": preload("res://data/dialogue_reeve.gd").LINES,
	&"chandler": preload("res://data/dialogue_chandler.gd").LINES,
	&"blacksmith": preload("res://data/dialogue_blacksmith.gd").LINES,
	&"alewife": preload("res://data/dialogue_alewife.gd").LINES,
	&"miller": preload("res://data/dialogue_miller.gd").LINES,
	&"shepherd": preload("res://data/dialogue_shepherd.gd").LINES,
}

const FALLBACK: Dictionary = {
	"greet_low": ["Good day to you."],
	"greet_mid": ["Good morrow, neighbour."],
	"greet_high": ["Well met, my friend."],
	"loved": ["Oh, that is wonderful. Thank you!"],
	"liked": ["How kind of you."],
	"neutral": ["Thank you."],
	"disliked": ["Hm. Thank you, I suppose."],
	"already": ["You have given me enough for one day."],
	"lore": ["Mind the weather, and the weeds."],
}
