extends Node
## Screenshot harness. Loads a scene, waits N frames, saves the viewport as PNG, quits.
##
## Usage (needs a real display, so the window opens briefly):
##   ~/.local/share/godot/4.6/godot --path . res://tools/screenshot.tscn -- \
##       --out /abs/dir --setup menu:pack --frames 30 --name pack
##
## Options (all after the `--`):
##   --out DIR      output directory (default user://shots)
##   --scene PATH   scene to load (default: the level when --setup is given, else the main scene;
##                  the title scene when the first setup step is `title`)
##   --session      boot through GameSession.start_new() (real session: the prologue speaks).
##                  Uses a throw-away save path, never the player's save.
##   --frames N     frames to wait before capture (default 60)
##   --name NAME    file name without extension (default "shot")
##   --size WxH     window size, e.g. 1280x720 (default: project default)
##   --raw WxH      content scaling off and a WxH window, for full-resolution art checks
##   --pos x,y      free camera centre in world pixels (with --zoom, or alone)
##   --zoom Z       camera zoom (default 1 for a free camera)
##   --setup STEPS  comma-separated steps run once the scene is up, in order (screenshot_setups.gd):
##                  title | menu:<pack|journal|folk|almanack|settings> | crafting:<station id> |
##                  shop:<shop id> | shop_sell:<shop id> | build | dialogue:<npc id> |
##                  festival:<festival id> | yard | herd | forage | village | fishing | rain | storm |
##                  night | noon | spring | summer | autumn | winter | plants | risks | highlight |
##                  days:N | <method on the scene>
##   --upscale N    also write NAME_xN.png, nearest-neighbour enlarged (default 4; 1 = off)
## The raw PNG is the base-resolution viewport (320x180); NAME_x4.png is the 1280x720 view.

const Setups := preload("res://tools/screenshot_setups.gd")
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

var _args: Dictionary = {}


func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	var win := get_window()
	if _args.has("raw"):
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var size_text: String = _args.get("raw", _args.get("size", ""))
	if size_text.contains("x"):
		win.size = Vector2i(int(size_text.get_slice("x", 0)), int(size_text.get_slice("x", 1)))
	var steps := String(_args.get("setup", "")).split(",", false)
	var scene := await _load_scene(steps)
	if scene == null:
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var setups := Setups.new(scene, get_tree())
	for step in steps:
		await setups.run(step)
	_apply_camera(setups, scene)
	for i in int(_args.get("frames", 60)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save()
	get_tree().quit()


func _parse(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i := 0
	while i < argv.size():
		if argv[i] == "--session":
			out["session"] = true
		elif argv[i].begins_with("--") and i + 1 < argv.size():
			out[argv[i].trim_prefix("--")] = argv[i + 1]
			i += 1
		i += 1
	return out


## Instantiate the scene under this node, or boot a real session (the level replaces the
## current scene, so a stand-in takes that role and the harness survives the change).
func _load_scene(steps: PackedStringArray) -> Node:
	var path: String = _args.get("scene", "")
	if path.is_empty():
		path = TITLE_SCENE if not steps.is_empty() and steps[0] == "title" else Setups.LEVEL_SCENE
		if steps.is_empty() and not _args.has("session"):
			path = ProjectSettings.get_setting("application/run/main_scene")
	if _args.has("session"):
		SaveManager.save_path = "user://screenshot_session.json"
		var stand_in := Node.new()
		await get_tree().process_frame  # the root is busy while this scene's _ready runs
		get_tree().root.add_child(stand_in)
		get_tree().current_scene = stand_in
		await GameSession.start_new()
		SaveManager.autosave_enabled = false
		return get_tree().current_scene
	if path == Setups.LEVEL_SCENE:
		SaveManager.new_game()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load %s" % path)
		return null
	var scene := packed.instantiate()
	add_child(scene)
	return scene


## A free Camera2D when --pos / --zoom (or a camera setup step) ask for one.
func _apply_camera(setups: Setups, scene: Node) -> void:
	var focus: Variant = setups.focus
	var zoom: float = setups.zoom
	if _args.has("pos"):
		var xy: PackedStringArray = String(_args["pos"]).split(",")
		focus = Vector2(float(xy[0]), float(xy[1]))
	if _args.has("zoom"):
		zoom = float(_args["zoom"])
	if focus == null and zoom <= 0.0:
		return
	var level := get_tree().get_first_node_in_group(&"Level") as Level
	var camera := Camera2D.new()
	camera.position = focus if focus != null else level.player.global_position if level else Vector2.ZERO
	camera.zoom = Vector2.ONE * (zoom if zoom > 0.0 else 1.0)
	(level if level else scene).add_child(camera)
	camera.make_current()


func _save() -> void:
	var dir := ProjectSettings.globalize_path(String(_args.get("out", "user://shots")))
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var base: String = _args.get("name", "shot")
	image.save_png(dir.path_join(base + ".png"))
	var factor := int(_args.get("upscale", 4))
	if factor > 1 and not _args.has("raw"):
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		image.save_png(dir.path_join("%s_x%d.png" % [base, factor]))
	print("screenshot: saved %s/%s (%dx%d)" % [dir, base, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
