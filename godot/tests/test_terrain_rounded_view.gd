extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const G=preload("res://model/terrain_geometry.gd")
const L=preload("res://view/iso_layer.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String):
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func run():
	var w=W.new(41)
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
	var c=25*52+25
	for y in range(22,29):
		for x in range(22,29):
			w.tiles[y*52+x].terrainShape="rounded"
			w.tiles[y*52+x].elev=maxi(0,12-(x-25)*(x-25)*2-(y-25)*(y-25)*2)
	var v=V.new();v.size=Vector2(854,394);root.add_child(v);v.set_world(w)
	await process_frame;await process_frame
	var cap=L.new();v._draw_ground(cap,c)
	check(cap.commands.size()>=16,"Rounded cap is tessellated, not one flat diamond")
	var point=v._terrain_points(c)[0]
	check(point==v._point(25,25,G.sample(w.tiles,c,0,0)),"Rounded vertex uses shared field")
	var at=v.camera+v._point(25.5,25.5,G.sample(w.tiles,c))*v.tile_scale/v.BASE
	check(v.screen_to_tile(at)==c,"Tap hits actual curved summit")
	var seen_colors: Dictionary = {}
	var continuous=true
	var gradient_commands=0
	for command in cap.commands:
		if command[0] not in [0,6] or command[3]==null: continue
		if command[0]==6: gradient_commands+=1
		for j in range(command[1].size()):
			var key: Vector2 = command[1][j].snapped(Vector2(.001,.001))
			var color: Color = command[2][j] if command[0]==6 else command[2]
			if seen_colors.has(key) and color!=seen_colors[key]: continuous=false
			seen_colors[key]=color
	check(continuous and gradient_commands>0,"Curved cap vertices share lighting across patch boundaries")
	cap.free()
	w.tiles[c+2].elev=11;v.refresh()
	await process_frame;await process_frame
	var cached=v._tile_records.duplicate(true)
	check(v.metrics.tiles_regenerated<=49,"Spline dependencies stay within local neighborhood")
	v._cached_world=null;v.refresh()
	await process_frame;await process_frame
	check(cached==v._tile_records,"Incremental curved caps and walls equal full rebuild")
	var high_quality=v._tile_records[c].duplicate(true)
	v.rounded_subdivisions=2
	await process_frame;await process_frame
	check(v._tile_records[c]!=high_quality,"Changing bounded subdivision quality refreshes retained caps")
	v.rounded_subdivisions=4
	await process_frame;await process_frame
	var old=v.metrics.ground_redraws
	for i in range(10): v.zoom_at(1.01,v.size*.5);v.camera+=Vector2(1,2)
	await process_frame
	check(v.metrics.ground_redraws==old,"Rounded geometry retained during camera motion")
	v.overlay="landValue"
	check(v._overlay_layer.commands.size()>W.COUNT,"Rounded overlays use the same subdivided caps")
	# The shore ribbon must meet the actual cap edge, including its curved midpoint.
	# Use a low bank: high cliff tops intentionally no longer get a beach ribbon.
	for y in range(22,29):
		for x in range(22,29): w.tiles[y*52+x].elev=0
	w.tiles[c].elev=1
	w.tiles[c-1].terrain="water";v.refresh()
	var shore=L.new();v._draw_ground(shore,c)
	var midpoint=v._rounded_mesh(c).points[2*5]
	var found=false
	for command in shore.commands:
		if command[0]!=0 or command[2]!=Color("dcc78d"): continue
		for vertex in command[1]:
			if vertex.is_equal_approx(midpoint): found=true
	check(found,"Shore ribbon shares the curved cap midpoint instead of a straight chord")
	shore.free()
	w.tiles[0].merge({"elev":12,"terrainShape":"rounded","roundedBase":12},true)
	v.refresh();v.fit_city()
	var north_vertex: Vector2 = v.camera+v._rounded_mesh(0).points[0]*v.tile_scale/v.BASE
	check(north_vertex.y>=15.99,"Fit includes the north vertex of a rounded corner plateau with its full margin")
	v.queue_free();await process_frame
	for message in failures: push_error(message)
	print("Rounded view: %d failures"%failures.size())
	quit(0 if failures.is_empty() else 1)
