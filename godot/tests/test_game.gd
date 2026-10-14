extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func touch(view, id: int, point: Vector2, pressed: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	view._gui_input(event)

func drag_touch(view, id: int, point: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = id
	event.position = point
	view._gui_input(event)

func center_tile(view, index: int) -> Vector2:
	view.camera += view.size / 2 - view.tile_to_screen(index)
	return view.tile_to_screen(index)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists("res://ui/main.gd"):
		check(false, "Native game controller must exist")
		quit(1)
		return
	var script = load("res://ui/main.gd")
	if script == null or not script.can_instantiate():
		check(false, "Native game controller must compile")
		quit(1)
		return
	var game = script.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await process_frame
	game.paused = true
	var world = game.world
	check(world != null and game.view != null, "Controller owns an independent world and native view")
	# Make a predictable construction area without relying on generated terrain.
	for i in range(600, 680):
		var tile: Dictionary = world.tiles[i]
		tile.terrain = "grass"
		tile.tree = false
		tile.waterSource = false
		tile.channel = false
	world.recalculate()
	game.choose_tool("road")
	var cash_before: float = world.cash
	check(game.construct_at(600), "Tap construction places a road")
	check(world.tiles[600].road and world.cash == cash_before - 18, "Construction charges real placement cost")
	world.month = 7
	world.cash += 123
	check(game.undo(), "Undo succeeds")
	check(not world.tiles[600].road and world.cash == cash_before + 123, "Undo refunds only construction cost")
	check(world.month == 7, "Undo preserves simulation calendar")
	check(game.redo(), "Redo succeeds")
	check(world.tiles[600].road and world.cash == cash_before + 105, "Redo restores tiles and charges construction cost")
	game.choose_tool("res")
	game.begin_stroke()
	game.construct_at(610)
	game.construct_at(611)
	game.end_stroke()
	check(world.tiles[610].parcel > 0 and world.tiles[610].parcel == world.tiles[611].parcel, "Paint stroke shares one parcel")
	check(game.undo() and not world.tiles[610].zone and not world.tiles[611].zone, "Undo restores whole construction stroke")
	world.cash = 0
	check(not game.redo() and not world.tiles[610].zone, "Unaffordable redo preserves undone construction")
	world.cash = 36000
	check(game.redo(), "Affordable redo remains available after rejection")
	game.clear_history()
	game.choose_tool("tree")
	for i in range(620, 665):
		game.construct_at(i)
	check(game.history.undo_stack.size() == 40, "Construction history is bounded to forty actions")
	# A dry-to-dry line may bridge eight water tiles; an unfinished water line cannot.
	for i in range(1040, 1050):
		world.tiles[i].terrain = "water" if i > 1040 and i < 1049 else "grass"
		world.tiles[i].waterSource = i > 1040 and i < 1049
	game.choose_tool("road")
	check(game.construct_line(1040, 1049) == 10, "Road stroke spans eight water tiles between land endpoints")
	check(world.tiles[1044].road, "Bridge tiles are real road tiles")
	game.undo()
	check(game.construct_line(1040, 1048) == 1 and not world.tiles[1044].road, "Bridge requires dry land at both ends")
	# Real native touch events cross the renderer/controller boundary.
	game.choose_tool("road")
	game.set_placement_mode("tapPan")
	var point: Vector2 = center_tile(game.view, 670)
	var gesture_cash: float = world.cash
	touch(game.view, 0, point, true)
	drag_touch(game.view, 0, point + Vector2(80, 0))
	touch(game.view, 0, point + Vector2(80, 0), false)
	check(world.cash == gesture_cash and not world.tiles[670].road, "Tap + pan drag never constructs")
	point = center_tile(game.view, 670)
	touch(game.view, 0, point, true)
	touch(game.view, 0, point, false)
	check(world.tiles[670].road and world.cash == gesture_cash - 18, "Native single tap constructs exactly once")
	game.choose_tool("res")
	game.set_placement_mode("paint")
	point = center_tile(game.view, 671)
	var last: Vector2 = game.view.tile_to_screen(672)
	gesture_cash = world.cash
	touch(game.view, 0, point, true)
	drag_touch(game.view, 0, last)
	touch(game.view, 1, last + Vector2(0, 30), true)
	drag_touch(game.view, 1, last + Vector2(5, 50))
	touch(game.view, 1, last + Vector2(5, 50), false)
	touch(game.view, 0, last, false)
	check(world.cash == gesture_cash and not world.tiles[671].zone, "Two-finger gesture cancels buffered construction")
	point = center_tile(game.view, 671)
	last = game.view.tile_to_screen(672)
	touch(game.view, 0, point, true)
	drag_touch(game.view, 0, last)
	touch(game.view, 0, last, false)
	check(world.tiles[671].parcel > 0 and world.tiles[671].parcel == world.tiles[672].parcel, "Native touch paint commits one shared parcel")
	check(game.undo() and not world.tiles[671].zone and not world.tiles[672].zone, "Native touch stroke undoes as one action")
	# Budget changes alter the real model and bonds cannot be stacked.
	game.set_tax("res", 12)
	game.set_funding("fire", 75)
	check(world.taxes.res == 12 and world.funding.fire == 75, "Budget controls change tax and funding policy")
	var pre_bond: float = world.cash
	check(game.request_bond() and world.cash == pre_bond + 10000 and world.bondMonths == 80, "Emergency bond grants cash and schedules repayment")
	check(not game.request_bond() and world.cash == pre_bond + 10000, "Emergency bonds cannot be stacked")
	check(game.dispatch_at(600), "Fire dispatch records a real city response event")
	check(world.events.back().type == "dispatch" and world.events.back().i == 600, "Dispatch targets the chosen tile")
	# Agent and monthly clocks obey pause and the actual 1x / 3x / 8x factors.
	game.paused = false
	game.set_speed(1)
	var tick_before: int = world.tick
	game.advance_time(4.0)
	check(world.tick == tick_before + 1, "One month advances per four seconds")
	game.paused = true
	game.advance_time(8.0)
	check(world.tick == tick_before + 1, "Pause stops monthly simulation")
	game.paused = false
	game.set_speed(8)
	game.advance_time(1.0)
	check(world.tick == tick_before + 3, "Eight times speed advances two months per second")
	game.paused = true
	var current_world = game.world
	check(not game.import_city_text("{invalid json"), "Invalid JSON import reports failure")
	check(game.world == current_world, "Invalid import preserves the active city")
	var exported: String = game.export_city_text()
	check(game.import_city_text(exported), "Controller accepts legacy-compatible exported JSON")
	check(game.world.tiles[600].road, "Controller import preserves construction")
	check(game.history.undo_stack.is_empty(), "Replacing world clears construction history")
	for dialog_name in ["overlays", "budget", "events", "guide", "files", "json"]:
		game.open_dialog(dialog_name)
		await process_frame
		check(game._modal.visible, "Native dialog opens: " + dialog_name)
		game.close_dialog()
	# Desktop and short landscape layouts retain an interactive map.
	for dimensions in [Vector2i(854, 394), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		await process_frame
		check(game.view.size.x > 800 and game.view.size.y >= 100, "Map retains usable space at " + str(dimensions))
		check(game.find_child("Playback", true, false).get_global_rect().end.y <= dimensions.y, "Playback fits landscape screen")
		game.open_dialog("budget")
		await process_frame
		var dialog_rect: Rect2 = game._dialog_panel.get_global_rect()
		check(dialog_rect.position.x >= 0 and dialog_rect.position.y >= 0 and dialog_rect.end.x <= dimensions.x and dialog_rect.end.y <= dimensions.y, "Budget dialog stays within landscape viewport")
		check(game._modal.z_index > 3010, "Native dialogs render above retained city layers")
		game.close_dialog()
		var camera_rect: Rect2 = game.find_child("CameraControls", true, false).get_global_rect()
		check(camera_rect.position.x > 0 and camera_rect.end.x <= dimensions.x, "Camera controls remain on screen")
	for node_name in ["Stats", "Categories", "Tools", "Playback", "Actions", "Status", "GrowthHint", "Selection"]:
		check(game.find_child(node_name, true, false) != null, "Native control exists: " + node_name)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS test_game: construction, parcels, history, bridges, timing, safe import and native controls")
	quit(0 if failures.is_empty() else 1)
