extends TestCase
## FestivalDirector with a stub Villagers: feast-day detection, gather/release, the feast
## table, partial and full contributions, reward tiers paid once, resolving at the end
## hour and on sleep, eve/greeting options, saved state, and quiet ordinary days.

const StubVillagers := preload("res://tests/test_quest_stub_villagers.gd")
const DIRECTOR_SCENE := preload("res://scenes/world/festival_director.tscn")
const FeastLines := preload("res://data/dialogue_feasts.gd")
const TEMP_PATH := "user://test_festival_tmp.json"

var stub: Node
var director: FestivalDirector


func before_each() -> void:
	SaveManager.new_game()


func _make_director(season: int, day: int, hour: int) -> void:
	GameClock.day_index = Calendar.day_index_for(1, season, day)
	GameClock.hour = hour
	stub = StubVillagers.new()
	director = DIRECTOR_SCENE.instantiate()
	director.villagers = stub
	tree.root.add_child(director)
	director.bind()


func _drop() -> void:
	director.free()
	stub.free()


func test_ordinary_day_is_untouched() -> void:
	_make_director(G.Season.SPRING, 5, 10)
	check(director.today() == null, "no feast on spring 5")
	check(director.running() == null, "nothing running")
	eq(stub.gathered.size(), 0, "no gathering")
	for hour in range(6, 24):
		GameClock.hour = hour
		director.sync()
	eq(stub.gathered.size() + stub.released, 0, "no gather/release all day")
	check(director.ledger.to_dict()["resolved"].is_empty(), "nothing resolved")
	_drop()


func test_may_day_gathers_and_pays_tiers_once() -> void:
	_make_director(G.Season.SPRING, 20, 8)
	eq(director.today().id, &"may_day", "feast day detected")
	check(director.running() == null, "not before the start hour")
	GameClock.hour = 9
	GameClock.hour_passed.emit(9)
	eq(director.running().id, &"may_day", "running from nine")
	eq(stub.gathered, [[&"village_green", "spot_"]], "gathered at the green (no feast_ground marker)")
	var feast := director.running()
	Inventory.add(&"hazel_rod", 3)
	eq(director.contribute(0), 3, "partial: three boughs")
	eq(director.given(feast, 0), 3, "recorded")
	eq(feast.tier_index(director.total_given(feast)), 0, "only the coming-along tier")
	Inventory.add(&"hazel_rod", 5)
	Inventory.add(&"reed", 7)
	Inventory.add(&"egg", 1)
	Inventory.add(&"apple", 4)
	eq(director.contribute_all(), 3 + 6 + 2, "full: capped at what is wanted")
	eq(Inventory.count(&"hazel_rod"), 2, "extra boughs kept")
	eq(Inventory.count(&"reed"), 1, "extra reed kept")
	eq(Inventory.count(&"egg") + Inventory.count(&"apple"), 3, "two treats given")
	eq(director.total_given(feast), feast.total_asked(), "everything asked for")
	eq(director.contribute_all(), 0, "nothing more wanted")
	var coins := Economy.coins
	GameClock.hour = 18
	GameClock.hour_passed.emit(18)
	check(director.running() == null, "ends at the end hour")
	eq(stub.released, 1, "villagers released")
	eq(director.ledger.resolved_tier(&"may_day", 1), feast.tiers.size() - 1, "top tier")
	eq(Economy.coins, coins + 80, "top tier coins")
	eq(Inventory.count(&"cabbage_seed"), 4 + 5, "top tier seed (plus the starting five)")
	eq(Relationships.points(&"shepherd"), 80, "friendship with everyone present")
	eq(director.speaker.pending(), 1, "host's closing lines queued")
	eq(director.resolve(), -1, "pays once")
	eq(Economy.coins, coins + 80, "no second payment")
	_drop()


func test_harvest_home_resolves_on_sleep() -> void:
	_make_director(G.Season.AUTUMN, 7, 16)
	eq(director.running().id, &"harvest_home", "already running when the scene loads at 16:00")
	Inventory.add(&"wheat_sheaf", 3)
	eq(director.contribute(0), 3, "three sheaves")
	var coins := Economy.coins
	GameClock.advance_day()
	eq(director.ledger.resolved_tier(&"harvest_home", 1), 1, "a fair share")
	eq(Economy.coins, coins + 60, "tier coins on sleep")
	check(director.running() == null, "over by morning")
	eq(stub.released, 1, "released")
	_drop()


func test_missing_a_feast_costs_nothing() -> void:
	_make_director(G.Season.SPRING, 20, 10)
	var coins := Economy.coins
	GameClock.hour = 18
	director.sync()
	eq(director.ledger.resolved_tier(&"may_day", 1), -1, "no tier without coming")
	eq(Economy.coins, coins, "no coins")
	eq(Relationships.points(&"reeve"), 0, "no friendship lost or gained")
	_drop()


func test_greeting_and_eve_options() -> void:
	_make_director(G.Season.SPRING, 19, 10)
	var may: Dictionary = FeastLines.LINES[&"may_day"]
	check(may["opt_eve"] in stub.offered(&"reeve"), "reeve mentions tomorrow's feast")
	check(not may["opt_greet"] in stub.offered(&"miller"), "no greeting the day before")
	GameClock.advance_day()
	check(not may["opt_eve"] in stub.offered(&"reeve"), "no eve option on the day")
	GameClock.hour = 10
	director.sync()
	check(may["opt_greet"] in stub.offered(&"miller"), "feast greeting during the feast")
	check(stub.choose(&"miller", may["opt_greet"]), "greet")
	check(director.ledger.attended(&"may_day", 1), "greeting counts as coming")
	check(director.reaction(director.running(), 1).contains(": "), "a villager reacts")
	_drop()


func test_feast_state_is_saved() -> void:
	SaveManager.save_path = TEMP_PATH
	_make_director(G.Season.SPRING, 20, 10)
	Inventory.add(&"reed", 4)
	director.contribute(1)
	eq(SaveManager.save_game(), OK, "save")
	SaveManager.new_game()
	eq(director.ledger.total(&"may_day", 1), 0, "reset")
	eq(SaveManager.load_game(), OK, "load")
	eq(director.ledger.given(&"may_day", 1, 1), 4, "contribution restored")
	check(director.ledger.attended(&"may_day", 1), "attendance restored")
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.DEFAULT_PATH
	_drop()


func test_feast_rows_are_complete() -> void:
	for feast in Content.festivals():
		check(not feast.note.is_empty(), "note on %s" % feast.id)
		check(not feast.announce.is_empty() and not feast.reminder.is_empty(), "%s toasts" % feast.id)
		check(not feast.asks.is_empty() and not feast.tiers.is_empty(), "%s asks and tiers" % feast.id)
		eq(feast.tiers[0].min_count, 0, "%s pays for coming" % feast.id)
		var lines: Dictionary = FeastLines.LINES.get(feast.id, {})
		for npc in Content.npcs():
			check((lines.get("greet", {}) as Dictionary).has(npc.id), "%s greets %s" % [feast.id, npc.id])
		for key in ["eve", "closing", "thanks"]:
			check(not (lines.get(key, []) as Array).is_empty(), "%s has %s" % [feast.id, key])
		for banned in ["BBC", "Monastery Farm", "Goodman", "Ginn", "Pinfold", "television"]:
			check(not banned in feast.note, "no '%s' in %s note" % [banned, feast.id])
