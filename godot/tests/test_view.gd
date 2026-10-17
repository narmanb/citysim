extends SceneTree

class FakeWorld extends RefCounted:
	var tiles: Array = []
	var fields: Dictionary = {}
	var cars: Array = []
	var trains: Array = []
	var events: Array = []
	var trafficHeat: Array = []
	var parcels: Dictionary = {}
	func _init() -> void:
		for i in range(52 * 52):
			tiles.append({"terrain": "grass", "biome": "temperate", "elev": 0, "zone": "", "level": 0})
	func can_place(_i: int, _tool: String, _bridge: bool = false) -> bool:
		return true
	func parcel_info(i: int) -> Dictionary:
		return parcels.get(int(tiles[i].get("parcel", 0)), {})

var failures: int = 0
var painted: Array = []
var pressed: Array = []
var selections: Array = []
var strokes: Array = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func touch(view, id: int, at: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	view._gui_input(event)

func drag(view, id: int, at: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = id
	event.position = at
	view._gui_input(event)

func _run() -> void:
	var script = load("res://view/isometric_view.gd")
	if script == null:
		push_error("IsometricView must load")
		quit(1)
		return
	var view = script.new()
	root.add_child(view)
	view.size = Vector2(1000, 700)
	var world = FakeWorld.new()
	view.set_world(world)
	view.fit_city()
	await process_frame
	check(view.tile_scale > 2.0 and view.tile_scale < 28.0, "fit adapts zoom to the available map rectangle")
	for i in [0, 51, 2652, 2703]:
		check(Rect2(Vector2.ZERO, view.size).has_point(view.tile_to_screen(i)), "fit includes every city corner")
	view.size = Vector2(854, 172)
	view.fit_city()
	for i in [0, 51, 2652, 2703]:
		check(Rect2(Vector2.ZERO, view.size).has_point(view.tile_to_screen(i)), "phone map rectangle includes every city corner")
	view.size = Vector2(1000, 700)
	view.fit_city()
	for i in [0, 51, 52, 1300, 2703]:
		check(view.screen_to_tile(view.tile_to_screen(i)) == i, "flat projected center round trip %s" % i)
	# Uniform planes ensure the centers are visible. Arbitrary neighboring
	# height jumps can correctly hide a back tile beneath a nearer cap.
	for elevation in range(-5, 13):
		for i in range(2704):
			world.tiles[i].elev = elevation
		for i in range(0, 2704, 37):
			check(view.screen_to_tile(view.tile_to_screen(i)) == i, "elevated projected center round trip %s at %s" % [i, elevation])
	var point: Vector2 = view.tile_to_screen(1300)
	var before: Vector2 = view._unproject(point)
	view.zoom_at(1.8, point)
	check(view._unproject(point).distance_to(before) < 0.0001, "zoom preserves point beneath the pointer")
	view.zoom_at(1000.0, point)
	check(view.tile_scale == 100.0, "zoom upper bound")
	view.zoom_at(0.0001, point)
	check(view.tile_scale == 2.0, "zoom lower bound supports mobile full-city overview")
	view.fit_city()
	for i in range(2704):
		world.tiles[i].elev = 0
	var center: int = 26 * 52 + 26
	for mask in range(16):
		for j in [center - 52, center + 1, center + 52, center - 1]:
			world.tiles[j].road = false
		for k in range(4):
			world.tiles[[center - 52, center + 1, center + 52, center - 1][k]].road = bool(mask & (1 << k))
		check(view._road_mask(center, "road") == mask, "all 16 road connectivity masks")
		var road_layer = load("res://view/iso_layer.gd").new()
		view._draw_road(road_layer, 26, 26, 0, mask, 1.0, false)
		var expected_commands: int = 3
		for k in range(4):
			if mask & (1 << k): expected_commands += 1
		check(road_layer.commands.size() == expected_commands, "road mask renders only connected arms %s" % mask)
		road_layer.free()
	var cap_layer = load("res://view/iso_layer.gd").new()
	view._surface(cap_layer, "grass", 0, 0, 4)
	var command: Array = cap_layer.commands[0]
	var atlas_origin: float = float(view._manifest.sprites.grass.y)
	for uv in command[4]:
		var pixel_y: float = uv.y * command[3].get_height()
		check(pixel_y >= atlas_origin - 0.001 and pixel_y <= atlas_origin + 66.001, "terrain UV stays within actual cap and excludes PNG sidewalls")
	check(is_equal_approx(command[1][2].y - command[1][0].y, 28.0), "elevation never changes flat cap pitch")
	cap_layer.free()
	for endpoint in [center + 5 + 5 * 52, center - 5 + 5 * 52, center + 5 - 5 * 52, center - 5 - 5 * 52, center + 7 + 2 * 52, center + 2 + 7 * 52, center, center + 5, center + 5 * 52]:
		for pair in [[center, endpoint], [endpoint, center]]:
			var path: Array = view._tile_line(pair[0], pair[1])
			check(path.front() == pair[0] and path.back() == pair[1], "Preview retains stroke endpoints")
			for k in range(1,path.size()):
				var a: int = path[k-1]
				var b: int = path[k]
				check(absi(a % 52 - b % 52) + absi(int(a / 52) - int(b / 52)) == 1, "Every preview step shares an edge")
	view.tile_pressed.connect(func(i): pressed.append(i))
	view.tile_painted.connect(func(i): painted.append(i))
	view.selection_changed.connect(func(i): selections.append(i))
	view.stroke_started.connect(func(): strokes.append("start"))
	view.stroke_finished.connect(func(): strokes.append("finish"))
	view.tool = "road"
	view.mode = "tapPan"
	point = view.tile_to_screen(center)
	touch(view, 0, point, true)
	touch(view, 0, point, false)
	check(pressed == [center], "tapPan tap builds exactly one tile")
	pressed.clear()
	var old_camera: Vector2 = view.camera
	touch(view, 0, point, true)
	drag(view, 0, point + Vector2(70, 20))
	touch(view, 0, point + Vector2(70, 20), false)
	check(pressed.is_empty() and painted.is_empty(), "tapPan drag spends nothing")
	check(view.camera.distance_to(old_camera + Vector2(70, 20)) < 0.1, "tapPan drag pans")
	view.fit_city()
	point = view.tile_to_screen(center)
	view.mode = "paint"
	touch(view, 0, point, true)
	drag(view, 0, view.tile_to_screen(center + 3))
	touch(view, 1, point + Vector2(70, 0), true)
	drag(view, 1, point + Vector2(100, 0))
	touch(view, 1, point + Vector2(100, 0), false)
	touch(view, 0, point, false)
	check(pressed.is_empty() and painted.is_empty() and strokes.is_empty(), "two-finger gesture never emits placement")
	view.fit_city()
	point = view.tile_to_screen(center)
	view.tool = "res"
	touch(view, 0, point, true)
	drag(view, 0, view.tile_to_screen(center + 4))
	touch(view, 0, view.tile_to_screen(center + 4), false)
	check(painted == [center, center + 1, center + 2, center + 3, center + 4], "paint fills skipped tiles once")
	check(strokes == ["start", "finish"], "paint is one history stroke")
	painted.clear()
	strokes.clear()
	view.tool = "road"
	touch(view, 0, point, true)
	drag(view, 0, view.tile_to_screen(center + 4))
	check(painted.is_empty(), "linear road preview does not spend before release")
	touch(view, 0, view.tile_to_screen(center + 4), false)
	check(painted == [center, center + 4] and strokes == ["start", "finish"], "road release supplies controller both bridge endpoints")
	painted.clear()
	strokes.clear()
	var emulated_mouse = InputEventMouseButton.new()
	emulated_mouse.device = -1
	emulated_mouse.position = point
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	view._gui_input(emulated_mouse)
	check(painted.is_empty() and view._touches.is_empty(), "emulated mouse stream cannot duplicate Android touches")
	view.tool = "pan"
	touch(view, 0, point, true)
	touch(view, 0, point, false)
	check(selections == [center] and view.selected == center, "pan tap selects")
	view.refresh()
	await process_frame
	check(view.metrics.visible_tiles == 2704 and view.get_node("City").get_child_count() > 2, "retained native terrain records cover the full map")
	var static_count: int = view.get_node("City").get_child_count()
	world.cars = [{"path": [center, center + 1], "p": 0.5}]
	view._process(0.01)
	check(view.get_node("City").get_child_count() <= static_count + 2, "agent animation does not rebuild static layers")
	check(view.metrics.ground_redraws >= 1, "renderer exposes redraw metrics")
	var redraws: int = view.metrics.ground_redraws
	for i in range(8): view.refresh()
	await process_frame
	check(view.metrics.ground_redraws == redraws + 1, "same-frame refresh requests coalesce into one rebuild")
	check(view._parcel_footprint([center, center + 1, center + 52, center + 53, center + 54]) == Rect2i(26, 26, 2, 2), "parcel building stays in contained footprint")
	_populate_render_fixture(world, center)
	view.refresh()
	for kind in ["zoning", "power", "water", "roadCondition", "traffic", "police", "fire", "school", "hospital", "pollution", "crime", "landValue", "none"]:
		view.overlay = kind
		await process_frame
	view.size = Vector2(1280, 800)
	root.size = Vector2i(1280, 800)
	view.fit_city()
	view.zoom_at(50.4 / view.tile_scale, view.size * 0.5)
	view.camera = view.size * 0.5 - view._point(26, 26) * view.tile_scale / 28.0
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		check(capture != null and not capture.is_empty(), "native viewport capture has pixels")
		if capture != null: capture.save_png("/tmp/metroforge-native-view.png")
	view.queue_free()
	print("View tests: %s failure(s)" % failures)
	quit(1 if failures else 0)

func _populate_render_fixture(world, center: int) -> void:
	for i in range(2704):
		world.tiles[i] = {"terrain": "grass", "biome": "temperate", "elev": 0, "zone": "", "level": 0}
		for field in ["power", "water", "police", "fire", "school", "hospital", "pollution", "crime", "landValue"]:
			if not world.fields.has(field): world.fields[field] = []
			world.fields[field].append(1.0 if field in ["power", "water", "police", "fire", "school", "hospital"] else 42.0)
	for y in range(16, 35):
		for x in range(15, 35):
			var i: int = y * 52 + x
			if x < 18:
				world.tiles[i].terrain = "water"
				world.tiles[i].elev = -1
			elif y < 20:
				world.tiles[i].elev = 3
				world.tiles[i].biome = "desert"
			elif (x + y) % 4 == 0:
				world.tiles[i].tree = true
	for x in range(15, 36):
		world.tiles[26 * 52 + x].road = true
		world.tiles[26 * 52 + x].condition = 0.9
		world.tiles[27 * 52 + x].rail = true
		world.tiles[28 * 52 + x].pipe = true
		world.tiles[29 * 52 + x].line = true
	for y in range(20, 34):
		world.tiles[y * 52 + 24].road = true
		world.tiles[y * 52 + 24].condition = 0.35
	var civic: Array = ["park", "plant", "pump", "tower", "police", "fire", "school", "hospital", "station"]
	for k in range(civic.size()):
		world.tiles[22 * 52 + 20 + k].civic = civic[k]
		world.tiles[22 * 52 + 20 + k].storage = 90
	for k in range(12):
		var index: int = 31 * 52 + 20 + k
		world.tiles[index].zone = ["res", "com", "ind"][k % 3]
		world.tiles[index].zoneType = ["house", "office", "heavy", "apt", "shop", "light"][k % 6]
		world.tiles[index].level = k % 4 + 1
		world.tiles[index].abandoned = k > 9
	world.tiles[center - 2].fire = true
	world.cars = [{"path": [center, center + 1], "p": 0.4}, {"path": [center - 1, center], "p": 0.6}]
	world.trains = [{"path": [center + 52, center + 53], "p": 0.5}]
	world.events = [{"type": "dispatch", "i": center - 2}]
