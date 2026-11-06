extends SceneTree
const W = preload("res://model/city_world.gd")
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func empty_world():
	var w = W.new(814)
	for i in W.COUNT: w.tiles[i] = W.blank_tile()
	w.recalculate()
	w.fields.power.fill(1)
	w.fields.water.fill(1)
	return w
func run():
	for type in W.SERVICES:
		var w = empty_world()
		var service = 10*W.N+5
		w.tiles[service].civic = type
		for x in range(5,16): w.tiles[11*W.N+x].road = true
		# Parallel street is close but isolated across a full river row.
		for x in W.N: w.tiles[12*W.N+x] = W.blank_tile("water")
		for x in range(5,16): w.tiles[13*W.N+x].road = true
		var target = 10*W.N+10
		var island = 14*W.N+7
		w.tiles[target].merge({"zone":"res","level":1},true)
		w.tiles[island].merge({"zone":"res","level":1},true)
		w._service_update()
		check(w.fields[type][target] > 0,type + " follows the connected road and spills to neighboring buildings")
		check(w.fields[type][island] == 0,type + " cannot cover a nearby disconnected street across water")
		var strong: float = w.fields[type][target]
		w.funding[type] = 40
		w._service_update()
		check(w.fields[type][target] < strong,type + " funding reduces strength/reach")
		w.funding[type] = 100
		w.fields.power[service] = 0
		w._service_update()
		check(w.fields[type][target] == 0,type + " requires electricity")
		w.fields.power[service] = 1
		w.fields.water[service] = 0
		w._service_update()
		check(w.fields[type][target] == 0,type + " requires water")
		w.fields.water[service] = 1
		for x in range(5,16): w.tiles[11*W.N+x].road = false
		w._service_update()
		check(w.fields[type][target] == 0,type + " requires accessible roads")
		# The only street connection is now a bad ramp edge.
		for x in range(5,16): w.tiles[11*W.N+x].road = true
		w.tiles[11*W.N+7].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E"},true)
		w.tiles[11*W.N+8].elev = 10
		w._service_update()
		check(w.fields[type][target] == 0,type + " cannot propagate across an illegal grade edge")
	# A diagonal spill must not serve a property entered only from another street.
	var w = empty_world()
	w.tiles[10*W.N+5].civic = "school"
	for x in range(5,11): w.tiles[11*W.N+x].road = true
	w.tiles[12*W.N+12].road = true
	var isolated = 12*W.N+11
	w.tiles[isolated].merge({"zone":"res","level":1},true)
	w._service_update()
	check(w.fields.school[isolated] == 0,"Local spill cannot jump into a building served only by a disconnected dry-land street")
	print("Service access: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
