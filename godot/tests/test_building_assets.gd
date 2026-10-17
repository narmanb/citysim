extends SceneTree
## Validate derived building assets independently of the atlas builder.

func _initialize() -> void:
	if not FileAccess.file_exists("res://assets/building_styles.json"):
		_fail("Curated building recipes and selective palette metadata are required")
		return
	var styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/building_styles.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_atlas.json"))
	var packed: Image = (load("res://" + layout.file) as Texture2D).get_image()
	var original: Image = (load("res://assets/atlases/buildings.png") as Texture2D).get_image()
	if styles.version != 1 or styles.palettes.size() != 6 or layout.width > 2048 or layout.height > 2048:
		_fail("Version, six palettes, and single atlas budget must be retained")
		return
	if FileAccess.get_sha256("res://assets/atlases/buildings.png") != styles.source_png_sha256:
		_fail("Building source receipt changed")
		return
	var xml_path: String = ProjectSettings.globalize_path("res://").path_join("../assets/atlases/buildings.xml").simplify_path()
	if FileAccess.get_sha256(xml_path) != styles.source_xml_sha256 or FileAccess.get_sha256("res://assets/building_styles.json") != layout.building_styles_sha256:
		_fail("Canonical crop or recipe/mask receipt changed")
		return
	var canonical: Dictionary = {}
	var xml := XMLParser.new()
	if xml.open(xml_path) != OK:
		_fail("Canonical source XML unavailable")
		return
	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "SubTexture":
			var rect: Dictionary = {}
			for field in ["x", "y", "width", "height"]:
				rect[field] = int(xml.get_named_attribute_value(field))
			canonical[xml.get_named_attribute_value("name")] = rect
	var occupied: Array[Rect2i] = []
	for alias in layout.sprites:
		var sprite: Dictionary = layout.sprites[alias]
		var region := Rect2i(int(sprite.x) - 2, int(sprite.y) - 2, int(sprite.width) + 4, int(sprite.height) + 4)
		if region.position.x < 0 or region.position.y < 0 or region.end.x > packed.get_width() or region.end.y > packed.get_height():
			_fail("Extruded sprite exceeds the texture: " + alias)
			return
		for prior in occupied:
			if prior.intersects(region):
				_fail("Sprites or their filtering borders overlap: " + alias)
				return
		occupied.append(region)
	var minimums: Dictionary = {"house": 6, "apt": 4, "shop": 4, "office": 4, "light": 3, "heavy": 3}
	for role in minimums:
		if styles.recipes.get(role, []).size() < minimums[role]:
			_fail("Missing curated recipes for " + role)
			return
		var distinct: Dictionary = {}
		for recipe in styles.recipes[role]:
			distinct[recipe.floor + "/" + recipe.roof] = true
			if recipe.get("step", 0) != 35.5:
				_fail("Floor lift changed for " + recipe.id)
				return
			for palette in styles.palettes:
				for piece in [recipe.floor, recipe.roof]:
					if not layout.sprites.has(piece + "__" + palette.id):
						_fail("Missing baked recipe alias " + piece + "__" + palette.id)
						return
		if distinct.size() != styles.recipes[role].size():
			_fail("Recipes must vary actual module combinations: " + role)
			return
	var checked: int = 0
	for alias in styles.sources:
		var source: Dictionary = styles.sources[alias]
		for field in ["x", "y", "width", "height"]:
			if source[field] != canonical[source.source][field]:
				_fail("Crop differs from canonical XML: " + alias)
				return
		var crop := original.get_region(Rect2i(source.x, source.y, source.width, source.height))
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(crop.get_data())
		if hash.finish().hex_encode() != source.crop_rgba_sha256:
			_fail("Imported crop receipt changed: " + alias)
			return
		var mask: Dictionary = {}
		for span in source.recolor_spans:
			for x in range(int(span[1]), int(span[1]) + int(span[2])):
				mask[Vector2i(x, int(span[0]))] = true
		if mask.size() < 250 or mask.size() > source.width * source.height * 0.65:
			_fail("Recolor mask must select a material, not the full sprite: " + alias)
			return
		if alias == "buildingTiles_045" and not mask.has(Vector2i(50, 82)):
			_fail("The opaque wall material must extend to its lower edge without a source-red stripe")
			return
		for palette in styles.palettes:
			var variant: String = alias + "__" + palette.id
			var target: Dictionary = layout.sprites[variant]
			if target.width != source.width or target.height != source.height or target.anchor.x != float(source.width) / 2.0 or target.anchor.y != float(source.height) - float(source.width) / 4.0:
				_fail("Dimensions/ground anchor changed: " + variant)
				return
			var changed: int = 0
			var preserved_windows: int = 0
			var expected_base: Color = Color(palette[source.material])
			var reference: Color = Color(source.reference_color)
			for y in range(-2, int(source.height) + 2):
				for x in range(-2, int(source.width) + 2):
					var point := Vector2i(clampi(x, 0, int(source.width) - 1), clampi(y, 0, int(source.height) - 1))
					var before: Color = crop.get_pixelv(point)
					var after: Color = packed.get_pixel(int(target.x) + x, int(target.y) + y)
					if before.a != after.a:
						_fail("Alpha/filter border changed: " + variant)
						return
					if not mask.has(point):
						if before != after:
							_fail("Window, trim, or outline outside material mask changed: " + variant)
							return
						if before.b > before.r * 1.15 and before.a > 0.9:
							preserved_windows += 1
					else:
						var shade: float = (before.r + before.g + before.b) / (reference.r + reference.g + reference.b)
						var expected := Color(clampf(expected_base.r * shade, 0, 1), clampf(expected_base.g * shade, 0, 1), clampf(expected_base.b * shade, 0, 1), before.a)
						if absf(after.r - expected.r) > 1.01 / 255.0 or absf(after.g - expected.g) > 1.01 / 255.0 or absf(after.b - expected.b) > 1.01 / 255.0:
							_fail("Authored shading ratio lost: " + variant)
							return
						if before != after:
							changed += 1
			if changed < 250 or (source.material == "wall" and preserved_windows < 20):
				_fail("Expected material recolor and unchanged glazing: " + variant)
				return
			checked += 1
	print("Building assets: %s recipes, %s baked selective variants, anchors/alpha/glazing/shading/borders: PASS" % [24, checked])
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
