extends SceneTree
const W=preload("res://model/city_world.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String):
	if not ok:failures.append(message)
func blank():
	var w=W.new(51)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	w.cash=100000;w.recalculate();return w
func touch(view,id,at,down,canceled=false):
	var e=InputEventScreenTouch.new();e.index=id;e.position=at;e.pressed=down;e.canceled=canceled;view._gui_input(e)
func _initialize():call_deferred("run")
func run():
	var game=load("res://ui/main.gd").new();root.add_child(game);game.paused=true;game.set_process(false)
	await process_frame;await process_frame
	var w=blank();game.set_world(w);game.choose_tool("raise")
	check(not game.terrain_settings.get("smooth_edges",false),"Sharp is default")
	var edge=game.find_child("TerrainEdges",true,false)
	check(edge!=null,"Raise/Lower exposes compact Edges selector")
	check(game.set_sculpt_settings({"smooth_edges":true}),"Smooth edges is a supported session setting")
	if edge==null or not game.terrain_settings.get("smooth_edges",false):
		for f in failures:push_error(f)
		game.queue_free();await process_frame;quit(1);return
	check(game.terrain_settings.shape=="flat","Smooth edges keeps the top flat")
	game.set_terrain_settings(1,2)
	var c=26*52+26
	var preview=game.terrain_preview_at(c)
	check(preview.after.size()==49 and preview.cost==980 and preview.level_top==2,"Preview includes selected platform and expanded perimeter")
	check(w.tiles[c].elev==0 and game.history.undo_stack.is_empty(),"Preview never commits")
	check(game.construct_at(c) and game.history.undo_stack.size()==1,"Entire platform and perimeter is one Undo")
	var after=w.tiles.duplicate(true)
	check(w.cash==100000-preview.cost,"Preview and committed total cost agree")
	check(game.undo() and w.tiles[c].elev==0 and w.cash==100000,"Undo restores full cost and original surface")
	check(game.redo() and w.tiles==after,"Redo preserves exact grade corners")
	w=blank();game.set_world(w);game.set_terrain_settings(0,1)
	game.begin_stroke();game.paint_at(c);game.paint_at(c+1);game.paint_at(c)
	preview=game.terrain_preview_at(c,[c,c+1])
	game.end_stroke()
	check(w.cash==100000-preview.cost and game.history.undo_stack.size()==1,"Overlapping frozen stroke matches preview")
	for i in [c,c+1]:check(w.tiles[i].elev==1 and w.tiles[i].terrainShape=="flat","Paint stroke has one level top")
	for cancel_kind in ["cancel","pinch"]:
		w=blank();game.set_world(w);game.set_placement_mode("paint")
		await process_frame;await process_frame
		game.view.tile_scale=30;game.view.camera=game.view.size*.5-game.view._point(26.5,26.5)*30/28.
		var at=game.view.tile_to_screen(c)
		touch(game.view,0,at,true)
		check(not game.view.terrain_preview.is_empty() and w.cash==100000,"Native touch previews graded platform without spending")
		if cancel_kind=="pinch":
			touch(game.view,1,at+Vector2(80,0),true);touch(game.view,1,at+Vector2(80,0),false)
		touch(game.view,0,at,false,cancel_kind=="cancel")
		check(w.cash==100000 and w.tiles[c].elev==0 and game.history.undo_stack.is_empty(),"Native "+cancel_kind+" discards graded edit")
	for dimensions in [Vector2i(854,394),Vector2i(640,360)]:
		root.size=dimensions;root.content_scale_size=dimensions
		for tool in ["raise","lower"]:
			game.choose_tool(tool)
			for smooth in [false,true]:
				game.set_sculpt_settings({"smooth_edges":smooth});await process_frame;await process_frame
				var dock=game.find_child("TerrainDock",true,false)
				var fps=game.find_child("PerformanceDisplay",true,false)
				check(edge.is_visible_in_tree() and dock.size.x<=168,"Edges control remains compact and visible")
				check(dock.get_global_rect().end.y<=fps.get_global_rect().position.y-2,"No collision with FPS/zoom "+str(dimensions))
				game.select_category("Terraform");game._close_tool_menu();await process_frame
				check(dock.visible and edge.is_visible_in_tree(),"Setting persists after submenu closes")
	game.choose_tool("flatten");await process_frame
	check(not edge.is_visible_in_tree(),"Edges appears only where applicable")
	game.choose_tool("raise");game.set_sculpt_settings({"smooth_edges":true})
	game.set_terrain_shape("slope","E",1)
	check(not game.terrain_settings.smooth_edges,"Choosing an explicit shape restores ordinary shape mode")
	check(not game.set_sculpt_settings({"smooth_edges":"yes"}),"Malformed flag rejects")
	w=blank();w.tiles[c+1].road=true;game.set_world(w);game.set_sculpt_settings({"smooth_edges":true});game.set_terrain_settings(0,1)
	preview=game.terrain_preview_at(c)
	check(not preview.error.is_empty() and not game.construct_at(c) and w.cash==100000,"Blocked transition is free and explained")
	game.queue_free();await process_frame
	for f in failures:push_error(f)
	print("Smooth edge controls: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
