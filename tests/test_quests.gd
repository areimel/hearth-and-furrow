extends TestCase
## QuestManager + QuestGiver: the prologue and the three errands played from a fresh game
## by driving the real services, option conditions at each stage, rewards once, perks,
## save round-trip, and season sanity of the errand data.

const StubVillagers := preload("res://tests/test_quest_stub_villagers.gd")
const QuestLines := preload("res://data/dialogue_quests.gd")
const TEMP_PATH := "user://test_quest_tmp.json"

var probes: Dictionary = {&"sown.wheat": 0, &"watered.cabbage": 0}
var stub: Node
var giver: QuestGiver


func before_each() -> void:
	SaveManager.new_game()
	for key: StringName in probes:
		QuestManager.register_probe(key, func() -> int: return int(probes[key]))


func _make_giver() -> void:
	stub = StubVillagers.new()
	giver = QuestGiver.new()
	giver.villagers = stub
	tree.root.add_child(giver)
	giver.bind()


func _drop_giver() -> void:
	giver.free()
	stub.free()
	for key: StringName in probes:
		QuestManager.register_probe(key, func() -> int: return 0)


func _set_probe(key: StringName, value: int) -> void:
	probes[key] = value
	QuestManager.refresh()


## Play a recipe the way a station does: inputs out, outputs in, `crafted` recorded.
func _craft(recipe_id: StringName, times: int = 1) -> void:
	var recipe := Content.recipe(recipe_id)
	for t in times:
		for id: StringName in recipe.inputs:
			check(Inventory.remove(id, recipe.inputs[id]), "%s needs %s" % [recipe_id, id])
		for id: StringName in recipe.outputs:
			Inventory.add(id, recipe.outputs[id])
			Progress.record(&"crafted", id, recipe.outputs[id])


func _harvest(item_id: StringName, amount: int) -> void:
	Inventory.add(item_id, amount)
	Progress.record(&"harvested", item_id, amount)


func _finish_prologue() -> void:
	QuestManager.start_auto_quests()
	_set_probe(&"sown.wheat", 4)
	_set_probe(&"watered.cabbage", 1)
	GameClock.advance_day()
	_harvest(&"wheat_sheaf", 2)
	_craft(&"thresh_wheat")
	_craft(&"grind_flour")
	for npc: StringName in [&"reeve", &"miller", &"alewife", &"chandler"]:
		Relationships.talk(npc)
	check(QuestManager.complete(&"prologue"), "prologue completes")


func test_prologue_walkthrough_and_rewards_once() -> void:
	var steps: Array[int] = []
	QuestManager.step_advanced.connect(func(_q: StringName, s: int) -> void: steps.append(s))
	eq(QuestManager.start_auto_quests(), [&"prologue"] as Array[StringName], "auto start")
	eq(QuestManager.start_auto_quests().size(), 0, "auto start once")
	check(not QuestManager.can_start(&"errand_miller_wheat"), "errands locked")
	_set_probe(&"watered.cabbage", 1)
	eq(QuestManager.current_step(&"prologue"), 0, "later steps wait their turn")
	eq(QuestManager.condition_progress(&"prologue", 1), 0, "future step reads 0")
	_set_probe(&"sown.wheat", 3)
	eq(QuestManager.condition_progress(&"prologue", 0), 3, "3/4 sown")
	_set_probe(&"sown.wheat", 4)
	eq(QuestManager.current_step(&"prologue"), 2, "sow, then the watered cabbage counts")
	_set_probe(&"sown.wheat", 0)
	eq(QuestManager.condition_progress(&"prologue", 0), 4, "finished steps latch")
	eq(QuestManager.current_step(&"prologue"), 2, "sleep not done the same day")
	GameClock.advance_day()
	eq(QuestManager.current_step(&"prologue"), 3, "a night passed")
	_harvest(&"cabbage", 1)
	_harvest(&"wheat_sheaf", 2)
	_craft(&"thresh_wheat")
	eq(QuestManager.current_step(&"prologue"), 5, "reaped and threshed")
	_craft(&"grind_flour")
	for npc: StringName in [&"reeve", &"miller", &"alewife"]:
		Relationships.talk(npc)
	check(not QuestManager.is_ready(&"prologue"), "three met is not enough")
	Relationships.talk(&"shepherd")
	check(QuestManager.is_ready(&"prologue"), "ready")
	eq(steps, [1, 2, 3, 4, 5, 6, 7] as Array[int], "each step advanced once, in order")
	var coins := Economy.coins
	check(QuestManager.complete(&"prologue"), "complete")
	check(not QuestManager.complete(&"prologue"), "only once")
	eq(Economy.coins, coins + 50, "coins once")
	eq(Inventory.count(&"barley_seed"), 6, "seed barley")
	eq(Inventory.count(&"flax_seed"), 4, "linseed")
	check(Progress.has_flag(&"prologue_done"), "flag")
	for id: StringName in [&"errand_miller_wheat", &"errand_alewife_barley", &"errand_chandler_linen"]:
		check(QuestManager.can_start(id), "%s unlocked" % id)


