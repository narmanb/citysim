extends SceneTree
const World=preload("res://model/city_world.gd")
const History=preload("res://ui/construction_history.gd")
class CountWorld extends World:
    var recalculations=0
    var reflows=0
    func recalculate():
        recalculations+=1
        super.recalculate()
    func _terrain_reflow():
        reflows+=1
        super._terrain_reflow()
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
    checks+=1
    if not ok: failures+=1;push_error(message)
func blank():
    var w=CountWorld.new(4242)
    for i in range(World.COUNT): w.tiles[i]=World.blank_tile()
    w.cash=1000000;w.recalculate();w.recalculations=0;w.reflows=0
    return w
func run():
    if not ResourceLoader.exists("res://model/terrain_editor.gd"):
        check(false,"A pure set-based terrain planner is required");quit(1);return
    var editor=load("res://model/terrain_editor.gd")
    for radius in [0,1,2]:
        var center=editor.footprint(26*52+26,radius)
        check(center.size()==(radius*2+1)*(radius*2+1),"Centered square has expected footprint")
        for corner in [0,51,2652,2703]:
            var cells=editor.footprint(corner,radius)
            check(cells.size()==(radius+1)*(radius+1),"Brush clips symmetrically at every corner")
            for i in cells: check(i>=0 and i<World.COUNT,"No invalid brush indices")
    check(editor.footprint(-1,1).is_empty() and editor.footprint(0,3).is_empty(),"Invalid footprints reject")
    var w=blank()
    var cells=editor.footprint(26*52+26,2)
    var before=w.serialize()
    var plan=editor.plan(w,cells+cells,"raise",4)
    check(w.serialize()==before and w.recalculations==0 and w.reflows==0,"Planning never mutates world or runs simulation")
    check(plan.cost==0 and plan.targets.size()==25,"Duplicates produce one free target per changed cell")
    var result=editor.commit(w,plan)
    check(result.changed and w.cash==before.cash,"Atomic set commits without spending")
    check(w.recalculations==1 and w.reflows==1,"A 25-cell stamp recalculates/reflows once")
    for i in cells: check(w.tiles[i].elev==4,"Step4 applies equally across footprint")
    for key in ["road","rail","line","pipe","civic","zone","terrain"]:
        var tile=World.blank_tile()
        if key in ["road","rail","line","pipe"]: tile[key]=true
        elif key=="civic": tile.civic="school"
        elif key=="zone": tile.zone="res";tile.zoneType="house";tile.resType="house";tile.parcel=88;tile.autoGrow=true
        else: tile=World.blank_tile("water")
        w.tiles[0]=tile
        w.tiles[1].elev=0
        plan=editor.plan(w,[0,1],"raise",2)
        check(plan.blocked.has(0) and not plan.targets.has(0) and plan.targets.has(1),"Protected "+key+" remains unchanged, eligible neighbor is planned")
        var saved=w.tiles[0].duplicate(true)
        result=editor.commit(w,plan)
        check(result.changed and w.tiles[0]==saved,"Commit preserves protected "+key+" exactly")
    w=blank();w.cash=-50
    plan=editor.plan(w,cells,"raise",4)
    before=w.serialize();result=editor.commit(w,plan)
    check(plan.affordable and result.changed and w.cash==before.cash and result.after.size()==25,"Free terrain transaction works in debt without spending")
    w=blank();w.tiles[0].elev=39;w.tiles[1].elev=-4
    plan=editor.plan(w,[0],"raise",4);editor.commit(w,plan)
    check(w.tiles[0].elev==40 and plan.cost==0,"Free bounded step clamps upward")
    plan=editor.plan(w,[1],"lower",4);editor.commit(w,plan)
    check(w.tiles[1].elev==-5 and plan.cost==0,"Bounded step clamps downward")
    plan=editor.plan(w,[0],"raise",4)
    check(plan.cost==0 and not editor.commit(w,plan).changed,"Bound no-op is free")
    plan=editor.plan(w,[0,1,2],"flatten",1,3);editor.commit(w,plan)
    check(w.tiles[0].elev==3 and w.tiles[1].elev==3 and w.tiles[2].elev==3,"Flatten targets both higher and lower natural land")
    check(editor.plan(w,[0,1,2],"flatten",1,3).cost==0,"Already-flat area is free")
    for args in [["raise",3,null],["flatten",1,41],["flatten",1,0.5],["unknown",1,null]]:
        plan=editor.plan(w,[0],args[0],args[1],args[2])
        check(not editor.commit(w,plan).changed,"Unsupported edit settings reject safely")
    plan=editor.plan(w,[3],"raise",1);w.tiles[3].tree=true
    check(not editor.commit(w,plan).changed and w.tiles[3].elev==0,"Stale preview cannot overwrite a changed tile")
    w=blank();w.tiles[100]=World.blank_tile("water")
    for i in [101,102,103]: w.tiles[i].channel=true;w.tiles[i].elev=-1
    w.recalculate();w.recalculations=0;w.reflows=0
    var original=w.tiles.duplicate(true)
    plan=editor.plan(w,[101],"raise",2);result=editor.commit(w,plan)
    check(result.changed and result.before.has(103) and result.after[103].terrain=="grass","Transaction captures downstream channel reflow")
    check(w.recalculations==1 and w.reflows==1,"Channel transaction also reflows exactly once")
    var history=History.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
    w.cash+=123;w.month=5
    check(history.undo(w) and w.tiles==original and w.cash==1000123 and w.month==5,"Undo restores all channels and refunds only edit, preserving income/time")
    check(history.redo(w) and w.tiles[103].terrain=="grass" and w.cash==1000123,"Redo restores full accepted free edit")
    print("Terrain editor: %s checks, %s failures"%[checks,failures]);quit(1 if failures else 0)
