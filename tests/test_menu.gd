extends TestCase
## The pause menu shell: opening, clock pause, tab switching, and every tab building
## from a fresh game and from a populated one.

var menu: GameMenu


func before_each() -> void:
	SaveManager.new_game()
	GameClock.set_paused(false)


func _spawn() -> void:
	menu = load("res://scenes/ui/game_menu.tscn").instantiate()
	tree.root.add_child.call_deferred(menu)
	await tree.process_frame


func _despawn() -> void:
	menu.free()
	await tree.process_frame


func _populate() -> void:
	for id in [&"wheat_sheaf", &"barley", &"bread", &"linen_sack", &"trout"]:
		Inventory.add(id, 4)
	QuestManager.start(&"prologue")
	Relationships.talk(&"reeve")
	Relationships.add_points(&"miller", 300)
	Progress.record(&"harvested", &"wheat_sheaf", 3)


func _slot_of(id: StringName) -> int:
	for i in Inventory.size():
		if Inventory.slot_id(i) == id:
			return i
	return -1


func test_opens_and_closes_and_pauses_the_clock() -> void:
	await _spawn()
	menu.open()
	check(menu.is_open, "open")
	check(GameClock.paused, "clock paused while open")
	menu.close()
	check(not menu.is_open and not GameClock.paused, "closed and running")
	await _despawn()


func test_clock_is_never_left_paused() -> void:
	await _spawn()
	menu.open()
	menu.free()  # removed while open, as a scene change would
	await tree.process_frame
	check(not GameClock.paused, "released on removal")


func test_does_not_unpause_a_clock_it_did_not_pause() -> void:
	await _spawn()
	GameClock.set_paused(true)
	menu.open()
	menu.close()
	check(GameClock.paused, "someone else's pause survives")
	GameClock.set_paused(false)
	await _despawn()


func test_tab_switching_wraps() -> void:
	await _spawn()
	menu.open()
	eq(menu.current_index(), 0, "starts on pack")
	menu.switch_tab(-1)
	eq(menu.current_index(), GameMenu.TABS.size() - 1, "back wraps to the last")
	menu.switch_tab(1)
	eq(menu.current_index(), 0, "forward wraps to the first")
	menu.close()
	await _despawn()


func test_open_tab_by_id_and_unknown_id() -> void:
	await _spawn()
	menu.open_tab(&"folk")
	check(menu.is_open, "opened")
	eq(menu.current_tab().tab_title(), "Folk", "folk tab shown")
	menu.open_tab(&"nonsense")
	eq(menu.current_tab().tab_title(), "Folk", "unknown id ignored")
	menu.close()
	await _despawn()


func test_every_tab_builds_from_a_fresh_game_and_a_populated_one() -> void:
	await _spawn()
	menu.open()
	for id in menu.tab_ids():
		menu.open_tab(id)
		check(menu.current_tab().tab_title() != "", "%s has a title" % id)
	_populate()
	for id in menu.tab_ids():
		menu.open_tab(id)
		await tree.process_frame
	menu.close()
	await _despawn()


func test_signals_from_settings_tab_are_forwarded() -> void:
	await _spawn()
	var got: Array[StringName] = []
	menu.save_and_quit_requested.connect(func() -> void: got.append(&"save"))
	menu.quit_requested.connect(func() -> void: got.append(&"quit"))
	var tab: SettingsTab = menu.tab(&"settings")
	tab.save_and_quit_requested.emit()
	tab.quit_requested.emit()
	eq(got, [&"save", &"quit"], "forwarded")
	await _despawn()


func test_pack_move_merge_and_split_through_the_tab() -> void:
	await _spawn()
	_populate()
	var tab: PackTab = menu.tab(&"pack")
	tab.on_shown()
	Inventory.add(&"stone", 6)
	var from := _slot_of(&"stone")
	var to := Inventory.size() - 1
	check(Inventory.is_slot_empty(to), "target slot empty")
	tab.activate_slot(from)
	eq(tab.held_index(), from, "picked up")
	tab.activate_slot(to)
	eq(tab.held_index(), -1, "put down")
	eq(Inventory.slot_id(to), &"stone", "moved")
	var made := tab.split_slot(to)
	check(made >= 0, "split made a stack")
	eq(Inventory.count(&"stone"), 6, "nothing lost")
	eq(Inventory.slot_count(to) + Inventory.slot_count(made), 6, "halves")
	await _despawn()


func test_pack_uses_a_linen_sack_on_second_accept() -> void:
	await _spawn()
	Inventory.add(&"linen_sack", 1)
	var tab: PackTab = menu.tab(&"pack")
	tab.on_shown()
	var before := Inventory.size()
	var at := _slot_of(&"linen_sack")
	tab.activate_slot(at)
	tab.activate_slot(at)
	eq(Inventory.size(), before + 6, "backpack grew")
	await _despawn()


func _set_prologue_probes(sown: int, watered: int) -> void:
	QuestManager.register_probe(&"sown.wheat", func() -> int: return sown)
	QuestManager.register_probe(&"watered.cabbage", func() -> int: return watered)


