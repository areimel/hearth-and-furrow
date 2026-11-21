class_name RiskSystem extends Node
## The two forgiving crop risks: storm-flattened grain and blight (PRD 4.9, 4.10).
## A feature root added under Level; finds the CropField through the Level.
##
## Order independence (docs/contracts.md "Day-end order"): the storm uses a snapshot of
## the crops that were ripe at dawn, so it does not matter whether FarmGrid grew crops
## first; blight is decided on the following morning (`day_passed`), after growth.
## Never both disasters on one crop, nothing in the first week, never a death spiral.

const SAVE_KEY := &"risks"

## Set to override the lookup (tests); otherwise resolved from the Level.
var crop_field: CropField

var _history: Dictionary = {}  # Vector2i -> Array[StringName], oldest first
var _exposed: Array[Vector2i] = []  # ripe, storm-sensitive cells at dawn of a stormy day
var _loss_log: Array = []  # [day, count] pairs
var _summary: String = ""
var _wired: bool = false


func _ready() -> void:
	SaveManager.register(SAVE_KEY, self)
	GameClock.day_ending.connect(_on_day_ending)
	GameClock.day_passed.connect(_on_day_passed)
	Weather.weather_changed.connect(_on_weather_changed)
	Weather.storm_warning.connect(_on_storm_warning)
	_field.call_deferred()


func _exit_tree() -> void:
	if SaveManager.is_registered(SAVE_KEY):
		SaveManager.unregister(SAVE_KEY)


## Crops lost (flattened or blighted) in the last Balance.LOSS_MEMORY_DAYS days:
## the "bad week" counter for future parish-relief quests.
func recent_losses() -> int:
	var total := 0
	for entry: Array in _loss_log:
		if int(entry[0]) > GameClock.day_index - Balance.LOSS_MEMORY_DAYS:
			total += int(entry[1])
	return total


## The crop last reaped from `cell` (rotation memory), or &"" when none.
func previous_crop(cell: Vector2i) -> StringName:
	var ids: Array = _history.get(cell, [])
	return ids.back() if not ids.is_empty() else &""


## True while no risk may strike (the first week of a new game).
func is_risk_free() -> bool:
	return GameClock.day_index < Balance.RISK_FREE_DAYS


## The reeve's advice for the almanack, depending on what is going on in the field.
func advice() -> String:
	var field := _field()
	var spotted := 0
	if field:
		for crop in field.crops():
			if crop.blight_warning or crop.blighted:
				spotted += 1
	if Weather.forecast == G.WeatherKind.STORM:
		return "A storm is coming. Reap what is ripe before it breaks."
	if spotted > 0:
		return "Hoe round the spotted plants, and sow something else on that ground next time."
	if Weather.is_wet_spell():
		return "Wet weeks breed blight. Never sow grain after grain; follow it with beans or peas."
	return "Rotate your fields: grain one year, peas or beans the next. Straw is better than nothing."


# ---------------------------------------------------------------- storm

## Dawn snapshot: which ripe, healthy, storm-sensitive crops stand in today's storm.
func _on_weather_changed(_today: int, _forecast: int) -> void:
	_exposed.clear()
	var field := _field()
	if not Weather.is_stormy() or field == null or is_risk_free():
		return
	for crop in field.crops():
		if crop.data.storm_sensitive and crop.is_ripe() and not crop.is_flattened() \
				and not crop.blighted and not crop.blight_warning:
			_exposed.append(crop.cell)


func _on_storm_warning(day: int) -> void:
	if day >= Balance.RISK_FREE_DAYS:
		_toast("The shepherd's knee aches: a storm tomorrow. Reap what is ripe.")


## Flatten some of the ripe grain that still stood in the storm (at most STORM_MAX_LOSS, floored).
func _resolve_storm() -> void:
	var field := _field()
	var by_crop: Dictionary = {}  # crop id -> [flattened, total]
	var cells: Array[Vector2i] = []
	for cell in _exposed:
		var crop := field.crop_at(cell) if field else null
		if crop and crop.is_ripe() and not crop.is_flattened():
			cells.append(cell)
			var tally: Array = by_crop.get(crop.crop_id, [0, 0])
			tally[1] += 1
			by_crop[crop.crop_id] = tally
	_exposed.clear()
	var most := floori(cells.size() * Balance.STORM_MAX_LOSS)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Weather.world_seed, GameClock.day_index, &"storm"])
	var count := rng.randi_range(ceili(most * Balance.STORM_LOSS_ROLL_MIN), most)
	_shuffle(cells, rng)
	for i in count:
		var crop := field.crop_at(cells[i])
		crop.flatten()
		by_crop[crop.crop_id][0] += 1
	if count > 0:
		_log_loss(count)
	_summary = _storm_summary(by_crop, count)


