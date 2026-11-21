class_name CraftingText extends RefCounted
## Text helpers for the crafting screen, derived from Content (no hardcoded ids).


## "30 min", "2 h", "1 h 30" or "Overnight" for a recipe; "Instant" for 0 minutes.
static func duration(recipe: RecipeData) -> String:
	if recipe.overnight:
		return "Overnight"
	return UIText.minutes(recipe.minutes)


## Where this recipe sits in its production chain, e.g.
## "flax > flax fibre > linen thread > linen > linen sack" (arrows as "→").
## Walks back to a raw item via recipes_producing() and forward to the nearest chain
## target via recipes_using(). Empty if the recipe has no inputs or outputs.
static func chain_preview(recipe: RecipeData) -> String:
	if recipe.inputs.is_empty() or recipe.outputs.is_empty():
		return ""
	var path: Array[StringName] = [_first_key(recipe.outputs)]
	var item: StringName = _first_key(recipe.inputs)
	var guard := 0
	while guard < 12:
		path.push_front(item)
		var makers := Content.recipes_producing(item)
		if makers.is_empty() or makers[0].inputs.is_empty():
			break
		item = _first_key(makers[0].inputs)
		guard += 1
	var targets := _chain_targets()
	var tail: StringName = path[-1]
	guard = 0
	while tail not in targets and guard < 12:
		var users := Content.recipes_using(tail)
		if users.is_empty() or users[0].outputs.is_empty():
			break
		tail = _first_key(users[0].outputs)
		path.append(tail)
		guard += 1
	var names: Array[String] = []
	for id in path:
		names.append(Content.item(id).display_name.to_lower())
	return " → ".join(names)


static func _first_key(table: Dictionary) -> StringName:
	return table.keys()[0]


static func _chain_targets() -> Array[StringName]:
	var out: Array[StringName] = []
	for chain: StringName in Content.chains():
		out.append_array(Content.chains()[chain])
	return out
