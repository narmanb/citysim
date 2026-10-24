extends SceneTree
const W=preload("res://model/city_world.gd")
var failures:Array[String]=[]
var game
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func type_number(spin:SpinBox,text:String):
 var edit=spin.get_line_edit();edit.grab_focus();edit.select_all()
 for letter in text:
  var code=letter.unicode_at(0)
  for down in [true,false]:
   var key=InputEventKey.new();key.keycode=code;key.unicode=code if down else 0;key.pressed=down;Input.parse_input_event(key);await process_frame
func run():
 root.size=Vector2i(854,394);root.content_scale_size=Vector2i(854,394)
 game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false)
 var w=W.new(41);w.cash=1000000
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 game.set_world(w);game.choose_tool("mountain");game._close_tool_menu()
 game._terrain_panel._profile.select(2);game._terrain_panel._profile.item_selected.emit(2)
 await process_frame;await process_frame
 game._terrain_panel._peak_button.pressed.emit();await process_frame
 await type_number(game._terrain_panel._peak,"40")
 game._terrain_panel._peak_popup.confirmed.emit();game._terrain_panel._peak_popup.hide()
 check(game.terrain_settings.mountain_peak==40,"Typing Peak40 updates the value without keyboard Enter")
 var c=25*52+25
 game.view.tile_scale=35;game.view.camera=game.view.size*.5-game.view._point(25.5,25.5)*35/28.
 var point=game.view.global_position+game.view.tile_to_screen(c)
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.global_position=point;e.pressed=down;Input.parse_input_event(e);await process_frame
 check(w.tiles[c].elev==40,"Map tap uses typed Peak40 while the numeric field still has focus")
 check(game.history.undo_stack.size()==1 and game.undo() and w.tiles[c].elev==0,"Typed peak placement stays one reversible action")
 check(game.redo() and w.tiles[c].elev==40,"Redo retains typed peak")
 game.choose_tool("flatten");game.set_terrain_settings(0,1,0)
 await process_frame;await process_frame
 await type_number(game._terrain_panel._target_level,"-5")
 check(game.terrain_settings.flatten_target==-5,"Typing a negative Flatten height updates without Enter")
 check(game.construct_at(c) and w.tiles[c].elev==-5,"Flatten uses the typed height")
 game.choose_tool("hill");await process_frame;await process_frame
 game._terrain_panel._peak_button.pressed.emit();await process_frame
 await type_number(game._terrain_panel._peak,"12")
 game._terrain_panel._peak_popup.confirmed.emit();game._terrain_panel._peak_popup.hide()
 check(game.terrain_settings.hill_peak==12 and game.terrain_settings.mountain_peak==40,"Hill and Mountain retain their independent typed settings")
 game._terrain_panel._peak_button.pressed.emit();await process_frame
 await type_number(game._terrain_panel._peak,"41")
 game._terrain_panel._peak_popup.confirmed.emit();game._terrain_panel._peak_popup.hide()
 check(game.terrain_settings.hill_peak==40 and game._terrain_panel._peak.get_line_edit().text=="40","Typed values above40 clamp both the setting and visible field")
 game._terrain_panel._peak_button.pressed.emit();game._terrain_panel._peak.value=29;game._terrain_panel._peak_popup.confirmed.emit()
 check(game.terrain_settings.hill_peak==29,"SpinBox arrow changes still update the setting")
 game.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Numeric terrain input: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
