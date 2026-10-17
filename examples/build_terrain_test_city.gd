extends SceneTree
## Reproducible 0.3.3 terrain test data, not a new game feature/showcase.
## godot --headless --path godot --script /absolute/path/to/this.gd -- OUTPUT
const World = preload("res://model/city_world.gd")
const Store = preload("res://persistence/city_store.gd")
const Editor = preload("res://model/terrain_editor.gd")
const History = preload("res://ui/construction_history.gd")
const FILE = "MetroForge-Terraform-Test-City-0.3.3.json"
var city
var output: String
var checks: Array = []
var failed: bool = false

func _initialize(): call_deferred("run")
func idx(x: int, y: int) -> int: return y * World.N + x
func require(ok: bool, message: String) -> void:
    checks.append({"check":message,"passed":ok})
    if not ok: failed=true;push_error(message)
func put(x: int,y: int,tool: String,bridge: bool=false) -> void:
    require(city.place(idx(x,y),tool,bridge),"Legal "+tool+" at "+str(Vector2i(x,y)))
func rectangle(x: int,y: int,width: int,depth: int,elevation: int,biome: String="grass") -> void:
    for yy in range(y,y+depth):
        for xx in range(x,x+width):
            city.tiles[idx(xx,yy)].elev=elevation
            city.tiles[idx(xx,yy)].biome=biome
func lot(x: int,y: int,tool: String,level: int) -> void:
    var parcel: int=city.nextParcelId
    for yy in range(y,y+2):
        for xx in range(x,x+2):
            require(city.place(idx(xx,yy),tool,false,parcel),"Clear test-town lot")
            city.tiles[idx(xx,yy)].level=level
            city.tiles[idx(xx,yy)].autoGrow=tool=="res"
func utilities(x: int,y: int) -> void:
    var t: Dictionary=city.tiles[idx(x,y)]
    if not t.civic and not t.line: put(x,y,"line")
    if not t.pipe: put(x,y,"pipe")
func copy_city(): return Store.import_json(Store.export_json(city))
func same_construction(a: Array,b: Array) -> bool:
    # Undo restores construction; live occupancy is derived by recalculate.
    for i in range(a.size()):
        var aa: Dictionary=a[i].duplicate(true)
        var bb: Dictionary=b[i].duplicate(true)
        aa.erase("occupancy");bb.erase("occupancy")
        if aa!=bb: return false
    return true

