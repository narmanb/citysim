extends SceneTree
const W = preload("res://model/city_world.gd")
const V = preload("res://view/isometric_view.gd")
const G = preload("res://model/terrain_geometry.gd")
var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func run():
	var w = W.new(83)
	for i in range(W.COUNT):
		w.tiles[i] = W.blank_tile()
		w.tiles[i].elev = -5
	var v = V.new()
	v.size = Vector2(854,394)
	root.add_child(v)
	v.set_world(w)
	await process_frame
	var c = 25*52+25
	for direction in ["N","E","S","W"]:
		for elevation in [-5,0,12]:
			w.tiles[c].merge({"terrainShape":"slope","slopeDir":direction,"shapeStrength":3,"elev":elevation},true)
			# Lower surroundings so these probes hit visible cap, not a foreground wall.
			for n in w.neighbors(c): w.tiles[n].elev = -5
			var h = G.corners(w.tiles,c)
			var points = v._terrain_points(c)
			for corner in range(4):
				var xy = [Vector2(25,25),Vector2(26,25),Vector2(26,26),Vector2(25,26)][corner]
				check(points[corner] == v._point(xy.x,xy.y,h[corner]), "Renderer uses actual corner " + direction)
			for u in [.15,.5,.85]:
				for z in [.15,.5,.85]:
					var projected = v.camera + v._point(25+u,25+z,G.sample(w.tiles,c,u,z))*v.tile_scale/v.BASE
					check(v.screen_to_tile(projected) == c, "Pick actual surface " + direction + str(elevation))
	w.tiles[c].merge({"elev":0,"slopeDir":"auto","shapeStrength":2},true)
	for n in w.neighbors(c): w.tiles[n].elev = 0
	w.tiles[c+1].elev = 2
	v.refresh()
	await process_frame
	await process_frame
	w.tiles[c+1].elev = -2
	v.refresh()
	await process_frame
	await process_frame
	var records = v._tile_records.duplicate(true)
	check(v.metrics.tiles_regenerated <= 13, "Auto dependency invalidation stays local")
	v._cached_world = null
	v.refresh()
	await process_frame
	await process_frame
	check(records == v._tile_records, "Incremental Auto slope and neighbor walls equal full rebuild")
	w.tiles[c].slopeDir = "E"
	w.tiles[c].shapeStrength = 2
	w.tiles[c+1].merge({"terrainShape":"flat","elev":0},true)
	var faces = v._terrain_faces(c)
	check(not faces.is_empty(), "Slope to flat has retaining faces")
	# A south edge crossing the flat neighbor must be a clipped triangle.
	w.tiles[c+52].elev = 0
	faces = v._terrain_faces(c)
	check(faces.any(func(face): return face[0].size() == 3), "Crossing edge closes with exact triangle")
	v.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS terrain shape view: real vertices, all directions/bounds picking, crossing walls and retained cache")
	for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
