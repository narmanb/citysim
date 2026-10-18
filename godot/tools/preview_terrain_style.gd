extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
func _initialize():call_deferred("run")
func shot(path):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();assert(image.save_png(path)==OK);return image
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless":push_error("Use GL display and output directory");quit(1);return
 var out:String=args[0];DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var w=W.new(41);w.cash=1000000
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 for y in range(20,27):
  for x in range(20,27):w.tiles[y*52+x].elev=4
 E.commit(w,E.plan(w,[],"mountain",1,null,{"preset_radius":2,"peak":12,"profile":2,"preset_shape":"rounded"},[23*52+23]))
 for y in range(21,26):
  for x in range(27,30):w.tiles[y*52+x].merge({"elev":2,"terrainShape":"cliff"},true)
 for y in range(21,26):w.tiles[y*52+26].merge({"elev":8,"terrainShape":"rounded","roundedBase":4},true)
 for x in range(21,25):w.place(20*52+x,"tree")
 E.commit(w,E.plan(w,[],"hill",1,null,{"preset_radius":2,"peak":8,"profile":2,"preset_shape":"rounded"},[23*52+34]))
 for y in range(20,27):
  for x in range(31,38):w.tiles[y*52+x].biome="desert"
 w.recalculate()
 var snapshot=w.tiles.duplicate(true)
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await process_frame;await process_frame
 game.view.tile_scale=24;game.view.camera=game.view.size*.5-game.view._point(24,23,1)*24/28.
 var cached=await shot(out+"/mountain-cliff.png")
 game.view._cached_world=null;game.view.refresh();var rebuilt=await shot(out+"/rebuilt.png")
 if cached.get_data()!=rebuilt.get_data():push_error("Material cached/full mismatch");quit(1);return
 w.tiles[23*52+27].elev=0;game.view.refresh();cached=await shot(out+"/edited-join.png")
 game.view._cached_world=null;game.view.refresh();rebuilt=await shot(out+"/edited-rebuilt.png")
 if cached.get_data()!=rebuilt.get_data():push_error("Edited material cached/full mismatch");quit(1);return
 w.tiles=snapshot.duplicate(true);game.view.refresh()
 game.view.tile_scale=16;game.view.camera=game.view.size*.5-game.view._point(27,24,0)*16/28.
 await shot(out+"/district.png")
 game.view.fit_city();await shot(out+"/fit.png")
 if w.tiles!=snapshot:push_error("Rendering changed terrain");quit(1);return
 print("PASS terrain style GL: grass/desert/cliff joins, edit invalidation, cached/full pixels, no world mutation")
 game.queue_free();await process_frame;quit()
