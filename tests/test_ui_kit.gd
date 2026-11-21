extends TestCase
## Behaviour of the UI kit: ListMenu signals, UIScreen open state, toasts and glyph lookup.


func _entries() -> Array[Dictionary]:
	return [
		{"text": "One", "payload": 1},
		{"text": "Two", "payload": 2, "disabled": true},
		{"text": "Three", "payload": 3},
	]


func test_list_menu_emits_payload_on_press() -> void:
	var menu := ListMenu.new()
	tree.root.add_child(menu)
	menu.set_entries(_entries())
	var picked: Array = []
	menu.entry_selected.connect(func(payload: Variant) -> void: picked.append(payload))
	menu.entry_button(2).pressed.emit()
	eq(menu.entry_count(), 3, "entry count")
	eq(picked, [3], "selected payload")
	menu.queue_free()


func test_list_menu_focus_first_skips_disabled() -> void:
	var menu := ListMenu.new()
	tree.root.add_child(menu)
	var entries := _entries()
	entries[0]["disabled"] = true
	menu.set_entries(entries)
	menu.focus_first()
	check(menu.entry_button(2).has_focus() or menu.entry_button(1).has_focus(), "focus landed on an enabled-or-later row")
	check(not menu.entry_button(0).has_focus(), "disabled first row must not take focus")
	menu.queue_free()


func test_ui_screen_tracks_open_state() -> void:
	var screen := UIScreen.new()
	tree.root.add_child(screen)
	check(not UIScreen.any_open(tree), "closed at start")
	screen.open()
	check(UIScreen.any_open(tree), "open after open()")
	screen.close()
	check(not UIScreen.any_open(tree), "closed after close()")
	screen.queue_free()


func test_toast_is_noop_without_node_and_pushes_with_one() -> void:
	Toast.show_message(tree, "nobody listening")
	var toasts: Toast = load("res://scenes/ui/kit/toasts.tscn").instantiate()
	tree.root.add_child(toasts)
	Toast.show_message(tree, "hello")
	eq(toasts.get_node("Stack").get_child_count(), 1, "toast stacked")
	toasts.queue_free()


func test_glyphs_resolve_for_known_and_generic_actions() -> void:
	Data.ControllerConnected = false
	check(InputGlyphs.texture_for(&"action") != null, "action glyph")
	check(InputGlyphs.texture_for(&"menu") != null, "menu keyboard glyph")
	Data.ControllerConnected = true
	check(InputGlyphs.texture_for(&"menu") != null, "menu gamepad glyph")
	Data.ControllerConnected = false
	check(InputGlyphs.texture_for(&"no_such_action") == null, "unknown action gives null")
