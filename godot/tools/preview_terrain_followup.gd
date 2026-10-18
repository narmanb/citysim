extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
func _initialize(): call_deferred("run")
func shot(path):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();assert(image.save_png(path)==OK);return image
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless": push_error("Use GL display and output directory");quit(1);return
 var out:String=args[0];DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var w=W.new(41)
 for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
 w.cash=1000000
 var c=25*52+25
 for i in E.footprint(c,1): w.tiles[i].elev=5
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.tile_scale=32;game.view.camera=game.view.size*.5-game.view._point(25.5,25.5,5)*32/28.
 await shot(out+"/plateau-before.png")
 var p=E.plan(w,E.footprint(c,1),"raise",1,null,{"shape":"rounded","direction":"auto","strength":1})
 E.commit(w,p);game.view.refresh();await shot(out+"/plateau-raised.png")
 E.commit(w,E.plan(w,[],"mountain",1,null,{"preset_radius":2,"peak":12,"profile":2,"preset_shape":"rounded"},[c+8]))
 game.view.refresh();game.view.tile_scale=24;game.view.camera=game.view.size*.5-game.view._point(29,25,0)*24/28.
 var cached=await shot(out+"/grass-mountain.png")
 game.view._cached_world=null;game.view.refresh();var rebuilt=await shot(out+"/rebuilt.png")
 if cached.get_data()!=rebuilt.get_data(): push_error("Cached/full mismatch");quit(1);return
 for i in E.footprint(c+8,2): w.tiles[i].biome="desert"
 game.view.refresh();await shot(out+"/sand-mountain.png")
 game.view.fit_city();await shot(out+"/fit.png")
 print("PASS follow-up capture: plateau before/raised, grass/sand, fit, cached/full equality")
 game.queue_free();await process_frame;quit()
