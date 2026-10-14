class_name IsometricView
extends Control
## Native retained 2D presentation. No city simulation or spending occurs here.
## Control.scale is a Vector2, so map zoom is exposed as tile_scale instead.

signal tile_pressed(index: int)
signal stroke_started
signal tile_painted(index: int)
signal stroke_finished
signal selection_changed(index: int)

const Layer = preload("res://view/iso_layer.gd")
const N: int = 52
const BASE: float = 28.0
const ELEVATION: float = 0.15
const ZCOL: Dictionary = {"res": Color("85dca3"), "com": Color("5aa8ed"), "ind": Color("dcac75")}
const TERRAIN_COLOR: Dictionary = {"grass": Color("8ab549"), "water": Color("9cd4e2"), "sand": Color("d8d19e"), "dirt": Color("ba8c5d")}

var world = null
var tool: String = "pan"
var mode: String = "tapPan"
var overlay: String = "none":
	set(value):
		overlay = value
		if is_node_ready():
			_update_overlay()
			_update_static_alpha()
var selected: int = -1:
	set(value):
		selected = value
		if is_node_ready():
			_update_indicators()
var tile_scale: float = BASE:
	set(value):
		tile_scale = clampf(value, 2.0, 100.0)
		_apply_camera()
var camera: Vector2 = Vector2.ZERO:
	set(value):
		camera = value
		_apply_camera()
var hover: int = -1
var metrics: Dictionary = {"ground_redraws": 0, "static_objects": 0, "visible_tiles": 0, "agents": 0}

var _city: Node2D
var _overlay_layer
var _indicator_layer
var _manifest: Dictionary = {}
var _textures: Dictionary = {}
var _agent_layers: Array = []
var _object_layers: Array = []
var _touches: Dictionary = {}
var _pointer_start: Vector2
var _pointer_previous: Vector2
var _anchor: int = -1
var _last_tile: int = -1
var _moved: bool = false
var _gesture: bool = false
var _right_pan: bool = false
var _stroke_active: bool = false
var _painted: Dictionary = {}
var _pending_tiles: Array = []
var _elapsed: float = 0.0
var _last_indicator_tick: int = 0
var _refresh_pending: bool = false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	_city = Node2D.new()
	_city.name = "City"
	add_child(_city)
	_overlay_layer = Layer.new()
	_overlay_layer.name = "Overlays"
	_overlay_layer.z_index = 3000
	_city.add_child(_overlay_layer)
	_indicator_layer = Layer.new()
	_indicator_layer.name = "Indicators"
	_indicator_layer.z_index = 3010
	_city.add_child(_indicator_layer)
	var text: String = FileAccess.get_file_as_string("res://assets/manifest.json")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_manifest = parsed
		for atlas_name in _manifest.get("atlases", {}):
			var path: String = "res://" + str(_manifest.atlases[atlas_name].file)
			_textures[atlas_name] = load(path)
	resized.connect(_on_resized)
	_apply_camera()
	queue_redraw()
	if world != null:
		refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("193848"))

func _on_resized() -> void:
	queue_redraw()

func set_world(value) -> void:
	world = value
	selected = -1
	hover = -1
	if is_node_ready():
		refresh()

func fit_city() -> void:
	# Include the full diamond with space above it for raised terrain and
	# buildings. Unlike the former fixed-scale Fit, this works on phones too.
	var bounds: Rect2 = Rect2(-float(N), -4.0, N * 2.0, N + 5.0)
	var available: Vector2 = (size - Vector2(32, 32)).max(Vector2.ONE)
	tile_scale = minf(available.x / bounds.size.x, available.y / bounds.size.y)
	camera = size * 0.5 - bounds.get_center() * tile_scale

func zoom_at(factor: float, at: Vector2) -> void:
	if factor <= 0.0:
		return
	var next: float = clampf(tile_scale * factor, 2.0, 100.0)
	var ratio: float = next / tile_scale
	camera = at + (camera - at) * ratio
	tile_scale = next

func _apply_camera() -> void:
	if is_instance_valid(_city):
		_city.position = camera
		_city.scale = Vector2.ONE * tile_scale / BASE

func _point(x: float, y: float, elevation: float = 0.0) -> Vector2:
	return Vector2((x - y) * BASE, (x + y) * BASE * 0.5 - elevation * BASE * ELEVATION)

func _unproject(point: Vector2) -> Vector2:
	var p: Vector2 = (point - camera) / tile_scale
	return Vector2(p.y + p.x * 0.5, p.y - p.x * 0.5)

func tile_to_screen(index: int) -> Vector2:
	if world == null or index < 0 or index >= world.tiles.size():
		return Vector2.INF
	var tile: Dictionary = world.tiles[index]
	return camera + _point(index % N + 0.5, floori(float(index) / N) + 0.5, float(tile.get("elev", 0))) * tile_scale / BASE

