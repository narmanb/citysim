extends SceneTree
## Check imported source texels/filtering borders, including Godot alpha-edge processing.

func _initialize() -> void:
	var manifest_path: String = "res://assets/manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var layout_path: String = "res://assets/render_atlas.json"
	if not FileAccess.file_exists(layout_path):
		push_error("A compact atlas of the existing selected sprites is required")
		quit(1)
		return
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if FileAccess.get_sha256(manifest_path) != layout.source_manifest_sha256 or FileAccess.get_sha256("res://" + layout.file) != layout.sha256:
		push_error("Render atlas receipts no longer match its source/derived image")
		quit(1)
		return
	var packed: Image = (load("res://" + layout.file) as Texture2D).get_image()
	var images: Dictionary = {}
	for name in manifest.atlases:
		images[name] = (load("res://" + manifest.atlases[name].file) as Texture2D).get_image()
	if layout.sprites.size() != manifest.sprites.size():
		push_error("The compact atlas must preserve every selected sprite")
		quit(1)
		return
	var count: int = 0
	for name in manifest.sprites:
		var source: Dictionary = manifest.sprites[name]
		var target: Dictionary = layout.sprites.get(name, {})
		if target.get("width", 0) != source.width or target.get("height", 0) != source.height:
			push_error("Sprite dimensions changed: " + name)
			quit(1)
			return
		for dy in range(-int(layout.padding), int(source.height) + int(layout.padding)):
			for dx in range(-int(layout.padding), int(source.width) + int(layout.padding)):
				var expected: Color = images[source.atlas].get_pixel(int(source.x) + clampi(dx, 0, int(source.width) - 1), int(source.y) + clampi(dy, 0, int(source.height) - 1))
				if packed.get_pixel(int(target.x) + dx, int(target.y) + dy) != expected:
					push_error("Source sprite/filtering border changed: " + name)
					quit(1)
					return
				count += 1
	print("Render atlas: %s selected sprites, %s exact source/border texels: PASS" % [layout.sprites.size(), count])
	quit()
