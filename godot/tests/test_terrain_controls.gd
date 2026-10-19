extends SceneTree
const World=preload("res://model/city_world.gd")
class CountWorld extends World:
    var edits_recalculated=0
    func recalculate():
        edits_recalculated+=1
        super.recalculate()
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
    checks+=1
    if not ok: failures+=1;push_error(message)
func touch(view,id,at,down,canceled=false):
    var e=InputEventScreenTouch.new();e.index=id;e.position=at;e.pressed=down;e.canceled=canceled;view._gui_input(e)
func drag(view,id,at):
    var e=InputEventScreenDrag.new();e.index=id;e.position=at;view._gui_input(e)
func blank():
    var w=CountWorld.new(4242)
    for i in range(World.COUNT): w.tiles[i]=World.blank_tile()
    w.cash=1000000;w.recalculate();w.edits_recalculated=0
    return w
func run():
    var game=load("res://ui/main.gd").new();root.add_child(game);game.paused=true
    await process_frame;await process_frame
    if not game.has_method("set_terrain_settings"):
        check(false,"Terrain controls need explicit brush/height/Flatten settings");game.queue_free();await process_frame;quit(1);return
    var w=blank();game.set_world(w);await process_frame;await process_frame
    var center=26*52+26
    check(game.terrain_settings.radius==0 and game.terrain_settings.step==1 and game.terrain_settings.flatten_target==null,"Session starts with single-cell one-step sampled settings")
    game.choose_tool("raise");game.set_terrain_settings(1,4)
    var preview=game.terrain_preview_at(center)
    check(preview.cost==180 and preview.targets.size()==9 and w.tiles[center].elev==0,"Preview reports exact nine-cell cost before editing")
    check(game._tool_name.text.contains("3×3") and game._tool_name.text.contains("4"),"Selected tool summary always exposes radius/step")
    check(game.construct_at(center),"Tap applies one whole brush")
    check(w.tiles[center-53].elev==4 and w.tiles[center+53].elev==4 and game.history.undo_stack.size()==1,"Tap covers full square in one undo action")
    check(w.edits_recalculated==1,"One controller brush recalculates once")
    await process_frame;await process_frame
    check(game.view.metrics.tiles_regenerated<=25,"Terrain brush invalidates only affected caps and neighboring walls")
    var redraws=game.view.metrics.ground_redraws
    game.view.camera+=Vector2(7,9);game.view.zoom_at(1.05,game.view.size*.5)
    await process_frame
    check(game.view.metrics.ground_redraws==redraws,"Terrain editing retains mesh reuse during camera movement")
    check(game.undo() and w.tiles[center].elev==0,"Whole brush undoes")
    check(game.redo() and w.tiles[center].elev==4,"Whole brush redoes")
    w=blank();game.set_world(w);game.choose_tool("raise");game.set_terrain_settings(1,2)
    game.begin_stroke();game.paint_at(center);game.paint_at(center+1);game.paint_at(center)
    game.paused=false;game.advance_time(5);game.paused=true
    check(w.month==1,"Staged terrain transaction holds simulation clock until commit")
    game.end_stroke()
    check(w.tiles[center].elev==2 and w.tiles[center+2].elev==2 and game.history.undo_stack.size()==1,"Overlapping stroke stamps apply one frozen delta")
    check(w.cash==1000000-12*20 and w.edits_recalculated==1,"Overlapping brushes charge12 unique cells and recalculate once")
    game.clear_history();w.cash=1
    var before=w.serialize();check(not game.construct_at(center) and w.serialize()==before and game.history.undo_stack.is_empty(),"Unaffordable brush makes no history or partial edits")
    w=blank();game.set_world(w);game.choose_tool("flatten");game.set_terrain_settings(1,1)
    w.tiles[center].elev=3
    check(game.construct_at(center) and w.tiles[center-53].elev==3 and w.tiles[center+53].elev==3,"Flatten samples first touched tile height")
    game.set_terrain_settings(0,1,-5)
    check(game.construct_at(center) and w.tiles[center].elev==-5,"Explicit Flatten target supports -5")
    game.set_terrain_settings(0,1,30);game.construct_at(center);game.clear_history();game.choose_tool("raise")
    var cash=w.cash
    check(not game.construct_at(center) and w.cash==cash and game.history.undo_stack.is_empty(),"Bound no-op makes no controller history")
    check(not game.set_terrain_settings(3,1) and not game.set_terrain_settings(0,3) and not game.set_terrain_settings(0,1,31),"Invalid UI settings reject")
    # Actual native touch stream: preview on down, cancel/pinch free, release commits.
    w=blank();game.set_world(w);game.choose_tool("raise");game.set_terrain_settings(1,1);game.set_placement_mode("paint")
    await process_frame;await process_frame
    game.view.tile_scale=30;game.view.camera=game.view.size*.5-game.view._point(26.5,26.5)*30/28.0
    var p=game.view.tile_to_screen(center);var q=game.view.tile_to_screen(center+4)
    touch(game.view,0,p,true);drag(game.view,0,q)
    check(w.tiles[center].elev==0 and not game.view.terrain_preview.is_empty(),"Touch drag previews without spending")
    touch(game.view,1,q+Vector2(80,0),true);drag(game.view,1,q+Vector2(100,0));touch(game.view,1,q,false);touch(game.view,0,q,false)
    check(w.cash==1000000 and game.history.undo_stack.is_empty(),"Pinch discards pending brush footprint")
    game.view.camera=game.view.size*.5-game.view._point(26.5,26.5)*30/28.0
    p=game.view.tile_to_screen(center);q=game.view.tile_to_screen(center+4)
    touch(game.view,0,p,true);drag(game.view,0,q);touch(game.view,0,q,false,true)
    check(w.cash==1000000 and game.history.undo_stack.is_empty(),"Canceled terrain stroke spends nothing")
    touch(game.view,0,p,true);drag(game.view,0,q);touch(game.view,0,q,false)
    check(w.tiles[center].elev==1 and w.tiles[center+4].elev==1 and game.history.undo_stack.size()==1,"Fast release fills skipped brush centers in one transaction")
    var mouse=InputEventMouseButton.new();mouse.device=-1;mouse.position=p;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;game.view._gui_input(mouse);mouse.pressed=false;game.view._gui_input(mouse)
    check(w.tiles[center].elev==1 and game.history.undo_stack.size()==1,"Synthetic mouse does not duplicate terrain edits")
    game.set_placement_mode("tapPan");cash=w.cash
    touch(game.view,0,p,true);drag(game.view,0,p+Vector2(90,30));touch(game.view,0,p+Vector2(90,30),false)
    check(w.cash==cash,"Tap-pan terrain drag pans freely")
    # A retraced path must commit exactly its deduplicated preview set.
    w=blank();game.set_world(w);game.choose_tool("raise");game.set_terrain_settings(0,1);game.set_placement_mode("paint")
    await process_frame;await process_frame
    game.view.tile_scale=30;game.view.camera=game.view.size*.5-game.view._point(10.5,11.5)*30/28.0
    var route=[10*52+10,11*52+10,12*52+10,11*52+10,11*52+11]
    p=game.view.tile_to_screen(route[0]);touch(game.view,0,p,true)
    for i in route.slice(1): drag(game.view,0,game.view.tile_to_screen(i))
    check(game.view.terrain_preview.targets.size()==4 and game.view.terrain_preview.cost==80,"Retraced-path preview contains four actual cells")
    touch(game.view,0,game.view.tile_to_screen(route[-1]),false)
    check(w.cash==1000000-80 and w.tiles[12*52+11].elev==0,"Retraced paint commits only previewed cells and exact cost")
    # Trackpad/native gesture events must discard a pending mouse terrain edit.
    for gesture_kind in ["magnify","pan"]:
        w=blank();game.set_world(w);await process_frame;await process_frame
        game.choose_tool("raise");game.set_terrain_settings(0,1)
        game.view.tile_scale=30;game.view.camera=game.view.size*.5-game.view._point(26.5,26.5)*30/28.0
        p=game.view.tile_to_screen(center)
        var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=p;game.view._gui_input(down)
        check(w.cash==1000000 and not game.view._pending_tiles.is_empty(),"Mouse terrain stroke is pending before native gesture")
        var gesture=InputEventMagnifyGesture.new() if gesture_kind=="magnify" else InputEventPanGesture.new()
        gesture.position=p
        if gesture_kind=="magnify": gesture.factor=1.1
        else: gesture.delta=Vector2(2,3)
        game.view._gui_input(gesture)
        down.pressed=false;game.view._gui_input(down)
        check(w.cash==1000000 and w.tiles[center].elev==0 and game.history.undo_stack.is_empty(),"Native "+gesture_kind+" cancels pending terrain construction")
    # Shape choices, preview, history and native cancellation share the terrain transaction.
    w=blank();game.set_world(w);game.choose_tool("shape");game.set_terrain_settings(1,1)
    check(game.set_terrain_shape("slope","E",2),"Explicit slope settings accepted")
    preview=game.terrain_preview_at(center)
    check(preview.after.size()==9 and preview.after[center].terrainShape=="slope" and preview.after[center].elev==0,"Shape preview changes corners without reference height")
    check(game.construct_at(center) and game.history.undo_stack.size()==1 and w.tiles[center].slopeDir=="E","Shape brush is one construction action")
    check(game.undo() and w.tiles[center].terrainShape=="flat" and game.redo() and w.tiles[center].shapeStrength==2,"Shape metadata and cost support Undo/Redo")
    var restored=preload("res://persistence/city_store.gd").import_json(game.export_city_text())
    check(restored!=null and restored.tiles[center].slopeDir=="E","Controller export retains ramps")
    game.set_terrain_settings(0,1);game.set_placement_mode("paint")
    await process_frame;await process_frame
    game.view.tile_scale=30;game.view.camera=game.view.size*.5-game.view._point(26.5,26.5)*30/28.0
    p=game.view.tile_to_screen(center+4);cash=w.cash
    touch(game.view,0,p,true)
    check(not game.view.terrain_preview.is_empty() and w.cash==cash,"Native shape touch previews")
    game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
    touch(game.view,0,p,false)
    check(w.tiles[center+4].terrainShape=="flat" and w.cash==cash,"Backgrounding discards uncommitted shape gesture")
    game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
    # Mouse Shape must stay pending like touch until release/cancellation.
    game.choose_tool("shape")
    p=game.view.tile_to_screen(center+4)
    var shape_down=InputEventMouseButton.new();shape_down.button_index=MOUSE_BUTTON_LEFT;shape_down.pressed=true;shape_down.position=p
    game.view._gui_input(shape_down)
    game.view._cancel_pointers()
    check(w.cash==cash and w.tiles[center+4].terrainShape=="flat","Cancel mouse Shape never commits or spends")
    game.choose_tool("raise")
    for dimensions in [Vector2i(1280,591),Vector2i(854,394),Vector2i(640,360)]:
        root.size=dimensions;root.content_scale_size=dimensions;await process_frame;await process_frame
        game.choose_tool("raise");game.set_terrain_shape("slope","E",2)
        game.select_category("Terraform");await process_frame;await process_frame
        var panel=game.find_child("TerrainSettings",true,false)
        var map_before=game.view.get_global_rect()
        check(panel!=null and panel.is_visible_in_tree(),"Terrain settings visible with menu at "+str(dimensions))
        check(not game._tool_menu.is_ancestor_of(panel),"Settings live outside the Terraform submenu")
        var dock=game.find_child("TerrainDock",true,false)
        check(dock!=null,"Persistent settings have their own map dock")
        if dock!=null:
            var bounds=dock.get_global_rect()
            check(bounds.position.x>=dimensions.x-180 and bounds.size.x<=168,"Settings stay in a narrow right-hand dock")
            check(game._tool_menu.get_global_rect().end.x+4<=bounds.position.x,"Tool menu and dock never overlap")
            var fps=game.view.get_parent().find_child("PerformanceDisplay",true,false)
            check(fps!=null and bounds.end.y<=fps.get_global_rect().position.y-2,"Dock stays above FPS and zoom controls at "+str(dimensions)+": "+str(bounds)+" FPS "+str(fps.get_global_rect() if fps!=null else Rect2()))
            check(bounds.encloses(panel._slope_row.get_global_rect()),"Direction and strength fit inside dock")
        check(game._tool_buttons.has("flatten") and game.CATEGORIES.Zoning==["res","shop","light"],"Terrain and zoning tool choices retained")
        game.choose_tool("flatten");await process_frame;await process_frame
        check(not game._tool_menu.visible and panel.is_visible_in_tree(),"Settings remain available after tool menu closes")
        check(game.view.get_global_rect()==map_before,"Persistent settings overlay preserves map size")
        game._terrain_panel._target_mode.select(1);game._terrain_panel._target_mode.item_selected.emit(1)
        game._terrain_panel._target_level.value=7
        check(game.terrain_settings.flatten_target==7 and panel.is_visible_in_tree() and not game._tool_menu.visible,"Flatten target adjusts from closed-menu dock")
        game.choose_tool("raise");await process_frame;await process_frame
        panel._steps[4].pressed.emit()
        check(game.terrain_settings.step==4 and panel.is_visible_in_tree() and not game._tool_menu.visible,"Height step adjusts without reopening submenu")
        game.set_terrain_settings(0,1)
        await process_frame;await process_frame
        var at=panel._steps[4].get_global_rect().get_center()
        var move=InputEventMouseMotion.new();move.position=at;root.push_input(move,true)
        var click=InputEventMouseButton.new();click.position=at;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
        cash=w.cash
        root.push_input(click,true)
        click=click.duplicate();click.pressed=false;root.push_input(click,true)
        await process_frame
        check(game.terrain_settings.step==4 and w.cash==cash,"Real dock button click updates settings without painting map beneath")
        game.set_terrain_shape("flat","auto",1)
        await process_frame;await process_frame
        if dock!=null: check(dock.size.y<=146 and not panel._slope_row.visible and panel._edges_row.visible,"Flat settings fit the new Edges row without unused slope space")
        panel._brush.select(2);panel._brush.item_selected.emit(2)
        check(game.terrain_settings.radius==2 and game.terrain_preview_at(center).targets.size()==25,"Dock brush dropdown updates actual preview footprint")
        panel._shape.select(1);panel._shape.item_selected.emit(1)
        await process_frame;await process_frame
        check(game.terrain_settings.shape=="slope" and panel._slope_row.is_visible_in_tree(),"Dock shape dropdown reveals live direction and strength")
        game.select_category("Zoning");await process_frame
        check(panel.is_visible_in_tree(),"Browsing another category keeps active terrain settings")
        game.choose_tool("res");await process_frame
        check(not panel.is_visible_in_tree(),"Selecting a non-terrain tool hides settings")
    game.choose_tool("river");game.select_category("Terraform");await process_frame
    check(not game.find_child("TerrainSettings",true,false).is_visible_in_tree(),"Height brush controls stay hidden for unchanged single-cell terrain tools")
    game.queue_free();await process_frame
    print("Terrain controls: %s checks, %s failures"%[checks,failures]);quit(1 if failures else 0)
