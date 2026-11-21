class_name SaveSnapshot extends RefCounted
## Helper (not test_*.gd, so the runner skips it) shared by the save tests and
## tools/year_sim.gd: a comparable picture of everything the save contract covers.


## Every registered section, with values that legitimately drift between a save and a
## reload (animal wander position) removed.
static func capture() -> Dictionary:
	var sections := SaveManager.snapshot()
	var herd: Dictionary = sections.get(&"livestock", {})
	for entry: Dictionary in herd.get("animals", []):
		entry.erase("pos")
	var farm: Dictionary = sections.get(&"farm", {})
	for key: String in ["tilled", "wet"]:
		if farm.has(key):
			farm[key].sort_custom(_pair_less)
	if farm.has("crops"):
		farm["crops"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _pair_less(a["cell"], b["cell"]))
	return sections


static func _pair_less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


## Names of the sections that differ between two captures ("" separated list when equal).
static func diff(a: Dictionary, b: Dictionary) -> String:
	var keys: Dictionary = {}
	for key: Variant in a:
		keys[key] = true
	for key: Variant in b:
		keys[key] = true
	var bad: PackedStringArray = []
	for key: Variant in keys:
		if a.get(key) != b.get(key):
			bad.append(str(key))
	return ", ".join(bad)


## Compact observable numbers for assertions and the year-sim report.
static func summary(level: Level) -> Dictionary:
	var stations := level.get_node_or_null("Workstations") as Workstations
	var herd := level.get_node_or_null("Livestock") as Livestock
	var jobs := 0
	if stations:
		for station in stations.stations():
			jobs += station.job_count()
	var hearts := 0
	for npc in Content.npcs():
		hearts += Relationships.hearts(npc.id)
	var items := 0
	for i in Inventory.size():
		items += Inventory.slot_count(i)
	return {"day": GameClock.day_index, "coins": Economy.coins, "items": items,
		"crops": level.farm_grid.crop_field.crops().size(), "jobs": jobs,
		"animals": herd.animals().size() if herd else 0, "hearts": hearts}
