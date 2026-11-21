extends RefCounted
## Recipe rows. Keys: name, station, inputs {item: n}, outputs {item: n}, minutes,
## overnight (finishes in the day-end pass), unlock (Progress flag; empty = known).

const ROWS: Dictionary = {
	# --- Bread: wheat sheaf -> grain -> flour -> bread (needs barm from ale) ---
	&"thresh_wheat": {name = "Thresh wheat", station = &"threshing_floor",
		inputs = {&"wheat_sheaf": 1}, outputs = {&"grain": 2, &"straw": 1}, minutes = 30},
	&"grind_flour": {name = "Grind flour", station = &"quern",
		inputs = {&"grain": 2}, outputs = {&"flour": 1}, minutes = 30},
	&"bake_bread": {name = "Bake bread", station = &"bread_oven",
		inputs = {&"flour": 1, &"barm": 1}, outputs = {&"bread": 2}, minutes = 120},
	# --- Dairy ---
	&"churn_butter": {name = "Churn butter", station = &"churn",
		inputs = {&"milk": 2}, outputs = {&"butter": 1}, minutes = 60},
	&"press_cheese": {name = "Press cheese", station = &"cheese_press",
		inputs = {&"milk": 3}, outputs = {&"cheese": 1}, overnight = true},
	# --- Ale: barley -> malt -> ale + barm ---
	&"malt_barley": {name = "Malt barley", station = &"malting_floor",
		inputs = {&"barley": 2}, outputs = {&"malt": 1}, overnight = true},
	&"brew_ale": {name = "Brew ale", station = &"brewing_vat",
		inputs = {&"malt": 1}, outputs = {&"ale": 2, &"barm": 1}, overnight = true},
	# --- Linen: flax -> fibre -> thread -> linen -> sack ---
	&"ret_flax": {name = "Ret flax", station = &"retting_tub",
		inputs = {&"flax": 2}, outputs = {&"flax_fibre": 1}, overnight = true},
	&"spin_thread": {name = "Spin thread", station = &"distaff",
		inputs = {&"flax_fibre": 1}, outputs = {&"linen_thread": 2}, minutes = 60},
	&"weave_linen": {name = "Weave linen", station = &"loom",
		inputs = {&"linen_thread": 4}, outputs = {&"linen": 1}, minutes = 180},
	&"sew_linen_sack": {name = "Sew a linen sack", station = &"workbench",
		inputs = {&"linen": 2}, outputs = {&"linen_sack": 1}, minutes = 60},
}

## MVP production chains: chain id -> items that must be craftable from raw items
## (G.RAW_CATEGORIES) using only ROWS. Checked by Content.validate().
const CHAINS: Dictionary = {
	&"bread": [&"bread"],
	&"dairy": [&"butter", &"cheese"],
	&"ale": [&"ale", &"barm"],
	&"linen": [&"linen_sack"],
}