func test_journal_shows_only_the_prologue_steps_reached() -> void:
	await _spawn()
	_set_prologue_probes(0, 0)
	QuestManager.start(&"prologue")
	var tab: JournalTab = menu.tab(&"journal")
	tab.on_shown()
	eq(tab.listed_quests(), [&"prologue"], "active quest listed")
	var lines := QuestText.objectives(&"prologue")
	eq(lines.size(), 1, "only the first step is shown")
	eq(lines[0]["done"], false, "not done yet")
	check(tab.body_text().contains("A Holding of One's Own"), "title shown")
	check(tab.body_text().contains("Thomas Ashby"), "giver shown")
	_set_prologue_probes(4, 1)
	QuestManager.refresh()
	tab.on_shown()
	lines = QuestText.objectives(&"prologue")
	eq(lines.size(), 3, "two steps done and the sleep step live")
	eq([lines[0]["done"], lines[1]["done"], lines[2]["done"]], [true, true, false], "ticks")
	eq(lines[0]["progress"], "4/4", "counted steps show progress")
	check(tab.body_text().contains("Reward: 50 coins"), "reward preview")
	_set_prologue_probes(0, 0)
	await _despawn()


func test_journal_marks_a_quest_ready_to_hand_in() -> void:
	await _spawn()
	QuestManager.from_dict({"states": {"prologue": G.QuestState.COMPLETE}})
	QuestManager.start(&"errand_miller_wheat")
	var tab: JournalTab = menu.tab(&"journal")
	tab.on_shown()
	check(not tab.body_text().contains("Ready to hand in"), "not ready without the loaf")
	Inventory.add(&"bread", 1)
	tab.on_shown()
	check(tab.body_text().contains("Ready to hand in - see Ned Miller"), "ready marker names the giver")
	await _despawn()


func test_journal_folds_completed_quests_and_shows_the_favour() -> void:
	await _spawn()
	QuestManager.from_dict({"states": {"prologue": G.QuestState.COMPLETE,
		"errand_miller_wheat": G.QuestState.COMPLETE}})
	var tab: JournalTab = menu.tab(&"journal")
	tab.on_shown()
	eq(tab.listed_quests(), [], "completed quests are folded away")
	tab._on_selected(JournalTab.DONE_ENTRY)
	check(&"errand_miller_wheat" in tab.listed_quests(), "unfolded")
	tab._on_focused(&"errand_miller_wheat")
	check(tab.body_text().contains("Grind my grain, Ned?"), "daily favour shown once earned")
	await _despawn()


func test_folk_hides_names_until_met() -> void:
	await _spawn()
	var tab: FolkTab = menu.tab(&"folk")
	tab.on_shown()
	eq(tab.rows().size(), Content.npcs().size(), "a row per villager")
	eq(tab.rows()[0].shown_name(), "???", "unmet")
	Relationships.talk(&"reeve")
	tab.on_shown()
	var reeve := Content.npc(&"reeve")
	eq(tab.rows()[0].shown_name(), reeve.display_name, "met")
	await _despawn()


func test_almanack_feast_and_sowing_and_discoveries() -> void:
	SaveManager.new_game()
	var feast := AlmanackPage.next_feast()
	eq(feast["festival"].id, &"may_day", "next feast in spring 1")
	eq(feast["days"], 19, "days to spring 20")
	check(not AlmanackPage.sowable_crops().is_empty(), "something to sow in spring")
	check(&"trout" not in AlmanackItemsPage.discovered(), "trout not yet obtained")
	Progress.record(&"caught", &"trout", 1)
	check(&"trout" in AlmanackItemsPage.discovered(), "trout discovered after a catch")


func test_almanack_lore_lists_only_what_was_met() -> void:
	SaveManager.new_game()
	var titles := AlmanackLorePage.notes().map(func(n: Dictionary) -> String: return n["title"])
	check("A Holding of One's Own" not in titles, "unstarted quest has no note")
	check("Bread" not in titles, "chain not crafted yet")
	QuestManager.start(&"prologue")
	Progress.record(&"crafted", &"bread", 1)
	titles = AlmanackLorePage.notes().map(func(n: Dictionary) -> String: return n["title"])
	check("A Holding of One's Own" in titles, "started quest note")
	check("Bread" in titles, "finished chain note")
	check("May Day" in titles, "feast of the season")
	check("Harvest Home" not in titles, "later feast not yet met")


func test_every_tab_keeps_focus_inside_itself() -> void:
	await _spawn()
	_populate()
	menu.open()
	for id in menu.tab_ids():
		menu.open_tab(id)
		await tree.process_frame
		var focused := menu.get_viewport().gui_get_focus_owner()
		check(focused != null and menu.current_tab().is_ancestor_of(focused), "%s has focus" % id)
	menu.close()
	await _despawn()


func test_shoulder_actions_switch_tabs_and_cancel_closes() -> void:
	await _spawn()
	menu.open()
	await tree.process_frame
	await tree.process_frame
	_press(&"tool_forward")
	await tree.process_frame
	eq(menu.current_index(), 1, "forward key")
	_press(&"tool_backward")
	await tree.process_frame
	eq(menu.current_index(), 0, "back key")
	_press(&"ui_cancel")
	await tree.process_frame
	check(not menu.is_open, "cancel closes")
	await _despawn()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
