extends SceneTree
## Deterministically repack only the existing selected sprites. No new artwork.
## Run: godot --headless --path godot --script tools/build_render_atlas.gd

const WIDTH: int = 512
const PADDING: int = 2

func _initialize() -> void:
	var source_path: String = "res://assets/manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var source_images: Dictionary = {}
	for name in manifest.atlases:
		source_images[name] = (load("res://" + manifest.atlases[name].file) as Texture2D).get_image()
	var names: Array = manifest.sprites.keys()
	names.sort()
	var crops: Dictionary = {}
	var x: int = PADDING
	var y: int = PADDING
	var row_height: int = 0
	for name in names:
		var sprite: Dictionary = manifest.sprites[name]
		var width: int = int(sprite.width)
		var height: int = int(sprite.height)
		if x + width + PADDING > WIDTH:
			x = PADDING
			y += row_height + PADDING * 2
			row_height = 0
		crops[name] = {"x": x, "y": y, "width": width, "height": height}
		x += width + PADDING * 2
		row_height = maxi(row_height, height)
	var height: int = int(nearest_po2(y + row_height + PADDING))
	var packed := Image.create(WIDTH, height, false, Image.FORMAT_RGBA8)
	packed.fill(Color.TRANSPARENT)
	for name in names:
		var source: Dictionary = manifest.sprites[name]
		var target: Dictionary = crops[name]
		var image: Image = source_images[source.atlas]
		# Preserve Godot-processed source RGBA, then duplicate outer texels so
		# linear filtering has the same crop clamp
		# as draw_texture_rect_region(clip_uv=true), with no neighboring bleed.
		for dy in range(-PADDING, int(source.height) + PADDING):
			for dx in range(-PADDING, int(source.width) + PADDING):
				var color: Color = image.get_pixel(int(source.x) + clampi(dx, 0, int(source.width) - 1), int(source.y) + clampi(dy, 0, int(source.height) - 1))
				packed.set_pixel(int(target.x) + dx, int(target.y) + dy, color)
	var png_path: String = "res://assets/render_atlas.png"
	if packed.save_png(png_path) != OK:
		push_error("Could not write the compact render atlas")
		quit(1)
		return
	var layout: Dictionary = {"version": 1, "file": "assets/render_atlas.png", "width": WIDTH, "height": height,
		"padding": PADDING, "source_manifest_sha256": FileAccess.get_sha256(source_path),
		"sha256": FileAccess.get_sha256(png_path), "sprites": crops}
	var output := FileAccess.open("res://assets/render_atlas.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(layout, "\t", true) + "\n")
	print("Packed %s existing sprites into %sx%s; original artwork unchanged" % [names.size(), WIDTH, height])
	quit()
