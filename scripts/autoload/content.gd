extends Node
## Autoload `Content`: read-only registry of all game content, built once from the
## const tables in res://data/. Lookups of unknown ids push_error once per id and
## return null; they never crash. Never mutate returned resources.

const Builder := preload("res://scripts/autoload/content_builder.gd")
const Validator := preload("res://scripts/autoload/content_validator.gd")
const Recipes := preload("res://data/recipes.gd")
const Gatherables := preload("res://data/gatherables.gd")
const ToolTiers := preload("res://data/tool_tiers.gd")

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}
var _recipes: Dictionary[StringName, RecipeData] = {}
var _stations: Dictionary[StringName, StationData] = {}
var _animals: Dictionary[StringName, AnimalData] = {}
var _gatherables: Dictionary[StringName, GatherableData] = {}
var _npcs:Dictionary[StringName, NPCData] = {}
var _quests: Dictionary[StringName, QuestData] = {}
var _festivals: Dictionary[StringName, FestivalData] = {}
var _tool_tiers: Dictionary[StringName, ToolTierData] = {}
var _shops: Dictionary[StringName, ShopData] = {}
var _crop_by_seed: Dictionary[StringName, CropData] = {}
var _builder: Builder
var _warned: Dictionary[String, bool] = {}


func _ready() -> void:
	_ensure_built()


# --- Items ---

func item(id: StringName) -> ItemData:
	return _lookup(_items, id, "item") as ItemData


func has_item(id: StringName) -> bool:
	_ensure_built()
	return _items.has(id)


func items() -> Array[ItemData]:
	return _list(_items, ItemData)


func items_with_tag(tag: StringName) -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.assign(items().filter(func(i: ItemData) -> bool: return tag in i.tags))
	return out