func screen_to_tile(point: Vector2) -> int:
	if world == null:
		return -1
	var best: int = -1
	var depth: int = -1
	# The model validates elevations to this range. Check all planes and keep
	# the frontmost cap, just as the retained records are depth ordered.
	for elevation in range(-3, 6):
		var p: Vector2 = _unproject(point + Vector2(0, elevation * tile_scale * ELEVATION))
		var x: int = floori(p.x)
		var y: int = floori(p.y)
		if x < 0 or y < 0 or x >= N or y >= N:
			continue
		var index: int = y * N + x
		if index >= world.tiles.size() or int(world.tiles[index].get("elev", 0)) != elevation:
			continue
		if x + y >= depth:
			best = index
			depth = x + y
	return best

func _neighbors(index: int) -> Array:
	var out: Array = []
	var x: int = index % N
	var y: int = floori(float(index) / N)
	if y > 0: out.append(index - N)
	if x < N - 1: out.append(index + 1)
	if y < N - 1: out.append(index + N)
	if x > 0: out.append(index - 1)
	return out

func _road_mask(index: int, kind: String = "road") -> int:
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var result: int = 0
	if y > 0 and world.tiles[index - N].get(kind, false): result |= 1
	if x < N - 1 and world.tiles[index + 1].get(kind, false): result |= 2
	if y < N - 1 and world.tiles[index + N].get(kind, false): result |= 4
	if x > 0 and world.tiles[index - 1].get(kind, false): result |= 8
	return result

func _new_layer(depth: float, object: bool = false):
	var layer = Layer.new()
	layer.z_index = clampi(roundi(depth * 20.0), 0, 2999)
	_city.add_child(layer)
	if object:
		_object_layers.append(layer)
	return layer

func refresh() -> void:
	# A touch stroke emits all committed tiles together. Coalesce controller
	# invalidations so a long stroke rebuilds the static city only once.
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_rebuild")

func _rebuild() -> void:
	_refresh_pending = false
	if not is_instance_valid(_city):
		return
	for child in _city.get_children():
		if child != _overlay_layer and child != _indicator_layer:
			_city.remove_child(child)
			child.queue_free()
	_agent_layers.clear()
	_object_layers.clear()
	if world == null:
		_overlay_layer.commands.clear()
		_indicator_layer.commands.clear()
		_overlay_layer.queue_redraw()
		_indicator_layer.queue_redraw()
		return
	for sum in range(2 * N - 1):
		for x in range(maxi(0, sum - N + 1), mini(N - 1, sum) + 1):
			var y: int = sum - x
			var index: int = y * N + x
			if index >= world.tiles.size():
				continue
			var tile: Dictionary = world.tiles[index]
			var elevation: float = float(tile.get("elev", 0))
			var ground = _new_layer(sum + 1.0)
			_draw_ground(ground, index)
			if tile.get("tree", false) and tile.get("terrain", "grass") != "water" and not tile.get("road", false) and not tile.get("rail", false) and not tile.get("civic", "") and not tile.get("level", 0):
				_tree(_new_layer(sum + 1.1, true), x + 0.5, y + 0.5, elevation)
			if tile.get("line", false):
				_draw_pole(_new_layer(sum + 1.2, true), index)
			if tile.get("civic", ""):
				_draw_civic(_new_layer(sum + 1.6, true), tile, x, y)
			if int(tile.get("level", 0)) > 0:
				var parcel: Dictionary = world.parcel_info(index) if tile.get("parcel", 0) else {}
				if not parcel.is_empty() and int(parcel.get("root", index)) != index:
					continue
				var fp: Rect2i = _parcel_footprint(parcel.get("members", [index]))
				var bx: float = fp.position.x + fp.size.x * 0.5
				var by: float = fp.position.y + fp.size.y * 0.5
				var span: float = mini(fp.size.x, fp.size.y)
				_draw_development(_new_layer(fp.position.x + fp.position.y + fp.size.x + fp.size.y - 0.1, true), tile, bx, by, span, index)
	metrics.ground_redraws += 1
	metrics.static_objects = _object_layers.size()
	metrics.visible_tiles = world.tiles.size()
	_update_static_alpha()
	_update_overlay()
	_update_indicators()
	_update_agents()

func _rect_points(x: float, y: float, elevation: float, left: float = 0, top: float = 0, width: float = 1, height: float = 1) -> PackedVector2Array:
	return PackedVector2Array([_point(x + left, y + top, elevation), _point(x + left + width, y + top, elevation), _point(x + left + width, y + top + height, elevation), _point(x + left, y + top + height, elevation)])

