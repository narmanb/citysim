# Software/display rendering probe: full-city pan and zoom, five warmup frames.
# Run with a display and --rendering-method gl_compatibility. Not an Android FPS test.
extends SceneTree
const World=preload("res://model/city_world.gd")
const View=preload("res://view/isometric_view.gd")
func _initialize(): call_deferred("run")
func run():
    root.size=Vector2i(1280,591)
    root.content_scale_size=Vector2i(1280,591)
    var view=View.new()
    view.size=Vector2(1280,591)
    root.add_child(view)
    var world=World.new(4242)
    view.set_world(world)
    view.fit_city()
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for i in range(5): await process_frame
    var values=[]
    var calls=[]
    var start=Time.get_ticks_usec()
    for i in range(65):
        view.camera+=Vector2(sin(i*0.2)*3,cos(i*0.3)*2)
        if i%2==0: view.zoom_at(1.003,view.size*0.5)
        else: view.zoom_at(1.0/1.003,view.size*0.5)
        await process_frame
        await RenderingServer.frame_post_draw
        var now=Time.get_ticks_usec()
        if i>=5:
            values.append((now-start)/1000.0)
            calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        start=now
    values.sort()
    calls.sort()
    print("ZOOMED_OUT_SOFTWARE=",JSON.stringify({"frame_interval_median_ms":values[values.size()/2],"frame_interval_p95_ms":values[int(values.size()*.95)],"draw_calls_median":calls[calls.size()/2],"nodes":view.get_node("City").get_child_count(),"ground_rebuilds":view.metrics.ground_redraws}))
    view.queue_free()
    await process_frame
    quit()
