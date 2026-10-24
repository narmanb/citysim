extends SceneTree
const W = preload("res://model/city_world.gd")
const E = preload("res://model/terrain_editor.gd")
var failures: Array[String] = []
var checks := 0

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func blank(cash: float):
	var w = W.new(51)
	for i in W.COUNT: w.tiles[i] = W.blank_tile()
	w.cash = cash
	return w
func run():
	var game = load("res://ui/main.gd").new()
	root.add_child(game); game.paused = true; game.set_process(false)
	await process_frame; await process_frame
	var c = 26 * 52 + 26
	# Every Terraform tool must work with no funds, including while in debt.
	for cash in [0., -50.]:
		for tool in ["surface", "raise", "lower", "flatten", "shape", "smooth", "hill", "mountain", "river", "grass", "desert", "tree", "forest"]:
			var w = blank(cash)
			if tool == "grass": w.tiles[c].biome = "desert"
			if tool == "smooth": w.tiles[c].elev = 8
			w.recalculate(); game.set_world(w); game.choose_tool(tool)
			game.set_terrain_settings(0, 1, 3)
			game.set_terrain_shape("slope", "E", 1)
			game.set_sculpt_settings({"surface_top":"snow", "surface_rock":"gray", "smooth_edges":false})
			var before = w.serialize()
			if tool in E.OPERATIONS:
				var p = game.terrain_preview_at(c)
				check(p.cost == 0 and p.affordable and not p.after.is_empty(), "Free, affordable changed preview: " + tool + str(cash))
				check(w.serialize() == before, "Preview is pure: " + tool)
			check(game.construct_at(c) and w.cash == cash, "Terraform changes terrain without spending: " + tool + str(cash))
			var after = w.serialize()
			check(game.history.undo_stack.size() == 1, "Free edit records one history action: " + tool)
			check(game.undo() and w.serialize() == before, "Free Undo restores exact state: " + tool)
			check(game.redo() and w.serialize() == after, "Free Redo restores exact state in debt: " + tool)
		# Grading adds a perimeter to both raise and lower, and must also stay free.
		for tool in ["raise", "lower"]:
			var w = blank(cash); w.recalculate(); game.set_world(w); game.choose_tool(tool)
			game.set_terrain_settings(0, 2); game.set_sculpt_settings({"smooth_edges":true})
			var before = w.serialize(); var p = game.terrain_preview_at(c)
			check(p.cost == 0 and p.affordable and p.after.size() == 25 and w.serialize() == before, "Graded preview is free and pure: " + tool)
			check(game.construct_at(c) and w.cash == cash, "Free graded edit works in debt: " + tool)
			var after = w.serialize()
			check(game.undo() and w.serialize() == before and game.redo() and w.serialize() == after, "Free grading retains exact history: " + tool)
	# Paid construction keeps its prices and affordability checks.
	for pair in [["road",18], ["rail",36], ["res",9], ["school",1600], ["bulldoze",18]]:
		var w = blank(10000.)
		if pair[0] == "bulldoze": w.tiles[c].tree = true
		check(w.place(c, pair[0]) and w.cash == 10000. - pair[1], "Paid construction price preserved: " + pair[0])
		w = blank(-50.)
		if pair[0] == "bulldoze": w.tiles[c].tree = true
		var original = w.tiles[c].duplicate(true)
		check(not w.place(c, pair[0]) and w.cash == -50. and w.tiles[c] == original, "Paid construction stays blocked in debt: " + pair[0])
	game.queue_free(); await process_frame
	for message in failures: push_error(message)
	print("Free Terraform: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
