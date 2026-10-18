extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
func _initialize():call_deferred("run")
func shot(path):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var im=root.get_texture().get_image();assert(im.save_png(path)==OK);return im
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=2 or DisplayServer.get_name()=="headless":quit(1);return
 var out:String=args[0];var peak=int(args[1]);DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var w=W.new(41);w.cash=1000000
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 E.commit(w,E.plan(w,[],"mountain",1,null,{"preset_radius":2,"peak":peak,"profile":3,"surface_top":"snow" if peak>12 else "auto","surface_rock":"brown" if peak>12 else "grass"},[25*52+25]))
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false);game.set_grid_visible(false)
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.tile_scale=35 if peak>12 else 55;game.view.camera=game.view.size*.5-game.view._point(26,26,peak*.4)*game.view.tile_scale/28.
 var original=w.serialize();var cached=await shot(out+"/mountain.png")
 game.view._cached_world=null;game.view.refresh();var rebuilt=await shot(out+"/rebuilt.png")
 assert(cached.get_data()==rebuilt.get_data());assert(original==w.serialize())
 game.choose_tool("mountain");game.set_sculpt_settings({"mountain_peak":peak});await shot(out+"/controls.png")
 game.view.fit_city();await shot(out+"/fit.png")
 print("PASS mountain GL capture, cache pixels and no world mutation; peak=",peak)
 game.queue_free();await process_frame;quit()
