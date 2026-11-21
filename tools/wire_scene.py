#!/usr/bin/env python3
"""Instance feature scenes into a .tscn without the editor.

Usage: tools/wire_scene.py <scene.tscn> <NodeName>=<res://child.tscn>@<parent path> [...]
Parent "." is the scene root. Idempotent: an existing node of that name is left alone.
"""
import re
import sys


def wire(scene_path: str, specs: list[str]) -> None:
	text = open(scene_path).read()
	for spec in specs:
		name, rest = spec.split("=", 1)
		res, parent = rest.split("@", 1)
		if re.search(r'^\[node name="%s" ' % re.escape(name), text, re.M):
			continue
		res_id = "wired_" + re.sub(r"\W", "_", name).lower()
		ext = '[ext_resource type="PackedScene" path="%s" id="%s"]\n' % (res, res_id)
		last = list(re.finditer(r"^\[ext_resource .*\]\n", text, re.M))[-1]
		text = text[: last.end()] + ext + text[last.end():]
		node = '\n[node name="%s" parent="%s" instance=ExtResource("%s")]\n' % (name, parent, res_id)
		conn = re.search(r"^\[connection ", text, re.M)
		if conn:
			text = text[: conn.start()] + node.lstrip("\n") + "\n" + text[conn.start():]
		else:
			text = text.rstrip("\n") + "\n" + node
	open(scene_path, "w").write(text)


if __name__ == "__main__":
	wire(sys.argv[1], sys.argv[2:])
