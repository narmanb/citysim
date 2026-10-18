extends SceneTree
const W=preload("res://model/city_world.gd")
var failures: Array[String]=[]
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func touch(view,id,at,down):
	var event=InputEventScreenTouch.new();event.index=id;event.position=at;event.pressed=down;view._gui_input(event)
func run():
	var game=load("res://ui/main.gd").new();root.add_child(game);game.paused=true
	await process_frame;await process_frame
	check(game.choose_tool("smooth"),"Smooth tool selectable")
	if game.selected_tool!="smooth":
		game.queue_free();await process_frame
		for message in failures: push_error(message)
		quit(1);return
	var w=W.new(42)
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
	w.cash=1000000;w.recalculate();game.set_world(w)
	var c=26*52+26
	game.choose_tool("mountain")
	var p=game.terrain_preview_at(c)
	check(p.after.has(c) and p.after[c].elev==12 and p.after.size()<=25,"Default Mountain preview is bounded5x5peak12")
	check(game.construct_at(c) and w.tiles[c].elev==12 and game.history.undo_stack.size()==1,"Preset tap is one transaction")
	check(game.undo() and w.tiles[c].elev==0 and game.redo() and w.tiles[c].terrainShape=="rounded","Preset entire shape/history roundtrip")
	game.choose_tool("smooth");game.set_terrain_settings(1,1)
	check(game.set_sculpt_settings({"smooth_strength":1}),"Smooth strength session setting")
	var before=w.tiles[c].elev
	check(game.construct_at(c) and w.tiles[c].elev>=before-1,"Smooth uses bounded Gentle action")
	for dimensions in [Vector2i(854,394),Vector2i(640,360)]:
		root.size=dimensions;root.content_scale_size=dimensions
		for tool in ["smooth","hill","mountain"]:
			game.choose_tool(tool);await process_frame;await process_frame
			var dock=game.find_child("TerrainDock",true,false)
			var fps=game.find_child("PerformanceDisplay",true,false)
			check(dock.is_visible_in_tree() and not game._tool_menu.visible,"Sculpt controls persistent for "+tool)
			check(dock.size.x<=168 and dock.get_global_rect().end.y<=fps.get_global_rect().position.y-2,"Sculpt controls fit without overlap "+tool+str(dimensions))
			game.select_category("Terraform");await process_frame;await process_frame
			check(game._tool_menu.get_global_rect().end.x+4<=dock.get_global_rect().position.x,"Expanded tools fit beside sculpt controls "+tool+str(dimensions)+str(game._tool_menu.get_global_rect())+str(dock.get_global_rect()))
	game.choose_tool("hill")
	game._terrain_panel._peak.value=7
	game._terrain_panel._preset_size.select(2);game._terrain_panel._preset_size.item_selected.emit(2)
	check(game.terrain_settings.hill_peak==7 and game.terrain_settings.preset_radius==4,"Preset Peak/Size controls update session")
	game.choose_tool("mountain");game.set_placement_mode("paint")
	await process_frame;await process_frame
	game.view.tile_scale=20;game.view.camera=game.view.size*.5-game.view._point(35.5,35.5)*20/28.
	var at=game.view.tile_to_screen(35*52+35)
	var cash=w.cash
	touch(game.view,0,at,true)
	check(not game.view.terrain_preview.is_empty() and w.cash==cash,"Preset native down previews only")
	touch(game.view,1,at+Vector2(40,0),true);touch(game.view,1,at+Vector2(40,0),false);touch(game.view,0,at,false)
	check(w.cash==cash,"Preset pinch cancels all pending spending")
	game.queue_free();await process_frame
	for message in failures: push_error(message)
	print("Sculpt controls: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
