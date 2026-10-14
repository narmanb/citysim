class_name CityStore
extends RefCounted
## JSON persistence shared by the game and future display modes.

static var last_error: String = ""
const MAX_BYTES = 8 * 1024 * 1024

static func export_json(world) -> String:
	return JSON.stringify(world.serialize(), "\t")

static func import_json(text: String):
	last_error = ""
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "This city file is too large."
		return null
	var parser = JSON.new()
	if parser.parse(text) != OK:
		last_error = "Could not read city JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return null
	var data = parser.data
	if not data is Dictionary or not data.get("tiles") is Array or data.tiles.size() != 2704:
		last_error = "Choose a MetroForge city containing a 52 × 52 map."
		return null
	for tile in data.tiles:
		if not tile is Dictionary:
			last_error = "The city contains an invalid map tile."
			return null
	var model = load("res://model/city_world.gd")
	if model == null:
		last_error = "The city model could not load."
		return null
	var city = model.from_dict(data)
	if city == null:
		last_error = "This city contains invalid data."
	return city

static func save_city(world, path: String = "user://city.json") -> Error:
	last_error = ""
	if world == null:
		last_error = "There is no city to save."
		return ERR_INVALID_DATA
	var absolute = ProjectSettings.globalize_path(path)
	var error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		last_error = "Could not create the save folder."
		return error
	var text = export_json(world)
	var temporary = absolute + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the city file for writing."
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		last_error = "The city could not be written completely."
		return error
	# Never replace a good backup with an already corrupt primary save.
	if FileAccess.file_exists(absolute):
		var previous = import_json(FileAccess.get_file_as_string(absolute))
		if previous != null:
			error = DirAccess.copy_absolute(absolute, absolute + ".bak")
			if error != OK:
				last_error = "Could not preserve the previous save."
				return error
	error = DirAccess.rename_absolute(temporary, absolute)
	last_error = "" if error == OK else "Could not finish saving the city."
	return error

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
