extends Node2D
## Retained draw commands. Static records never redraw when an agent moves.

var commands: Array = []
var _meshes: Array = []

func polygon(points: PackedVector2Array, color: Color, texture: Texture2D = null, uv: PackedVector2Array = PackedVector2Array()) -> void:
	commands.append([0, points, color, texture, uv])

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
	var index: int = 0
	while index < commands.size():
		var command: Array = commands[index]
		if _is_textured_quad(command):
			var end: int = index + 1
			while end < commands.size() and _is_textured_quad(commands[end]) and commands[end][3] == command[3]:
				end += 1
			if end - index > 1:
				_draw_textured_quads(index, end)
				index = end
				continue
		match command[0]:
			0:
				draw_polygon(command[1], PackedColorArray([command[2]]), command[4], command[3])
			1:
				draw_polyline(command[1], command[2], command[3], true)
			2:
				draw_texture_rect_region(command[1], command[2], command[3], command[4], false, true)
			3:
				var font: Font = ThemeDB.fallback_font
				var at: Vector2 = command[2]
				at.x -= font.get_string_size(command[1], HORIZONTAL_ALIGNMENT_LEFT, -1, command[3]).x * 0.5
				draw_string(font, at, command[1], HORIZONTAL_ALIGNMENT_LEFT, -1, command[3], command[4])
			4:
				draw_arc(command[1], command[2], 0, TAU, 32, command[3], command[4], true)
		index += 1

func _is_textured_quad(command: Array) -> bool:
	return command[0] == 0 and command[3] != null and command[1].size() == 4 and command[4].size() == 4

func _draw_textured_quads(first: int, end: int) -> void:
	# One mesh per contiguous atlas run, with independent triangles for each cap.
	# Keeping the command order also keeps shorelines, roads and zoning above it.
	var count: int = end - first
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	vertices.resize(count * 4)
	colors.resize(count * 4)
	uv.resize(count * 4)
	indices.resize(count * 6)
	for tile in range(count):
		var command: Array = commands[first + tile]
		var offset: int = tile * 4
		for corner in range(4):
			var point: Vector2 = command[1][corner]
			vertices[offset + corner] = Vector3(point.x, point.y, 0)
			colors[offset + corner] = command[2]
			uv[offset + corner] = command[4][corner]
		for triangle in range(6):
			indices[tile * 6 + triangle] = offset + [0, 1, 2, 0, 2, 3][triangle]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes.append(mesh)
	draw_mesh(mesh, commands[first][3])
