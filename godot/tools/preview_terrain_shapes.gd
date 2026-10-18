extends SceneTree
## Actual native renders of an internal regression fixture; no distributed city.
const W = preload("res://model/city_world.gd")
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image.save_png(path) != OK: push_error("Capture failed");quit(1)
	return image
func run():
	var args = OS.get_cmdline_user_args()
	if args.size()!=1 or DisplayServer.get_name()=="headless":
		push_error("Use GL display and OUTPUT directory");quit(1);return
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,591)
	root.content_scale_size=Vector2i(854,394)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var w = W.new(4242)
	w.cash=1000000
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
	var patches = [[20,18,"N"],[26,18,"E"],[20,24,"S"],[26,24,"W"]]
	for patch in patches:
		for dy in range(3):
			for dx in range(3):
				var t: Dictionary = w.tiles[(patch[1]+dy)*52+patch[0]+dx]
				t.terrainShape="slope";t.slopeDir=patch[2];t.shapeStrength=2
				t.elev=5 + 2 * (-dy if patch[2]=="N" else dx if patch[2]=="E" else dy if patch[2]=="S" else -dx)
				t.biome="desert" if patch[0]==26 else "grass"
	for dy in range(3):
		for dx in range(3):
			w.tiles[(30+dy)*52+24+dx].merge({"terrainShape":"cliff","elev":12},true)
	w.tiles[20*52+22].tree=true
	w.place(26*52+26,"line")
	w.recalculate()
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.paused=true;game.set_process(false);game.set_world(w)
	await process_frame;await process_frame
	game._toast.hide()
	game.view.tile_scale=21
	game.view.camera=game.view.size*.5-game.view._point(25,25,3)*21/28.
	await shot(out+"/ramps.png")
	# Freeze only the volatile FPS label during deterministic raster comparison.
	var fps = game.find_child("PerformanceDisplay",true,false)
	fps._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var cached = await shot(out+"/cached.png")
	game.view._cached_world=null;game.view.refresh()
	var rebuilt = await shot(out+"/rebuilt.png")
	if cached.get_data()!=rebuilt.get_data(): push_error("Cached/full raster mismatch");quit(1);return
	fps._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	game.choose_tool("shape");game.set_terrain_shape("slope","E",2);game.select_category("Terraform")
	await shot(out+"/phone-controls.png")
	game._close_tool_menu()
	await shot(out+"/phone-dock-closed.png")
	game.choose_tool("raise");game.set_terrain_shape("flat","auto",1)
	await shot(out+"/phone-raise-controls.png")
	game.set_terrain_shape("slope","E",2);game.select_category("Terraform")
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
	await shot(out+"/narrow-controls.png")
	print("PASS actual GL captures; cached/full pixels identical; ",game.view.metrics)
	game.queue_free();await process_frame
	quit()
