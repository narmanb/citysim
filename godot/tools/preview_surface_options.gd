extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const S=preload("res://persistence/city_store.gd")
func _initialize():call_deferred("run")
func shot(path):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();assert(image.save_png(path)==OK);return image
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or DisplayServer.get_name()=="headless":push_error("Use GL display and output directory");quit(1);return
 var out:String=args[0];DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var w=W.new(41)
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 w.cash=1000000;w.recalculate()
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
 await process_frame;await process_frame
 if not game.has_method("set_grid_visible"):push_error("Missing functional grid toggle");quit(1);return
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 game.set_grid_visible(false);game.view.tile_scale=28;game.view.camera=game.view.size*.5-game.view._point(26,26,0)
 var flat=await shot(out+"/flat.png")
 for y in range(23,29):
  for x in range(23,29):w.tiles[y*52+x].terrainShape="rounded"
 game.view.refresh();var rounded=await shot(out+"/rounded-flat.png")
 if flat.get_data()!=rounded.get_data():push_error("Flat and zero-relief rounded base must render identically");quit(1);return
 var redraws=game.view.metrics.ground_redraws
 game.set_grid_visible(true);var grid=await shot(out+"/grid-on.png")
 if grid.get_data()==rounded.get_data() or game.view.metrics.ground_redraws!=redraws:push_error("Grid must toggle actual pixels without mesh rebuild");quit(1);return
 game.set_grid_visible(false)
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 for x in range(17,20):
  for y in range(18,38):w.tiles[y*52+x]=W.blank_tile("water")
 for spec in [[24,24,"snow","gray"],[32,25,"sand","brown"],[25,33,"grass","grass"]]:
  var result=E.commit(w,E.plan(w,[],"mountain",1,null,{"preset_radius":2,"peak":12,"surface_top":spec[2],"surface_rock":spec[3]},[spec[1]*52+spec[0]]))
  if not result.changed:push_error("Material preset failed");quit(1);return
 for x in range(21,26):w.place(21*52+x,"tree")
 game.view.refresh();game.view.tile_scale=19;game.view.camera=game.view.size*.5-game.view._point(27,27,0)*19/28.
 var before=S.export_json(w)
 var cached=await shot(out+"/materials.png")
 game.view._cached_world=null;game.view.refresh();var rebuilt=await shot(out+"/rebuilt.png")
 if cached.get_data()!=rebuilt.get_data() or S.export_json(w)!=before:push_error("Surface cache or world mutation regression");quit(1);return
 game.set_grid_visible(true);await shot(out+"/materials-grid.png");game.set_grid_visible(false)
 game.choose_tool("surface");game.set_sculpt_settings({"surface_top":"snow","surface_rock":"gray"});game.select_category("Terraform")
 await shot(out+"/controls.png")
 root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
 await shot(out+"/narrow.png")
 game.open_dialog("overlays");await shot(out+"/grid-toggle.png")
 var state=S.import_json(before)
 if state==null or state.tiles[24*52+24].surfaceTop!="snow":push_error("Appearance import failed");quit(1);return
 print("PASS GL surfaces: exact flat/rounded base pixels, grid pixels/no rebuild, snow/sand/grass, water, cache equality, controls, import")
 game.queue_free();await process_frame;quit()