func run() -> void:
    var args=OS.get_cmdline_user_args()
    if args.size()!=1: push_error("Pass an output folder");quit(1);return
    output=args[0]
    DirAccess.make_dir_recursive_absolute(output)
    city=World.new(733003)
    for i in range(World.COUNT): city.tiles[i]=World.blank_tile()
    city.cash=1000000
    # Color/shape landmarks; the practice field remains flat and editable.
    rectangle(8,16,5,5,12)
    rectangle(15,30,5,5,-5)
    for strip in range(4): rectangle(32+strip*2,25,2,8,strip*2,"desert")
    for x in [18,20,22]: city.tiles[idx(x,25)].tree=true
    for y in range(17,29):
        put(16,y,"road");put(28,y,"road")
    for x in range(17,28): put(x,17,"road");put(x,28,"road")
    # Natural water plus one-cell channel: first channel tile is the dam gate.
    for y in range(34,44):
        for x in range(5,12): city.tiles[idx(x,y)]=World.blank_tile("water")
    for x in range(12,27): put(x,38,"river")
    for x in range(4,15):
        put(x,36,"road",true);put(x,42,"rail",true)
    put(4,42,"station");put(14,42,"station")
    for y in range(29,37): put(28,y,"road")
    for x in range(15,28): put(x,36,"road")
    # Compact functional neighborhood to test protection and service continuity.
    for y in [11,13,16]:
        for x in range(30,45): put(x,y,"road")
    for x in [30,37,44]:
        for y in range(8,19):
            if not city.tiles[idx(x,y)].road: put(x,y,"road")
    put(29,17,"road")
    put(29,8,"plant")
    put(29,9,"pump")
    for entry in [[32,9,"res",2],[35,9,"res",2],[38,9,"shop",2],[41,9,"shop",2],[32,14,"apt",2],[35,14,"apt",2],[38,14,"office",2],[41,14,"light",2]]:
        lot(entry[0],entry[1],entry[2],entry[3])
    put(34,12,"school");put(35,12,"hospital");put(38,12,"fire")
    put(32,12,"park");put(40,12,"park")
    for x in range(30,45):
        for y in [8,12,16]: utilities(x,y)
    for y in range(9,19):
        for x in [30,37,44]: utilities(x,y)
    # A separate pipe/pole pair in the grass field makes buried protection visible.
    put(26,20,"pipe");put(26,21,"line")
    city.recalculate()
    for n in range(300): city.advance_agents(1.0/30.0)
    city.cash=1000000
    city.notify("TERRAIN TEST LAB: Pause first. Road-framed grass = brushes; stepped desert = Flatten; tall bare plateau = +12; deep basin = -5. Lake channel gate is its first tile beside shore. Re-import to reset.")
    var text: String=Store.export_json(city)
    require(text.to_utf8_buffer().size()<Store.MAX_BYTES,"File fits native import size limit")
    var restored=Store.import_json(text)
    require(restored!=null,"Export imports through native CityStore")
    if restored==null: quit(1);return
    # JSON numbers load as floats; compare semantic numeric content, then use
    # the normalized imported city as the baseline for exact history checks.
    require(JSON.parse_string(JSON.stringify(restored.tiles))==JSON.parse_string(JSON.stringify(city.tiles)) and restored.cash==1000000,"Every tile and treasury survives JSON round-trip")
    city=restored
    text=Store.export_json(city)
    require(city.stats.population>0 and city.stats.jobs>0,"Test town has real residents and jobs")
    require(city.stats.unpowered==0 and city.stats.unwatered==0,"Test town has adequate real connected utilities")
    require(city.tiles[idx(26,38)].terrain=="water","Entire downstream test channel begins filled")
    var w=copy_city()
    var cells=Editor.footprint(idx(21,21),1)
    var plan=Editor.plan(w,cells,"raise",2)
    var result=Editor.commit(w,plan)
    require(result.changed and result.cost==180 and plan.targets.size()==9,"Open-field 3x3 step2 costs exactly $180")
    var history=History.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
    require(history.undo(w) and same_construction(w.tiles,city.tiles) and w.cash==city.cash,"One Undo restores the full test brush and money")
    require(history.redo(w) and w.tiles[idx(21,21)].elev==2,"Redo reapplies complete test brush")
    w=copy_city();cells=Editor.footprint(idx(35,28),2)
    plan=Editor.plan(w,cells,"flatten",1,3);result=Editor.commit(w,plan)
    require(result.changed and plan.targets.size()==25,"5x5 desert patch can flatten to +3")
    for i in cells: require(w.tiles[i].elev==3 and w.tiles[i].biome=="desert","Flatten preserves sand and sets exact target")
    for pair in [[idx(10,18),"raise"],[idx(17,32),"lower"]]:
        w=copy_city();var old_cash=w.cash
        result=Editor.commit(w,Editor.plan(w,[pair[0]],pair[1]))
        require(not result.changed and w.cash==old_cash,"Height-limit edit is free")
    w=copy_city();var gate=idx(12,38)
    result=Editor.commit(w,Editor.plan(w,[gate],"raise",2))
    require(result.changed and w.tiles[idx(26,38)].terrain=="grass","Raising channel gate from -1 to +1 dries downstream channel")
    history=History.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
    require(history.undo(w) and same_construction(w.tiles,city.tiles),"Channel Undo restores distant water exactly")
    var blocked=[idx(32,9),idx(30,11),idx(4,42),idx(29,8),idx(26,20),idx(26,21),idx(8,38)]
    plan=Editor.plan(city,blocked,"raise",2)
    require(plan.targets.is_empty() and plan.blocked.size()==blocked.size(),"Homes roads rail buildings pipes poles and natural water are protected")
    w=copy_city();w.cash=179
    var before=w.serialize()
    result=Editor.commit(w,Editor.plan(w,Editor.footprint(idx(21,21),1),"raise",2))
    require(not result.changed and w.serialize()==before,"Unaffordable brush applies no partial edit")
    if failed: quit(1);return
    var file=FileAccess.open(output+"/"+FILE,FileAccess.WRITE);file.store_string(text);file.close()
    var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false)
    await process_frame
    game._native_action="import";game._on_file_selected(output+"/"+FILE)
    require(game.world.seed==city.seed and game.world.tiles==city.tiles,"Actual native file-import callback loads the downloaded test city")
    await process_frame;await process_frame
    if DisplayServer.get_name()!="headless":
        root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(854,480)
        root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
        await process_frame;await process_frame
        game._toast.hide();game.view.tile_scale=10
        game.view.camera=game.view.size*.5-game.view._point(25,25)*10/28.0
        await process_frame;await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/Terrain-Test-City-Preview.png")
    var report={"source_commit":"43979e90c0a0e268c2cdac244c4e6c6393074aab","required_app":"0.3.3-terraform-preview","map":[52,52],"cash":city.cash,"population":city.stats.population,"jobs":city.stats.jobs,"power_missing":city.stats.unpowered,"water_missing":city.stats.unwatered,"cars":city.cars.size(),"trains":city.trains.size(),"bytes":text.to_utf8_buffer().size(),"checks":checks,"passed":not failed}
    file=FileAccess.open(output+"/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    game.queue_free();await process_frame
    print("Terrain Test City: %s checks; pop %s / jobs %s / cash %s; failures %s"%[checks.size(),city.stats.population,city.stats.jobs,city.cash,failed])
    quit(1 if failed else 0)
