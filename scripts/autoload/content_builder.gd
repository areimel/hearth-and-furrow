extends RefCounted
## Turns const rows from data/*.gd into typed resources. Used only by Content.
## Records problems (duplicate ids, bad texture paths) instead of failing.

const Balance := preload("res://data/balance.gd")
const P := preload("res://data/paths.gd")

## Paths that do not exist, outside the placeholder folder: content errors.
var bad_textures: Array[String] = []
## Placeholder paths not yet generated: expected, informational.
var pending_placeholders: Array[String] = []
var problems: Array[String] = []
var _placeholder: Texture2D


## Shared magenta 16x16 stand-in for missing art.
func placeholder() -> Texture2D:
	if _placeholder == null:
		var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 0.0, 1.0))
		_placeholder = ImageTexture.create_from_image(image)
	return _placeholder


func texture(path: String, owner_id: StringName) -> Texture2D:
	if path.is_empty():
		return placeholder()
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if path.begins_with(P.PLACEHOLDER):
		pending_placeholders.append(path)
	else:
		bad_textures.append("%s: missing texture %s" % [owner_id, path])
	return placeholder()


## Merges several ROWS tables into `into`, reporting duplicate ids.
func merge(into: Dictionary, rows: Dictionary, kind: String) -> void:
	for id: StringName in rows:
		if into.has(id):
			problems.append("duplicate %s id %s" % [kind, id])
		into[id] = rows[id]


func item(id: StringName, row: Dictionary) -> ItemData:
	var res := ItemData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.description = row.get("desc", "")
	res.category = row.get("cat", G.ItemCategory.MATERIAL)
	res.base_price = row.get("price", 0)
	res.tool_kind = row.get("tool", G.ToolKind.NONE)
	res.tool_tier = row.get("tier", &"")
	res.backpack_slots = row.get("slots", 0)
	res.tags.assign(row.get("tags", []))
	res.stack_size = Balance.TOOL_STACK_SIZE if res.is_tool() else Balance.STACK_SIZE
	res.icon_path = row.get("icon", "")
	res.icon = texture(res.icon_path, id)
	return res


func crop(id: StringName, row: Dictionary) -> CropData:
	var res := CropData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.kind = row.get("kind", G.CropKind.FIELD)
	res.seasons.assign(row.get("seasons", []))
	res.seed_item = row.get("seed", &"")
	res.yield_item = row.get("harvest", &"")
	res.yield_amount = row.get("amount", 1)
	res.days_to_mature = row.get("days", 1)
	res.regrow_days = row.get("regrow", 0)
	res.storm_sensitive = row.get("storm", false)
	res.blight_sensitive = row.get("blight", false)
	res.sprite_frames = row.get("frames", 3)
	res.sprite_path = row.get("sprite", "")
	res.sprite = texture(res.sprite_path, id)
	return res


func recipe(id: StringName, row: Dictionary) -> RecipeData:
	var res := RecipeData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.station = row.get("station", &"")
	res.inputs.assign(row.get("inputs", {}))
	res.outputs.assign(row.get("outputs", {}))
	res.minutes = row.get("minutes", 60)
	res.overnight = row.get("overnight", false)
	res.unlock_flag = row.get("unlock", &"")
	return res


func station(id: StringName, row: Dictionary) -> StationData:
	var res := StationData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.description = row.get("desc", "")
	res.build_cost.assign(row.get("cost", {}))
	res.slots = row.get("slots", 1)
	res.texture_path = row.get("texture", "")
	res.texture = texture(res.texture_path, id)
	return res


func animal(id: StringName, row: Dictionary) -> AnimalData:
	var res := AnimalData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.price = row.get("price", 0)
	res.product_item = row.get("product", &"")
	res.product_amount = row.get("amount", 1)
	res.product_days = row.get("every", 1)
	res.feed_item = row.get("feed", &"")
	res.sprite_path = row.get("sprite", "")
	res.sprite = texture(res.sprite_path, id)
	return res


