extends SceneTree
## Native Sharp/Smooth comparison and construction on the same level platform.
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
var game
var out: String
func _initialize():call_deferred("run")
func shot(name: String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();assert(image.save_png(out+"/"+name)==OK);return image
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1 or DisplayServer.get_name()=="headless":push_error("Use GL display and OUTPUT directory");quit(1);return
	out=args[0];DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var w=W.new(51)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	w.cash=1000000;w.recalculate()
	game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
	game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	game.choose_tool("raise");game.set_terrain_settings(2,4);game.set_terrain_shape("flat","auto",1)
	var c=26*52+26
	await process_frame;await process_frame
	game.view.tile_scale=24;game.view.camera=game.view.size*.5-game.view._point(26.5,26.5,2)*24/28.
	assert(game.construct_at(c));game._toast.hide();await shot("sharp-edges.png")
	assert(game.undo());assert(game.set_sculpt_settings({"smooth_edges":true}))
	game.view.hover=c;game.view._update_indicators();await shot("smooth-edges-preview.png")
	game.view.hover=-1;assert(game.construct_at(c));game._toast.hide()
	await shot("smooth-edges.png")
	# Real tool placement on flat top and all Gentle ramp tiles, not injected roads.
	for x in range(19,34):assert(w.place(26*52+x,"road"))
	for x in [25,27]:
		for y in [25,27]:
			var i=y*52+x;assert(w.place(i,"res"));w.tiles[i].level=1+(x+y)%2;w.tiles[i].occupancy=8
	for xy in [[22,25],[23,29],[29,24],[30,29],[24,22]]:w.tiles[xy[1]*52+xy[0]].tree=true
	w.recalculate();w.cars=[{"path":range(26*52+19,26*52+34),"p":4.7,"speed":.7}];w.trains=[];w.events=[]
	assert(S.import_json(S.export_json(w))!=null)
	game.view.refresh();game.refresh_ui();game.choose_tool("pan");game._toast.hide()
	var cached=await shot("smooth-platform-city.png")
	var local_tiles: int=game.view.metrics.tiles_regenerated
	assert(local_tiles<W.COUNT,"Construction triggered a full terrain rebuild")
	game.view._cached_world=null;game.view.refresh()
	var full=await shot("smooth-platform-city-full.png")
	assert(cached.get_data()==full.get_data(),"Cached/full pixels differ")
	game.view.set_grid_visible(true);await shot("smooth-platform-grid.png");game.view.set_grid_visible(false)
	game.choose_tool("raise");game.set_terrain_settings(0,1)
	game.view.hover=c+52*5;game.view._update_indicators()
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
	await shot("smooth-controls-640.png")
	var results={"local_construction_tiles_regenerated":local_tiles,"cached_full_equal":true,"save_version":w.serialize().version,"metrics":game.view.metrics,"renderer":RenderingServer.get_video_adapter_name()}
	var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "))
	print("PASS native Sharp/Smooth comparison, real roads/houses, import/export and exact cached/full raster")
	game.queue_free();await process_frame;quit()
