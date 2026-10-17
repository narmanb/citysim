extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script = load("res://ui/performance_display.gd") if ResourceLoader.exists("res://ui/performance_display.gd") else null
	check(script != null, "A self-contained rendered-frame performance display exists")
	if script == null:
		quit(1)
		return
	test_sample_cadence(script)
	test_elapsed_frame_average(script)
	test_foreground_stall(script)
	test_background_resume(script)
	await test_map_layout()
	if failures.is_empty():
		print("PASS test_performance_display: monotonic frame timing, sample cadence, foreground stalls, background resume and touch-safe 854x394 map layout")
	quit(0 if failures.is_empty() else 1)

func test_sample_cadence(script: Script) -> void:
	var display = script.new()
	var pending: String = display.text
	display._record_frame(10000000)
	for frame in range(1, 38):
		display._record_frame(10000000 + frame * 20000)
	check(display.text == pending, "Frame text remains unchanged before the 0.75-second sample completes")
	display._record_frame(10760000)
	check(display.text == "50.0 FPS · 20.0 ms", "Completed sample displays coherent FPS and milliseconds from real frame intervals")
	for frame in range(1, 15):
		display._record_frame(10760000 + frame * 50000)
	check(display.text == "50.0 FPS · 20.0 ms", "A new sample leaves the previous reading stable until its interval completes")
	display._record_frame(11510000)
	check(display.text == "20.0 FPS · 50.0 ms", "The next full sample reflects changed rendering speed")
	display.free()

func test_elapsed_frame_average(script: Script) -> void:
	var display = script.new()
	display._record_frame(0)
	for frame in range(1, 6):
		display._record_frame(frame * 100000)
	display._record_frame(750000)
	check(display.text == "8.0 FPS · 125.0 ms", "Uneven frame intervals use total elapsed wall time and frame count, not a mean of instantaneous FPS")
	display.free()

func test_foreground_stall(script: Script) -> void:
	var display = script.new()
	display._record_frame(0)
	display._record_frame(2500000)
	check(display.text == "0.4 FPS · 2500.0 ms", "A multi-second foreground stall remains visible in both FPS and frame time")
	display.free()

func test_background_resume(script: Script) -> void:
	var display = script.new()
	var pending: String = display.text
	display._record_frame(0)
	display._record_frame(750000)
	display.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(display.text == pending, "Backgrounding clears the old sample instead of presenting it as a current reading")
	display._record_frame(10000000)
	check(display.text == pending, "Background frames are excluded from the measurement")
	display.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	display._record_frame(20000000)
	for frame in range(1, 38):
		display._record_frame(20000000 + frame * 20000)
	check(display.text == pending, "Resuming starts a fresh full interval and excludes time spent backgrounded")
	display._record_frame(20760000)
	check(display.text == "50.0 FPS · 20.0 ms", "The first reading after resume contains only foreground frames")
	display.free()

func test_map_layout() -> void:
	root.size = Vector2i(854, 394)
	root.content_scale_size = Vector2i(854, 394)
	var game = load("res://ui/main.gd").new()
	root.add_child(game)
	game.paused = true
	await process_frame
	await process_frame
	var display = game.find_child("PerformanceDisplay", true, false)
	check(display != null, "The native map always includes its performance display")
	if display != null:
		check(display.is_visible_in_tree(), "FPS is visible without opening a menu")
		check(display.mouse_filter == Control.MOUSE_FILTER_IGNORE and display.focus_mode == Control.FOCUS_NONE, "The display cannot intercept map touches or take keyboard focus")
		var bounds: Rect2 = display.get_global_rect()
		var map_bounds: Rect2 = game.view.get_global_rect()
		var camera: Rect2 = game.find_child("CameraControls", true, false).get_global_rect()
		check(map_bounds.encloses(bounds), "FPS is wholly inside the 854x394 map")
		check(bounds == Rect2(698, 274, 148, 24), "FPS has a stable lower-right 148x24-pixel slot above zoom")
		check(not bounds.intersects(camera) and camera.position.y - bounds.end.y >= 8, "FPS clears the zoom and Fit buttons by eight pixels")
		var touch = InputEventScreenTouch.new()
		touch.index = 7
		touch.position = bounds.get_center()
		touch.pressed = true
		root.push_input(touch, true)
		check(game.view._touches.has(7), "A screen touch on the FPS text reaches the real map input handler")
		touch = touch.duplicate()
		touch.pressed = false
		root.push_input(touch, true)
		check(not game.view._touches.has(7), "Releasing through the FPS text completes the map gesture")
		for hud in [game._header, game._tool_dock, game._footer, game._status, game._growth]:
			check(not bounds.intersects(hud.get_global_rect()), "FPS leaves existing HUD and map hints readable: " + str(hud.name))
		game._on_selection(0)
		await process_frame
		check(not bounds.intersects(game._selection_panel.get_global_rect()), "FPS clears the visible tile inspector")
		game.select_category("Terraform")
		await process_frame
		check(not bounds.intersects(game._tool_menu.get_global_rect()), "FPS remains clear of the largest construction palette")
		var font: Font = display.get_theme_font("font")
		var text_width: float = font.get_string_size("0.4 FPS · 2500.0 ms", HORIZONTAL_ALIGNMENT_LEFT, -1, display.get_theme_font_size("font_size")).x
		var style: StyleBox = display.get_theme_stylebox("normal")
		check(text_width + style.get_minimum_size().x <= bounds.size.x, "Even a multi-second stall fits at the readable display font size")
		print("Performance display layout: ", bounds, "; zoom controls: ", camera, "; map: ", map_bounds)
	game.queue_free()
	await process_frame
