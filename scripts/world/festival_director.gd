class_name FestivalDirector extends Node
## Feature root for feasts. Add scenes/world/festival_director.tscn under the Level (one
## line); it sets itself up deferred. Generic over data/festivals.gd rows:
## - the day before: reminder toast, and the host villager has an "any news?" option;
## - the morning of: announcement toast (and `announced` for any HUD banner);
## - start hour: villagers gather (Villagers.gather_at), a feast table appears at the
##   feast location; it opens the FestivalScreen to see the asks and contribute;
##   every villager offers a feast greeting option;
## - end hour or sleep: the feast resolves (highest tier reached pays out if the player
##   came), villagers are released, the host says the closing lines.
## Saves the FestivalLedger under `festivals`. Missing a feast costs nothing.

signal announced(text: String)
signal feast_started(festival_id: StringName)
signal contributed(festival_id: StringName, ask_index: int, amount: int)
## `tier` is the RewardTier index paid, or -1 when nothing was paid.
signal feast_resolved(festival_id: StringName, tier: int)

const TABLE_SCENE := preload("res://scenes/world/feast_table.tscn")
const SCREEN_SCENE := preload("res://scenes/ui/festival_screen.tscn")
const SAVE_KEY := &"festivals"
const TABLE_OFFSET := Vector2(0, 20)

## Villagers feature root; found by name when left empty (tests may set a stand-in).
var villagers: Node
var ledger := FestivalLedger.new()
var speaker := QuestSpeaker.new()
## Feast dialogue options and lines.
var talk := FestivalTalk.new(self)
var _running: FestivalData
var _table: Node2D
var _bound: bool = false


func _ready() -> void:
	SaveManager.register(SAVE_KEY, self)
	GameClock.day_passed.connect(_on_day_passed)
	GameClock.hour_passed.connect(_on_hour_passed)
	GameClock.day_ending.connect(_on_day_ending)
	SaveManager.loaded.connect(_on_loaded)
	bind.call_deferred()


func _exit_tree() -> void:
	if SaveManager.is_registered(SAVE_KEY):
		SaveManager.unregister(SAVE_KEY)


func _process(_delta: float) -> void:
	speaker.flush(get_tree())


## Find the Villagers, register feast options and catch up with the clock. Runs once,
## deferred from _ready (tests may call it directly).
func bind() -> void:
	if _bound or not is_inside_tree():
		return
	_bound = true
	if villagers == null:
		villagers = QuestSpeaker.find_villagers(get_tree())
	speaker.villagers = villagers
	talk.register(villagers)
	sync()


# ---------------------------------------------------------------- queries

## Feast held today, or null.
func today() -> FestivalData:
	return Calendar.festival_today()


## Feast held tomorrow, or null.
func tomorrow() -> FestivalData:
	return Calendar.festival_today(GameClock.day_index + 1)


## The feast currently gathered, or null.
func running() -> FestivalData:
	return _running


## Items given to ask `ask_index` of `festival` this year.
func given(festival: FestivalData, ask_index: int) -> int:
	return ledger.given(festival.id, Calendar.year(), ask_index)


## Items given to `festival` this year.
func total_given(festival: FestivalData) -> int:
	return ledger.total(festival.id, Calendar.year())


## Inventory items that `ask` would accept right now.
func can_give(festival: FestivalData, ask_index: int) -> int:
	var ask := festival.asks[ask_index]
	var have := 0
	for id in ask.ids():
		have += Inventory.count(id)
	return mini(have, ask.amount - given(festival, ask_index))


## Villager ids at the feast (everyone gathered).
func present() -> Array[StringName]:
	var out: Array[StringName] = []
	if villagers != null and villagers.has_method(&"all"):
		for villager: Node in villagers.call(&"all"):
			out.append(villager.get(&"npc_id"))
	if out.is_empty():
		for npc in Content.npcs():
			out.append(npc.id)
	return out


## A thanks line from someone present, e.g. "Margery Brewster: Well gathered!".
func reaction(festival: FestivalData, salt: int = 0) -> String:
	return talk.reaction(festival.id, present(), salt)


# ---------------------------------------------------------------- actions

## Bring the state in line with the clock: begin, resolve or wind down a feast.
func sync() -> void:
	var feast := today()
	if feast == null or ledger.is_resolved(feast.id, Calendar.year()):
		_end_gathering()
	elif feast.is_running_at(GameClock.hour):
		begin(feast)
	elif GameClock.hour >= feast.end_hour:
		resolve(_running == null)


## Gather the villagers and set out the feast table. No-op if already running.
func begin(feast: FestivalData) -> void:
	if _running == feast:
		return
	_end_gathering()
	_running = feast
	if villagers != null:
		var place := feast.gather_place
		if not Places.has(get_tree(), place):
			place = feast.location
		villagers.gather_at(place, feast.spot_prefix)
	_spawn_table(feast)
	feast_started.emit(feast.id)


