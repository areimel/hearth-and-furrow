extends Node
## Throwaway demo for screenshots: the level with the HUD and pause menu instanced the
## way the integrator will. Use with the harness, e.g.
##   godot --path . res://tools/screenshot.tscn -- --scene res://tools/hud_demo.tscn \
##       --setup hud --size 1280x720 --name hud
## Setup steps: hud, hud_feast, pack, journal, folk, almanack, encyclopedia, settings.
## Steps ending in _large switch to Large text first (not saved).

var _level: Level
var _hud: HUD
var _menu: GameMenu


func _ready() -> void:
	SaveManager.new_game()
	_populate()
	_level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(_level)
	var layer := _level.get_node("Overlay/CanvasLayer")
	for legacy in ["KeyboardControlHintUI", "Inventory"]:
		layer.get_node(legacy).hide()
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	layer.get_node("HUD").add_child(_hud)
	_menu = load("res://scenes/ui/game_menu.tscn").instantiate()
	layer.get_node("Menus").add_child(_menu)


func _populate() -> void:
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 13)
	GameClock.hour = 13
	GameClock.minute = 40
	Weather.set_today(G.WeatherKind.RAIN)
	Weather.set_forecast(G.WeatherKind.CLEAR)
	Economy.coins = 247
	for id in [&"wheat_sheaf", &"barley", &"bread", &"cheese", &"log", &"stone", &"hazelnut",
			&"apple", &"flour", &"butter", &"egg", &"linen_sack", &"trout", &"clay"]:
		Inventory.add(id, 3 + id.length() % 7)
	Inventory.select_hotbar(2)
	QuestManager.start(&"prologue")
	Relationships.add_points(&"reeve", 520)
	Relationships.talk(&"reeve")
	Relationships.add_points(&"miller", 230)
	Relationships.add_points(&"alewife", 80)
	Relationships.add_points(&"chandler", 340)
	Relationships.add_points(&"blacksmith", 40)
	Relationships.add_points(&"shepherd", 700)
	Relationships.gift(&"reeve", &"bread")
	for npc in [&"chandler", &"miller", &"shepherd"]:
		Relationships.talk(npc)
	Progress.record(&"harvested", &"wheat_sheaf", 5)
	Progress.record(&"gathered", &"hazelnut", 2)


## HUD over the farm in the rain with a prompt and a few toasts.
func hud() -> void:
	GameClock.running = true
	_hud.show_prompt(&"action", "Talk")
	_hud.push_toast("+3 Wheat sheaf", Content.item(&"wheat_sheaf").icon)
	_hud.push_toast("+1 Hazelnut", Content.item(&"hazelnut").icon)
	Economy.add_coins(12)
	Inventory.select_hotbar(3)


## A feast day: marker line on the clock card.
func hud_feast() -> void:
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 20)
	Calendar.begin_day(GameClock.day_index)
	Weather.set_today(G.WeatherKind.CLEAR)
	_hud.get_node("Shown/TopRight/Clock").refresh()


## Pause menu tabs.
func pack() -> void:
	_menu.open_tab(&"pack")


func journal() -> void:
	QuestManager.start(&"errand_miller_wheat")
	Inventory.add(&"wheat_sheaf", 3)
	_menu.open_tab(&"journal")


func folk() -> void:
	_menu.open_tab(&"folk")


func almanack() -> void:
	_menu.open_tab(&"almanack")


func encyclopedia() -> void:
	_menu.open_tab(&"almanack")
	_menu.current_tab().show_page(1)


func settings() -> void:
	_menu.open_tab(&"settings")


func pack_large() -> void:
	_large()
	pack()


func folk_large() -> void:
	_large()
	folk()


func almanack_large() -> void:
	_large()
	almanack()


func settings_large() -> void:
	_large()
	settings()


func _large() -> void:
	var settings_node := GameSettings.instance(get_tree())
	settings_node.autosave = false
	settings_node.set_value(&"text_size", "large")