func items_in_category(category: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.assign(items().filter(func(i: ItemData) -> bool: return i.category == category))
	return out


## Tool item for a G.ToolKind at a tier id, e.g. tool_item(G.ToolKind.AXE, &"wooden").
func tool_item(kind: int, tier: StringName) -> ItemData:
	_ensure_built()
	for i: ItemData in _items.values():
		if i.tool_kind == kind and i.tool_tier == tier:
			return i
	_warn_once("tool %s/%s" % [kind, tier])
	return null


# --- Crops ---

func crop(id: StringName) -> CropData:
	return _lookup(_crops, id, "crop") as CropData


func crops() -> Array[CropData]:
	return _list(_crops, CropData)


## Crop sown by a seed item, or null (quietly) if the item is not a seed.
func crop_for_seed(item_id: StringName) -> CropData:
	_ensure_built()
	return _crop_by_seed.get(item_id)


# --- Recipes and stations ---

func recipe(id: StringName) -> RecipeData:
	return _lookup(_recipes, id, "recipe") as RecipeData


func recipes() -> Array[RecipeData]:
	return _list(_recipes, RecipeData)


func recipes_for_station(station_id: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	out.assign(recipes().filter(func(r: RecipeData) -> bool: return r.station == station_id))
	return out


func recipes_producing(item_id: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	out.assign(recipes().filter(func(r: RecipeData) -> bool: return r.outputs.has(item_id)))
	return out


func recipes_using(item_id: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	out.assign(recipes().filter(func(r: RecipeData) -> bool: return r.inputs.has(item_id)))
	return out


func station(id: StringName) -> StationData:
	return _lookup(_stations, id, "station") as StationData


func stations() -> Array[StationData]:
	return _list(_stations, StationData)


# --- Animals, villagers, quests, festivals, tool tiers ---

func animal(id: StringName) -> AnimalData:
	return _lookup(_animals, id, "animal") as AnimalData


func has_animal(id: StringName) -> bool:
	_ensure_built()
	return _animals.has(id)


func animals() -> Array[AnimalData]:
	return _list(_animals, AnimalData)


func gatherable(id: StringName) -> GatherableData:
	return _lookup(_gatherables, id, "gatherable") as GatherableData


func has_gatherable(id: StringName) -> bool:
	_ensure_built()
	return _gatherables.has(id)


func gatherables() -> Array[GatherableData]:
	return _list(_gatherables, GatherableData)


func npc(id: StringName) -> NPCData:
	return _lookup(_npcs, id, "npc") as NPCData


func npcs() -> Array[NPCData]:
	return _list(_npcs, NPCData)


func quest(id: StringName) -> QuestData:
	return _lookup(_quests, id, "quest") as QuestData


func quests() -> Array[QuestData]:
	return _list(_quests, QuestData)


func festival(id: StringName) -> FestivalData:
	return _lookup(_festivals, id, "festival") as FestivalData


func festivals() -> Array[FestivalData]:
	return _list(_festivals, FestivalData)


## Festival on a G.Season + day of season (1-based), or null (quietly).
func festival_on(season: int, day: int) -> FestivalData:
	for f: FestivalData in festivals():
		if f.season == season and f.day == day:
			return f
	return null


func tool_tier(id: StringName) -> ToolTierData:
	return _lookup(_tool_tiers, id, "tool tier") as ToolTierData


## All tiers, lowest rank first.
func tool_tiers() -> Array[ToolTierData]:
	var out := _list(_tool_tiers, ToolTierData)
	out.sort_custom(func(a: ToolTierData, b: ToolTierData) -> bool: return a.rank < b.rank)
	return out


func shop(id: StringName) -> ShopData:
	return _lookup(_shops, id, "shop") as ShopData


func shops() -> Array[ShopData]:
	return _list(_shops, ShopData)


# --- Diagnostics ---

## Every content problem found (broken id references, unreachable chains, bad texture
## paths). Empty means the tables are consistent. Placeholders not yet generated are
## not problems; see pending_placeholders().
func validate() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	out.append_array(_builder.problems)
	out.append_array(_builder.bad_textures)
	out.append_array(Validator.new().run(self))
	return out


## res://graphics/placeholder/ paths that rows point at but that do not exist yet.
func pending_placeholders() -> Array[String]:
	_ensure_built()
	return _builder.pending_placeholders.duplicate()


## Chain id -> target item ids, from data/recipes.gd.
func chains() -> Dictionary:
	return Recipes.CHAINS


## Tool kinds that must exist in every tier, from data/tool_tiers.gd.
func tool_kinds() -> Array[int]:
	return ToolTiers.TOOL_KINDS


# --- Internals ---

func _ensure_built() -> void:
	if _builder != null:
		return
	_builder = Builder.new()
	var tables := _builder.build_all()
	_items.assign(tables[&"items"])
	_crops.assign(tables[&"crops"])
	_recipes.assign(tables[&"recipes"])
	_stations.assign(tables[&"stations"])
	_animals.assign(tables[&"animals"])
	_gatherables.assign(tables[&"gatherables"])
	_npcs.assign(tables[&"npcs"])
	_quests.assign(tables[&"quests"])
	_festivals.assign(tables[&"festivals"])
	_tool_tiers.assign(tables[&"tool_tiers"])
	_shops.assign(tables[&"shops"])
	for crop_row: CropData in _crops.values():
		_crop_by_seed[crop_row.seed_item] = crop_row


## The values of a built table as a typed array of `type` (the one place lists are made).
func _list(table: Dictionary, type: Script) -> Array:
	_ensure_built()
	return Array(table.values(), TYPE_OBJECT, &"Resource", type)


func _lookup(table: Dictionary, id: StringName, kind: String) -> Resource:
	_ensure_built()
	if table.has(id):
		return table[id]
	_warn_once("%s %s" % [kind, id])
	return null


func _warn_once(what: String) -> void:
	if not _warned.has(what):
		_warned[what] = true
		push_error("Content: unknown %s" % what)
