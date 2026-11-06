extends SceneTree
## Import the distributed city through the real native file callback and capture it.
const S=preload("res://persistence/city_store.gd")
const FILE="MetroForge-Three-Valleys-0.3.19.json"
var game
var out:String
func _initialize():call_deferred("run")
func shot(name:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var pixels=root.get_texture().get_image()
 assert(pixels.save_png(out+"/"+name)==OK)
 return pixels
func focus(x:float,y:float,h:float,scale:float):
 game.view.tile_scale=scale
 game.view.camera=game.view.size*.5-game.view._point(x,y,h)*scale/28.
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless":quit(1);return
 out=args[0]
 root.size=Vector2i(1800,1100);root.content_scale_size=Vector2i(854,522)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 game=load("res://main.tscn").instantiate();root.add_child(game)
 game.paused=true;game.set_process(false)
 game._native_action="import";game._on_file_selected(out+"/"+FILE)
 assert(game.world.seed==6110626,"Native city import callback failed")
 assert(game.world.cityHistory.size()==25,"Native file import retains real monthly history")
 assert(game.world.scenario.is_empty(),"Example opens in sandbox")
 var before=S.export_json(game.world)
 game.view.set_process(false);game.set_grid_visible(false);game.choose_tool("pan");game._toast.hide()
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.fit_city()
 var cached=await shot("Three-Valleys-Overview.png")
 game.view._cached_world=null;game.view.refresh()
 var full=await shot("Three-Valleys-Full-Rebuild.png")
 assert(cached.get_data()==full.get_data(),"Retained and full terrain rendering must match")
 focus(14,16,3,20);await shot("Three-Valleys-Granite-City.png")
 focus(41,11,2,25);await shot("Three-Valleys-Riverbend.png")
 focus(41,44,2,25);await shot("Three-Valleys-Lakehaven.png")
 focus(12,42,24,16);await shot("Three-Valleys-High-Country.png")
 game.open_dialog("report");await process_frame;await process_frame
 assert(game._report_panel!=null,"Report opens in the actual game")
 game._report_panel.select_section("History");await shot("Three-Valleys-History.png")
 game.close_dialog()
 assert(S.export_json(game.world)==before,"Rendering and Report views must preserve the save")
 var result={"native_file_import":true,"rendering_preserves_city":true,"retained_full_equal":true,"real_history_months":game.world.cityHistory.size(),"population":game.world.stats.population,"save_version":game.world.serialize().version,"renderer":RenderingServer.get_video_adapter_name(),"city_sha256":FileAccess.get_file_as_string(out+"/"+FILE).sha256_text()}
 var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("PASS Three Valleys native import, history, sandbox, preview neutrality and retained/full raster")
 game.queue_free();await process_frame;quit()