func test_giver_options_through_the_prologue() -> void:
	_make_giver()
	var lines: Dictionary = QuestLines.LINES[&"prologue"]
	check(QuestManager.is_active(&"prologue"), "giver auto-starts the prologue")
	check(lines["opt_progress"] in stub.offered(&"reeve"), "reeve: what next")
	check(not lines["opt_ready"] in stub.offered(&"reeve"), "reeve: not ready yet")
	check(not QuestGiver.OPT_OFFER in stub.offered(&"miller"), "miller: no errand yet")
	eq(QuestGiver.progress_lines(Content.quest(&"prologue")),
			[lines["hints"][0]] as Array[String], "hint for step 0")
	_set_probe(&"sown.wheat", 4)
	_set_probe(&"watered.cabbage", 1)
	GameClock.advance_day()
	_harvest(&"wheat_sheaf", 2)
	_craft(&"thresh_wheat")
	_craft(&"grind_flour")
	for npc: StringName in [&"reeve", &"miller", &"alewife", &"chandler"]:
		Relationships.talk(npc)
	check(lines["opt_ready"] in stub.offered(&"reeve"), "reeve: hand in")
	check(not lines["opt_progress"] in stub.offered(&"reeve"), "reeve: no chatter when ready")
	check(stub.choose(&"reeve", lines["opt_ready"]), "hand in")
	check(QuestManager.is_complete(&"prologue"), "complete")
	check(stub.offered(&"reeve").is_empty(), "reeve: nothing left")
	check(QuestGiver.OPT_OFFER in stub.offered(&"miller"), "miller: errand offered")
	_drop_giver()


func test_miller_bread_errand_with_bought_barm_and_favour() -> void:
	_finish_prologue()
	_make_giver()
	check(stub.choose(&"miller", QuestGiver.OPT_OFFER), "accept")
	check(QuestManager.is_active(&"errand_miller_wheat"), "active")
	check(QuestGiver.OPT_PROGRESS in stub.offered(&"miller"), "progress chatter")
	check(not QuestGiver.OPT_READY in stub.offered(&"miller"), "not ready")
	_harvest(&"wheat_sheaf", 1)
	_craft(&"thresh_wheat")
	_craft(&"grind_flour")
	check(Economy.buy(&"barm", 1), "barm bought from the alewife's trade")
	_craft(&"bake_bread")
	check(QuestGiver.OPT_READY in stub.offered(&"miller"), "ready")
	var coins := Economy.coins
	check(stub.choose(&"miller", QuestGiver.OPT_READY), "hand in")
	check(QuestManager.is_complete(&"errand_miller_wheat"), "complete")
	eq(Inventory.count(&"bread"), 1, "one loaf delivered")
	eq(Economy.coins, coins + 60, "coins")
	check(Progress.has_flag(&"miller_fair_measure"), "fair measure flag")
	var perk := Content.quest(&"errand_miller_wheat").perk_text
	check(perk in stub.offered(&"miller"), "favour offered")
	check(not QuestManager.can_claim_perk(&"errand_miller_wheat"), "needs grain")
	Inventory.add(&"grain", 3)
	var flour := Inventory.count(&"flour")
	check(stub.choose(&"miller", perk), "favour taken")
	eq(Inventory.count(&"flour"), flour + 2, "two flour")
	eq(Inventory.count(&"grain"), 0, "three grain")
	check(not perk in stub.offered(&"miller"), "once a day")
	GameClock.advance_day()
	check(perk in stub.offered(&"miller"), "again tomorrow")
	_drop_giver()


func test_alewife_ale_errand_and_daily_barm() -> void:
	_finish_prologue()
	_make_giver()
	check(stub.choose(&"alewife", QuestGiver.OPT_OFFER), "accept")
	_harvest(&"barley", 2)
	_craft(&"malt_barley")
	_craft(&"brew_ale")
	check(stub.choose(&"alewife", QuestGiver.OPT_READY), "hand in")
	eq(Inventory.count(&"ale"), 0, "two ale delivered")
	check(Progress.has_flag(&"alewife_barm_share"), "taught")
	var barm := Inventory.count(&"barm")
	check(stub.choose(&"alewife", Content.quest(&"errand_alewife_barley").perk_text), "barm")
	eq(Inventory.count(&"barm"), barm + 1, "one barm a day")
	check(not QuestManager.claim_perk(&"errand_alewife_barley"), "not twice a day")
	_drop_giver()


