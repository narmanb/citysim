extends SceneTree
## Internal rounded-geometry validation; not a distributed showcase city.
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const S=preload("res://persistence/city_store.gd")
func _initialize(): call_deferred("run")
func shot(path):
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if image.save_png(path)!=OK: push_error("Capture failed");quit(1)
	return image
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1 or DisplayServer.get_name()=="headless": push_error("Use GL display and OUTPUT folder");quit(1);return
	var out:String=args[0];DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var w=W.new(177);w.cash=1000000
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
	for y in range(17,40):
		for x in range(13,17): w.tiles[y*52+x]=W.blank_tile("water")
	# Tiny elevated island exercises all four Rounded/water borders.
	for y in range(19,21):
		for x in range(14,16): w.tiles[y*52+x].merge({"terrain":"grass","elev":4,"terrainShape":"rounded"},true)
	for y in range(18,33):
		for x in range(31,42): w.tiles[y*52+x].biome="desert"
	for preset in [[26,24,12,1],[35,26,6,2]]:
		var settings={"preset_radius":4,"peak":preset[2],"profile":preset[3],"preset_shape":"rounded"}
		var result=E.commit(w,E.plan(w,[],"mountain",1,null,settings,[preset[1]*52+preset[0]]))
		if not result.changed: push_error("Preset fixture failed");quit(1);return
	for y in range(30,39):
		for x in range(20,29):
			var t:Dictionary=w.tiles[y*52+x]
			t.elev=mini(0,-5+int(((x-24)*(x-24)+(y-34)*(y-34))/4.))
			t.terrainShape="rounded"
	for y in range(18,21):
		for x in range(32,35): w.tiles[y*52+x].merge({"elev":6,"terrainShape":"cliff"},true)
	w.place(19*52+33,"plant")
	w.place(24*52+27,"tree");w.place(24*52+25,"line")
	for x in range(11,20):
		w.place(38*52+x,"road",true);w.place(39*52+x,"rail",true)
	w.recalculate();w.cars=[];w.trains=[];w.events=[]
	var text=S.export_json(w)
	if S.import_json(text)==null: push_error("Fixture roundtrip failed: "+S.last_error);quit(1);return
	var data=FileAccess.open(out+"/internal-terrain-regression.json",FileAccess.WRITE);data.store_string(text);data.close()
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
	await process_frame;await process_frame
	game._toast.hide()
	var fps=game.find_child("PerformanceDisplay",true,false)
	fps._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	game.view.fit_city();await shot(out+"/fit.png")
	game.view.tile_scale=16;game.view.camera=game.view.size*.5-game.view._point(27,27,3)*16/28.
	await shot(out+"/district.png")
	game.view.tile_scale=32;game.view.camera=game.view.size*.5-game.view._point(27,26,3)*32/28.
	await shot(out+"/close.png")
	w.tiles[24*52+28].elev+=1;game.view.refresh()
	var cached=await shot(out+"/incremental.png")
	game.view._cached_world=null;game.view.refresh()
	var rebuilt=await shot(out+"/rebuilt.png")
	if cached.get_data()!=rebuilt.get_data(): push_error("Incremental/full rounded raster mismatch");quit(1);return
	game.choose_tool("smooth");game.select_category("Terraform")
	await shot(out+"/smooth-controls.png")
	game.choose_tool("mountain");await shot(out+"/mountain-controls.png")
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
	game.select_category("Terraform");await shot(out+"/narrow-controls.png")
	var metrics={"metrics":game.view.metrics,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"rounded_tiles":w.tiles.filter(func(tile):return tile.terrainShape=="rounded").size()}
	var f=FileAccess.open(out+"/metrics.json",FileAccess.WRITE);f.store_string(JSON.stringify(metrics));f.close()
	print("PASS Phase4 actual GL: presets/import, all zooms, compact controls, incremental/full pixel equality; ",metrics)
	game.queue_free();await process_frame;quit()
