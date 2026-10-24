extends SceneTree
const W=preload("res://model/city_world.gd")
const G=preload("res://model/terrain_geometry.gd")
var failures:Array[String]=[]
func check(ok:bool,msg:String):
 if not ok:failures.append(msg)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false)
 await process_frame;await process_frame
 var w=W.new(41)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.cash=1000000;w.recalculate();game.set_world(w);game.choose_tool("mountain")
 var panel=game._terrain_panel
 var button=panel.find_child("PeakPickerButton",true,false)
 check(button!=null,"Peak is opened by a button")
 check(W.MAX_TERRAIN_ELEV==40,"All terrain shares maximum40")
 if button!=null:
  for size in [Vector2i(854,394),Vector2i(640,360)]:
   root.size=size;root.content_scale_size=size
   button.pressed.emit();await process_frame;await process_frame
   check(panel._peak_popup.visible,"Peak opens modal popup")
   check(panel._peak_popup.size.x<=size.x and panel._peak_popup.size.y<=size.y,"Picker fits viewport")
   panel.find_child("PeakPreset40",true,false).pressed.emit()
   check(game.terrain_settings.mountain_peak==40 and not panel._peak_popup.visible,"Preset40 applies and closes")
  button.pressed.emit();panel._peak.value=23
  panel._peak_popup.confirmed.emit();panel._peak_popup.hide()
  check(game.terrain_settings.mountain_peak==23 and button.text.contains("23"),"Custom height applies to button and tool")
  button.pressed.emit();panel._peak.value=17;panel._peak_popup.hide()
  check(game.terrain_settings.mountain_peak==23,"Dismiss discards unconfirmed custom value")
  game.choose_tool("hill");button.pressed.emit();panel.find_child("PeakPreset12",true,false).pressed.emit()
  check(game.terrain_settings.hill_peak==12 and game.terrain_settings.mountain_peak==23,"Hill/Mountain choices independent")
  game.choose_tool("mountain");button.pressed.emit();panel.find_child("PeakPreset40",true,false).pressed.emit()
  var c=26*52+26
  check(game.construct_at(c) and is_equal_approx(G.sample(w.tiles,c),40.),"Picker40 creates visible summit40")
  check(game.undo() and w.tiles[c].elev==0 and game.redo(),"Peak40 placement reversible")
  check(W.from_dict(w.serialize())!=null,"Peak40 saves import")
  check(not game.set_sculpt_settings({"mountain_peak":41}),"Beyond40 rejects")
 game.queue_free();await process_frame
 for f in failures:push_error(f)
 print("Peak picker: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
