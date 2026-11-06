extends SceneTree
const W = preload("res://model/city_world.gd")
const C = preload("res://model/commute_system.gd")
var failures = 0
var checks = 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func empty_world():
	var w = W.new(812)
	for i in W.COUNT: w.tiles[i] = W.blank_tile()
	w.recalculate()
	return w
func building(w, x: int, y: int, zone: String, people: int):
	w.tiles[y*W.N+x].merge({"zone":zone,"level":1,"occupancy":people},true)
func refresh(w):
	w._population_update(false)
	w._traffic_prepare()
func run():
	var w = empty_world()
	for x in range(5,16): w.tiles[10*W.N+x].road = true
	building(w,5,9,"res",20)
	building(w,10,9,"com",7)
	building(w,15,9,"ind",8)
	refresh(w)
	check(w.stats.employed == 15 and w.stats.unemployment == 25,"Job capacity is conserved across multiple destinations")
	check(w.stats.get("commuters",-1) == 15 and w.stats.get("commuteUnserved",-1) == 5,"Analytical commute totals exist without cars")
	check(is_equal_approx(float(w.stats.get("avgCommute",-1)),115.0/15.0),"Average commute weights nearest-job routes by assigned workers")
	check(w.trafficHeat[10*W.N+5] > 0 and w.stats.congestion > 0,"Assigned workers create traffic with zero visible cars")
	var heat = w.trafficHeat.duplicate()
	var congestion = w.stats.congestion
	for n in range(70): w.cars.append({"path":[10*W.N+5,10*W.N+6,10*W.N+7],"p":0.0,"speed":0.7})
	w._traffic_prepare()
	for n in range(40): w.advance_agents(0.1)
	check(w.trafficHeat == heat and w.stats.congestion == congestion and w.stats.employed == 15,"Seventy cars and animation cannot change analytical traffic or employment")
	w.tiles[10*W.N+8].road = false
	refresh(w)
	check(w.stats.employed == 0 and w.stats.get("commuteUnserved",-1) == 20,"Disconnected homes cannot borrow jobs")
	check(w.trafficHeat[10*W.N+5] == 0,"Road deletion immediately removes analytical flows")
	w.tiles[10*W.N+8].road = true
	w.tiles[10*W.N+8].merge({"terrainShape":"slope","shapeStrength":1,"slopeDir":"E"},true)
	w.tiles[10*W.N+9].elev = 10
	refresh(w)
	check(w.stats.employed == 0,"Adjacent roads with illegal Civil grade joins cannot share jobs")
	w.tiles[10*W.N+9].elev = 0
	refresh(w)
	check(w.stats.employed == 15,"A compatible gentle grade restores commuting")
	# Authored ramp corner edits can change legality without changing elevation/shape.
	w.tiles[10*W.N+8].gradeCorners = [-0.5,0.5,0.5,-0.5]
	refresh(w)
	check(w.stats.employed == 15,"Authored compatible grade corners preserve commuting")
	w.tiles[10*W.N+8].gradeCorners[1] = 0.6
	w.tiles[10*W.N+8].gradeCorners[2] = 0.6
	refresh(w)
	check(w.stats.employed == 0,"Grade-only edits invalidate the cached analytical road graph")
	# Only the far member of each parcel reaches a road. The root holds occupancy once.
	w = empty_world()
	for x in range(5,15): w.tiles[12*W.N+x].road = true
	for p in [["res",1,9,5,30],["com",2,9,14,12]]:
		for y in range(p[2],12):
			w.tiles[y*W.N+p[3]].merge({"zone":p[0],"parcel":p[1],"level":1,"occupancy":p[4] if y==p[2] else 0},true)
	refresh(w)
	check(w.stats.employed == 12 and w.stats.get("commuters",-1) == 12,"Both home and job parcels use entrances on all actual members")
	# A second origin competes for the same twelve jobs; they cannot be counted twice.
	building(w,6,13,"res",30)
	refresh(w)
	check(w.stats.employed == 12 and w.stats.get("commuteUnserved",-1) == 48,"Competing residential properties cannot reuse occupied jobs")
	var result = C.calculate(w)
	var assigned = 0
	for trip in result.routes: assigned += trip.flow
	check(assigned == 12 and result.routes.size() <= 3,"Aggregate route count is bounded by origins and job destinations")
	check(result.searches == 2,"Search count scales with residential properties, not people")
	var state = w._rng.state
	var snapshot = w.tiles.duplicate(true)
	check(C.calculate(w) == result and w.tiles == snapshot and w._rng.state == state,"Repeated commute calculation is deterministic and does not mutate tiles or RNG")
	# Two entrances on separate components: do not arbitrarily choose the first.
	w = empty_world()
	building(w,6,10,"res",9)
	building(w,9,10,"com",9)
	w.tiles[10*W.N+5].road = true
	for x in range(7,10): w.tiles[9*W.N+x].road = true
	w.tiles[10*W.N+7].road = true
	refresh(w)
	check(w.stats.employed == 9,"A second reachable entrance works when the first entrance is disconnected")
	# Road paths may span more than the old animation route's 900-node search cap.
	w = empty_world()
	var path: Array = []
	for band in range(20):
		var y = 2+band*2
		for offset in range(48):
			var x = 2+offset if band%2==0 else 49-offset
			path.append(y*W.N+x)
		if band < 19: path.append((y+1)*W.N+(49 if band%2==0 else 2))
	for road in path: w.tiles[road].road = true
	building(w,2,1,"res",5)
	building(w,2,41,"com",5)
	refresh(w)
	check(w.stats.employed == 5 and w.stats.avgCommute == path.size()-1,"Analytical searches cover a long legal network without animation's search cap")
	# Legacy imports may contain excessive visual agents; preparation enforces caps.
	w = empty_world()
	w.tiles[100].rail = true
	w.tiles[101].rail = true
	for n in range(15): w.trains.append({"path":[100,101],"p":0.0,"speed":0.46})
	w._traffic_prepare()
	check(w.trains.size() == 9,"Legacy visual trains remain capped at nine")
	print("Commuting: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
