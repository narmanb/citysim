extends SceneTree
## Internal terrain regression fixture, never a distributed showcase city.
const World=preload("res://model/city_world.gd")
const View=preload("res://view/isometric_view.gd")
func _initialize(): call_deferred("run")
func shot(path):
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(path)!=OK:
        push_error("Cannot save terrain capture");quit(1)
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()<1 or DisplayServer.get_name()=="headless":
        push_error("Use a GL display: --script tools/preview_terrain.gd -- OUTPUT [PEAK]");quit(1);return
    var out=args[0]
    var peak=int(args[1]) if args.size()>1 else 12
    DirAccess.make_dir_recursive_absolute(out)
    root.size=Vector2i(1280,720)
    root.content_scale_size=Vector2i(1280,720)
    var world=World.new(4242)
    world.cash=1000000
    for i in range(World.COUNT): world.tiles[i]=World.blank_tile()
    for y in range(17,34):
        for x in range(17,22): world.tiles[y*World.N+x]=World.blank_tile("water")
    for y in range(20,23):
        for x in range(25,28): world.tiles[y*World.N+x].elev=peak
    for y in range(25,29):
        for x in range(26,31): world.tiles[y*World.N+x].biome="desert"
    for y in range(24,27):
        for x in range(23,25): world.tiles[y*World.N+x].elev=-3 if peak==5 else -5
    for x in range(16,25):
        world.place(29*World.N+x,"road",true)
        world.place(31*World.N+x,"rail",true)
    for y in range(20,23):
        for x in range(25,28):
            world.place(y*World.N+x,"apt",false,1)
            world.tiles[y*World.N+x].level=2
    for x in range(29,32): world.tiles[22*World.N+x].tree=true
    world.place(22*World.N+28,"line")
    world.recalculate()
    world.cars=[];world.trains=[];world.events=[]
    var view=View.new()
    view.size=Vector2(1280,720)
    root.add_child(view)
    view.set_process(false)
    view.set_world(world)
    view.fit_city()
    await shot(out+"/fit.png")
    view.tile_scale=45
    view.camera=view.size*.5-view._point(25,25)*view.tile_scale/28.0
    await shot(out+"/terrain.png")
    var bounds=FileAccess.open(out+"/metrics.json",FileAccess.WRITE)
    bounds.store_string(JSON.stringify({"peak":peak,"metrics":view.metrics,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}))
    view.queue_free();await process_frame;quit()
