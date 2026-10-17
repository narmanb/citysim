extends SceneTree
## Mixed network geometry must keep painter order without one GPU call per line.

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var layer = load("res://view/iso_layer.gd").new()
	if not layer.has_method("compile_batches"):
		push_error("Mixed road, utility and sprite commands need an ordered mesh compiler")
		layer.free()
		quit(1)
		return
	var texture: Texture2D = load("res://assets/atlases/vehicles.png")
	var points := PackedVector2Array([Vector2.ZERO, Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	for i in range(100):
		layer.polygon(points, Color.RED)
		layer.line(PackedVector2Array([Vector2(0, 2), Vector2(4, 2)]), Color.BLACK, 1.0)
		layer.sprite(texture, Rect2(0, 0, 4, 4), Rect2(140, 222, 32, 25))
	var batches: Array = layer.compile_batches()
	check(batches.size() == 1, "300 interleaved network/texture commands share one ordered mesh")
	if batches.size() == 1:
		var arrays: Array = batches[0][1].surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_VERTEX].size() == 1200, "each polygon, line and sprite retains its own four vertices")
		check(arrays[Mesh.ARRAY_INDEX].size() == 1800, "all original geometry survives batching")
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(colors[0] == Color.RED and colors[4] == Color.BLACK and colors[8] == Color.WHITE,
			"mesh triangles retain polygon, wire, sprite painter order")
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(uv[8].distance_to(Vector2(140.0 / texture.get_width(), 222.0 / texture.get_height())) < 0.00001,
			"sprite UV retains its exact source crop")
	# Text and a different source texture must interrupt an otherwise mergeable run.
	layer.label_at("PWR", Vector2.ZERO, 12, Color.WHITE)
	layer.polygon(points, Color.GREEN)
	layer.sprite(load("res://assets/atlases/details.png"), Rect2(0, 0, 4, 4), Rect2(71, 0, 32, 45))
	layer.sprite(texture, Rect2(0, 0, 4, 4), Rect2(140, 222, 32, 25))
	batches = layer.compile_batches()
	check(batches.size() == 4 and batches[1][0] == 3, "labels and texture changes preserve paint barriers")
	# Degenerate wires cannot introduce NaNs or prevent later geometry drawing.
	layer.commands.clear()
	layer.line(PackedVector2Array([Vector2.ONE, Vector2.ONE]), Color.WHITE)
	check(layer.compile_batches().is_empty(), "zero-length wires are ignored")
	layer.commands.clear()
	layer.line(PackedVector2Array([Vector2.ZERO, Vector2(4, 4)]), Color.WHITE, 1.0)
	var wire_arrays: Array = layer.compile_batches()[0][1].surface_get_arrays(0)
	var first: Vector3 = wire_arrays[Mesh.ARRAY_VERTEX][0]
	var outer_width: float = Vector2(first.x, first.y).length()
	# At minimum supported zoom (2/28), a diagonal pixel footprint spans
	# sqrt(2)*14 local units. The quad must retain the entire filter support.
	check(outer_width >= 0.5 + sqrt(2.0) * 14.0 * 0.5, "thin diagonal wires retain full AA support at minimum zoom")
	layer.commands.clear()
	# Concave polygons must use actual triangulation, not a quad/fan shortcut.
	var concave := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(2, 1), Vector2(0, 4)])
	layer.polygon(concave, Color(1, 0, 0, 0.25))
	batches = layer.compile_batches()
	var mesh_arrays: Array = batches[0][1].surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
	var area: float = 0.0
	for i in range(0, indices.size(), 3):
		var a := Vector2(vertices[indices[i]].x, vertices[indices[i]].y)
		var b := Vector2(vertices[indices[i + 1]].x, vertices[indices[i + 1]].y)
		var c := Vector2(vertices[indices[i + 2]].x, vertices[indices[i + 2]].y)
		area += absf((b - a).cross(c - a)) * 0.5
	check(is_equal_approx(area, 10.0), "concave footprint area is preserved")
	check(absf(mesh_arrays[Mesh.ARRAY_COLOR][0].a - 0.25) <= 1.0 / 255.0, "transparent overlays retain their alpha within GPU color precision")
	layer.free()
	print("Mixed draw batch tests: %s failure(s)" % failures)
	quit(1 if failures else 0)
