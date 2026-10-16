extends SceneTree
const World = preload("res://model/city_world.gd")
const View = preload("res://view/isometric_view.gd")
const Layer = preload("res://view/iso_layer.gd")
var failures=0
func check(value: bool, message: String):
    if not value:
        failures+=1
        push_error(message)
func _initialize(): call_deferred("run")
func run():
    var world=World.new(4242)
    var view=View.new()
    view.size=Vector2(854,394)
    root.add_child(view)
    view.set_world(world)
    await process_frame
    await process_frame
    check(view.get_node("City").get_child_count()<450,"Map rendering must batch static items instead of one scene node per tile")
    var retained={}
    for node in view.get_node("City").get_children(): retained[node.get_instance_id()]=true
    var edited=26*52+26
    world.tiles[edited]=World.blank_tile()
    var cap=Layer.new()
    view._draw_ground(cap,edited)
    check(cap.commands.size()==1,"Opaque flat terrain must draw one textured cap without redundant fill and antialiased borders")
    cap.free()
    world.recalculate()
    view.refresh()
    await process_frame
    await process_frame
    var stable={}
    for node in view.get_node("City").get_children(): stable[node.get_instance_id()]=true
    check(world.place(edited,"res"),"Fixture zone placement succeeds")
    world.recalculate()
    view.refresh()
    await process_frame
    await process_frame
    var reused=0
    for node in view.get_node("City").get_children():
        if stable.has(node.get_instance_id()): reused+=1
    check(reused>=int(stable.size()*0.9),"A single zone edit must retain existing static canvas items")
    check(int(view.metrics.get("tiles_regenerated",2704))<=9,"A single zone edit must regenerate only its local neighborhood")
    var before=view.metrics.ground_redraws
    for i in range(25):
        view.camera+=Vector2(3,-2)
        view.zoom_at(1.01,view.size*0.5)
    await process_frame
    check(view.metrics.ground_redraws==before,"Pan and zoom must reuse static commands")
    view.overlay="landValue"
    check(view._overlay_layer.commands.size()==2704,"Field overlays cover every tile even when no tiles are burning")
    view.overlay="none"
    # Distant mutations and parcel developments must still refresh at their own locations.
    var far=33*52+35
    world.tiles[far]=World.blank_tile()
    world.place(far,"res")
    world.tiles[far].level=1
    world.tiles[far].elev=3
    world.recalculate()
    view.refresh()
    await process_frame
    await process_frame
    check(view.screen_to_tile(view.tile_to_screen(far))==far,"Cached raised development retains accurate picking")
    var cache_count=view.get_node("City").get_child_count()
    for i in range(8):
        world.tiles[edited].elev=(i%3)
        view.refresh()
        await process_frame
    check(view.get_node("City").get_child_count()<=cache_count+6,"Repeated terrain editing must not leak canvas items")
    view.queue_free()
    await process_frame
    print("RENDER CACHE: ",failures," failures")
    quit(0 if failures==0 else 1)
