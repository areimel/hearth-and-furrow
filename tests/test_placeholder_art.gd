extends TestCase
## Every placeholder path referenced by the data tables has been generated
## (tools/make_placeholder_art.sh), and crop sheets match their declared frame count.


func test_no_pending_placeholders() -> void:
	var pending := Content.pending_placeholders()
	eq(pending.size(), 0, "pending placeholders: %s" % ", ".join(pending))


func test_crop_sheets_are_four_16x32_frames() -> void:
	for crop: CropData in Content.crops():
		var tex := crop.sprite
		check(tex != null, "%s has no sprite" % crop.id)
		if tex == null:
			continue
		eq(crop.sprite_frames, 4, "%s frames" % crop.id)
		eq(tex.get_size(), Vector2(64, 32), "%s sheet size" % crop.id)
