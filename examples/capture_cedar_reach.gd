extends SceneTree
## Actual native file import, deterministic captures and retained/full equality.
var game
var out:String
func _initialize():call_deferred("run")
func shot(name:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var pixels=root.get_texture().get_image()
 assert(pixels.save_png(out+"/"+name)==OK)
 return pixels
func focus(x:float,y:float,h:float,scale:float):
 game.view.tile_scale=scale;game.view.camera=game.view.size*.5-game.view._point(x,y,h)*scale/28.
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless":quit(1);return
 out=args[0]
 root.size=Vector2i(1800,1100);root.content_scale_size=Vector2i(854,522);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false)
 game._native_action="import";game._on_file_selected(out+"/MetroForge-Cedar-Reach.json")
 assert(game.world.seed==191026,"Native import callback failed")
 game.view.set_process(false);game.set_grid_visible(false);game.choose_tool("pan");game._toast.hide()
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.fit_city()
 var cached=await shot("Cedar-Reach-Overview.png")
 game.view._cached_world=null;game.view.refresh()
 var full=await shot("Cedar-Reach-Full-Rebuild.png")
 assert(cached.get_data()==full.get_data(),"Cached/full terrain raster differs")
 focus(20,21,5,18);await shot("Cedar-Reach-Main-City.png")
 focus(40,45,2,23);await shot("Cedar-Reach-Lakeside-Town.png")
 focus(38,21,0,17);await shot("Cedar-Reach-River-and-Lake.png")
 focus(10,5,10,15);await shot("Cedar-Reach-High-Country.png")
 focus(6,42,5,23);await shot("Cedar-Reach-Mesas-and-Quarry.png")
 var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"native_file_import":true,"cached_full_equal":true,"population":game.world.stats.population,"save_version":game.world.serialize().version,"save_sha256":FileAccess.get_file_as_string(out+"/MetroForge-Cedar-Reach.json").sha256_text(),"renderer":RenderingServer.get_video_adapter_name()},"  "))
 print("PASS Cedar Reach native file import, screenshots and exact cached/full raster")
 game.queue_free();await process_frame;quit()
