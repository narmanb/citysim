## Deterministic visible-city draw-call/frame probe. Import fixture, pause simulation, animate agents/pan at fixed timesteps.
extends SceneTree
var results=[]
var game
var out: String
var city_path: String
func _initialize(): call_deferred("run")
func run():
    var arguments = OS.get_cmdline_user_args()
    if arguments.size() != 2 or DisplayServer.get_name() == "headless":
        push_error("Run with a GL display: --script tools/profile_city.gd -- CITY.json OUTPUT_DIRECTORY")
        quit(1)
        return
    city_path = arguments[0]
    out = arguments[1]
    DirAccess.make_dir_recursive_absolute(out)
    root.size=Vector2i(1280,591)
    root.content_scale_size=Vector2i(854,394)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    game=load("res://main.tscn").instantiate()
    root.add_child(game)
    game.paused=true
    game.set_process(false)
    if not game.import_city_text(FileAccess.get_file_as_string(city_path)):
        push_error("City import failed");quit(1);return
    game.view.set_process(false)
    game._toast.hide()
    for i in range(5): await process_frame
    var hist={}
    var ground={}
    var objects={}
    for key in game.view._static_layers:
        var layer=game.view._static_layers[key]
        for c in layer.commands:
            hist[c[0]]=hist.get(c[0],0)+1
            var d=objects if game.view._bucket_objects.get(key,false) else ground
            d[c[0]]=d.get(c[0],0)+1
    print("COMMANDS all=",JSON.stringify(hist)," ground=",JSON.stringify(ground)," objects=",JSON.stringify(objects)," static_layers=",game.view._static_layers.size())
    await measure("fit_static",0,false,false)
    await measure("fit_agents",0,true,true)
    await measure("district_agents",14.5,true,true)
    await measure("close_agents",35.0,true,true)
    for key in game.view._static_layers:
        if game.view._bucket_objects.get(key,false): game.view._static_layers[key].visible=false
    await measure("fit_ground_only",0,false,false)
    for key in game.view._static_layers:
        game.view._static_layers[key].visible=not game.view._static_layers[key].commands.is_empty()
        if not game.view._bucket_objects.get(key,false): game.view._static_layers[key].visible=false
    await measure("fit_objects_only",0,false,false)
    for key in game.view._static_layers:
        game.view._static_layers[key].visible=not game.view._static_layers[key].commands.is_empty()
    for layer in game.view._agent_layers: layer.visible=false
    for key in game.view._static_layers:
        if int(key)%20==4: game.view._static_layers[key].visible=false
    await measure("fit_without_poles",0,false,false)
    var f=FileAccess.open(out+"/render.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name() + "; desktop measurements do not establish Android FPS","viewport":[1280,591],"logical":[854,394],"population":game.world.stats.population,"commands":hist,"ground_commands":ground,"object_commands":objects,"results":results},"  "))
    f.close()
    game.queue_free()
    await process_frame
    quit()
func measure(label:String, scale_value:float, agents:bool, pan:bool):
    var view=game.view
    if scale_value==0: view.fit_city()
    else:
        view.tile_scale=scale_value
        view.camera=view.size*0.5-view._point(25,22)*view.tile_scale/28.0
    for i in range(5):
        await process_frame
        await RenderingServer.frame_post_draw
    var times=[]
    var calls=[]
    var objects=[]
    var start=Time.get_ticks_usec()
    var cpu=[]
    for i in range(35):
        var cstart=Time.get_ticks_usec()
        if agents:
            game.world.advance_agents(1.0/60.0)
            view._update_agents()
        if pan:
            view.camera+=Vector2(sin(i*.2)*.6,cos(i*.3)*.4)
            view.zoom_at(1.001 if i%2==0 else 1.0/1.001,view.size*.5)
        cpu.append((Time.get_ticks_usec()-cstart)/1000.0)
        await process_frame
        await RenderingServer.frame_post_draw
        var now=Time.get_ticks_usec()
        if i>=5:
            times.append((now-start)/1000.0)
            calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
            objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
        start=now
    times.sort();calls.sort();cpu.sort();objects.sort()
    var row={"case":label,"frame_median_ms":times[times.size()/2],"frame_p95_ms":times[int(times.size()*.95)],"draw_calls_median":calls[calls.size()/2],"objects_median":objects[objects.size()/2],"input_agents_cpu_median_ms":cpu[cpu.size()/2],"scale":view.tile_scale}
    results.append(row)
    print("HARBOR ",JSON.stringify(row))
    if label in ["fit_static","district_agents","close_agents"]:
        root.get_texture().get_image().save_png(out+"/"+label+".png")
