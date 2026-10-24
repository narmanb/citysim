extends SceneTree
## Actual native file import, deterministic captures and retained/full equality.
const S=preload("res://persistence/city_store.gd")
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
 game._native_action="import";game._on_file_selected(out+"/MetroForge-Summit-Bay-0.3.17.json")
 assert(game.world.seed==241026,"Native import callback failed")
 var before=S.export_json(game.world)
 game.view.set_process(false);game.set_grid_visible(false);game.choose_tool("pan");game._toast.hide()
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.fit_city()
 var cached=await shot("Summit-Bay-0.3.17-Overview.png")
 game.view._cached_world=null;game.view.refresh()
 var full=await shot("Summit-Bay-0.3.17-Full-Rebuild.png")
 assert(cached.get_data()==full.get_data(),"Cached/full terrain raster differs")
 focus(20,21,5,18);await shot("Summit-Bay-0.3.17-Main-City.png")
 focus(40,45,2,23);await shot("Summit-Bay-0.3.17-Lakeside-Town.png")
 focus(38,21,0,17);await shot("Summit-Bay-0.3.17-River-and-Lake.png")
 focus(30,5,25,18);await shot("Summit-Bay-0.3.17-High-Country.png")
 focus(6,42,5,23);await shot("Summit-Bay-0.3.17-Mesas-and-Quarry.png")
 focus(41.5,48.5,2,40);await shot("Summit-Bay-0.3.17-Parks-and-Services.png")
 focus(18,41,1,36);await shot("Summit-Bay-0.3.17-Work-District.png")
 assert(S.export_json(game.world)==before,"Preview rendering changed the city")
 var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"native_file_import":true,"rendering_preserves_city":true,"cached_full_equal":true,"population":game.world.stats.population,"save_version":game.world.serialize().version,"save_sha256":FileAccess.get_file_as_string(out+"/MetroForge-Summit-Bay-0.3.17.json").sha256_text(),"renderer":RenderingServer.get_video_adapter_name()},"  "))
 print("PASS Summit Bay native file import, screenshots and exact cached/full raster")
 game.queue_free();await process_frame;quit()
