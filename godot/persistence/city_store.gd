class_name CityStore
extends RefCounted
## JSON persistence shared by the game and future display modes.

static var last_error: String = ""
const MAX_BYTES = 8 * 1024 * 1024

static func export_json(world) -> String:
	return JSON.stringify(world.serialize(), "\t")

static func import_json(text: String):
	var result = decode_json(text)
	last_error = result.message
	return result.world

static func decode_json(text: String) -> Dictionary:
	var message: String = ""
	if text.to_utf8_buffer().size() > MAX_BYTES:
		message = "This city file is too large."
		return {"world": null, "message": message}
	var parser = JSON.new()
	if parser.parse(text) != OK:
		message = "Could not read city JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return {"world": null, "message": message}
	var data = parser.data
	if not data is Dictionary or not data.get("tiles") is Array or data.tiles.size() != 2704:
		message = "Choose a MetroForge city containing a 52 × 52 map."
		return {"world": null, "message": message}
	for tile in data.tiles:
		if not tile is Dictionary:
			message = "The city contains an invalid map tile."
			return {"world": null, "message": message}
	var model = load("res://model/city_world.gd")
	if model == null:
		message = "The city model could not load."
		return {"world": null, "message": message}
	var city = model.from_dict(data)
	if city == null:
		message = "This city contains invalid data."
	return {"world": city, "message": message}


static func save_city(world, path: String = "user://city.json") -> Error:
	if world == null:
		last_error = "There is no city to save."
		return ERR_INVALID_DATA
	var result = write_snapshot(world.serialize(), path)
	last_error = result.message
	return result.code

# Worker-safe: only detached data and local error state, never live simulation.
static func write_snapshot(data: Dictionary, path: String) -> Dictionary:
	var absolute = ProjectSettings.globalize_path(path)
	var error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return {"code": error, "message": "Could not create the save folder."}
	var temporary = absolute + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return {"code": FileAccess.get_open_error(), "message": "Could not open the city file for writing."}
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return {"code": error, "message": "The city could not be written completely."}
	if FileAccess.file_exists(absolute):
		var previous = decode_json(FileAccess.get_file_as_string(absolute))
		if previous.world != null:
			error = DirAccess.copy_absolute(absolute, absolute + ".bak")
			if error != OK: return {"code": error, "message": "Could not preserve the previous save."}
	error = DirAccess.rename_absolute(temporary, absolute)
	return {"code": error, "message": "" if error == OK else "Could not finish saving the city."}

static func load_city(path: String = "user://city.json"):
	last_error = ""
	var saw_file = false
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		saw_file = true
		var city = import_json(FileAccess.get_file_as_string(candidate))
		if city != null:
			if candidate.ends_with(".bak"):
				last_error = "Recovered the previous valid city from backup."
			return city
	if not saw_file:
		last_error = "No saved city was found."
	return null
