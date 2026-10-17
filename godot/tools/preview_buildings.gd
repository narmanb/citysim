extends SceneTree
## GL building gallery and incremental/full-render regression.
## Run with a display: godot --path godot --script tools/preview_buildings.gd -- OUTPUT_DIRECTORY
var output: String
const World=preload("res://model/city_world.gd")
const View=preload("res://view/isometric_view.gd")
func _initialize(): call_deferred("run")
func shot(path):
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var pic=root.get_texture().get_image()
    if pic.save_png(path)!=OK:
        push_error("Cannot save capture");quit(1)
    return pic
func run():
    var arguments=OS.get_cmdline_user_args()
    if arguments.size()!=1 or DisplayServer.get_name()=="headless":
        push_error("Run with a GL display and one output-directory argument");quit(1);return
    output=arguments[0]
    if DirAccess.make_dir_recursive_absolute(output)!=OK:
        push_error("Cannot create output directory");quit(1);return
    root.size=Vector2i(1440,900)
    root.content_scale_size=Vector2i(1440,900)
    var world=World.new(4242)
    for i in range(World.COUNT): world.tiles[i]=World.blank_tile()
    world.cash=1000000
    var parcel=1
    for entry in [[20,20,"res",1],[25,20,"apt",2],[30,20,"shop",2],[20,25,"office",3],[25,25,"light",2],[30,25,"heavy",3]]:
        for y in range(entry[1],entry[1]+3):
            for x in range(entry[0],entry[0]+3):
                var i=y*World.N+x
                world.place(i,entry[2],false,parcel)
                world.tiles[i].level=entry[3]
        parcel+=1
    for y in [19,24,29]:
        for x in range(19,35): world.place(y*World.N+x,"road")
    for y in range(19,30):
        for x in [19,24,29,34]: world.place(y*World.N+x,"road")
    world.recalculate()
    world.cars=[];world.trains=[];world.events=[]
    var view=View.new()
    view.size=Vector2(1440,900)
    root.add_child(view)
    view.set_process(false)
    view.set_world(world)
    view.tile_scale=42
    view.camera=view.size*.5-view._point(26.5,24.5)*view.tile_scale/28.0
    await shot(output+"/all-types.png")
    view.tile_scale=74
    view.camera=view.size*.5-view._point(26.5,21.5)*view.tile_scale/28.0+Vector2(0,70)
    await shot(output+"/apartment-complex.png")
    for y in range(20,23):
        for x in range(20,23):
            var t=world.tiles[y*World.N+x]
            t.zoneType="apt";t.resType="apt";t.level=2;t.elev=1
    world.recalculate();view.refresh()
    view.tile_scale=42
    view.camera=view.size*.5-view._point(26.5,24.5)*view.tile_scale/28.0
    var cached=await shot(output+"/incremental.png")
    view._cached_world=null
    view.refresh()
    var complete=await shot(output+"/full.png")
    if cached.get_data()!=complete.get_data():
        push_error("Incremental building promotion/elevation differs from complete rebuild");quit(1);return
    print("BUILDING PROMOTION/ELEVATION: INCREMENTAL PIXELS MATCH FULL REBUILD")
    view.queue_free();await process_frame;quit()
