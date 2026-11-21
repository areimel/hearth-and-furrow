class_name QuestProbes extends RefCounted
## World probes for QuestCondition.PROBE, read from the Level's crop field:
## "sown.<crop id>" crops of that kind standing, "watered.<crop id>" those on wet soil.
## Pokes QuestManager.refresh() (deferred, after the Level applied the effect) when a crop
## appears or the player uses a tool, since sowing and watering change neither the
## Inventory nor Progress at that moment.

var _grid: FarmGrid
var _keys: Array[StringName] = []
var _poke_pending: bool = false


## Register the probes against `level` (a Level; anything else registers nothing).
func bind(level: Node) -> void:
	if not level is Level:
		return
	_grid = (level as Level).farm_grid
	for crop in Content.crops():
		_add(StringName("sown." + crop.id), _count.bind(crop.id, false))
		_add(StringName("watered." + crop.id), _count.bind(crop.id, true))
	(level as Level).crops().child_entered_tree.connect(_poke.unbind(1))
	var player := (level as Level).player
	if player and player.has_signal(&"tool_use"):
		player.tool_use.connect(_poke.unbind(3))
	QuestManager.refresh()


## Remove every probe this object registered.
func unbind() -> void:
	for key in _keys:
		QuestManager.unregister_probe(key)
	_keys.clear()


func _add(key: StringName, probe: Callable) -> void:
	QuestManager.register_probe(key, probe)
	_keys.append(key)


func _count(crop_id: StringName, watered: bool) -> int:
	if not is_instance_valid(_grid) or _grid.crop_field == null:
		return 0
	var n := 0
	for crop in _grid.crop_field.crops():
		if crop.crop_id == crop_id and (not watered or _grid.is_wet(crop.cell)):
			n += 1
	return n


func _poke() -> void:
	if _poke_pending:
		return
	_poke_pending = true
	_refresh_later.call_deferred()


func _refresh_later() -> void:
	_poke_pending = false
	QuestManager.refresh()
