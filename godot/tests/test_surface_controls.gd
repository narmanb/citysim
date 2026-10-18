extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true
 await process_frame;await process_frame
 game.choose_tool("surface")
 if game.selected_tool!="surface":push_error("Surface brush must be selectable");game.queue_free();await process_frame;quit(1);return
 check(game.set_sculpt_settings({"surface_top":"snow","surface_rock":"gray"}),"Appearance controls accept current materials")
 check(not game.set_sculpt_settings({"surface_top":"lava"}),"Unsupported material rejected")
 for viewport in [Vector2(854,394),Vector2(640,360)]:
  game.size=viewport;game._layout_shell();await process_frame
  check(game._terrain_panel.find_child("SurfaceTop",true,false).visible,"Top control visible")
  check(game._terrain_dock.get_global_rect().end.y<game.view.get_global_rect().end.y-70,"Surface controls clear FPS and zoom")
 game.open_dialog("overlays")
 var toggle=game.find_child("GridToggle",true,false)
 check(toggle!=null,"Grid toggle exists in Overlays")
 if toggle!=null:
  toggle.button_pressed=true
  check(game.view.grid_visible,"GUI grid toggle updates renderer")
  toggle.button_pressed=false
  check(not game.view.grid_visible,"Grid can be hidden")
 game.close_dialog()
 game.set_grid_visible(true)
 var saved=ConfigFile.new();saved.load("user://view.cfg")
 check(saved.get_value("view","grid",false)==true,"Grid preference saved")
 game.set_grid_visible(false)
 game.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Surface controls: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