## Give what the inventory has towards ask `ask_index` of the running feast, up to what
## is still wanted. Returns the number of items given.
func contribute(ask_index: int) -> int:
	if _running == null or ask_index < 0 or ask_index >= _running.asks.size():
		return 0
	var year := Calendar.year()
	var ask := _running.asks[ask_index]
	var wanted := ask.amount - given(_running, ask_index)
	var taken := 0
	for id in ask.ids():
		var n := mini(Inventory.count(id), wanted - taken)
		if n > 0 and Inventory.remove(id, n):
			taken += n
	if taken > 0:
		ledger.add(_running.id, year, ask_index, taken)
		ledger.mark_attended(_running.id, year)
		contributed.emit(_running.id, ask_index, taken)
	return taken


## contribute() for every ask. Returns the items given.
func contribute_all() -> int:
	var taken := 0
	if _running != null:
		for i in _running.asks.size():
			taken += contribute(i)
	return taken


## The player came to the running feast (talked to the table or a villager there).
func mark_attended() -> void:
	if _running != null:
		ledger.mark_attended(_running.id, Calendar.year())


## End today's feast: pay the highest tier reached (if the player came), release the
## villagers, and (unless `quiet`) have the host say the closing lines. Returns the tier
## index paid or -1. Pays at most once per feast per year.
func resolve(quiet: bool = false) -> int:
	var feast := _running if _running != null else today()
	var year := Calendar.year()
	if feast == null or ledger.is_resolved(feast.id, year):
		return -1
	var tier := -1
	if ledger.attended(feast.id, year):
		tier = feast.tier_index(ledger.total(feast.id, year))
	var people := present()
	if tier >= 0:
		for reward in feast.tiers[tier].rewards:
			QuestManager.grant(reward, people)
	ledger.mark_resolved(feast.id, year, tier)
	_end_gathering()
	if tier >= 0:
		Toast.show_message(get_tree(), "%s: %s" % [feast.display_name, feast.tiers[tier].text])
	if not quiet:
		speaker.say_later(FestivalTalk.host(feast.id), FestivalTalk.lines(feast.id, "closing"))
	feast_resolved.emit(feast.id, tier)
	return tier


## Open the FestivalScreen on the running feast.
func open_table() -> void:
	if _running == null:
		return
	mark_attended()
	var screen := get_tree().get_first_node_in_group(FestivalScreen.SCREEN_GROUP) as FestivalScreen
	if screen == null:
		screen = SCREEN_SCENE.instantiate()
		_screen_parent().add_child(screen)
	screen.open_for(self, _running)


# ---------------------------------------------------------------- world

func _spawn_table(feast: FestivalData) -> void:
	var level := get_tree().get_first_node_in_group(&"Level") as Level
	var where := Places.position_of(get_tree(), feast.location) if Places.has(get_tree(), feast.location) \
			else (level.player.global_position + TABLE_OFFSET if level else Vector2.ZERO)
	_table = TABLE_SCENE.instantiate()
	var parent: Node = level.stations() if level else self
	parent.add_child(_table)
	_table.global_position = where
	(_table.get_node(^"Interactable") as Interactable).interacted.connect(
			func(_player: Node) -> void: open_table())


func _end_gathering() -> void:
	if _running != null and villagers != null:
		villagers.release()
	_running = null
	if is_instance_valid(_table):
		_table.queue_free()
	_table = null


## The level's Menus node, else the first CanvasLayer, else this node.
func _screen_parent() -> Node:
	var menus := get_tree().root.find_child("Menus", true, false)
	if menus != null:
		return menus
	var layers := get_tree().root.find_children("*", "CanvasLayer", true, false)
	return layers[0] if not layers.is_empty() else self


# ---------------------------------------------------------------- events

func _on_day_passed(_day: int) -> void:
	var feast := today()
	var next := tomorrow()
	for text: String in [feast.announce if feast else "", next.reminder if next else ""]:
		if not text.is_empty():
			Toast.show_message(get_tree(), text)
			announced.emit(text)
	sync()


func _on_hour_passed(_hour: int) -> void:
	sync()


## Sleeping (or passing out) ends today's feast; quietly, since the screen is dark.
func _on_day_ending(_day: int) -> void:
	if today() != null:
		resolve(true)


func _on_loaded(_path: String) -> void:
	_end_gathering()
	sync()


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return ledger.to_dict()


func from_dict(data: Dictionary) -> void:
	ledger.from_dict(data)


func reset() -> void:
	ledger.reset()
	speaker.clear()
	_end_gathering()
