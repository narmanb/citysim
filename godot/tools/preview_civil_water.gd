extends SceneTree
## Deterministic native renderer fixture: never replaces a distributed city.
const W=preload("res://model/city_world.gd")
const G=preload("res://model/terrain_geometry.gd")
const S=preload("res://persistence/city_store.gd")
var out: String
var game
func _initialize():call_deferred("run")
func shot(name: String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	assert(image.save_png(out+"/"+name)==OK)
	return image
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1 or DisplayServer.get_name()=="headless":push_error("Use GL display and OUTPUT directory");quit(1);return
	out=args[0];DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(854,480);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var w=W.new(141)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	w.cash=1000000
	# Eastward gentle hillside. Each E ramp shares exact edges with its neighbor.
	for y in range(16,37):
		for x in range(20,35):
			w.tiles[y*52+x].merge({"elev":mini(x-20,8),"terrainShape":"slope" if x<29 else "flat","slopeDir":"E","shapeStrength":1},true)
	for x in range(19,33):assert(w.place(25*52+x,"road"))
	for x in [21,23,25,27]:
		for y in [24,26]:
			var i=y*52+x
			assert(w.place(i,"res"))
			w.tiles[i].level=1+(x+y)%2;w.tiles[i].occupancy=7
	for x in [22,26]:
		var i=23*52+x;assert(w.place(i,"school"))
	for xy in [[21,22],[23,22],[25,22],[27,22],[22,28],[24,28],[26,28],[28,28]]:w.tiles[xy[1]*52+xy[0]].tree=true
	# A level lake and deep connected channel beside a grass/desert boundary.
	for y in range(16,36):
		for x in range(9,18):
			var i=y*52+x
			if Vector2((x-13.5)/4.5,(y-25.5)/9.).length()<1:w.tiles[i]=W.blank_tile("water")
	for x in range(17,21):assert(w.place(30*52+x,"river"))
	for x in range(17,21):w.tiles[30*52+x].elev=-1-(x%4)
	for y in range(16,37):
		for x in range(9,35):
			if y>28:w.tiles[y*52+x].biome="desert"
	for x in range(9,19):assert(w.place(27*52+x,"road",true))
	w.recalculate()
	w.cars=[{"path":range(25*52+19,25*52+33),"p":5.65,"speed":.7}]
	w.trains=[];w.events=[]
	assert(S.import_json(S.export_json(w))!=null)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.set_process(false);assert(game.set_world(w));game.view.set_process(false)
	game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	game._toast.hide();game.choose_tool("pan")
	await process_frame;await process_frame
	game.view.tile_scale=36;game.view.camera=game.view.size*.5-game.view._point(25.5,25.5,5)*36/28.
	await shot("slope-roads-and-foundations.png")
	game.view.tile_scale=23;game.view.camera=game.view.size*.5-game.view._point(18,26,2)*23/28.
	var cached=await shot("lake-river-and-biomes.png")
	game.view._cached_world=null;game.view.refresh()
	var full=await shot("full-rebuild.png")
	assert(cached.get_data()==full.get_data(),"Cached and complete pixels differ")
	w.tiles[30*52+20].biome="grass";game.view.refresh()
	var edited=await shot("edited-biome.png")
	var local_count=game.view.metrics.tiles_regenerated
	game.view._cached_world=null;game.view.refresh()
	var rebuilt=await shot("edited-full-rebuild.png")
	assert(edited.get_data()==rebuilt.get_data(),"Edited cached and complete pixels differ")
	var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"cached_full_equal":true,"edited_cached_full_equal":true,"local_tiles_regenerated":local_count,"metrics":game.view.metrics,"renderer":RenderingServer.get_video_adapter_name(),"save_version":w.serialize().version},"  "))
	print("PASS native civil/water captures, exact cached/full pixels, import/export; local tiles ",local_count)
	game.queue_free();await process_frame;quit()
