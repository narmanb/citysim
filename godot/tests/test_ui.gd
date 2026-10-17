extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://ui/main.gd").new()
	root.add_child(game)
	game.paused = true
	await process_frame
	await process_frame
	for dimensions in [Vector2i(1280, 591), Vector2i(854, 394), Vector2i(640, 360)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		await process_frame
		for button in [game._undo_button, game._redo_button]:
			var bounds: Rect2 = button.get_global_rect()
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(bounds), "History button fits landscape " + str(dimensions))
			var ancestor = button.get_parent()
			while ancestor is Control:
				if ancestor.clip_contents:
					check(ancestor.get_global_rect().encloses(bounds), "History button is fully visible outside clipped category strip " + str(dimensions))
				ancestor = ancestor.get_parent()
		if dimensions.x >= 854:
			for button in game._category_buttons.values():
				var clip = game.find_child("Categories",true,false)
				check(clip.get_global_rect().encloses(button.get_global_rect()),"All six categories fit alongside fixed history at " + str(dimensions))
		var map_rect: Rect2 = game.view.get_global_rect()
		var compact: bool = dimensions.x <= 950
		var expected_top: float = 78 if compact else 86
		var expected_footer: float = 42 if compact else 46
		check(is_equal_approx(map_rect.position.x, 0) and is_equal_approx(map_rect.size.x, dimensions.x), "Map spans the full landscape width at " + str(dimensions))
		check(is_equal_approx(map_rect.position.y, expected_top), "Exactly two compact bars sit above the map at " + str(dimensions))
		check(is_equal_approx(map_rect.end.y, dimensions.y - expected_footer), "Only the compact footer reserves space below the map at " + str(dimensions))
		check(game._status.get_parent() == game.view.get_parent() and game._growth.get_parent() == game.view.get_parent(), "Status and growth hints overlay the map")
		var stats = game.find_child("Stats", true, false)
		check(stats.find_children("*Badge", "PanelContainer", true, false).size() == 7, "Date, cash, population, jobs, power, water and net have separate stat badges")
		var camera: Rect2 = game.find_child("CameraControls", true, false).get_global_rect()
		check(camera.position.x > dimensions.x - 200 and camera.end.y <= map_rect.end.y and camera.position.y > map_rect.end.y - 50, "Zoom and Fit sit over the lower-right map")
		check(game.find_child("Demand", true, false) != null, "R/C/I demand chips exist in the footer")
		check(game.find_children("DemandMeter*", "Range", true, false).size() == 3, "R/C/I demand includes three graphical meters")
		for meter in game._demand_meters.values():
			check(meter.size.y == 9 and meter.get_global_rect().end.y < dimensions.y, "Demand fill stays inside its nine-pixel meter in the footer")
		var actions = game.find_child("Actions", true, false)
		check(actions.get_global_rect().end.x >= dimensions.x - 10, "Footer actions reach the right edge without unused space")
	var tools = game.find_child("Tools", true, false)
	check(not tools.is_visible_in_tree(), "Category tool picker starts closed")
	for group in game.CATEGORIES:
		game.select_category(group)
		await process_frame
		check(tools.is_visible_in_tree(), "Category opens its picker over the map: " + group)
		check(game._tool_buttons.size() == game.CATEGORIES[group].size(), "Every category tool remains available: " + group)
		var before: Rect2 = game.view.get_global_rect()
		var chosen: String = game.CATEGORIES[group].back()
		game.choose_tool(chosen)
		await process_frame
		check(not tools.is_visible_in_tree() and game.selected_tool == chosen, "Choosing a tool closes its picker: " + chosen)
		check(game.view.get_global_rect() == before, "Tool picker never consumes map layout space")
	game.select_category("Transport")
	game.set_placement_mode("paint")
	check(game._status.text.contains("Drag paints"), "Placement mode explains its behavior in the lower map status")
	check(not tools.is_visible_in_tree() and game.view.mode == "paint", "Placement mode closes the picker and updates the native gesture mode")
	game.set_placement_mode("tapPan")
	game._toast.hide()
	game.select_category("Transport")
	var cash_before: float = game.world.cash
	var outside = InputEventScreenTouch.new()
	outside.pressed = true
	outside.position = Vector2(800, 220)
	game._menu_dismiss.gui_input.emit(outside)
	check(not tools.is_visible_in_tree() and game.world.cash == cash_before, "Touching the map outside a picker dismisses it without construction")
	game.select_category("Transport")
	game.select_category("Transport")
	check(not tools.is_visible_in_tree(), "Tapping the open category again closes it")
	game.choose_tool("road")
	check(game.find_child("ToolName", true, false).text.contains("Road") and game.find_child("ToolName", true, false).text.contains("18"), "Selected tool and real cost remain in the second bar")
	var saved_demand = game.world.demand.res
	game.world.demand.res = -70
	game.refresh_ui()
	check(game._demand_meters.res.value == 70 and game._demand_meters.res.fill_mode == ProgressBar.FILL_END_TO_BEGIN and game._demand_labels.res.text == "-70", "Negative demand fills toward the left of zero with its signed value")
	check(game._demand_meters.res.get_theme_stylebox("fill").bg_color == Color("ee897c"), "Negative demand uses the original red meter")
	game.world.demand.res = saved_demand
	game.refresh_ui()
	check(game._speed_buttons[1].get_theme_stylebox("pressed").bg_color == Color("a96a36"), "Selected speed uses the original orange color")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 854 and ProjectSettings.get_setting("display/window/size/viewport_height") == 394, "Phone base viewport keeps native touch controls at the former Android CSS scale")
	if "--capture" in OS.get_cmdline_user_args():
		for dimensions in [Vector2i(1280, 591), Vector2i(854, 394)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			game.choose_tool("pan")
			await process_frame
			await process_frame
			game.view.fit_city()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/metroforge-ui-%dx%d.png" % [dimensions.x, dimensions.y])
			game.select_category("Zoning")
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/metroforge-ui-menu-%dx%d.png" % [dimensions.x, dimensions.y])
			game.choose_tool("pan")
		root.size = Vector2i(1280, 591)
		root.content_scale_size = Vector2i(854, 394)
		await process_frame
		await process_frame
		game.view.fit_city()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/metroforge-ui-android-scale-1280x591.png")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS test_ui: compact two-bar layout, stat badges, demand meters, map overlays and category picker")
	quit(0 if failures.is_empty() else 1)