func _storm_summary(by_crop: Dictionary, flattened: int) -> String:
	if by_crop.is_empty():
		return ""
	if flattened == 0:
		return "The storm passed over; your ripe grain stood firm."
	var parts: Array[String] = []
	for id: StringName in by_crop:
		var tally: Array = by_crop[id]
		if tally[0] > 0:
			parts.append("%d of your %d %s" % [tally[0], tally[1], Content.crop(id).display_name.to_lower()])
	return "The storm flattened %s. The straw can still be reaped." % " and ".join(parts)


# ---------------------------------------------------------------- blight

## Morning: last night's spots turn to blight; a wet spell on repeated ground shows new spots.
func _resolve_blight() -> void:
	var field := _field()
	if field == null or is_risk_free():
		return
	var candidates: Array[Crop] = []
	var sensitive := 0
	var spotted := 0
	var turned := 0
	for crop in field.crops():
		if not crop.data.blight_sensitive or crop.is_flattened():
			continue
		sensitive += 1
		if crop.blight_warning:
			crop.blight_warning = false
			if not crop.is_ripe():  # reaped in time or ripened: spared
				crop.blighted = true
				turned += 1
		if crop.blighted:
			spotted += 1
		elif not crop.is_ripe() and crop.data.grows_in(Calendar.season()) \
				and previous_crop(crop.cell) == crop.crop_id:
			candidates.append(crop)
	if turned > 0:
		_log_loss(turned)
	if Weather.is_wet_spell():
		_warn_new_spots(candidates, floori(sensitive * Balance.BLIGHT_MAX_SHARE) - spotted)


func _warn_new_spots(candidates: Array[Crop], room: int) -> void:
	var first: Crop
	for crop in candidates:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([Weather.world_seed, GameClock.day_index, crop.cell, &"blight"])
		rng.randi()  # decorrelate nearby seeds
		if room > 0 and rng.randf() < Balance.BLIGHT_DAILY_CHANCE:
			crop.blight_warning = true
			crop.weeds = maxi(1, crop.weeds)  # FarmGrid lets the hoe work on weedy crops only
			room -= 1
			first = first if first else crop
	if first:
		_toast("Spots on the %s leaves. Hoe around it or reap early." % first.data.display_name.to_lower())


# ---------------------------------------------------------------- day flow

func _on_day_ending(_day: int) -> void:
	if Weather.is_stormy() and not is_risk_free():
		_resolve_storm()
	else:
		_exposed.clear()


func _on_day_passed(_day: int) -> void:
	_resolve_blight()
	if _summary != "":
		_toast(_summary)
		_summary = ""


# ---------------------------------------------------------------- helpers

func _field() -> CropField:
	if crop_field == null or not is_instance_valid(crop_field):
		var level := get_tree().get_first_node_in_group(&"Level") as Level
		if level == null:
			level = get_parent() as Level
		crop_field = level.farm_grid.crop_field if level and level.farm_grid else null
		_wired = false
	if crop_field and not _wired:
		crop_field.crop_reaped.connect(_on_crop_reaped)
		_wired = true
	return crop_field


func _on_crop_reaped(cell: Vector2i, crop_id: StringName) -> void:
	var ids: Array = _history.get(cell, [])
	ids.append(crop_id)
	while ids.size() > Balance.ROTATION_MEMORY:
		ids.pop_front()
	_history[cell] = ids


func _log_loss(count: int) -> void:
	_loss_log.append([GameClock.day_index, count])
	while _loss_log.size() > 16:
		_loss_log.pop_front()


func _toast(text: String) -> void:
	Toast.show_message(get_tree(), text)


static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


# ---------------------------------------------------------------- save

## Save section `risks`: rotation memory, bad-week log and the storm snapshot.
func to_dict() -> Dictionary:
	var history: Array = []
	for cell: Vector2i in _history:
		history.append([cell.x, cell.y, (_history[cell] as Array).duplicate()])
	var exposed: Array = _exposed.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y])
	return {"history": history, "loss_log": _loss_log.duplicate(true), "exposed": exposed, "summary": _summary}


## Restore from to_dict() output. Accepts `{}`.
func from_dict(data: Dictionary) -> void:
	reset()
	for entry: Array in data.get("history", []):
		var ids: Array = []
		for id: Variant in entry[2]:
			ids.append(StringName(id))
		_history[Vector2i(int(entry[0]), int(entry[1]))] = ids
	for entry: Array in data.get("loss_log", []):
		_loss_log.append([int(entry[0]), int(entry[1])])
	for pair: Array in data.get("exposed", []):
		_exposed.append(Vector2i(int(pair[0]), int(pair[1])))
	_summary = String(data.get("summary", ""))


## New game: forget rotation history and losses.
func reset() -> void:
	_history.clear()
	_exposed.clear()
	_loss_log.clear()
	_summary = ""
