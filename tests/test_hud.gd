extends TestCase
## The HUD reacts to clock, coin, weather and hotbar signals, coalesces pickup toasts and
## hides while a UIScreen is open.

var hud: HUD


func before_each() -> void:
	SaveManager.new_game()
	GameClock.start()


func _spawn() -> void:
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	tree.root.add_child.call_deferred(hud)  # the root is busy while the runner starts
	await tree.process_frame


func _despawn() -> void:
	hud.free()
	GameClock.stop()
	await tree.process_frame


func _clock() -> HudClockCard:
	return hud.get_node("Shown/TopRight/Clock")


func test_clock_card_follows_the_clock() -> void:
	await _spawn()
	eq(_clock().time_text(), "6:00", "start of day")
	GameClock.advance_minutes(10 * 8)
	eq(_clock().time_text(), GameClock.time_string(), "after ticks")
	eq(_clock().date_text(), "Mon 1 Spring", "first day")
	await _despawn()


func test_clock_card_shows_weather_and_market_marker() -> void:
	await _spawn()
	Weather.set_today(G.WeatherKind.RAIN)
	check(_clock().weather_texture() == StatusIcons.weather(G.WeatherKind.RAIN), "rain icon")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 13)
	_clock().refresh()
	eq(_clock().marker_text(), "Market day", "Saturday marker")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 20)
	_clock().refresh()
	check(_clock().marker_text().begins_with("Feast"), "feast marker")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SPRING, 14)
	_clock().refresh()
	eq(_clock().marker_text(), "", "ordinary day")
	await _despawn()


func test_purse_updates_and_flashes() -> void:
	await _spawn()
	var purse: HudPurse = hud.get_node("Shown/TopRight/Purse")
	var start := Economy.coins
	Economy.add_coins(25)
	eq(purse.amount_text(), str(start + 25), "amount after gain")
	eq(purse.flash_text(), "+25", "gain flash")
	Economy.spend(5)
	eq(purse.flash_text(), "-5", "spend flash")
	await _despawn()


func test_hotbar_highlights_the_selection_and_names_it() -> void:
	await _spawn()
	var bar: HudHotbar = hud.get_node("Shown/Bottom/Hotbar")
	Inventory.select_hotbar(3)
	check(bar.is_selected(3) and not bar.is_selected(0), "slot 3 selected")
	eq(hud.shown_item_name(), Inventory.selected_item().display_name, "item name")
	await _despawn()


func test_pickups_of_one_item_coalesce_into_one_toast() -> void:
	await _spawn()
	var toasts: Toast = hud.get_node("Toasts")
	Inventory.add(&"wheat_sheaf", 2)
	Inventory.add(&"wheat_sheaf", 1)
	Inventory.add(&"stone", 1)
	eq(hud.pending_pickups(), {&"wheat_sheaf": 3, &"stone": 1}, "merged pickups")
	hud.flush_pickups()
	eq(toasts.message_count(), 2, "one toast per item")
	eq(hud.pending_pickups().size(), 0, "pending cleared")
	await _despawn()


func test_pickups_are_silent_while_the_clock_is_stopped() -> void:
	await _spawn()
	GameClock.stop()
	Inventory.add(&"log", 1)
	eq(hud.pending_pickups().size(), 0, "no toast outside play")
	await _despawn()


func test_hud_hides_while_a_screen_is_open_and_on_demand() -> void:
	await _spawn()
	check(hud.is_hud_visible(), "visible at start")
	var screen := UIScreen.new()
	tree.root.add_child(screen)
	screen.open()
	check(not hud.is_hud_visible(), "hidden behind a screen")
	screen.close()
	check(hud.is_hud_visible(), "back after close")
	hud.set_hud_visible(false)
	check(not hud.is_hud_visible(), "hidden for a cutscene")
	hud.set_hud_visible(true)
	check(hud.is_hud_visible(), "restored")
	screen.free()
	await _despawn()
