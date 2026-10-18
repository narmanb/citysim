extends SceneTree
const World=preload("res://model/city_world.gd")
const View=preload("res://view/isometric_view.gd")
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
    checks+=1
    if not ok: failures+=1;push_error(message)
func blank():
    var w=World.new(4242)
    for i in range(World.COUNT): w.tiles[i]=World.blank_tile()
    w.cash=1000000
    w.recalculate()
    return w
func run():
    var w=blank()
    check(World.MAX_TERRAIN_ELEV==30,"Maximum elevation is30")
    for i in [0,51,2652,2703,26*52+26]:
        w.tiles[i].elev=-5
        for height in range(-5,31):
            if height>-5: check(w.place(i,"raise"),"Raise reaches height %s at %s"%[height,i])
            check(w.tiles[i].elev==height,"Authoritative height matches requested raise")
        var cash=w.cash
        check(not w.place(i,"raise") and w.cash==cash,"Raise at +30 is a free no-op")
        for height in range(29,-6,-1): check(w.place(i,"lower") and w.tiles[i].elev==height,"Lower reaches every legal height")
        cash=w.cash
        check(not w.place(i,"lower") and w.cash==cash,"Lower at -5 is a free no-op")
    for height in range(-5,31):
        w.tiles[0].elev=height
        var restored=World.from_dict(JSON.parse_string(JSON.stringify(w.serialize())))
        check(restored!=null and restored.tiles[0].elev==height,"Every legal elevation survives JSON import")
    for height in [-6,31,0.5,"5",INF,NAN]:
        var data=w.serialize();data.tiles[0].elev=height
        check(World.from_dict(data)==null,"Malformed or unsupported elevation rejects import")
    var old=World.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy-city-v6.json")))
    check(old!=null and old.cash==23456 and old.tiles[1325].elev==3,"Legacy v6 remains readable")
    if old!=null:
        var restored=World.from_dict(old.serialize())
        check(restored!=null and restored.tiles==old.tiles and restored.cash==old.cash,"Normalized old save retains all tiles on round-trip")
    w=blank()
    var view=View.new();view.size=Vector2(854,274)
    root.add_child(view);view.set_process(false);view.set_world(w)
    await process_frame;await process_frame
    for height in range(-5,31):
        for t in w.tiles: t.elev=height
        for i in [0,51,2652,2703,26*52+26,27*52+26]:
            check(view.screen_to_tile(view.tile_to_screen(i))==i,"Visible cap selection at height %s edge %s"%[height,i])
    for t in w.tiles: t.elev=0
    var high=26*52+26
    w.tiles[high].elev=30
    var wall=view.camera+view._point(27,26.5,15)*view.tile_scale/view.BASE
    check(view.screen_to_tile(wall)==high,"Visible cliff wall prevents selecting hidden background cap")
    w.tiles[0].elev=30
    w.place(0,"office",false,77);w.tiles[0].level=4
    view.refresh();await process_frame;await process_frame
    view.fit_city()
    for commands in view._tile_records[0].values():
        for command in commands:
            if command[0]==2:
                var r: Rect2=command[2]
                for p in [r.position,r.end,Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y)]:
                    var screen=view.camera+p*view.tile_scale/view.BASE
                    check(Rect2(Vector2.ZERO,view.size).grow(0.01).has_point(screen),"Fit includes every roof corner on +30 map edge")
    # Deep channel plus an upstream dam retains the legacy connectivity rule.
    w=blank();w.tiles[100]=World.blank_tile("water")
    for i in [101,102,103]: w.place(i,"river");w.tiles[i].elev=-5
    w._terrain_reflow()
    check(w.tiles[103].terrain=="water","Deep connected channel fills")
    w.tiles[101].elev=30;w._terrain_reflow()
    check(w.tiles[102].terrain=="grass" and w.tiles[103].terrain=="grass" and w.tiles[104].terrain=="grass","High dam disconnects channels without flooding ordinary land")
    view.queue_free();await process_frame
    print("Terrain bounds: %s checks, %s failures"%[checks,failures]);quit(1 if failures else 0)
