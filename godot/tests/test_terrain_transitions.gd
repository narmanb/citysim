extends SceneTree
const W=preload("res://model/city_world.gd")
const G=preload("res://model/terrain_geometry.gd")
const V=preload("res://view/isometric_view.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String):
	if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
	var w=W.new(141)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	var c=25*52+25
	for bed in [-5,-3,-1,0]:
		w.tiles[c]=W.blank_tile("water");w.tiles[c].channel=true;w.tiles[c].elev=bed
		check(G.sample(w.tiles,c)==0,"Water surface independent of negative bed "+str(bed))
		check(w.tiles[c].elev==bed,"Stored bed is never raised for rendering")
	var v=V.new();root.add_child(v);v.size=Vector2(854,394);v.set_world(w);v.set_process(false)
	await process_frame;await process_frame
	w.tiles[c].elev=-5;v.refresh();await process_frame;await process_frame
	var quad=v._terrain_points(c)
	check(quad[0]==v._point(25,25,0),"Rendered water cap uses surface0")
	check(v.screen_to_tile(v.camera+v._point(25.5,25.5,0)*v.tile_scale/v.BASE)==c,"Pick visible water, not bed")
	check(v.has_method("_shore_band"),"Banks distinguish high cliffs from low shore strips")
	if v.has_method("_shore_band"):
		w.tiles[c-1].elev=12
		check(not v._shore_band(c-1,c),"No sand stripe on high cliff top")
		w.tiles[c-1].elev=0
		check(v._shore_band(c-1,c),"Low ground gets shoreline strip")
	var module=load("res://view/terrain_transitions.gd") if ResourceLoader.exists("res://view/terrain_transitions.gd") else null
	check(module!=null,"Biome transition helper exists")
	if module!=null:
		w.tiles[c]=W.blank_tile();w.tiles[c+1]=W.blank_tile();w.tiles[c+1].biome="desert"
		var a=module.biome_corners(w.tiles,c)
		var b=module.biome_corners(w.tiles,c+1)
		check(a.size()==4 and b.size()==4,"Mixed borders use vertex colors")
		if a.size()==4 and b.size()==4:check(a[1]==b[0] and a[2]==b[3],"Shared biome edge colors agree")
		w.tiles[c].surfaceTop="snow"
		check(module.biome_corners(w.tiles,c).is_empty(),"Explicit terrain paint is preserved")
		w.tiles[c]=W.blank_tile("water")
		check(module.biome_corners(w.tiles,c).is_empty(),"Water never blends to grass/desert")
	# Reflow and appearance never flood a dry basin; a raised dam still dries channels.
	w.tiles[c]=W.blank_tile("water")
	w.tiles[c+1]=W.blank_tile();w.tiles[c+1].channel=true;w.tiles[c+1].elev=-4
	w.tiles[c+2]=W.blank_tile();w.tiles[c+2].elev=-5
	w._terrain_reflow()
	check(w.tiles[c+1].terrain=="water" and w.tiles[c+2].terrain=="grass","Only connected channel fills")
	w.tiles[c+1].elev=1;w._terrain_reflow()
	check(w.tiles[c+1].terrain=="grass","Raised channel disconnects as before")
	v.queue_free();await process_frame
	for f in failures:push_error(f)
	print("Terrain transitions: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
