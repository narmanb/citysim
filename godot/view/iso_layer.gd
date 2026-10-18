extends Node2D
## Retained, ordered meshes: network strokes and sprites share the same GPU batch.

const BatchShader = preload("res://view/opaque_ground.gdshader")
const LINE_UV_ORIGIN: float = -32.0
# Half a diagonal pixel footprint at minimum zoom (tile_scale 2/BASE 28).
const LINE_FRINGE: float = 10.0
static var _shared_material: ShaderMaterial

var commands: Array = []
var _meshes: Array = []

func _init() -> void:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = BatchShader
	material = _shared_material

func polygon(points: PackedVector2Array, color: Color, texture: Texture2D = null, uv: PackedVector2Array = PackedVector2Array()) -> void:
	commands.append([0, points, color, texture, uv])

func polygon_colors(points: PackedVector2Array, colors: PackedColorArray, texture: Texture2D, uv: PackedVector2Array) -> void:
	assert(points.size()==colors.size())
	commands.append([6,points,colors,texture,uv])

func line(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	commands.append([1, points, color, width])

func sprite(texture: Texture2D, rect: Rect2, source: Rect2, color: Color = Color.WHITE) -> void:
	commands.append([2, texture, rect, source, color])

func label_at(text: String, at: Vector2, font_size: int, color: Color) -> void:
	commands.append([3, text, at, font_size, color])

func ring(at: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	commands.append([4, at, radius, color, width])

func _draw() -> void:
	_meshes.clear()
	# Cars are separate depth-sorted moving layers; don't allocate a mesh for a
	# single sprite every animation frame. Static layers compile only on edits.
	if commands.size() == 1 and commands[0][0] == 2:
		var c: Array = commands[0]
		draw_texture_rect_region(c[1], c[2], c[3], c[4], false, true)
		return
	for command in compile_batches():
		match command[0]:
			5:
				_meshes.append(command[1])
				draw_mesh(command[1], command[2])
			3:
				var font: Font = ThemeDB.fallback_font
				var at: Vector2 = command[2]
				at.x -= font.get_string_size(command[1], HORIZONTAL_ALIGNMENT_LEFT, -1, command[3]).x * 0.5
				draw_string(font, at, command[1], HORIZONTAL_ALIGNMENT_LEFT, -1, command[3], command[4])
			4:
				draw_arc(command[1], command[2], 0, TAU, 32, command[3], command[4], true)

func compile_batches() -> Array:
	# Triangle order is command order. Never sort by texture: that would place
	# terrain over roads or wires over buildings at the wrong depth.
	var output: Array = []
	var batch: Dictionary = _empty_batch()
	for command in commands:
		var kind: int = command[0]
		if kind == 3 or kind == 4:
			_flush_batch(batch, output)
			output.append(command)
			continue
		var texture: Texture2D = null
		if kind in [0,6]: texture = command[3]
		if kind == 2: texture = command[1]
		if texture != null:
			if batch.texture != null and batch.texture != texture:
				_flush_batch(batch, output)
			batch.texture = texture
		match kind:
			0,6:
				_append_polygon(batch, command[1], command[2], command[4] if texture != null else PackedVector2Array())
			1:
				_append_line(batch, command[1], command[2], command[3])
			2:
				var rect: Rect2 = command[2]
				var source: Rect2 = command[3]
				var texture_size: Vector2 = texture.get_size()
				var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
				var uv := PackedVector2Array([source.position / texture_size, Vector2(source.end.x, source.position.y) / texture_size,
					source.end / texture_size, Vector2(source.position.x, source.end.y) / texture_size])
				_append_polygon(batch, corners, command[4], uv)
	_flush_batch(batch, output)
	return output

func _empty_batch() -> Dictionary:
	# Ordinary arrays are reference types; packed arrays here would copy on each
	# helper call. Convert once when uploading the finished mesh.
	return {"vertices": [], "colors": [], "uv": [], "indices": [], "texture": null}

func _append_polygon(batch: Dictionary, points: PackedVector2Array, color, uv: PackedVector2Array) -> void:
	if points.size() < 3: return
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	if triangles.is_empty(): return
	var offset: int = batch.vertices.size()
	for i in range(points.size()):
		batch.vertices.append(Vector3(points[i].x, points[i].y, 0.0))
		batch.colors.append(color[i] if color is PackedColorArray else color)
		batch.uv.append(uv[i] if uv.size() == points.size() else Vector2(-1, 0))
	for index in triangles:
		batch.indices.append(offset + index)

func _append_line(batch: Dictionary, points: PackedVector2Array, color: Color, width: float) -> void:
	var half_width: float = maxf(width, 0.0) * 0.5
	if half_width <= 0.0: return
	var outer: float = half_width + LINE_FRINGE
	for i in range(1, points.size()):
		var delta: Vector2 = points[i] - points[i - 1]
		if delta.length_squared() < 0.000001: continue
		var normal := Vector2(-delta.y, delta.x).normalized() * outer
		var corners := PackedVector2Array([points[i - 1] - normal, points[i] - normal, points[i] + normal, points[i - 1] + normal])
		# Negative UVs identify untextured geometry. The shader integrates line
		# coverage over a screen pixel, keeping thin wires visible when zoomed out.
		var uv := PackedVector2Array([Vector2(LINE_UV_ORIGIN - outer, half_width), Vector2(LINE_UV_ORIGIN - outer, half_width),
			Vector2(LINE_UV_ORIGIN + outer, half_width), Vector2(LINE_UV_ORIGIN + outer, half_width)])
		_append_polygon(batch, corners, color, uv)

func _flush_batch(batch: Dictionary, output: Array) -> void:
	if not batch.indices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(batch.vertices)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(batch.colors)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(batch.uv)
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(batch.indices)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		output.append([5, mesh, batch.texture])
	batch.vertices.clear()
	batch.colors.clear()
	batch.uv.clear()
	batch.indices.clear()
	batch.texture = null
