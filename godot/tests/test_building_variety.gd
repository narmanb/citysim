extends SceneTree
const World = preload("res://model/city_world.gd")
const View = preload("res://view/isometric_view.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists("res://view/building_catalog.gd"):
		push_error("Stable building styles must have a catalog separate from the simulation")
		quit(1)
		return
	var catalog = load("res://view/building_catalog.gd").new()
	var seen: Dictionary = {}
	for parcel in range(1, 97):
		var style: Dictionary = catalog.style_for(4242, parcel, "house")
		check(style == catalog.style_for(4242, parcel, "house"), "Style remains stable for the same city/property")
		seen[style.floor] = true
	check(seen.size() >= 12, "A neighborhood uses multiple silhouettes and palettes")
	var world = World.new(4242)
	for i in range(World.COUNT): world.tiles[i] = World.blank_tile()
	var members: Array = []
	for y in range(25, 28):
		for x in range(25, 28):
			var i: int = y * World.N + x
			world.place(i, "res", false, 100)
			world.tiles[i].level = 1
			members.append(i)
	world.recalculate()
	var view = View.new()
	view.size = Vector2(854, 394)
	root.add_child(view)
	view.set_process(false)
	view.set_world(world)
	await process_frame
	await process_frame
	check(view._parcel_footprint(members) == Rect2i(25, 25, 3, 3), "A complete flat 3x3 property supports its full footprint")
	var root_index: int = members[0]
	var sprites: int = 0
	var regions: Dictionary = {}
	for commands in view._tile_records[root_index].values():
		for command in commands:
			if command[0] == 2:
				sprites += 1
				regions[command[3]] = true
	check(sprites == 18, "A low-density3x3 property draws nine houses with roofs, including shared depth diagonals")
	check(regions.size() >= 4, "Houses within the same property have visual variation")
	var redraws: int = view.metrics.ground_redraws
	view.camera += Vector2(10, 20)
	view.zoom_at(1.1, view.size * 0.5)
	await process_frame
	check(view.metrics.ground_redraws == redraws, "Camera movement reuses building meshes")
	for i in members:
		world.tiles[i].zoneType = "apt"
		world.tiles[i].resType = "apt"
		world.tiles[i].level = 2
	view.refresh()
	await process_frame
	await process_frame
	sprites = 0
	for bucket in view._tile_records[root_index]:
		for command in view._tile_records[root_index][bucket]:
			if command[0] == 2:
				sprites += 1
				check(bool(view._bucket_objects.get(bucket, false)) and int(bucket) % 20 != 0,
					"Every complex wing stays separate from ground/pavement depth buckets")
	check(sprites == 20, "A3x3 apartment property forms four four-storey wings with roofs")
	world.tiles[members[-1]].elev = 3
	var fp: Rect2i = view._parcel_footprint(members)
	check(fp.size.x * fp.size.y < 9, "A shared building footprint never spans uneven ground")
	view.queue_free()
	await process_frame
	print("Building variety/layout: %s failures" % failures)
	quit(1 if failures else 0)
