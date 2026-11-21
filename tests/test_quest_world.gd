extends TestCase
## QuestGiver inside the real Level: the field probes see sowing and watering, so the
## prologue's first steps complete from actual farm actions.

var level: Level
var giver: QuestGiver


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = await spawn_level()
	giver = load("res://scenes/world/quest_giver.tscn").instantiate()
	level.add_child(giver)


func test_sowing_and_watering_advance_the_prologue() -> void:
	await _spawn()
	check(QuestManager.is_active(&"prologue"), "prologue started with the level")
	var field := level.farm_grid.crop_field
	for i in 4:
		var cell := level.target_cell() + Vector2i(i + 2, 2)
		level.farm_grid.till(cell)
		field.sow(cell, &"wheat")
	await tree.process_frame
	eq(QuestManager.current_step(&"prologue"), 1, "four wheat sown")
	var garden := level.target_cell()
	level.farm_grid.till(garden)
	check(field.sow(garden, &"cabbage") != null, "cabbage sown at %s" % garden)
	await tree.process_frame
	eq(QuestManager.current_step(&"prologue"), 1, "cabbage not yet watered")
	var player := level.player
	player.tool_use.emit(G.ToolKind.WATERING_CAN, player.position, player.animation_direction)
	await tree.process_frame
	check(level.farm_grid.is_wet(garden), "the can watered the garden cell")
	eq(QuestManager.current_step(&"prologue"), 2, "watered cabbage")
	await despawn_level()
	check(QuestManager.condition_progress(&"prologue", 0) == 4, "latched after the level is gone")
	SaveManager.new_game()
