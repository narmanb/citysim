extends SceneTree
const Session = preload("res://persistence/city_session.gd")
const Store = preload("res://persistence/city_store.gd")
const World = preload("res://model/city_world.gd")
var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func run():
	var path = "user://tests/session/resume.json"
	var session = Session.new(path)
	check(session.restore() == null, "Fresh install has no resumed city")
	var world = World.new(73)
	world.cash = 65432
	world.tiles[1000] = World.blank_tile()
	world.tiles[1000].elev = 12
	session.mark_dirty()
	session.checkpoint(world)
	# A newer city arriving during a background save must win on shutdown.
	world.cash = 98765
	session.mark_dirty()
	check(session.flush(world) == OK, "Flush saves latest committed state after worker")
	var restarted = Session.new(path)
	var city = restarted.restore()
	check(city != null and city.cash == 98765 and city.tiles[1000].elev == 12, "Restart restores city, treasury and terrain")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt primary")
	file.close()
	city = restarted.restore()
	check(city != null and city.cash == 65432 and restarted.message.contains("backup"), "Corrupt primary recovers valid backup")
	file = FileAccess.open(path + ".bak", FileAccess.WRITE)
	file.store_string("corrupt backup")
	file.close()
	city = restarted.restore()
	check(city == null and restarted.message.contains("preserved"), "Both corrupt files retained before starting fresh")
	check(FileAccess.get_file_as_string(path + ".recovery") == "corrupt primary" and FileAccess.get_file_as_string(path + ".bak.recovery") == "corrupt backup", "Exact corrupt bytes preserved")
	# Actual shell startup, import and lifecycle checkpoint, using isolated paths.
	var game = load("res://ui/main.gd").new()
	game.session = Session.new(path + "-shell")
	root.add_child(game)
	game.paused = true
	await process_frame
	check(game.import_city_text(Store.export_json(world)), "Shell accepts city import")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	game.queue_free()
	await process_frame
	var next = load("res://ui/main.gd").new()
	next.session = Session.new(path + "-shell")
	root.add_child(next)
	next.paused = true
	await process_frame
	check(next.world.cash == 98765 and next.world.seed == 73 and next.world.tiles[1000].elev == 12, "Reopening shell automatically loads imported city")
	next.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS city session: background snapshots, latest state, recovery, import and actual shell restart")
	for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
