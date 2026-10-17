extends SceneTree
## Bake curated Kenney module palettes once; preserve the original selected RGBA.
## Run: godot --headless --path godot --script tools/build_render_atlas.gd

const WIDTH: int = 1024
const PADDING: int = 2
const FLOOR_IDS: Array = [0, 32, 38, 39, 43, 44, 45, 47, 48, 49, 53, 56]
const ROOF_IDS: Array = [5, 60, 65, 69, 74, 81, 88, 90, 104, 118]
const PALETTES: Array = [
	{"id": "cream", "wall": "#d6c9aa", "roof": "#936953"},
	{"id": "stone", "wall": "#b0b1a9", "roof": "#626976"},
	{"id": "terracotta", "wall": "#bd8170", "roof": "#a95648"},
	{"id": "sage", "wall": "#a2b297", "roof": "#63776b"},
	{"id": "slate", "wall": "#8eabb4", "roof": "#505d70"},
	{"id": "ochre", "wall": "#c9ac76", "roof": "#776a58"},
]

func _initialize() -> void:
	var source_path: String = "res://assets/manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var source_images: Dictionary = {}
	for name in manifest.atlases:
		# Source Texture2D is essential: source import alpha-edge processing is
		# part of the original renderer's RGBA and must survive repacking.
		source_images[name] = (load("res://" + manifest.atlases[name].file) as Texture2D).get_image()
	var images: Dictionary = {}
	var descriptors: Dictionary = {}
	for name in manifest.sprites:
		var sprite: Dictionary = manifest.sprites[name]
		images[name] = source_images[sprite.atlas].get_region(Rect2i(sprite.x, sprite.y, sprite.width, sprite.height))
		descriptors[name] = {"width": sprite.width, "height": sprite.height, "anchor": sprite.anchor.duplicate()}
	var xml_path: String = ProjectSettings.globalize_path("res://").path_join("../assets/atlases/buildings.xml").simplify_path()
	var xml := XMLParser.new()
	if xml.open(xml_path) != OK:
		push_error("Canonical building crop XML is required: " + xml_path)
		quit(1)
		return
	var sources: Dictionary = {}
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT or xml.get_node_name() != "SubTexture":
			continue
		var filename: String = xml.get_named_attribute_value("name")
		var id: int = int(filename.trim_prefix("buildingTiles_").trim_suffix(".png"))
		if not FLOOR_IDS.has(id) and not ROOF_IDS.has(id):
			continue
		var alias: String = filename.trim_suffix(".png")
		var source: Dictionary = {"source": filename, "material": "wall" if FLOOR_IDS.has(id) else "roof"}
		for field in ["x", "y", "width", "height"]:
			source[field] = int(xml.get_named_attribute_value(field))
		source.anchor = {"x": source.width / 2.0, "y": source.height - source.width / 4.0}
		var crop: Image = source_images.buildings.get_region(Rect2i(source.x, source.y, source.width, source.height))
		source.crop_rgba_sha256 = _rgba_hash(crop)
		source.reference_color = _reference_color(id)
		source.recolor_spans = _material_spans(crop, id)
		sources[alias] = source
		for palette in PALETTES:
			var variant: String = alias + "__" + palette.id
			images[variant] = _recolor(crop, source, Color(palette[source.material]))
			descriptors[variant] = {"width": source.width, "height": source.height, "anchor": source.anchor.duplicate()}
	var names: Array = images.keys()
	names.sort()
	var crops: Dictionary = {}
	var x: int = PADDING
	var y: int = PADDING
	var row_height: int = 0
	for name in names:
		var sprite: Dictionary = descriptors[name]
		if x + int(sprite.width) + PADDING > WIDTH:
			x = PADDING
			y += row_height + PADDING * 2
			row_height = 0
		crops[name] = sprite.duplicate(true)
		crops[name].x = x
		crops[name].y = y
		x += int(sprite.width) + PADDING * 2
		row_height = maxi(row_height, int(sprite.height))
	var height: int = int(nearest_po2(y + row_height + PADDING))
	if height > 2048:
		push_error("Building atlas exceeds single texture budget")
		quit(1)
		return
	var packed := Image.create(WIDTH, height, false, Image.FORMAT_RGBA8)
	packed.fill(Color.TRANSPARENT)
	for name in names:
		var target: Dictionary = crops[name]
		var image: Image = images[name]
		# Extrude the final RGBA two pixels, including transparent RGB.
		for dy in range(-PADDING, image.get_height() + PADDING):
			for dx in range(-PADDING, image.get_width() + PADDING):
				packed.set_pixel(int(target.x) + dx, int(target.y) + dy,
					image.get_pixel(clampi(dx, 0, image.get_width() - 1), clampi(dy, 0, image.get_height() - 1)))
	var png_path: String = "res://assets/render_atlas.png"
	if packed.save_png(png_path) != OK:
		push_error("Could not write the render atlas")
		quit(1)
		return
	var styles: Dictionary = {"version": 1, "palettes": PALETTES, "recipes": _recipes(), "sources": sources,
		"source_png": "assets/atlases/buildings.png", "source_png_sha256": FileAccess.get_sha256("res://assets/atlases/buildings.png"),
		"source_xml": "assets/atlases/buildings.xml", "source_xml_sha256": FileAccess.get_sha256(xml_path),
		"license": "Kenney CC0; assets/licenses/Buildings.txt unchanged",
		"mask_rule": "Authored material color clusters restricted to wall faces or roof surface; spans [y,x,length] select pixels. Source luminance ratio scales target RGB; alpha and unselected RGBA remain exact.",
		"industrial_scope": "Modular shell only; renderer supplies workshop, loading and chimney details. No finished factory source art is claimed.",
		"excluded_foundations": ["buildingTiles_002", "buildingTiles_009", "buildingTiles_018", "buildingTiles_034", "buildingTiles_100", "buildingTiles_108", "buildingTiles_113", "buildingTiles_124"]}
	_write_json("res://assets/building_styles.json", styles)
	var layout: Dictionary = {"version": 1, "file": "assets/render_atlas.png", "width": WIDTH, "height": height,
		"padding": PADDING, "source_manifest_sha256": FileAccess.get_sha256(source_path),
		"building_styles_sha256": FileAccess.get_sha256("res://assets/building_styles.json"),
		"sha256": FileAccess.get_sha256(png_path), "sprites": crops}
	_write_json("res://assets/render_atlas.json", layout)
	print("Packed %s originals + %s selective building variants into %sx%s" % [manifest.sprites.size(), sources.size() * PALETTES.size(), WIDTH, height])
	quit()

