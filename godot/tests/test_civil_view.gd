extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const C=preload("res://model/civil_engineering.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String):
	if not ok: failures.append(message)
func _initialize():call_deferred("run")
func run():
	var w=W.new(141)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	w.cash=1000000
	var c=25*52+25
	w.tiles[c].merge({"terrainShape":"slope","slopeDir":"E","shapeStrength":1,"elev":4},true)
	w.tiles[c+1].elev=5
	check(w.place(c,"road") and w.place(c+1,"road"),"Ramp to flat road builds")
	var v=V.new();root.add_child(v);v.size=Vector2(854,394);v.set_world(w);v.set_process(false)
	await process_frame;await process_frame
	check(v.has_method("_road_points") and v.has_method("_building_points"),"Renderer has grade-aware roads and pads")
	if not v.has_method("_road_points"):
		for failure in failures:push_error(failure)
		quit(1);return
	var a=v._road_points(c)
	var b=v._road_points(c+1)
	check(a[1]==b[0] and a[2]==b[3],"Ramp/flat road deck shared edge has no crack")
	check(C.road_sample(w.tiles,c,1,.5)==C.road_sample(w.tiles,c+1,0,.5),"Car crossing samples agree")
	for f in [.1,.49,.5,.51,.9]:
		var x: float=25.5+f
		var index: int=c if f<.5 else c+1
		check(v._agent_height(c,c+1,f,x,25.6,true)==C.road_sample(w.tiles,index,x-index%52,.6),"Car follows exact deck, including lane offset")
	var middle=v.camera+v._point(25.5,25.5,C.road_sample(w.tiles,c))*v.tile_scale/v.BASE
	check(v.screen_to_tile(middle)==c,"Picking uses raised road deck")
	w.tiles[c].road=false
	check(w.place(c,"res"),"Gentle foundation builds")
	v.refresh();await process_frame;await process_frame
	var pad=v._building_points(c)
	check(not v._construction_faces(c).is_empty(),"Downhill foundation has retaining faces")
	for face in v._construction_faces(c):
		check(not Geometry2D.triangulate_polygon(face[0]).is_empty(),"Retaining face triangulates into actual rendered geometry")
	for k in range(4):
		var uv=[Vector2(25,25),Vector2(26,25),Vector2(26,26),Vector2(25,26)][k]
		check(pad[k]==v._point(uv.x,uv.y,4.5),"Pad is level at4.5")
	var p=v.camera+v._point(25.5,25.5,4.5)*v.tile_scale/v.BASE
	check(v.screen_to_tile(p)==c,"Picking uses foundation top")
	v.selected=c
	var outline=v._indicator_layer.commands.back()[1]
	check(outline[0]==pad[0] and outline[3]==pad[3],"Selection outline meets the level foundation, not underlying slope")
	w.tiles[c+52].biome="desert";v.refresh();await process_frame;await process_frame
	check(v.metrics.tiles_regenerated<=25,"Local join edits stay bounded")
	var records=v._tile_records.duplicate(true)
	v._cached_world=null;v.refresh();await process_frame;await process_frame
	check(records==v._tile_records,"Cached/full civil geometry agrees")
	v.queue_free();await process_frame
	for failure in failures:push_error(failure)
	print("Civil view: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