func npc(id: StringName, row: Dictionary) -> NPCData:
	var res := NPCData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.role = row.get("role", "")
	res.loved_gifts.assign(row.get("loved", []))
	res.liked_gifts.assign(row.get("liked", []))
	res.disliked_gifts.assign(row.get("disliked", []))
	res.shop_stock.assign(row.get("stock", []))
	res.buys_items = row.get("buys", false)
	for entry_row: Dictionary in row.get("schedule", []):
		var entry := NPCScheduleEntry.new()
		entry.start_hour = entry_row.get("at", Balance.DAY_START_HOUR)
		entry.location = entry_row.get("loc", &"")
		entry.weekdays.assign(entry_row.get("days", []))
		entry.seasons.assign(entry_row.get("seasons", []))
		entry.rain_only = entry_row.get("rain", false)
		res.schedule.append(entry)
	res.sprite_path = row.get("sprite", "")
	res.faceset_path = row.get("faceset", "")
	res.sprite = texture(res.sprite_path, id)
	res.faceset = texture(res.faceset_path, id)
	return res


func quest(id: StringName, row: Dictionary) -> QuestData:
	var res := QuestData.new()
	res.id = id
	res.title = row.get("title", String(id))
	res.description = row.get("desc", "")
	res.giver = row.get("giver", &"")
	res.requires.assign(row.get("requires", []))
	for c: Dictionary in row.get("conditions", []):
		var cond := QuestCondition.new()
		cond.kind = c.get("kind", &"")
		cond.target = c.get("target", &"")
		cond.amount = c.get("amount", 1)
		cond.text = c.get("text", "")
		res.conditions.append(cond)
	for r: Dictionary in row.get("rewards", []):
		var reward := QuestReward.new()
		reward.kind = r.get("kind", &"")
		reward.target = r.get("target", &"")
		reward.amount = r.get("amount", 1)
		res.rewards.append(reward)
	return res


func festival(id: StringName, row: Dictionary) -> FestivalData:
	var res := FestivalData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.description = row.get("desc", "")
	res.season = row.get("season", G.Season.SPRING)
	res.day = row.get("day", 1)
	res.location = row.get("loc", &"")
	res.start_hour = row.get("start", 9)
	res.end_hour = row.get("end", 18)
	res.shops_closed = row.get("shops_closed", true)
	return res


func tool_tier(id: StringName, row: Dictionary) -> ToolTierData:
	var res := ToolTierData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.rank = row.get("rank", 1)
	res.next_tier = row.get("next", &"")
	res.upgrade_coins = row.get("coins", 0)
	res.upgrade_items.assign(row.get("items", {}))
	res.unlock_flag = row.get("unlock", &"")
	res.area = row.get("area", 1)
	res.power = row.get("power", 1.0)
	return res


func shop(id: StringName, row: Dictionary) -> ShopData:
	var res := ShopData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.keeper = row.get("keeper", &"")
	for w: Dictionary in row.get("sells", []):
		res.wares.append(_ware(id, w))
	for rule: Dictionary in row.get("buys", []):
		res.buy_rules.append({"cats": rule.get("cats", []), "tags": rule.get("tags", []),
			"ids": rule.get("ids", []), "factor": rule.get("factor", 1.0)})
	return res


# Normalises one ware row: fills defaults and works out its kind, target and unique id.
func _ware(shop_id: StringName, w: Dictionary) -> Dictionary:
	var kind := &"item"
	for k: StringName in [&"animal", &"tool_upgrade", &"station"]:
		if w.has(k):
			kind = k
	var target: Variant = w.get(kind)
	if target == null:
		problems.append("shop %s: ware without a target" % shop_id)
	var ware_id: StringName = w.get("id", StringName("%s:%s" % [kind, target]))
	return {"id": ware_id, "kind": kind, "target": target, "price": w.get("price", -1),
		"stock": w.get("stock", -1), "seasons": w.get("seasons", []),
		"sowable": w.get("sowable", false), "unlock": w.get("unlock", &""),
		"requires": w.get("requires", {}), "amount": w.get("amount", 1),
		"label": w.get("label", "")}
