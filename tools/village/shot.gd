extends Node
## Village screenshot harness (dev only). Usage:
##   godot --path . res://tools/village/shot.tscn -- --out /abs/dir --name overview \
##       [--pos x,y] [--zoom 1] [--raw WxH] [--farm 1]
## --pos is the camera centre in world pixels, --zoom the camera zoom. Without --raw the image is the
## 320x180 game viewport (plus a x4 copy); with --raw the content scaling is off and the window is WxH.

func _ready() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var win := get_window()
	if args.has("raw"):
		var wh: PackedStringArray = String(args["raw"]).split("x")
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(int(wh[0]), int(wh[1]))
	var scene := (load(args.get("scene", "res://scenes/world/village.tscn")) as PackedScene).instantiate()
	if args.has("farm"):  # integration preview: village under Level/Objects, like the real game
		var level := (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
		add_child(level)
		level.get_node("Objects").add_child(scene)
	else:
		add_child(scene)
	var cam := Camera2D.new()
	var pos: PackedStringArray = String(args.get("pos", "0,0")).split(",")
	cam.position = Vector2(float(pos[0]), float(pos[1]))
	var zoom := float(args.get("zoom", 1.0))
	cam.zoom = Vector2(zoom, zoom)
	add_child(cam)
	cam.make_current()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := String(args.get("out", "/tmp/shots"))
	DirAccess.make_dir_recursive_absolute(dir)
	var base: String = args.get("name", "village")
	image.save_png(dir.path_join(base + ".png"))
	if not args.has("raw"):
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
		image.save_png(dir.path_join(base + "_x4.png"))
	get_tree().quit()


func _parse(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < argv.size():
		if argv[i].begins_with("--") and i + 1 < argv.size():
			out[argv[i].trim_prefix("--")] = argv[i + 1]
			i += 1
		i += 1
	return out