func _diamond(layer, x: float, y: float, elevation: float, fill: Color, outline: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
	var points: PackedVector2Array = _rect_points(x, y, elevation)
	if fill.a > 0:
		layer.polygon(points, fill)
	if outline.a > 0:
		points.append(points[0])
		layer.line(points, outline, width)

func _surface(layer, name: String, x: float, y: float, elevation: float, left: float = 0, top: float = 0, width: float = 1, height: float = 1) -> void:
	if not _manifest.get("sprites", {}).has(name):
		return
	var sprite: Dictionary = _manifest.sprites[name]
	var texture: Texture2D = _textures.get(sprite.atlas)
	if texture == null:
		return
	var uv: PackedVector2Array = PackedVector2Array()
	for p in [Vector2(left, top), Vector2(left + width, top), Vector2(left + width, top + height), Vector2(left, top + height)]:
		# Sample only the 132 by 66 cap, never the PNG's foundation walls.
		uv.append((Vector2(float(sprite.x) + 66.0 + (p.x - p.y) * 66.0, float(sprite.y) + (p.x + p.y) * 33.0)) / Vector2(texture.get_size()))
	layer.polygon(_rect_points(x, y, elevation, left, top, width, height), Color.WHITE, texture, uv)

func _sprite(layer, name: String, point: Vector2, span: float = 1.0, lift: float = 0.0, color: Color = Color.WHITE) -> void:
	if not _manifest.get("sprites", {}).has(name):
		return
	var sprite: Dictionary = _manifest.sprites[name]
	var texture: Texture2D = _textures.get(sprite.atlas)
	if texture == null:
		return
	var factor: float = BASE / 66.0 * span
	var rect: Rect2 = Rect2(point - Vector2(float(sprite.anchor.x), float(sprite.anchor.y) + lift) * factor, Vector2(float(sprite.width), float(sprite.height)) * factor)
	layer.sprite(texture, rect, Rect2(float(sprite.x), float(sprite.y), float(sprite.width), float(sprite.height)), color)

func _draw_ground(layer, index: int) -> void:
	var tile: Dictionary = world.tiles[index]
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var elevation: float = float(tile.get("elev", 0))
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var next: Vector2i = Vector2i(x, y) + axis
		var lower: float = float(world.tiles[next.y * N + next.x].get("elev", 0)) if next.x < N and next.y < N else 0.0
		if elevation > lower:
			var a: Vector2 = Vector2(x + 1, y) if axis.x else Vector2(x, y + 1)
			var b: Vector2 = Vector2(x + 1, y + 1)
			layer.polygon(PackedVector2Array([_point(a.x, a.y, elevation), _point(b.x, b.y, elevation), _point(b.x, b.y, lower), _point(a.x, a.y, lower)]), Color("8b7954") if axis.x else Color("a18b62"))
	var name: String = "water" if tile.get("terrain", "grass") == "water" else "dirt" if tile.get("channel", false) else "sand" if tile.get("biome", "") == "desert" else "grass"
	_diamond(layer, x, y, elevation, TERRAIN_COLOR[name], TERRAIN_COLOR[name], 0.6)
	_surface(layer, name, x, y, elevation)
	if name != "water":
		for j in _neighbors(index):
			if world.tiles[j].get("terrain", "grass") != "water": continue
			var rect: Rect2 = Rect2(0, 0, 1, 0.1) if j == index - N else Rect2(0, 0.9, 1, 0.1) if j == index + N else Rect2(0, 0, 0.1, 1) if j == index - 1 else Rect2(0.9, 0, 0.1, 1)
			layer.polygon(_rect_points(x, y, elevation, rect.position.x, rect.position.y, rect.size.x, rect.size.y), Color("dcc78d"))
	if tile.get("zone", ""):
		_draw_zone(layer, index)
	if tile.get("road", false):
		_draw_road(layer, x, y, elevation, _road_mask(index), float(tile.get("condition", 1.0)), name == "water")
	if tile.get("rail", false):
		_draw_rail(layer, index)
	if tile.get("pipe", false):
		_connections(layer, index, "pipe", Color("6fe0ec") if _field("water", index) else Color("cf799a"), 1.96, BASE * 0.15)
	if tile.get("channel", false) and name != "water":
		layer.line(PackedVector2Array([_point(x + 0.2, y + 0.5, elevation), _point(x + 0.8, y + 0.5, elevation)]), Color("796345"), BASE * 0.12)

func _draw_zone(layer, index: int) -> void:
	var tile: Dictionary = world.tiles[index]
	var color: Color = ZCOL.get(tile.get("zone", ""), Color.WHITE)
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var elevation: float = float(tile.get("elev", 0))
	_diamond(layer, x, y, elevation, Color(color, 0.133 if tile.get("level", 0) else 0.4))
	var parcel: int = int(tile.get("parcel", 0))
	if not parcel:
		_diamond(layer, x, y, elevation, Color.TRANSPARENT, color)
		return
	for side in [[0, -1, 0, 0, 1, 0], [1, 0, 1, 0, 1, 1], [0, 1, 1, 1, 0, 1], [-1, 0, 0, 1, 0, 0]]:
		var xx: int = x + side[0]
		var yy: int = y + side[1]
		if xx >= 0 and yy >= 0 and xx < N and yy < N and int(world.tiles[yy * N + xx].get("parcel", 0)) == parcel:
			continue
		layer.line(PackedVector2Array([_point(x + side[2], y + side[3], elevation), _point(x + side[4], y + side[5], elevation)]), color, BASE * 0.045)

func _draw_road(layer, x: int, y: int, elevation: float, mask: int, condition: float, bridge: bool) -> void:
	_diamond(layer, x, y, elevation, Color("d8d2b8"))
	_surface(layer, "pavement", x, y, elevation)
	# Non-overlapping center and arms avoid doubling translucent atlas edges.
	_surface(layer, "asphalt", x, y, elevation, 0.23, 0.23, 0.54, 0.54)
	if mask & 1: _surface(layer, "asphalt", x, y, elevation, 0.23, 0, 0.54, 0.23)
	if mask & 2: _surface(layer, "asphalt", x, y, elevation, 0.77, 0.23, 0.23, 0.54)
	if mask & 4: _surface(layer, "asphalt", x, y, elevation, 0.23, 0.77, 0.54, 0.23)
	if mask & 8: _surface(layer, "asphalt", x, y, elevation, 0, 0.23, 0.23, 0.54)
	if condition < 0.5:
		_diamond(layer, x, y, elevation, Color("382f2680"))
	if bridge:
		var edges: Array = [[0.15, 0, 0.15, 1], [0.85, 0, 0.85, 1]] if mask & 5 else [[0, 0.15, 1, 0.15], [0, 0.85, 1, 0.85]]
		for edge in edges:
			layer.line(PackedVector2Array([_point(x + edge[0], y + edge[1], elevation) - Vector2(0, 3), _point(x + edge[2], y + edge[3], elevation) - Vector2(0, 3)]), Color("dfc99b"), BASE * 0.05)

func _connections(layer, index: int, kind: String, color: Color, width: float, shift: float = 0) -> void:
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var elevation: float = float(world.tiles[index].get("elev", 0))
	var center: Vector2 = _point(x + 0.5, y + 0.5, elevation) + Vector2(0, shift)
	var connected: bool = false
	for j in _neighbors(index):
		var tile: Dictionary = world.tiles[j]
		if not tile.get(kind, false) and not (kind == "pipe" and tile.get("civic", "") in ["pump", "tower"]): continue
		var endpoint: Vector2 = _point(x + 0.5 + float(j % N - x) * 0.5, y + 0.5 + float(floori(float(j) / N) - y) * 0.5, elevation) + Vector2(0, shift)
		layer.line(PackedVector2Array([center, endpoint]), color, width)
		connected = true
	if not connected:
		layer.line(PackedVector2Array([center - Vector2(BASE * 0.1, 0), center + Vector2(BASE * 0.1, 0)]), color, width)

func _draw_rail(layer, index: int) -> void:
	_connections(layer, index, "rail", Color("695039"), BASE * 0.22)
	_connections(layer, index, "rail", Color("dbc699"), BASE * 0.09)
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var elevation: float = float(world.tiles[index].get("elev", 0))
	var mask: int = _road_mask(index, "rail")
	for axis in [[1, 0, -1], [2, 1, 0], [4, 0, 1], [8, -1, 0]]:
		if not mask & axis[0]: continue
		for distance in [0.12, 0.32, 0.48]:
			var px: float = x + 0.5 + axis[1] * distance
			var py: float = y + 0.5 + axis[2] * distance
			layer.line(PackedVector2Array([_point(px - axis[2] * 0.09, py + axis[1] * 0.09, elevation), _point(px + axis[2] * 0.09, py - axis[1] * 0.09, elevation)]), Color("66503c"), BASE * 0.065)

func _tree(layer, x: float, y: float, elevation: float) -> void:
	_sprite(layer, "tree", _point(x, y, elevation), 2.0)

func _box(layer, x: float, y: float, elevation: float, width: float, depth: float, height: float, colors: Array) -> void:
	var points: PackedVector2Array = _rect_points(x, y, elevation, 0, 0, width, depth)
	var roof: PackedVector2Array = PackedVector2Array()
	for point in points: roof.append(point - Vector2(0, height))
	layer.polygon(PackedVector2Array([roof[1], roof[2], points[2], points[1]]), Color(colors[1]))
	layer.polygon(PackedVector2Array([roof[2], roof[3], points[3], points[2]]), Color(colors[2]))
	layer.polygon(roof, Color(colors[0]))

func _draw_pole(layer, index: int) -> void:
	var x: int = index % N
	var y: int = floori(float(index) / N)
	var point: Vector2 = _point(x + 0.5, y + 0.5, float(world.tiles[index].get("elev", 0)))
	var top: Vector2 = point - Vector2(0, BASE * 0.65)
	layer.line(PackedVector2Array([point, top]), Color("614d39"), BASE * 0.07)
	layer.line(PackedVector2Array([top - Vector2(BASE * 0.16, 0), top + Vector2(BASE * 0.16, 0)]), Color("d5b97b"), BASE * 0.05)
	for j in _neighbors(index):
		if not world.tiles[j].get("line", false) and world.tiles[j].get("civic", "") != "plant": continue
		var endpoint: Vector2 = _point(j % N + 0.5, floori(float(j) / N) + 0.5, float(world.tiles[j].get("elev", 0))) - Vector2(0, BASE * 0.65)
		layer.line(PackedVector2Array([top, (top + endpoint) * 0.5 + Vector2(0, BASE * 0.07), endpoint]), Color("b9af8b"), BASE * 0.025)

func _draw_civic(layer, tile: Dictionary, x: int, y: int) -> void:
	var kind: String = str(tile.get("civic", ""))
	var elevation: float = float(tile.get("elev", 0))
	if kind == "park":
		_tree(layer, x + 0.35, y + 0.35, elevation)
		_tree(layer, x + 0.7, y + 0.65, elevation)
		return
	var palette: Dictionary = {"plant": ["a4a6a0", "525c60", "737d80"], "pump": ["84c7d6", "347484", "4994a3"], "tower": ["b2dbe0", "417c8b", "70a8b5"], "police": ["82acce", "385c89", "587d9f"], "fire": ["d98764", "9a3d38", "bd5e4c"], "school": ["e3cc86", "a2844c", "c1a66a"], "hospital": ["f1e8db", "a69d96", "d6cfc1"], "station": ["bcb1cd", "675d82", "91839f"]}
	var colors: Array = palette.get(kind, ["bbbbbb", "777777", "999999"])
	var height: float = BASE * (1.2 if kind == "tower" else 0.55 if kind == "plant" else 0.6)
	_box(layer, x + 0.16, y + 0.16, elevation, 0.68, 0.68, height, colors)
	if kind == "plant":
		for offset in [0.25, 0.55]:
			_box(layer, x + offset, y + 0.27, elevation, 0.12, 0.12, BASE, ["cabfb0", "737572", "949891"])
	var labels: Dictionary = {"plant": "PWR", "pump": "W", "tower": "T", "police": "POL", "fire": "F", "school": "E", "hospital": "+", "station": "R"}
	layer.label_at(labels.get(kind, "?"), _point(x + 0.5, y + 0.5, elevation) + Vector2(0, -height + 3), 10, Color("fff5da"))

func _parcel_footprint(members: Array) -> Rect2i:
	if members.is_empty(): return Rect2i(0, 0, 1, 1)
	var first: int = int(members[0])
	var best: Rect2i = Rect2i(first % N, floori(float(first) / N), 1, 1)
	var contained: Dictionary = {}
	for i in members: contained[int(i)] = true
	for i in members:
		var x: int = int(i) % N
		var y: int = floori(float(i) / N)
		for width in [1, 2]:
			for depth in [1, 2]:
				if x + width > N or y + depth > N or width * depth <= best.size.x * best.size.y: continue
				var fits: bool = true
				for dy in range(depth):
					for dx in range(width):
						if not contained.has((y + dy) * N + x + dx): fits = false
				if fits: best = Rect2i(x, y, width, depth)
	return best

func _draw_development(layer, tile: Dictionary, x: float, y: float, span: float, index: int) -> void:
	var zone: String = str(tile.get("zone", "res"))
	var type: String = str(tile.get("zoneType", ""))
	if type.is_empty(): type = str(tile.get("resType", ""))
	if type.is_empty(): type = "house" if zone == "res" else "shop" if zone == "com" else "light"
	var level: int = int(tile.get("level", 1))
	var elevation: float = float(tile.get("elev", 0))
	var abandoned: bool = bool(tile.get("abandoned", false))
	if zone == "ind":
		var size_factor: float = BASE * span
		var footprint: float = 0.7 * span
		var height: float = size_factor * ((0.4 if type == "heavy" else 0.25) + mini(4, level) * 0.1)
		_box(layer, x - footprint * 0.5, y - footprint * 0.5, elevation, footprint, footprint, height, ["99968a", "69665b", "817e70"] if abandoned else ["c3b793", "6c716d", "999482"])
		if type == "heavy": _box(layer, x + footprint * 0.25, y - footprint * 0.2, elevation, footprint * 0.16, footprint * 0.16, size_factor * 1.4, ["a18464", "5d5350", "8b7268"])
		layer.label_at("LOG" if type == "logistics" else "H" if type == "heavy" else "IND", _point(x, y, elevation) + Vector2(0, -height + 3), 10, Color("342f29"))
		return
	var floors: int = clampi(level, 1, 3) if type in ["house", "shop"] else mini(5, level + 1)
	var variant: int = int(tile.get("parcel", index)) % 2
	var sprite: String = ("house" if variant else "houseBeige") if type == "house" else "office" if type in ["shop", "office"] else "house"
	var step: float = 35.5
	var tint: Color = Color(0.65, 0.65, 0.65, 0.65) if abandoned else Color.WHITE
	for floor_number in range(floors):
		_sprite(layer, sprite, _point(x, y, elevation), span, floor_number * step, tint)
	_sprite(layer, "roof" if type == "house" else "flatRoof", _point(x, y, elevation), span, floors * step, tint)
	if abandoned:
		layer.label_at("×", _point(x, y, elevation) - Vector2(0, floors * step * BASE / 66.0 * span + 8), 11, Color("f5ba90"))

func _field(name: String, index: int, fallback: float = 0.0) -> float:
	var values = world.fields.get(name, [])
	return float(values[index]) if index < values.size() else fallback

func _overlay_color(index: int) -> Color:
	var tile: Dictionary = world.tiles[index]
	var kind: String = overlay
	if kind == "none": return Color.TRANSPARENT
	if kind == "zoning":
		return Color(ZCOL.get(tile.get("zone", ""), Color.TRANSPARENT), 0.4) if tile.get("zone", "") else Color.TRANSPARENT
	if kind in ["power", "water"]:
		var supplied: bool = _field(kind, index) > 0
		var civic: String = str(tile.get("civic", ""))
		if kind == "water" and civic == "pump": supplied = supplied and _field("power", index) > 0
		if kind == "water" and civic == "tower": supplied = float(tile.get("storage", 0)) > 0
		if (kind == "water" and civic in ["pump", "tower"]) or (kind == "power" and civic == "pump") or tile.get("zone", "") or tile.get("level", 0) or (civic and civic not in ["plant", "pump", "tower", "park"]):
			return Color("4ad8c057") if supplied else Color("ef464b9c")
		if tile.get("line" if kind == "power" else "pipe", false): return Color("38e8ed87") if supplied else Color("e75488a0")
		return Color.TRANSPARENT
	if kind == "roadCondition":
		var condition: float = float(tile.get("condition", 1))
		return Color(220.0 * (1.0 - condition) / 255.0, 190.0 * condition / 255.0, 35.0 / 255.0, 0.65) if tile.get("road", false) else Color.TRANSPARENT
	if kind == "traffic":
		var heat_values = world.get("trafficHeat")
		var heat: float = float(heat_values[index]) if heat_values != null and index < heat_values.size() else 0.0
		return Color(minf(255.0, 50.0 + heat * 18.0) / 255.0, maxf(25.0, 190.0 - heat * 17.0) / 255.0, 35.0 / 255.0, 0.67) if tile.get("road", false) else Color.TRANSPARENT
	var value: float = _field(kind, index)
	if kind in ["police", "fire", "school", "hospital"]: return Color(60.0 / 255.0, 210.0 / 255.0, (130.0 + value * 90.0) / 255.0, 0.1 + value * 0.64)
	if kind in ["pollution", "crime"]: return Color(222.0 / 255.0, (180.0 - value * 1.35) / 255.0, (75.0 if kind == "crime" else 40.0) / 255.0, clampf(0.08 + value / 145.0, 0, 1))
	return Color((230.0 - value * 1.7) / 255.0, (70.0 + value * 1.7) / 255.0, 70.0 / 255.0, 0.38)

func _update_static_alpha() -> void:
	for layer in _object_layers:
		layer.modulate.a = 1.0 if overlay == "none" else 0.7

func _update_overlay() -> void:
	if not is_instance_valid(_overlay_layer): return
	_overlay_layer.commands.clear()
	if world != null and overlay != "none":
		for index in range(world.tiles.size()):
			var color: Color = _overlay_color(index)
			if color.a > 0:
				_diamond(_overlay_layer, index % N, floori(float(index) / N), float(world.tiles[index].get("elev", 0)), color)
	_overlay_layer.queue_redraw()

func _update_indicators() -> void:
	if not is_instance_valid(_indicator_layer): return
	_indicator_layer.commands.clear()
	if world != null:
		for index in range(world.tiles.size()):
			var tile: Dictionary = world.tiles[index]
			if not tile.get("fire", false): continue
			var p: Vector2 = _point(index % N + 0.5, floori(float(index) / N) + 0.5, float(tile.get("elev", 0)))
			_indicator_layer.polygon(PackedVector2Array([p - Vector2(BASE * 0.16, 0), p - Vector2(0, BASE * 0.8), p + Vector2(BASE * 0.18, -BASE * 0.1)]), Color("f69b3b"))
		for index in _pending_tiles:
			if index >= 0 and index < world.tiles.size():
				_diamond(_indicator_layer, index % N, floori(float(index) / N), float(world.tiles[index].get("elev", 0)), Color("eaf2a04d"))
		if selected >= 0 and selected < world.tiles.size():
			_diamond(_indicator_layer, selected % N, floori(float(selected) / N), float(world.tiles[selected].get("elev", 0)), Color.TRANSPARENT, Color("fff3ad"), 2.0)
		if hover >= 0 and hover < world.tiles.size() and tool != "pan":
			var valid: bool = world.can_place(hover, tool)
			_diamond(_indicator_layer, hover % N, floori(float(hover) / N), float(world.tiles[hover].get("elev", 0)), Color("eaf2a077") if valid else Color("ee555577"), Color.WHITE, 1.5)
		for event in world.events:
			if event.get("type", "") != "dispatch": continue
			var index: int = int(event.get("i", -1))
			if index < 0 or index >= world.tiles.size(): continue
			_indicator_layer.ring(_point(index % N + 0.5, floori(float(index) / N) + 0.5, float(world.tiles[index].get("elev", 0))), BASE * (0.35 + sin(_elapsed * 8) * 0.05), Color("80e5f4"), 2.0)
	_indicator_layer.queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if world == null: return
	_update_agents()
	if int(_elapsed * 12) != _last_indicator_tick:
		_last_indicator_tick = int(_elapsed * 12)
		if not world.events.is_empty(): _update_indicators()

func _update_agents() -> void:
	if world == null: return
	var slot: int = 0
	for kind in ["car", "train"]:
		var agents: Array = world.cars if kind == "car" else world.trains
		for agent in agents:
			var path = agent.get("path", [])
			var progress: float = float(agent.get("p", 0))
			var path_index: int = floori(progress)
			if path.is_empty() or path_index < 0 or path_index >= path.size(): continue
			var a: int = int(path[path_index])
			var b: int = int(path[mini(path.size() - 1, path_index + 1)])
			if a < 0 or b < 0 or a >= world.tiles.size() or b >= world.tiles.size(): continue
			var fraction: float = fposmod(progress, 1.0)
			var ax: int = a % N
			var ay: int = floori(float(a) / N)
			var dx: int = b % N - ax
			var dy: int = floori(float(b) / N) - ay
			var x: float = ax + 0.5 + dx * fraction + (-dy * 0.1 if kind == "car" else 0.0)
			var y: float = ay + 0.5 + dy * fraction + (dx * 0.1 if kind == "car" else 0.0)
			var elevation: float = lerpf(float(world.tiles[a].get("elev", 0)), float(world.tiles[b].get("elev", 0)), fraction)
			if slot >= _agent_layers.size(): _agent_layers.append(_new_layer(x + y + 0.1))
			var layer = _agent_layers[slot]
			layer.visible = true
			layer.z_index = roundi((x + y + 0.1) * 20.0)
			layer.commands.clear()
			layer.modulate.a = 1.0 if overlay == "none" else 0.7
			if kind == "car":
				var direction: String = "SE" if dx > 0 else "NW" if dx < 0 else "SW" if dy > 0 else "NE"
				_sprite(layer, "car" + direction, _point(x, y, elevation), 0.85)
			else:
				_box(layer, x - 0.17, y - 0.17, elevation, 0.34, 0.34, BASE * 0.26, ["e39a7e", "924b49", "c66b56"])
			layer.queue_redraw()
			slot += 1
	for i in range(slot, _agent_layers.size()): _agent_layers[i].visible = false
	metrics.agents = slot

func _gui_input(event: InputEvent) -> void:
	# Android can also synthesize a mouse sequence for each touch. Processing
	# both streams would build twice and corrupt the two-finger gesture state.
	if event is InputEventMouse and event.device == -1:
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(1.0 / 1.15, event.position)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed: _pointer_down(-1, event.position, false, event.button_index == MOUSE_BUTTON_RIGHT)
			else: _pointer_up(-1, event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer_move(-1, event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed: _pointer_down(event.index, event.position, true)
		else: _pointer_up(event.index, event.position, event.canceled)
		accept_event()
	elif event is InputEventScreenDrag:
		_pointer_move(event.index, event.position)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		camera -= event.delta * 18.0
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_pointers()

func _cancel_pointers() -> void:
	_touches.clear()
	_pending_tiles.clear()
	_gesture = false
	if _stroke_active:
		_stroke_active = false
		stroke_finished.emit()
	hover = -1
	_update_indicators()

func _pointer_down(id: int, point: Vector2, touch: bool, right: bool = false) -> void:
	_touches[id] = {"point": point, "touch": touch}
	if _touches.size() > 1:
		_gesture = true
		_moved = true
		_pending_tiles.clear()
		_update_indicators()
		return
	_pointer_start = point
	_pointer_previous = point
	_anchor = screen_to_tile(point)
	_last_tile = _anchor
	_moved = false
	_gesture = false
	_right_pan = right
	_painted.clear()
	_pending_tiles.clear()
	hover = _anchor
	if mode == "paint" and tool != "pan" and not right and _anchor >= 0:
		if touch or tool in ["road", "rail"]:
			_pending_tiles.append(_anchor)
		else:
			_emit_paint(_anchor)
	_update_indicators()

func _pointer_move(id: int, point: Vector2) -> void:
	if not _touches.has(id):
		hover = screen_to_tile(point)
		_update_indicators()
		return
	var old: Vector2 = _touches[id].point
	if _touches.size() >= 2:
		var keys: Array = _touches.keys()
		var a: Vector2 = _touches[keys[0]].point
		var b: Vector2 = _touches[keys[1]].point
		var previous_middle: Vector2 = (a + b) * 0.5
		var previous_distance: float = a.distance_to(b)
		_touches[id].point = point
		a = _touches[keys[0]].point
		b = _touches[keys[1]].point
		var middle: Vector2 = (a + b) * 0.5
		camera += middle - previous_middle
		if previous_distance > 5.0: zoom_at(a.distance_to(b) / previous_distance, middle)
		_pointer_previous = point
		return
	_touches[id].point = point
	if _gesture: return
	var just_moved: bool = not _moved and point.distance_to(_pointer_start) > 7.0
	if just_moved: _moved = true
	if tool == "pan" or mode == "tapPan" or _right_pan:
		if _moved:
			camera += point - (_pointer_start if just_moved else old)
	else:
		var index: int = screen_to_tile(point)
		if index >= 0 and _last_tile >= 0:
			if tool in ["road", "rail"]:
				_pending_tiles = _tile_line(_anchor, index)
			else:
				for tile_index in _tile_line(_last_tile, index):
					if _touches[id].touch:
						if not _pending_tiles.has(tile_index): _pending_tiles.append(tile_index)
					else: _emit_paint(tile_index)
			_last_tile = index
		hover = index
	_pointer_previous = point
	_update_indicators()

func _pointer_up(id: int, point: Vector2, canceled: bool = false) -> void:
	if not _touches.has(id): return
	var touch: bool = bool(_touches[id].touch)
	if not _gesture and not canceled and _touches.size() == 1:
		if tool == "pan" and not _moved:
			selected = screen_to_tile(point)
			selection_changed.emit(selected)
		elif mode == "tapPan" and tool != "pan" and not _moved and not _right_pan and _anchor >= 0:
			tile_pressed.emit(_anchor)
		elif mode == "paint" and tool != "pan" and not _right_pan:
			if tool in ["road", "rail"]:
				var last: int = screen_to_tile(point)
				if _anchor >= 0 and last >= 0:
					_emit_paint(_anchor)
					_emit_paint(last)
			elif touch:
				for index in _pending_tiles: _emit_paint(index)
	_touches.erase(id)
	if _touches.is_empty():
		if _stroke_active:
			_stroke_active = false
			stroke_finished.emit()
		_pending_tiles.clear()
		_gesture = false
		_right_pan = false
		_anchor = -1
		_last_tile = -1
		hover = -1
	_update_indicators()

func _emit_paint(index: int) -> void:
	if index < 0 or _painted.has(index): return
	if not _stroke_active:
		_stroke_active = true
		stroke_started.emit()
	_painted[index] = true
	tile_painted.emit(index)

func _tile_line(a: int, b: int) -> Array:
	var x: int = a % N
	var y: int = floori(float(a) / N)
	var xx: int = b % N
	var yy: int = floori(float(b) / N)
	var out: Array = []
	var dx: int = absi(xx - x)
	var dy: int = absi(yy - y)
	var sx: int = 1 if x < xx else -1
	var sy: int = 1 if y < yy else -1
	var error: int = dx - dy
	while true:
		out.append(y * N + x)
		if x == xx and y == yy: break
		var twice_error: int = 2 * error
		if twice_error > -dy:
			error -= dy
			x += sx
		# Keep preview/paint paths four-connected, matching construction.
		if twice_error > -dy and twice_error < dx:
			out.append(y * N + x)
		if twice_error < dx:
			error += dx
			y += sy
	return out
