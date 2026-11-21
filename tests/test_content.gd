extends TestCase
## Content registry: tables are consistent and the MVP chains are completable.

const Recipes := preload("res://data/recipes.gd")
const P := preload("res://data/paths.gd")


func test_validate_reports_no_problems() -> void:
	var problems := Content.validate()
	eq(problems.size(), 0, "validate problems: %s" % "\n".join(problems))


func test_mvp_counts() -> void:
	eq(Content.crops().size(), 6, "crops")
	eq(Content.animals().size(), 3, "animals")
	eq(Content.npcs().size(), 6, "npcs")
	eq(Content.stations().size(), 11, "stations")
	eq(Content.tool_tiers().size(), 2, "tool tiers")
	eq(Content.festivals().size(), 2, "festivals")
	eq(Content.items_in_category(G.ItemCategory.TOOL).size(), 10, "tools")


## Independent of Content.validate(): a fixpoint over the raw recipe table only.
func test_all_chains_completable_from_raw_items() -> void:
	var have: Dictionary = {}
	for item: ItemData in Content.items():
		if item.category in G.RAW_CATEGORIES:
			have[item.id] = true
	var changed := true
	while changed:
		changed = false
		for row: Dictionary in Recipes.ROWS.values():
			var ok := true
			for input: StringName in row.inputs:
				ok = ok and have.has(input)
			if ok:
				for output: StringName in row.outputs:
					if not have.has(output):
						have[output] = true
						changed = true
	for chain: StringName in Recipes.CHAINS:
		for target: StringName in Recipes.CHAINS[chain]:
			check(have.has(target), "chain %s cannot make %s" % [chain, target])
	check(not have.has(&"wheat_seed"), "seeds are bought, not crafted")


func test_typed_lookups() -> void:
	var wheat := Content.crop_for_seed(&"wheat_seed")
	check(wheat != null and wheat.id == &"wheat", "wheat seed sows wheat")
	eq(Content.crop_for_seed(&"stone"), null, "non-seed has no crop")
	eq(Content.item(&"milk").category, G.ItemCategory.ANIMAL_PRODUCT, "milk category")
	eq(Content.item(&"axe_wooden").stack_size, 1, "tools stack to 1")
	eq(Content.item(&"stone").stack_size, 99, "materials stack to 99")
	eq(Content.tool_item(G.ToolKind.SICKLE, &"iron_shod").id, &"sickle_iron_shod", "tool_item")
	eq(Content.tool_tier(&"wooden").next_tier, &"iron_shod", "tier chain")
	eq(Content.recipes_for_station(&"brewing_vat").size(), 1, "vat recipes")
	eq(Content.recipe(&"brew_ale").outputs[&"barm"], 1, "ale makes barm")
	check(Content.recipe(&"press_cheese").overnight, "cheese is overnight")
	check(Content.has_item(&"linen_sack") and not Content.has_item(&"nope"), "has_item")
	eq(Content.items_with_tag(&"grain").size(), 3, "grain tag")
	eq(Content.festival_on(G.Season.SPRING, 20).id, &"may_day", "festival_on")


func test_every_texture_resolves_to_something() -> void:
	for item: ItemData in Content.items():
		check(item.icon != null, "icon for %s" % item.id)
	for crop: CropData in Content.crops():
		check(crop.sprite != null, "sprite for %s" % crop.id)
	for path: String in Content.pending_placeholders():
		check(path.begins_with(P.PLACEHOLDER), "pending outside placeholder dir: %s" % path)