func _write_json(path: String, data: Dictionary) -> void:
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(data, "\t", true) + "\n")

func _rgba_hash(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func _reference_color(id: int) -> String:
	if [0, 32, 38, 43, 47].has(id):
		return "#a77d53"
	if [39, 44, 48].has(id):
		return "#c2bb8e"
	if [45, 49].has(id):
		return "#b15252"
	if [53, 56].has(id):
		return "#c2beac"
	if id == 60:
		return "#f0ead4"
	if id == 65:
		return "#cf9c68"
	if [69, 74, 90].has(id):
		return "#dc6868"
	if [81, 88, 104].has(id):
		return "#757575"
	return "#d8d3bf"

func _material_spans(image: Image, id: int) -> Array:
	var spans: Array = []
	for y in range(image.get_height()):
		var start: int = -1
		for x in range(image.get_width() + 1):
			var selected: bool = x < image.get_width() and _is_material(image, id, x, y)
			if selected and start < 0:
				start = x
			if not selected and start >= 0:
				spans.append([y, start, x - start])
				start = -1
	return spans

func _is_material(image: Image, id: int, x: int, y: int) -> bool:
	var c: Color = image.get_pixel(x, y)
	if c.a < 0.98:
		return false
	var r: float = c.r * 255.0
	var g: float = c.g * 255.0
	var b: float = c.b * 255.0
	if FLOOR_IDS.has(id):
		var across: float = absf(float(x) - image.get_width() / 2.0) * 0.5
		# Exclude the roof rim and underside while retaining the wall to its lower edge.
		if y < image.get_height() - 35.5 - across + 3.0 or y > image.get_height() - across - 1.0:
			return false
		if [0, 32, 38, 43, 47].has(id):
			return r > g * 1.22 and r < g * 1.45 and g > b * 1.30 and g < b * 1.75 and r < 190
		if [39, 44, 48].has(id):
			return r > g and r - g < 15 and g - b > 25 and r < b * 1.6
		if [45, 49].has(id):
			return r > g * 1.6 and absf(g - b) < 8
		return absf(r - 194) < 3 and absf(g - 190) < 3 and absf(b - 172) < 3 or (r >= 143 and r <= 153 and g >= 140 and g <= 150 and b >= 126 and b <= 135)
	if id == 65:
		return r > g * 1.22 and g > b * 1.30 and r > 150
	if [69, 74, 90].has(id):
		return r > g * 1.6 and absf(g - b) < 8
	if [81, 88, 104].has(id):
		return maxf(r, maxf(g, b)) - minf(r, minf(g, b)) < 3 and r >= 80 and r <= 140
	if id == 60:
		return (r > 220 and g > 210 and b > 190) or (absf(r - 151) < 1 and absf(g - 147) < 1 and absf(b - 133) < 1)
	# Flat roofs: retain parapet, rim, ventilation and their shadows.
	var diamond: float = absf(float(x) - image.get_width() / 2.0) / 41.0 + absf(float(y) - 28.0) / 20.0
	return diamond < 1.0 and r > 185 and r > g and g > b * 1.07 and r < b * 1.18

func _recolor(crop: Image, source: Dictionary, target: Color) -> Image:
	var result: Image = crop.duplicate()
	var reference: Color = Color(source.reference_color)
	for span in source.recolor_spans:
		for x in range(int(span[1]), int(span[1]) + int(span[2])):
			var before: Color = crop.get_pixel(x, int(span[0]))
			var shade: float = (before.r + before.g + before.b) / (reference.r + reference.g + reference.b)
			result.set_pixel(x, int(span[0]), Color(clampf(target.r * shade, 0, 1), clampf(target.g * shade, 0, 1), clampf(target.b * shade, 0, 1), before.a))
	return result

func _recipe(id: String, floor_id: int, roof_id: int, awning: bool = false) -> Dictionary:
	var recipe: Dictionary = {"id": id, "floor": "buildingTiles_%03d" % floor_id, "roof": "buildingTiles_%03d" % roof_id, "step": 35.5}
	if awning:
		recipe.awning = true
	return recipe

func _recipes() -> Dictionary:
	return {
		"house": [_recipe("arched_hip", 38, 60), _recipe("paired_gable", 39, 69), _recipe("square_hip", 43, 74), _recipe("arched_gable", 44, 81), _recipe("square_reverse_hip", 47, 88), _recipe("arched_barrel", 49, 90)],
		"apt": [_recipe("narrow_terrace", 45, 118), _recipe("paired_terrace", 48, 5), _recipe("arched_barrel_block", 53, 104), _recipe("square_hip_block", 56, 65)],
		"shop": [_recipe("glass_corner", 0, 118, true), _recipe("arched_market", 38, 5, true), _recipe("arched_boutique", 49, 81, true), _recipe("square_corner", 56, 69, true)],
		"office": [_recipe("glass_terrace", 0, 5), _recipe("square_terrace", 43, 118), _recipe("arched_gable_office", 53, 81), _recipe("square_barrel_office", 56, 104)],
		"light": [_recipe("workshop_terrace", 32, 118), _recipe("workshop_flat", 43, 5), _recipe("workshop_gable", 56, 81)],
		"heavy": [_recipe("works_barrel", 32, 104), _recipe("works_terrace", 47, 118), _recipe("works_flat", 53, 5)]}
