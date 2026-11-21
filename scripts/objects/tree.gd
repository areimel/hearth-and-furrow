class_name AppleTree extends StaticBody2D
## A choppable apple tree. Axe hits knock apples down and wear it down; at zero health it
## is felled: logs go to the player (Loot) and a stump stays. The stump regrows into a
## tree after Balance.TREE_REGROW_DAYS days, so wood is renewable. Apples regrow over
## evenings, but only in Balance.APPLE_SEASONS. Saved by TreeGrove.

const APPLE_TEXTURE := preload("res://graphics/plants/apple.png")
const APPLE_RANGE := Vector2i(2, 4)

## Remaining hit points; the axe's tier `power` is subtracted per hit.
var health: float = Balance.APPLE_TREE_HEALTH
## True while only the stump stands.
var felled: bool = false
## Evenings since it was felled.
var stump_days: int = 0

var _color_tween: Tween

@onready var _upper: Sprite2D = $FlashSprite2DUpper
@onready var _bottom: Sprite2D = $FlashSprite2DBottom


func _ready() -> void:
	_upper.frame = [0, 1, 1, 3].pick_random()
	add_to_group("Tree")
	GameClock.day_ending.connect(_on_day_ending)
	_grow_apples()
	_apply_felled()


## How many axe hits a tree needs with a tool of `tier` (null = base power 1).
static func hits_to_fell(tier: ToolTierData) -> int:
	return ceili(Balance.APPLE_TREE_HEALTH / (tier.power if tier else 1.0))


## Number of apples currently hanging.
func apple_count() -> int:
	return $Apples.get_child_count()


## Axe_able contract: `action` is a G.ToolKind; only the axe works. `tier` is the swung
## tool's ToolTierData (power per hit, bonus logs); null counts as the base tier.
func hit(action: int, _direction: Vector2, tier: ToolTierData = null) -> void:
	if action != G.ToolKind.AXE or felled:
		return
	_upper.flash()
	_bottom.flash()
	_pick_apple()
	health -= tier.power if tier else 1.0
	if health <= 0.0:
		fell(tier.bonus_logs if tier else 0)


## Fell the tree now: give logs (base + `bonus_logs`) and leave a stump.
func fell(bonus_logs: int = 0) -> void:
	felled = true
	stump_days = 0
	_apply_felled()
	Loot.give(get_tree(), &"log", Balance.TREE_LOGS + bonus_logs, &"gathered")


## Bring the tree back at full health with a fresh crop of apples.
func regrow() -> void:
	felled = false
	stump_days = 0
	health = Balance.APPLE_TREE_HEALTH
	_apply_felled()
	_grow_apples()


## State for the save file.
func to_dict() -> Dictionary:
	return {"health": health, "felled": felled, "stump_days": stump_days, "apples": apple_count()}


## Restore from to_dict(); `{}` restores a healthy tree with a fresh crop of apples.
func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", Balance.APPLE_TREE_HEALTH))
	felled = bool(data.get("felled", false))
	stump_days = int(data.get("stump_days", 0))
	_apply_felled()
	if data.has("apples"):
		_show_apples(int(data["apples"]))
	else:
		_grow_apples()


## Roll a fresh crop of apples (at most one per remaining health point).
func _grow_apples() -> void:
	_show_apples(mini(randi_range(APPLE_RANGE.x, APPLE_RANGE.y), int(health)))


## Evening: a stump ages and regrows; a living tree heals and, in season, may fruit.
func _on_day_ending(_day: int) -> void:
	if felled:
		stump_days += 1
		if stump_days >= Balance.TREE_REGROW_DAYS:
			regrow()
		return
	health = minf(Balance.APPLE_TREE_HEALTH, health + 1.0)
	if Calendar.season() in Balance.APPLE_SEASONS and randf() < Balance.APPLE_REGROW_CHANCE:
		_grow_apples()


func _apply_felled() -> void:
	_upper.visible = not felled
	_bottom.visible = not felled
	$Stump.visible = felled
	$CollisionShapeTree2D.set_deferred("disabled", felled)
	$CollisionShapeStumpD2.set_deferred("disabled", not felled)
	if felled:
		remove_from_group("Axe_able")
		_show_apples(0)
	else:
		add_to_group("Axe_able")


func _pick_apple() -> void:
	if apple_count() > 0:
		var apple: Node = $Apples.get_children().pick_random()
		$Apples.remove_child(apple)
		apple.queue_free()
		Loot.give(get_tree(), &"apple", 1, &"gathered")


func _show_apples(count: int) -> void:
	for child in $Apples.get_children():
		$Apples.remove_child(child)
		child.queue_free()
	var markers := $AppleSpawnPositions.get_children()
	markers.shuffle()
	for i in mini(count, markers.size()):
		var sprite := Sprite2D.new()
		sprite.texture = APPLE_TEXTURE
		sprite.position = (markers[i] as Node2D).position
		$Apples.add_child(sprite)


func _on_behid_tree_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_fade_canopy(Color("ffffff96"))


func _on_behid_tree_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_fade_canopy(Color("ffffff"))


func _fade_canopy(target: Color) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(_upper, "modulate", target, 0.2)
	_color_tween.parallel().tween_property($Apples, "modulate", target, 0.2)
