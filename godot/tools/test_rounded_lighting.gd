extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
func _initialize(): call_deferred("run")
func capture():
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	if DisplayServer.get_name()=="headless": push_error("Use actual GL display");quit(1);return
	root.size=Vector2i(854,394);root.content_scale_size=Vector2i(854,394)
	var w=W.new(41)
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
	var v=V.new();v.size=Vector2(854,394);root.add_child(v);v.set_world(w)
	v.tile_scale=28;v.camera=v.size*.5-v._point(26,26)
	var flat=await capture()
	for y in range(23,29):
		for x in range(23,29): w.tiles[y*52+x].terrainShape="rounded"
	v.refresh();var rounded=await capture()
	var difference:float=0;var count:int=0
	var flat_mean:=Vector3.ZERO
	var rounded_mean:=Vector3.ZERO
	for y in range(177,217):
		for x in range(387,467):
			var a=flat.get_pixel(x,y);var b=rounded.get_pixel(x,y)
			difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);count+=3
			flat_mean+=Vector3(a.r,a.g,a.b);rounded_mean+=Vector3(b.r,b.g,b.b)
	difference/=count
	flat_mean/=float(count)/3.;rounded_mean/=float(count)/3.
	print("Mean flat ",flat_mean," Rounded ",rounded_mean)
	print("Flat/Rounded zero-grade mean color difference: ",difference)
	# Detail intentionally varies individual pixels; retain the mean palette and
	# reject the old whole-surface darkening without rejecting the new texture.
	var mean_delta: Vector3 = (flat_mean-rounded_mean).abs()
	var failed: bool = maxf(mean_delta.x,maxf(mean_delta.y,mean_delta.z))>.005 or difference>.02
	if failed: push_error("Level Rounded detail must preserve average base material brightness")
	v.queue_free();await process_frame;quit(1 if failed else 0)
