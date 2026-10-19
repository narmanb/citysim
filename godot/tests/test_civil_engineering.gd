extends SceneTree
const W = preload("res://model/city_world.gd")
const G = preload("res://model/terrain_geometry.gd")
const S = preload("res://persistence/city_store.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func run():
	var w = W.new(141)
	for i in W.COUNT: w.tiles[i] = W.blank_tile()
	w.cash = 1000000
	var c := 25 * W.N + 25
	for direction in ["N", "E", "S", "W"]:
		for tool in ["road", "res", "shop", "light", "school", "park"]:
			w.tiles[c] = W.blank_tile()
			w.tiles[c].merge({"elev":4,"terrainShape":"slope","slopeDir":direction,"shapeStrength":1},true)
			var corners = G.corners(w.tiles,c)
			check(w.can_place(c,tool) and w.place(c,tool), "Gentle " + direction + " supports " + tool)
			check(G.corners(w.tiles,c)==corners, "Construction preserves slope geometry")
			if tool!="road": check(is_equal_approx(float(w.tiles[c].get("foundationHeight",-100)),4.5), "Level foundation at highest corner")
			else: check(not w.tiles[c].has("foundationHeight"), "Road follows ground without building pad")
			var restored = S.import_json(S.export_json(w))
			var same: bool = restored!=null
			if same:
				for key in w.tiles[c]: same = same and restored.tiles[c].get(key)==w.tiles[c][key]
			check(same, "Construction JSON roundtrip " + tool)
	for shape in ["slope", "rounded"]:
		for strength in [2,3]:
			for tool in ["road","res","school","rail"]:
				w.tiles[c] = W.blank_tile()
				w.tiles[c].merge({"terrainShape":shape,"shapeStrength":strength},true)
				var cash: float = w.cash
				check(not w.place(c,tool) and w.cash==cash, "Unsafe construction rejects without cost")
	w.tiles[c] = W.blank_tile()
	w.tiles[c].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"auto"},true)
	w.tiles[c+1].elev = 2
	check(w.place(c,"road") and w.tiles[c].slopeDir=="E", "Road freezes resolved Auto direction")
	w.tiles[c+1].elev = -2
	check(G.direction(w.tiles,c)=="E", "Neighbor editing cannot rotate road")
	w.tiles[c] = W.blank_tile()
	w.tiles[c].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E"},true)
	w.tiles[c+1] = W.blank_tile()
	w.tiles[c+1].elev = 5
	check(w.place(c+1,"road"), "Existing raised flat road")
	var cash: float = w.cash
	check(not w.place(c,"road") and w.cash==cash, "Road rejects disconnected height join")
	w.tiles[c+1] = W.blank_tile()
	check(w.place(c+1,"road") and w.place(c,"road"), "Gentle ramp joins integer flat road")
	check(w.route(c,c+1)==[c,c+1], "Traffic routes over compatible ramp")
	w.tiles[c+1].elev = 10
	check(w.route(c,c+1).is_empty(), "Traffic never crosses broken shaped-road join")
	w.tiles[c]=W.blank_tile()
	w.tiles[c].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E"},true)
	w.tiles[c+1]=W.blank_tile("water")
	check(w.place(c,"road"),"Ramp beside water fixture")
	cash=w.cash
	check(not w.place(c+1,"road",true) and w.cash==cash,"Bridge rejects a warped landing; needs a flat bank tile")
	w.tiles[c+1]=W.blank_tile()
	w.tiles[c+2]=W.blank_tile("water")
	check(w.place(c+1,"road") and w.place(c+2,"road",true),"Flat landing safely connects ramp to level bridge")
	w.tiles[c+1] = W.blank_tile()
	w.tiles[c] = W.blank_tile()
	w.tiles[c].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E","elev":4},true)
	check(w.place(c,"res"), "Foundation fixture")
	if w.tiles[c].has("foundationHeight"):
		for invalid in [null, "4.5", 3.5, 31, NAN]:
			var data = w.serialize()
			data.tiles[c].foundationHeight = invalid
			check(W.from_dict(data)==null, "Malformed foundation rejects " + str(invalid))
		check(w.place(c,"bulldoze") and not w.tiles[c].has("foundationHeight"), "Removing zoning removes its pad")
	w.tiles[c] = W.blank_tile()
	w.tiles[c].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E"},true)
	w.cash=0
	check(not w.place(c,"res") and not w.tiles[c].has("foundationHeight"), "Unaffordable placement creates no foundation")
	var game=load("res://ui/main.gd").new()
	root.add_child(game)
	game.paused=true;game.set_process(false);w.cash=100000
	game.set_world(w)
	game.choose_tool("res")
	var before: Dictionary = w.tiles[c].duplicate(true)
	check(game.construct_at(c), "Controller allows gentle foundation")
	var after: Dictionary = w.tiles[c].duplicate(true)
	check(game.undo() and w.tiles[c]==before, "Undo restores original shape without pad")
	check(game.redo() and w.tiles[c]==after, "Redo restores complete foundation")
	game.queue_free();await process_frame
	for failure in failures: push_error(failure)
	print("Civil engineering: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