func test_chandler_linen_errand_pays_a_sack() -> void:
	_finish_prologue()
	_make_giver()
	check(stub.choose(&"chandler", QuestGiver.OPT_OFFER), "accept")
	_harvest(&"flax", 4)
	_craft(&"ret_flax", 2)
	_craft(&"spin_thread", 2)
	_craft(&"weave_linen")
	check(stub.choose(&"chandler", QuestGiver.OPT_READY), "hand in")
	eq(Inventory.count(&"linen"), 0, "linen delivered")
	eq(Inventory.count(&"linen_sack"), 1, "sack reward")
	check(Relationships.hearts(&"chandler") >= 1, "friendship")
	_drop_giver()


func test_quest_state_survives_save_mid_progress() -> void:
	SaveManager.save_path = TEMP_PATH
	QuestManager.start_auto_quests()
	_set_probe(&"sown.wheat", 4)
	_set_probe(&"watered.cabbage", 1)
	GameClock.advance_day()
	eq(QuestManager.current_step(&"prologue"), 3, "at the reaping step")
	eq(SaveManager.save_game(), OK, "save")
	SaveManager.new_game()
	eq(QuestManager.current_step(&"prologue"), 0, "reset")
	eq(SaveManager.load_game(), OK, "load")
	check(QuestManager.is_active(&"prologue"), "still active")
	eq(QuestManager.current_step(&"prologue"), 3, "step restored")
	eq(QuestManager.condition_progress(&"prologue", 0), 4, "done steps still done")
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.DEFAULT_PATH


## Every errand: the crops its chain needs (stopping at items a villager sells) are listed
## on the row, each grows in some season, and the giver says when to come back.
func test_errand_seasons_are_sane() -> void:
	for quest in Content.quests():
		if quest.auto_start:
			continue
		var needed: Array[StringName] = []
		for cond in quest.conditions:
			if cond.kind == QuestCondition.DELIVER_ITEM:
				for recipe in Content.recipes_producing(cond.target):
					for input: StringName in recipe.inputs:
						_crops_behind(input, needed, [])
		for crop_id in needed:
			check(crop_id in quest.crops, "%s lists crop %s" % [quest.id, crop_id])
		for crop_id in quest.crops:
			check(not Content.crop(crop_id).seasons.is_empty(), "%s sowable" % crop_id)
		var pool: Dictionary = QuestLines.LINES.get(quest.id, {})
		for key in ["offer", "progress", "complete"]:
			check(not (pool.get(key, []) as Array).is_empty(), "%s has %s lines" % [quest.id, key])
		if not quest.crops.is_empty():
			check(not (pool.get("out_of_season", []) as Array).is_empty(),
					"%s has an out-of-season line" % quest.id)
	GameClock.day_index = Calendar.day_index_for(1, G.Season.WINTER, 3)
	var ale := Content.quest(&"errand_alewife_barley")
	check(QuestGiver.out_of_season(ale), "no barley in winter")
	QuestManager.start(&"errand_alewife_barley")
	eq(QuestGiver.progress_lines(ale), QuestGiver.lines(ale.id, "out_of_season"), "says come back")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SUMMER, 3)
	check(not QuestGiver.out_of_season(ale), "barley in summer")


func test_notes_and_content_are_valid() -> void:
	eq(Content.validate().filter(func(p: String) -> bool: return "quest" in p or "festival" in p),
			[] as Array[String], "no quest/festival problems")
	var almanack: Dictionary = preload("res://data/almanack.gd").CHAINS
	var texts: Array[String] = []
	for chain: StringName in Content.chains():
		check(almanack.has(chain), "chain note %s" % chain)
		texts.append(str(almanack.get(chain, "")))
	for quest in Content.quests():
		check(not quest.note.is_empty(), "note on %s" % quest.id)
		texts.append(quest.note)
	for text in texts:
		for banned in ["BBC", "Monastery Farm", "Goodman", "Ginn", "Pinfold", "television"]:
			check(not banned in text, "no '%s' in notes" % banned)


func _crops_behind(item_id: StringName, out: Array[StringName], seen: Array) -> void:
	if item_id in seen:
		return
	seen.append(item_id)
	for npc in Content.npcs():
		if item_id in npc.shop_stock:
			return
	for crop in Content.crops():
		if crop.yield_item == item_id and not crop.id in out:
			out.append(crop.id)
	for recipe in Content.recipes_producing(item_id):
		for input: StringName in recipe.inputs:
			_crops_behind(input, out, seen)
