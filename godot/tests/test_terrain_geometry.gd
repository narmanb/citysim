extends SceneTree
const G = preload("res://model/terrain_geometry.gd")
const W = preload("res://model/city_world.gd")
const E = preload("res://model/terrain_editor.gd")
const S = preload("res://persistence/city_store.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func run():
	var w = W.new(89)
	for i in range(W.COUNT): w.tiles[i] = W.blank_tile()
	var c: int = 25 * 52 + 25
	for direction in ["N", "E", "S", "W"]:
		w.tiles[c].merge({"terrainShape":"slope", "slopeDir":direction, "shapeStrength":2}, true)
		var expected = {"N":[1.,1.,-1.,-1.], "E":[-1.,1.,1.,-1.], "S":[-1.,-1.,1.,1.], "W":[1.,-1.,-1.,1.]}
		check(Array(G.corners(w.tiles,c)) == expected[direction], "Correct high edge " + direction)
		check(G.sample(w.tiles,c,.5,.5) == 0, "Surface center matches reference")
		for elevation in [-5,30]:
			w.tiles[c].elev = elevation
			for height in G.corners(w.tiles,c): check(height >= -5 and height <= 30, "Clamped real corners")
		w.tiles[c].elev = 0
	w.tiles[c].slopeDir = "auto"
	w.tiles[c+1].elev = 2
	check(G.direction(w.tiles,c) == "E", "Auto follows east gradient")
	w.tiles[c+52].elev = 2
	check(G.direction(w.tiles,c) == "E", "Auto tie is stable X first")
	w.tiles[c+1].elev = 0
	check(G.direction(w.tiles,c) == "S", "Auto responds to neighbor changes")
	w.tiles[c].slopeDir = "W"
	check(G.direction(w.tiles,c) == "W", "Manual overrides gradient")
	w.tiles[c+52].elev = 0
	w.tiles[c] = W.blank_tile()
	var p = E.plan(w,[c],"shape",1,null,{"shape":"slope","direction":"auto","strength":1})
	check(p.before.is_empty() and p.cost == 0, "Auto on flat neighborhood is a free no-op")
	p = E.plan(w,[c],"shape",1,null,{"shape":"slope","direction":"E","strength":1})
	check(p.cost == 20 and E.commit(w,p).changed, "Manual shape commits without height change")
	check(w.can_place(c,"road") and w.can_place(c,"res") and w.can_place(c,"plant"), "Gentle slope supports safe construction")
	check(w.can_place(c,"line") and w.can_place(c,"tree"), "Slopes support anchored utilities and trees")
	check(E.plan(w,[c],"shape",1,null,{"shape":"slope","direction":"E","strength":1}).cost == 0, "Repeated shape free")
	w.tiles[c+1].merge({"terrainShape":"slope","slopeDir":"E","shapeStrength":1,"elev":1},true)
	var a = G.corners(w.tiles,c)
	var b = G.corners(w.tiles,c+1)
	check(a[1] == b[0] and a[2] == b[3], "Compatible ramp shared corners exactly match")
	p = E.plan(w,[c],"flatten",1,0)
	check(p.cost == 20 and E.commit(w,p).changed and w.tiles[c].terrainShape == "flat", "Flatten removes slope at same height")
	var data = w.serialize()
	check(data.version == 13, "New shape save version")
	var restored = S.import_json(JSON.stringify(data))
	check(restored != null and G.corners(restored.tiles,c+1) == G.corners(w.tiles,c+1), "Shape JSON round trip deterministic")
	for pair in [["terrainShape","invalid"],["slopeDir","bad"],["shapeStrength",0],["shapeStrength",1.5],["shapeStrength",null]]:
		var bad = data.duplicate(true)
		bad.tiles[c][pair[0]] = pair[1]
		check(S.import_json(JSON.stringify(bad)) == null, "Invalid shape data rejected " + str(pair))
	var old = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy-city-v6.json"))
	restored = S.import_json(JSON.stringify(old))
	check(restored != null and restored.tiles[c].terrainShape == "flat" and restored.tiles[c].slopeDir == "auto", "Legacy defaults remain flat")
	if failures.is_empty(): print("Terrain geometry: %d checks PASS" % checks)
	for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
