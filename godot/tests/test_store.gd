extends SceneTree

const Store = preload("res://persistence/city_store.gd")
const World = preload("res://model/city_world.gd")
var failures: Array[String] = []
var checks = 0
var path = "user://tests/store/city.json"

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures.append(message)

func run():
	var city = World.new(4242)
	city.cash = 12345
	city.year = 2003
	city.month = 8
	city.tick = 43
	city.tiles[800].elev = 3
	var text = Store.export_json(city)
	var imported = Store.import_json(text)
	check(imported != null, "Current city imports")
	if imported != null:
		check(imported.cash == 12345 and imported.year == 2003 and imported.month == 8, "Treasury and calendar preserved")
		check(imported.tiles[800].elev == 3 and imported.seed == 4242, "Elevation and seed preserved")
	var legacy = JSON.parse_string(text)
	legacy.version = 2
	legacy.erase("nextParcelId")
	for tile in legacy.tiles:
		tile.erase("elev")
		tile.erase("biome")
		tile.erase("zoneType")
	var old = Store.import_json(JSON.stringify(legacy))
	check(old != null, "Legacy optional fields accepted")
	if old != null:
		check(old.tiles[800].get("elev", -99) == 0, "Legacy missing elevation defaults to zero")
	for invalid in ["{broken", "[]", "null", "{}", '{"tiles":[null]}']:
		check(Store.import_json(invalid) == null, "Invalid city rejected: " + invalid)
		check(not Store.last_error.is_empty(), "Invalid import explains error")
	check(city.cash == 12345 and city.tiles[800].elev == 3, "Invalid imports do not mutate current city")
	var fixture = Store.import_json(FileAccess.get_file_as_string("res://tests/fixtures/legacy-city-v6.json"))
	check(fixture != null, "Actual JavaScript city exports import")
	if fixture != null:
		check(fixture.cash == 23456 and fixture.year == 2004 and fixture.month == 9 and fixture.tick == 56, "Actual legacy treasury/calendar preserved")
		check(fixture.tiles[25 * 52 + 25].elev == 3 and fixture.seed == 4242, "Actual legacy elevation and seed preserved")
	check(Store.save_city(city, path) == OK, "First atomic save succeeds")
	city.cash = 22222
	check(Store.save_city(city, path) == OK, "Second atomic save succeeds")
	var loaded = Store.load_city(path)
	check(loaded != null and loaded.cash == 22222, "Newest save loads")
	check(FileAccess.file_exists(path + ".bak"), "Previous valid save retained")
	var corrupt = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	loaded = Store.load_city(path)
	check(loaded != null and loaded.cash == 12345, "Corrupt primary recovers previous valid city")
	var bad_structure = city.serialize()
	bad_structure.tiles[0].merge({"zone":null,"level":1,"line":true}, true)
	bad_structure.tiles[1].civic = "plant"
	check(Store.import_json(JSON.stringify(bad_structure)) == null and not Store.last_error.is_empty(), "Structurally invalid JSON rejects with an explanation")
	corrupt = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string(JSON.stringify(bad_structure))
	corrupt.close()
	loaded = Store.load_city(path)
	check(loaded != null and loaded.cash == 12345 and Store.last_error.contains("backup"), "Structurally corrupt primary recovers valid backup")
	check(Store.save_city(city, path) == OK, "Saving over structurally corrupt primary succeeds")
	var backup = Store.load_city(path + ".bak")
	check(backup != null and backup.cash == 12345, "Structurally corrupt primary cannot replace valid backup")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	if failures.is_empty():
		print("CityStore: %d checks PASS" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
