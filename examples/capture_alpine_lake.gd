extends SceneTree
func _initialize():call_deferred("run")
func shot(path):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var error=root.get_texture().get_image().save_png(path)
 if error!=OK:push_error("Capture failed");quit(1)
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless":quit(1);return
 var out:String=args[0]
 root.size=Vector2i(1800,1100);root.content_scale_size=Vector2i(854,522);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false)
 game._native_action="import";game._on_file_selected(out+"/MetroForge-Alpine-Lake.json")
 if game.world.seed!=187203:push_error("Native file-import callback failed");quit(1);return
 game.view.set_process(false);game.set_grid_visible(false);game.choose_tool("pan");game._toast.hide()
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.fit_city();await shot(out+"/Alpine-Lake-Overview.png")
 game.view.tile_scale=13.8;game.view.camera=game.view.size*.5-game.view._point(18,24,8)*13.8/28.
 await shot(out+"/Alpine-Lake-Foothill-City.png")
 game.view.tile_scale=20;game.view.camera=game.view.size*.5-game.view._point(38,41,1)*20/28.
 await shot(out+"/Alpine-Lake-Town.png")
 game.view.tile_scale=12;game.view.camera=game.view.size*.5-game.view._point(38,26,1)*12/28.
 await shot(out+"/Alpine-Lake-Highway-and-Lake.png")
 print("PASS native showcase import/captures: pop=",game.world.stats.population," schema=",game.world.serialize().version)
 game.queue_free();await process_frame;quit()
