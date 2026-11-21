extends TestCase
## Chain preview text, duration text and the crafting screen opening on a station.


func before_each() -> void:
	SaveManager.new_game()


func test_chain_preview_is_derived_from_content() -> void:
	eq(CraftingText.chain_preview(Content.recipe(&"ret_flax")),
			"flax → flax fibre → linen thread → linen cloth → linen sack", "linen chain")
	eq(CraftingText.chain_preview(Content.recipe(&"grind_flour")),
			"wheat sheaf → wheat grain → flour → loaf", "bread chain")


func test_duration_text() -> void:
	eq(CraftingText.duration(Content.recipe(&"press_cheese")), "Overnight", "overnight")
	eq(CraftingText.duration(Content.recipe(&"bake_bread")), "2 h", "two hours")
	eq(UIText.minutes(90), "1 h 30", "ninety")


func test_screen_opens_collects_and_starts_job() -> void:
	var screen: CraftingScreen = load("res://scenes/ui/crafting_screen.tscn").instantiate()
	tree.root.add_child.call_deferred(screen)
	var station := Station.create(&"quern")
	tree.root.add_child.call_deferred(station)
	await tree.process_frame
	station.output = {&"flour": 1}
	screen.open_for(station)
	check(screen.is_open, "open")
	check(not station.has_output(), "output collected on open")
	eq(Inventory.count(&"flour"), 1, "flour in pack")
	Inventory.add(&"grain", 2)
	screen._on_entry_selected(&"grind_flour")
	check(station.is_working(), "accept starts the job")
	screen.close()
	station.free()
	screen.free()
