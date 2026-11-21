extends Node
## Autoload `Content`: read-only registry of all game content, built once from the
## const tables in res://data/. Lookups of unknown ids push_error once per id and
## return null; they never crash. Never mutate returned resources.

const Builder := preload("res://scripts/autoload/content_builder.gd")
const Validator := preload("res://scripts/autoload/content_validator.gd")
const ItemsTools := preload("res://data/items_tools.gd")
const ItemsGoods := preload("res://data/items_goods.gd")
const Crops := preload("res://data/crops.gd")
const Recipes := preload("res://data/recipes.gd")
const Stations := preload("res://data/stations.gd")
const Animals := preload("res://data/animals.gd")
const Npcs := preload("res://data/npcs.gd")
const Quests := preload("res://data/quests.gd")
const Festivals := preload("res://data/festivals.gd")
const ToolTiers := preload("res://data/tool_tiers.gd")
const Shops := preload("res://data/shops.gd")

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}
var _recipes: Dictionary[StringName, RecipeData] = {}
var _stations: Dictionary[StringName, StationData] = {}
var _animals: Dictionary[StringName, AnimalData] = {}
var _npcs: Dictionary[StringName, NPCData] = {}
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
	_ensure_built()
	var out: Array[ItemData] = []
	out.assign(_items.values())
	return out


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
	_ensure_built()
	var out: Array[CropData] = []
	out.assign(_crops.values())
	return out


## Crop sown by a seed item, or null (quietly) if the item is not a seed.
func crop_for_seed(item_id: StringName) -> CropData:
	_ensure_built()
	return _crop_by_seed.get(item_id)


# --- Recipes and stations ---

func recipe(id: StringName) -> RecipeData:
	return _lookup(_recipes, id, "recipe") as RecipeData


func recipes() -> Array[RecipeData]:
	_ensure_built()
	var out: Array[RecipeData] = []
	out.assign(_recipes.values())
	return out


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
	_ensure_built()
	var out: Array[StationData] = []
	out.assign(_stations.values())
	return out


# --- Animals, villagers, quests, festivals, tool tiers ---

func animal(id: StringName) -> AnimalData:
	return _lookup(_animals, id, "animal") as AnimalData


func has_animal(id: StringName) -> bool:
	_ensure_built()
	return _animals.has(id)


func animals() -> Array[AnimalData]:
	_ensure_built()
	var out: Array[AnimalData] = []
	out.assign(_animals.values())
	return out


func npc(id: StringName) -> NPCData:
	return _lookup(_npcs, id, "npc") as NPCData


func npcs() -> Array[NPCData]:
	_ensure_built()
	var out: Array[NPCData] = []
	out.assign(_npcs.values())
	return out


func quest(id: StringName) -> QuestData:
	return _lookup(_quests, id, "quest") as QuestData


func quests() -> Array[QuestData]:
	_ensure_built()
	var out: Array[QuestData] = []
	out.assign(_quests.values())
	return out


func festival(id: StringName) -> FestivalData:
	return _lookup(_festivals, id, "festival") as FestivalData


func festivals() -> Array[FestivalData]:
	_ensure_built()
	var out: Array[FestivalData] = []
	out.assign(_festivals.values())
	return out


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
	_ensure_built()
	var out: Array[ToolTierData] = []
	out.assign(_tool_tiers.values())
	out.sort_custom(func(a: ToolTierData, b: ToolTierData) -> bool: return a.rank < b.rank)
	return out


func shop(id: StringName) -> ShopData:
	return _lookup(_shops, id, "shop") as ShopData


func shops() -> Array[ShopData]:
	_ensure_built()
	return Array(_shops.values(), TYPE_OBJECT, &"Resource", ShopData)


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


func placeholder_texture() -> Texture2D:
	_ensure_built()
	return _builder.placeholder()


# --- Internals ---

func _ensure_built() -> void:
	if _builder != null:
		return
	_builder = Builder.new()
	var item_rows: Dictionary = {}
	_builder.merge(item_rows, ItemsTools.ROWS, "item")
	_builder.merge(item_rows, ItemsGoods.ROWS, "item")
	for id: StringName in item_rows:
		_items[id] = _builder.item(id, item_rows[id])
	for id: StringName in Crops.ROWS:
		_crops[id] = _builder.crop(id, Crops.ROWS[id])
		_crop_by_seed[_crops[id].seed_item] = _crops[id]
	for id: StringName in Recipes.ROWS:
		_recipes[id] = _builder.recipe(id, Recipes.ROWS[id])
	for id: StringName in Stations.ROWS:
		_stations[id] = _builder.station(id, Stations.ROWS[id])
	for id: StringName in Animals.ROWS:
		_animals[id] = _builder.animal(id, Animals.ROWS[id])
	for id: StringName in Npcs.ROWS:
		_npcs[id] = _builder.npc(id, Npcs.ROWS[id])
	for id: StringName in Quests.ROWS:
		_quests[id] = _builder.quest(id, Quests.ROWS[id])
	for id: StringName in Festivals.ROWS:
		_festivals[id] = _builder.festival(id, Festivals.ROWS[id])
	for id: StringName in ToolTiers.ROWS:
		_tool_tiers[id] = _builder.tool_tier(id, ToolTiers.ROWS[id])
	for id: StringName in Shops.ROWS:
		_shops[id] = _builder.shop(id, Shops.ROWS[id])


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
