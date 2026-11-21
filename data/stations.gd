extends RefCounted
## Station rows. Keys: name, desc, cost {item: n} to build, slots (parallel jobs), texture.
## All stations share one generic scene; what they make is in data/recipes.gd.

const P := preload("res://data/paths.gd")

const ROWS: Dictionary = {
	&"threshing_floor": {name = "Threshing Floor", desc = "Flail sheaves into grain.",
		cost = {&"log": 6, &"stone": 4}, texture = P.PLACEHOLDER + "threshing_floor.png"},
	&"quern": {name = "Hand Quern", desc = "Grind grain into flour.",
		cost = {&"stone": 8}, texture = P.PLACEHOLDER + "quern.png"},
	&"bread_oven": {name = "Bread Oven", desc = "Bake loaves.",
		cost = {&"stone": 10, &"clay": 6}, texture = P.PLACEHOLDER + "bread_oven.png"},
	&"churn": {name = "Butter Churn", desc = "Churn milk into butter.",
		cost = {&"log": 4}, texture = P.PLACEHOLDER + "churn.png"},
	&"cheese_press": {name = "Cheese Press", desc = "Press curds overnight.",
		cost = {&"log": 6, &"stone": 2}, texture = P.PLACEHOLDER + "cheese_press.png"},
	&"malting_floor": {name = "Malting Floor", desc = "Sprout and dry barley.",
		cost = {&"stone": 6, &"reed": 8}, texture = P.PLACEHOLDER + "malting_floor.png"},
	&"brewing_vat": {name = "Brewing Vat", desc = "Mash and ferment ale.",
		cost = {&"log": 8, &"hazel_rod": 4}, texture = P.PLACEHOLDER + "brewing_vat.png"},
	&"retting_tub": {name = "Retting Tub", desc = "Soak flax to free the fibre.",
		cost = {&"log": 4, &"clay": 4}, texture = P.PLACEHOLDER + "retting_tub.png"},
	&"distaff": {name = "Distaff", desc = "Spin fibre into thread.",
		cost = {&"hazel_rod": 3}, texture = P.PLACEHOLDER + "distaff.png"},
	&"loom": {name = "Loom", desc = "Weave thread into cloth.",
		cost = {&"log": 8, &"hazel_rod": 6}, texture = P.PLACEHOLDER + "loom.png"},
	&"workbench": {name = "Workbench", desc = "Sew, mend and make.",
		cost = {&"log": 5}, texture = P.PLACEHOLDER + "workbench.png"},
}
