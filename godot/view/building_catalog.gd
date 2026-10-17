extends RefCounted
## Cosmetic selection has no random-stream or monthly-simulation side effects.

var data: Dictionary

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/building_styles.json"))

func style_for(seed: int, parcel: int, kind: String, slot: int = 0) -> Dictionary:
	var recipes: Array = data.recipes.get(kind, data.recipes.house)
	var recipe: Dictionary = recipes[_choice(seed, parcel, kind, slot, 17) % recipes.size()]
	var palette: Dictionary = data.palettes[_choice(seed, parcel, kind, slot, 71) % data.palettes.size()]
	return {"recipe": recipe, "palette": palette,
		"floor": str(recipe.floor) + "__" + str(palette.id),
		"roof": str(recipe.roof) + "__" + str(palette.id),
		"wall": Color(palette.wall), "roof_color": Color(palette.roof)}

func _choice(seed: int, parcel: int, kind: String, slot: int, salt: int) -> int:
	var value: int = (seed * 374761393 + parcel * 668265263 + slot * 2246822519 + kind.hash() + salt) & 0xffffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
	return (value ^ (value >> 16)) & 0xffffffff
