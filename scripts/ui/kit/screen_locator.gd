class_name ScreenLocator extends RefCounted
## Finds the single instance of a modal screen by group, or creates it under the first
## CanvasLayer of the running scene (so it draws over the world). Feature roots use this
## instead of each hand-rolling the lookup.


## The screen in `group`, instancing `scene` under the first CanvasLayer if none exists.
## `fallback_parent` hosts a fresh CanvasLayer when the tree has none.
static func find_or_create(tree: SceneTree, group: StringName, scene: PackedScene,
		fallback_parent: Node) -> Node:
	var screen := tree.get_first_node_in_group(group)
	if screen == null:
		screen = scene.instantiate()
		layer_for(tree, fallback_parent).add_child(screen)
	return screen


## The first CanvasLayer in the tree, or a new one added to `fallback_parent`.
static func layer_for(tree: SceneTree, fallback_parent: Node) -> Node:
	var layers := tree.root.find_children("*", "CanvasLayer", true, false)
	if not layers.is_empty():
		return layers[0]
	var layer := CanvasLayer.new()
	fallback_parent.add_child(layer)
	return layer
