extends RefCounted
## Named setup steps for tools/screenshot.gd (see its header for the command line). One
## step is "name" or "name:argument"; steps run in order and may await. The state they
## build is realistic (a lived-in pack, friendships, a date) so the screens read as in play.
## Camera steps only record `focus` / `zoom`; the harness applies them (and any --pos / --zoom).

const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const STOCK: Array[StringName] = [&"wheat_sheaf", &"barley", &"bread", &"cheese", &"log", &"stone",
	&"hazelnut", &"apple", &"flour", &"butter", &"egg", &"linen_sack", &"trout", &"clay", &"fleece", &"milk"]

var scene: Node
var tree: SceneTree
## World position the harness centres a free camera on, and its zoom (0 = leave the player camera).
var focus: Variant = null
var zoom: float = 0.0


func _init(root_scene: Node, scene_tree: SceneTree) -> void:
	scene = root_scene
	tree = scene_tree


func run(step: String) -> void:
	var parts := step.split(":")
	var arg := parts[1] if parts.size() > 1 else ""
	match parts[0]:
		"title":
			pass  # the harness loads the title scene itself
		"days":
			for i in int(arg):
				GameClock.advance_day()
		"fishing":
			var game := scene.find_child("FishingGame", true, false)
			if game:
				game.reveal()
		"rain":
			Weather.set_today(G.WeatherKind.RAIN)
		"storm":
			Weather.set_today(G.WeatherKind.STORM)
		"night":
			GameClock.advance_minutes(17 * 60)
		"noon":
			GameClock.advance_minutes(5 * 60)
		"spring", "summer", "autumn", "winter":
			GameClock.day_index = Calendar.day_index_for(1, SEASONS.find(parts[0]), 10)
		"plants":
			_plants()
		"risks":
			_risks()
		"highlight":
			_level().player.highlighter_on = true
		"menu":
			_menu(arg)
		"crafting":
			_crafting(StringName(arg))
		"shop", "shop_sell":
			_shop(StringName(arg), parts[0] == "shop_sell")
		"build":
			_stock()
			_menus().get_node("BuildMenu").open_menu()
		"dialogue":
			await _dialogue(StringName(arg))
		"festival":
			await _festival(StringName(arg))
		"yard":
			_yard()
		"herd":
			focus = _level().get_node("Livestock").pen_center()
			zoom = 1.0
		"forage":
			focus = _level().player.global_position
			zoom = 0.55
		"village":
			focus = Places.position_of(tree, &"village_green")
			zoom = 0.5
		_:
			if scene.has_method(parts[0]):
				scene.call(parts[0])
			else:
				push_warning("screenshot: unknown setup step '%s'" % step)


func _level() -> Level:
	return tree.get_first_node_in_group(&"Level") as Level


func _menus() -> Node:
	return _level().get_node("Overlay/CanvasLayer/Menus")


## A lived-in game: mid-spring afternoon, a full pack, a few friendships and a started errand.
func _stock() -> void:
	for toasts in tree.get_nodes_in_group(Toast.GROUP):  # the pickups below are set dressing, not news
		toasts.hold_time = 0.0
		toasts.fade_time = 0.01
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 13)
	GameClock.hour = 13
	Economy.coins = 247
	for id in STOCK:
		Inventory.add(id, 3 + String(id).length() % 7)
	Inventory.select_hotbar(2)
	QuestManager.start(&"prologue")
	for npc: Array in [[&"reeve", 520], [&"miller", 230], [&"alewife", 80], [&"chandler", 340], [&"blacksmith", 40], [&"shepherd", 700]]:
		Relationships.add_points(npc[0], npc[1])
		Relationships.talk(npc[0])
	Relationships.gift(&"reeve", &"bread")
	Progress.record(&"harvested", &"wheat_sheaf", 5)
	Progress.record(&"gathered", &"hazelnut", 2)


func _menu(tab_id: String) -> void:
	_stock()
	if tab_id == "journal":
		QuestManager.start(&"errand_miller_wheat")
	var menu := _menus().get_node("GameMenu") as GameMenu
	if tab_id.is_empty():
		menu.open()
	else:
		menu.open_tab(StringName(tab_id))


func _station(id: StringName) -> Station:
	var works: Workstations = _level().get_node("Workstations")
	for station in works.stations():
		if station.station_id == id:
			return station
	# Not in the starter yard: stand one beside the player, as if built.
	return works.place(id, _level().target_cell() + Vector2i(2, 0))


## The crafting screen on station `id`, ingredients in the pack and the first recipe cooking.
func _crafting(id: StringName) -> void:
	_stock()
	var station := _station(id)
	var recipes := Content.recipes_for_station(id)
	for recipe in recipes:
		for item in recipe.inputs:
			Inventory.add(item, recipe.inputs[item] * 2)
	if not recipes.is_empty():
		station.start_job(recipes[0].id)
	_menus().get_node("CraftingScreen").open_for(station)


func _shop(id: StringName, sell: bool) -> void:
	_stock()
	Economy.coins = 350
	Inventory.add(&"cheese", 3)
	_level().get_node("Shops").open(id)
	if sell:
		(tree.get_first_node_in_group(&"ShopScreen") as ShopScreen).show_tab(ShopScreen.Tab.SELL)


func _dialogue(npc_id: StringName) -> void:
	_stock()
	(_level().get_node("Villagers") as Villagers).npc(npc_id)._talk.talk()
	await tree.create_timer(2.5).timeout
	var press := InputEventAction.new()  # skip the typewriter so the choices show
	press.action = &"action"
	press.pressed = true
	Input.parse_input_event(press)


## The feast table screen on feast day `id`, with a few contributions made.
func _festival(id: StringName) -> void:
	var feast := Content.festival(id)
	var director: FestivalDirector = _level().get_node("FestivalDirector")
	_stock()
	GameClock.day_index = Calendar.day_index_for(1, feast.season, feast.day)
	GameClock.hour = feast.start_hour + 2
	director.sync()
	for ask in feast.asks:
		Inventory.add(ask.ids()[0], ask.amount)
	director.contribute(0)
	director.open_table()
	await tree.process_frame


func _yard() -> void:
	var cells: Array[Vector2i] = []
	for station in (_level().get_node("Workstations") as Workstations).stations():
		cells.append(station.coord)
		station.output = {&"bread": 2}
		station.call("_update_visuals")
	focus = Vector2(cells[cells.size() / 2] * 16) + Vector2(8, 8)
	zoom = 1.0


func _plants() -> void:
	var grid := _level().farm_grid
	for i in 6:
		var cell := Vector2i(9 + i, -8)
		grid.till(cell)
		grid.crop_field.sow(cell, Content.crops()[i].id)


## Ripe wheat in five conditions: normal, flattened, blight warning, blighted, weedy.
func _risks() -> void:
	var grid := _level().farm_grid
	for i in 5:
		var cell := Vector2i(11 + i, -6)
		grid.till(cell)
		var crop := grid.crop_field.sow(cell, &"wheat")
		crop.age = crop.data.days_to_mature
		match i:
			1:
				crop.flatten()
			2:
				crop.blight_warning = true
			3:
				crop.blighted = true
			4:
				crop.weeds = 2
		crop.call("_refresh")
