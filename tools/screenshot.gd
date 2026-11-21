extends Node
## Screenshot harness. Loads a scene, waits N frames, saves the viewport as PNG, quits.
##
## Usage (needs a real display, so the window opens briefly):
##   ~/.local/share/godot/4.6/godot --path . res://tools/screenshot.tscn -- \
##       --out /abs/dir --scene res://scenes/levels/level.tscn --frames 90 --name farm
##
## Options (all after the `--`):
##   --out DIR      output directory (default user://shots)
##   --scene PATH   scene to load (default: the project's main scene)
##   --frames N     frames to wait before capture (default 60)
##   --name NAME    file name without extension (default "shot")
##   --size WxH     window size, e.g. 1280x800 (default: project default)
##   --setup STEP   named setup step run once the scene is up: fishing | rain | plants | menu
##   --upscale N    also write NAME_xN.png, nearest-neighbour enlarged (default 4; 1 = off)
## The raw PNG is the base-resolution viewport (320x180, or 320x200 on 16:10 windows).

var _args: Dictionary = {}


func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	if _args.has("size"):
		var parts: PackedStringArray = String(_args["size"]).split("x")
		if parts.size() == 2:
			get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var path: String = _args.get("scene", ProjectSettings.get_setting("application/run/main_scene"))
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load %s" % path)
		get_tree().quit(1)
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	if _args.has("setup"):
		_run_setup(String(_args["setup"]), scene)
	for i in int(_args.get("frames", 60)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save()
	get_tree().quit()


func _parse(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i := 0
	while i < argv.size():
		if argv[i].begins_with("--") and i + 1 < argv.size():
			out[argv[i].trim_prefix("--")] = argv[i + 1]
			i += 1
		i += 1
	return out


func _run_setup(step: String, scene: Node) -> void:
	match step:
		"fishing":
			var game := scene.find_child("FishingGame", true, false)
			if game:
				game.reveal()
		"rain":
			scene.set("raining", true)
		"plants":
			var level := scene as Level
			if level:
				for x in [10, 11, 12]:
					level.farm_grid.till(Vector2i(x, -8))
					level.call("_sow", Vector2i(x, -8))
		"menu":
			if scene.has_method("open"):
				scene.open()
		_:
			if scene.has_method(step):
				scene.call(step)
			else:
				push_warning("screenshot: unknown setup step '%s'" % step)


func _save() -> void:
	var dir := ProjectSettings.globalize_path(String(_args.get("out", "user://shots")))
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var base: String = _args.get("name", "shot")
	image.save_png(dir.path_join(base + ".png"))
	var factor := int(_args.get("upscale", 4))
	if factor > 1:
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		image.save_png(dir.path_join("%s_x%d.png" % [base, factor]))
	print("screenshot: saved %s/%s (%dx%d)" % [dir, base, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
