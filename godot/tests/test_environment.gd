extends SceneTree

const WorldModel = preload("res://model/city_world.gd")

class DistanceCountingWorld:
	extends CityWorld
	static var distance_calls: int = 0
	static func _man(a: int, b: int) -> int:
		distance_calls += 1
		return abs(a % N - b % N) + abs(int(a / N) - int(b / N))

var checks = 0
var failures = 0

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func empty_world():
	var world = DistanceCountingWorld.new(24)
	for i in range(world.COUNT):
		world.tiles[i] = world.blank_tile()
	world.recalculate()
	return world

func check_amenity_cell(world, x: int, y: int, park: int, transport: int, message: String):
	var i = y * world.N + x
	var expected_crime = PackedFloat32Array([clampf(15 - park * 0.1, 0.0, 100.0)])[0]
	var expected_land = PackedFloat32Array([clampf(48 + park + transport - expected_crime * 0.34, 0.0, 100.0)])[0]
	check(world.fields.pollution[i] == 0.0 and world.fields.crime[i] == expected_crime and world.fields.landValue[i] == expected_land, message)

func run():
	var world = empty_world()
	world.tiles[0].civic = "park"
	world._environment_update()
	check_amenity_cell(world, 0, 0, 5, 0, "park includes its own tile")
	check_amenity_cell(world, 1, 0, 13, 0, "adjacent park combines local and distance benefits")
	check_amenity_cell(world, 1, 1, 3, 0, "park falloff uses Manhattan distance")
	check_amenity_cell(world, 4, 0, 1, 0, "park benefit reaches distance four")
	check_amenity_cell(world, 5, 0, 0, 0, "park benefit is zero at distance five")
	check_amenity_cell(world, world.N - 1, 0, 0, 0, "park influence does not wrap across rows")
	check_amenity_cell(world, 0, world.N - 1, 0, 0, "park influence clips at the map edge")

	world.tiles[1].civic = "park"
	world._environment_update()
	check_amenity_cell(world, 0, 0, 18, 0, "overlapping parks add their full benefits")
	check_amenity_cell(world, 1, 1, 16, 0, "overlapping falloffs retain each adjacency bonus")
	world.tiles[0].civic = null
	world.tiles[1].civic = null
	world.tiles[world.COUNT - 1].civic = "park"
	world._environment_update()
	check_amenity_cell(world, 0, 0, 0, 0, "removed parks stop affecting the next update")
	check_amenity_cell(world, world.N - 1, world.N - 1, 5, 0, "moved park reaches the opposite corner")

	world = empty_world()
	world.tiles[0].merge({"civic":"station", "rail":true}, true)
	world._environment_update()
	check_amenity_cell(world, 3, 2, 0, 8, "station includes the Manhattan radius-five boundary")
	check_amenity_cell(world, 3, 3, 0, 0, "station excludes distance six")
	check_amenity_cell(world, world.N - 1, 0, 0, 0, "station influence does not wrap across rows")
	world.tiles[1].merge({"civic":"station", "rail":true}, true)
	world._environment_update()
	check_amenity_cell(world, 2, 1, 0, 8, "overlapping stations grant one transport bonus")
	world.tiles[0].rail = false
	world.tiles[1].rail = false
	world._environment_update()
	check_amenity_cell(world, 2, 1, 0, 0, "station without rail stops providing its bonus")

	world = empty_world()
	world.tiles[10 * world.N + 10].civic = "park"
	world.tiles[40 * world.N + 40].merge({"civic":"station", "rail":true}, true)
	DistanceCountingWorld.distance_calls = 0
	world._environment_update()
	# A radius-five Manhattan neighborhood has 61 tiles. Amenity work must stay
	# local even when the map has thousands of tiles outside either influence.
	check(DistanceCountingWorld.distance_calls <= 2 * 61, "local amenities avoid map-wide distance calculations (got %d)" % DistanceCountingWorld.distance_calls)
	print("Environment: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
