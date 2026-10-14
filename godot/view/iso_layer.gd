extends Node2D
## Retained draw commands. Static records never redraw when an agent moves.

var commands: Array = []

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
	for command in commands:
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
