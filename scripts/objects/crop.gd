class_name Crop extends Node2D
## One planted crop, driven by its CropData row. Crops never die: out of season, or (garden
## crops) when their tile stayed dry, they simply pause. Growth resolves once a day from
## CropField.resolve_day(). Weeds, blight and storms only reduce the yield (never below 1).

const Balance := preload("res://data/balance.gd")
## Pixel width of one growth frame in a crop sprite sheet.
const FRAME_WIDTH: int = 16
const WEED_COLOR := Color(0.28, 0.5, 0.2)
const WEED_OFFSETS: Array[Vector2] = [Vector2(-5, 3), Vector2(4, 4), Vector2(0, 5)]

## Crop row id, e.g. &"wheat" (not the seed or harvest item id).
var crop_id: StringName
var cell: Vector2i
## Growing days so far; the crop is ripe at CropData.days_to_mature.
var age: int = 0
## Weeds on the tile; each costs Balance.WEED_YIELD_PENALTY of the yield.
var weeds: int = 0
## Set by the blight system; halves the yield (Balance.BLIGHT_YIELD_FACTOR).
var blighted: bool = false:
	set(value):
		blighted = value
		_refresh()
var data: CropData
var _flattened: bool = false
var _frames: int = 1

@onready var _sprite: Sprite2D = $Sprite2D


## Place the crop on `grid_cell` under `parent`. Call before the node is used.
func setup(grid_cell: Vector2i, id: StringName, parent: Node) -> void:
	cell = grid_cell
	crop_id = id
	data = Content.crop(id)
	position = Vector2(grid_cell * Balance.TILE_SIZE) + Vector2(8, 5)
	parent.add_child(self)


func _ready() -> void:
	var texture := data.sprite
	_frames = data.sprite_frames
	if texture.get_width() % _frames != 0:  # sheet does not match the row: assume 16px frames
		_frames = maxi(1, texture.get_width() / FRAME_WIDTH)
	_sprite.texture = texture
	_sprite.hframes = _frames
	_sprite.centered = false
	_sprite.offset = Vector2(-texture.get_width() / float(_frames) / 2.0, -texture.get_height() + 6.0)
	_refresh()


## True when it can be reaped: fully grown, or flattened by a storm (salvage).
func is_ripe() -> bool:
	return _flattened or age >= data.days_to_mature


## True after flatten().
func is_flattened() -> bool:
	return _flattened


## Storm damage: the crop is lost but can still be salvaged with the sickle for
## Balance.FLATTENED_SALVAGE_ITEM instead of its yield.
func flatten() -> void:
	_flattened = true
	_refresh()


## Days of growth still needed (0 when ripe).
func days_left() -> int:
	return maxi(0, data.days_to_mature - age)


## One evening's growth. `watered`: the tile is wet. Field crops ignore water; garden
## crops need it. Pauses outside the crop's seasons and when ripe. May gain a weed.
func resolve_day(watered: bool, rng: RandomNumberGenerator) -> void:
	if is_ripe() or not data.grows_in(Calendar.season()):
		return
	if data.kind == G.CropKind.GARDEN and not watered:
		return
	age += 1
	if weeds < Balance.MAX_WEEDS and rng.randf() < Balance.WEED_DAILY_CHANCE:
		weeds += 1
	_refresh()


## Pull the weeds (hoe on the crop's cell).
func clear_weeds() -> void:
	weeds = 0
	_refresh()


## Item count a reap would give: base yield less weeds and blight, never below 1.
func yield_amount() -> int:
	var amount := floori(data.yield_amount * (1.0 - weeds * Balance.WEED_YIELD_PENALTY))
	if blighted:
		amount = ceili(amount * Balance.BLIGHT_YIELD_FACTOR)
	return maxi(1, amount)


## Reap into the Inventory (and Progress). Returns the items actually added. Does not
## free the crop: CropField.reap() decides between regrowing and removal.
func collect() -> int:
	if _flattened:
		return Loot.give(get_tree(), Balance.FLATTENED_SALVAGE_ITEM, 1, &"harvested")
	return Loot.give(get_tree(), data.yield_item, yield_amount(), &"harvested")


## Back to growing after a reap for crops that regrow (regrow_days > 0).
func regrow() -> void:
	age = maxi(0, data.days_to_mature - data.regrow_days)
	weeds = 0
	blighted = false
	_flattened = false
	_refresh()


## "Wheat - 3 days to ripe, weedy" style one-liner for the target readout.
func info_text() -> String:
	var parts: Array[String] = []
	if _flattened:
		parts.append("flattened, salvage it")
	elif is_ripe():
		parts.append("ripe")
	elif not data.grows_in(Calendar.season()):
		parts.append("resting out of season")
	else:
		parts.append("%d day%s to ripe" % [days_left(), "" if days_left() == 1 else "s"])
	if weeds > 0:
		parts.append("weedy")
	if blighted:
		parts.append("blighted")
	return "%s - %s" % [data.display_name, ", ".join(parts)]


## Save data: ids and plain values only.
func to_dict() -> Dictionary:
	return {"id": crop_id, "cell": [cell.x, cell.y], "age": age, "weeds": weeds,
			"blighted": blighted, "flattened": _flattened}


## Restore the state written by to_dict() (call after setup()).
func from_dict(saved: Dictionary) -> void:
	age = int(saved.get("age", 0))
	weeds = int(saved.get("weeds", 0))
	_flattened = bool(saved.get("flattened", false))
	blighted = bool(saved.get("blighted", false))
	_refresh()


func _draw() -> void:
	for i in mini(weeds, WEED_OFFSETS.size()):
		var at := WEED_OFFSETS[i]
		draw_line(at, at + Vector2(-1, -3), WEED_COLOR, 1.0)
		draw_line(at, at + Vector2(1, -3), WEED_COLOR, 1.0)
		draw_line(at, at + Vector2(0, -4), WEED_COLOR, 1.0)


func _refresh() -> void:
	if _sprite == null or data == null:
		return
	var t := clampf(float(age) / float(maxi(1, data.days_to_mature)), 0.0, 1.0)
	_sprite.frame = _frames - 1 if is_ripe() and not _flattened else int(t * (_frames - 1))
	_sprite.modulate = Color(0.75, 0.62, 0.45) if blighted else Color.WHITE
	_sprite.rotation = 1.2 if _flattened else 0.0
	queue_redraw()
