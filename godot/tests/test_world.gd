extends SceneTree

const WorldModel = preload("res://model/city_world.gd")
var failures = 0
var checks = 0

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func empty_world():
	var world = WorldModel.new(24)
	for i in range(world.COUNT):
		world.tiles[i] = world.blank_tile()
	world.recalculate()
	return world

func run():
	var w = empty_world()
	check(w.tiles.size() == 2704 and w.cash == 36000, "52x52 map and starting treasury")
	w.tiles[100].tree = true
	check(w.place(100, "line"), "line placement")
	check(not w.tiles[100].tree and w.cash == 35987, "power lines clear trees for $13")
	check(not w.place(100, "forest"), "forest rejects power lines")
	var money = w.cash
	check(not w.place(100, "line") and w.cash == money, "duplicate construction is free")
	check(not w.place(-1, "road") and not w.place(2704, "road"), "invalid indices rejected")
	check(not w.place(100, "bogus"), "unknown tools rejected")
	w.tiles[101].terrain = "water"
	w.tiles[101].waterSource = true
	check(not w.place(101, "road"), "water requires bridge flag")
	check(w.place(101, "road", true) and w.cash == money - 90, "bridge costs five times road cost")
	w.cash = 0
	check(not w.place(102, "plant"), "unaffordable construction rejected")
	w.cash = 10000
	check(not w.place(102, "grass") and w.cash == 10000, "unchanged terrain is free")
	w.tiles[102].elev = 5
	check(not w.place(102, "raise"), "terrain bounds are free noops")

	w = empty_world()
	check(w.place(500, "apt", false, 17) and w.place(501, "apt", false, 17), "parcel construction")
	var parcel = w.parcel_info(500)
	check(parcel.area == 2 and parcel.root == 500 and parcel.anchor == 501, "parcel bounding metadata")
	check(w.parcel_capacity(parcel, 1) == 30 and w.parcel_capacity(parcel, 4) == 102, "apartment area/level capacity")
	check(w.place(502, "road") and w.road_near(500), "road touching any parcel member serves whole parcel")
	check(w.place(490, "plant") and w.place(552, "pump"), "utility sources near parcel")
	for index in range(491,500): w.place(index, "line")
	check(w.place(551, "line"), "pump electrical connection")
	w.recalculate()
	check(w.parcel_has(w.parcel_info(500), "power"), "empty parcel sees adjacent energized network")
	check(w.fields.power[552] == 1 and w.stats.waterPumped == 286, "inland powered pump produces 55 percent capacity")
	check(w.parcel_has(w.parcel_info(500), "water"), "adjacent water reaches parcel")
	w.step()
	check(w.tiles[500].level > 0 and w.stats.population > 0, "serviced apartment parcel grows")
	check(w.tiles[501].level == w.tiles[500].level and w.tiles[501].occupancy == 0, "parcel levels synchronized, occupancy counted once")
	check(w.stats.resCapacity == w.parcel_capacity(w.parcel_info(500), w.tiles[500].level), "parcel population capacity counted once")
	check(w.month == 2 and w.tick == 1 and w.cash < 36000, "monthly progression and economy")
	var before_cash = w.cash
	var before_net = w.stats.net
	w.funding.road = 0
	w.step()
	check(is_equal_approx(w.cash - before_cash, float(w.stats.net)), "economy pays exact calculated monthly net")
	check(w.stats.expenses > 0 and w.stats.revenue > 0 and before_net < 0, "real maintenance and tax income")
	w.tiles[552].civic = null
	w.recalculate()
	check(not w.parcel_has(w.parcel_info(500), "water"), "disconnected water supply cannot reach parcel")

	w = empty_world()
	w.tiles[100].terrain = "water"
	w.tiles[100].waterSource = true
	check(w.place(101, "river") and w.tiles[101].terrain == "water", "channel floods from natural water")
	check(w.place(102, "river") and w.tiles[102].terrain == "water", "connected channel propagates water")
	check(w.place(101, "raise") and w.place(101, "raise"), "channel elevation editing")
	check(w.tiles[101].terrain == "grass" and w.tiles[102].terrain == "grass", "raised channel disconnects downstream water")
	w = empty_world()
	w.place(100, "plant")
	w.place(101, "res")
	w.place(102, "res")
	w.place(103, "pump")
	w.recalculate()
	check(w.fields.power[101] == 1 and w.fields.power[102] == 0 and w.fields.power[103] == 0, "empty zoning cannot bridge electricity gap")

	w = empty_world()
	w.place(100, "plant")
	w.place(101, "pump")
	w.place(102, "pipe")
	w.place(103, "tower")
	w.recalculate()
	w.step()
	check(w.tiles[103].storage == 180, "connected tower stores pump surplus")
	w.tiles[101].civic = null
	w.step()
	check(w.tiles[103].storage == 179, "stored water loses one unit per month without pump")
	check(w.stats.waterCapacity == 180, "stored water supplies disconnected network for current month")
	w.tiles[104].tree = true
	w.tiles[104].line = true
	var saved = w.serialize()
	saved.cash = -321.5
	saved.year = 2042
	saved.month = 11
	saved.taxes.res = 17
	saved.funding.road = 63
	saved.tiles[104].elev = 3
	var restored = WorldModel.from_dict(saved)
	check(restored != null, "legacy city imports")
	check(restored.cash == -321.5 and restored.year == 2042 and restored.month == 11, "treasury/calendar preserved")
	check(restored.taxes.res == 17 and restored.funding.road == 63, "budget preserved")
	check(restored.tiles[104].elev == 3 and not restored.tiles[104].tree, "legacy elevation preserved and trees on lines normalized")
	check(restored.serialize().tiles == restored.tiles, "serialize contains full native tiles")
	saved.tiles[104].elev = 2
	check(restored.tiles[104].elev == 3, "import owns tile state")
	check(WorldModel.from_dict({"tiles": []}) == null, "invalid map rejected")
	check(w.neighbors(0) == [1, 52] and w.neighbors(2703) == [2702, 2651], "cardinal neighbors respect map edges")

	var legacy_data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy-city-v6.json"))
	var generated = WorldModel.new(4242)
	var terrain_matches = true
	for i in range(2704):
		if generated.tiles[i].terrain != legacy_data.tiles[i].terrain or generated.tiles[i].tree != legacy_data.tiles[i].tree:
			terrain_matches = false
	check(terrain_matches, "seed4242 matches genuine JavaScript terrain and tree layout")
	var legacy_world = WorldModel.from_dict(legacy_data)
	check(legacy_world != null and legacy_world.cash == 23456 and legacy_world.tiles[1325].elev == 3, "genuine legacy fixture preserves treasury and elevation")

	# Values obtained by executing the original JavaScript simulation for the same district.
	w = empty_world()
	w.seed = 4242
	w.tiles[19*52+3].terrain = "water"
	w.tiles[19*52+3].waterSource = true
	w.place(19*52+4,"plant")
	w.place(20*52+3,"pump")
	for x in range(4,35):
		w.place(20*52+x,"line")
		w.place(20*52+x,"pipe")
		w.place(22*52+x,"road")
	var sections = [[4,7,"apt",200],[8,9,"shop",201],[10,13,"light",202],[14,17,"apt",203],[18,19,"office",204],[20,22,"logistics",205],[23,26,"apt",206],[27,30,"heavy",207],[31,34,"apt",208]]
	for section in sections:
		for x in range(section[0],section[1]+1): w.place(21*52+x,section[2],false,section[3])
	for service in [[20,"hospital"],[18,"school"],[16,"police"],[14,"fire"]]: w.place(19*52+service[0],service[1])
	w.recalculate()
	var expected = {
		1:{"cash":23906,"population":79,"jobs":44,"powerUsed":67,"waterUsed":57,"net":-441,"demand":{"res":23,"com":45,"ind":41},"levels":[0,0,0,1,0,1,0,0,0]},
		6:{"cash":23083,"population":191,"jobs":205,"powerUsed":113,"waterUsed":103,"net":55,"demand":{"res":54,"com":39,"ind":56},"levels":[0,1,2,3,2,2,0,1,1]},
		12:{"cash":24131,"population":296,"jobs":227,"powerUsed":141,"waterUsed":131,"net":227,"demand":{"res":28,"com":46,"ind":52},"levels":[1,1,2,3,3,2,1,2,2]}}
	for step in range(1,13):
		w.step()
		if not expected.has(step): continue
		var baseline = expected[step]
		check(w.cash == baseline.cash and w.stats.net == baseline.net, "JavaScript economy parity month %d" % step)
		check(w.stats.population == baseline.population and w.stats.jobs == baseline.jobs, "JavaScript population/jobs parity month %d" % step)
		check(w.stats.powerUsed == baseline.powerUsed and w.stats.waterUsed == baseline.waterUsed, "JavaScript utility usage parity month %d" % step)
		check(w.demand == baseline.demand, "JavaScript demand parity month %d" % step)
		var levels: Array = []
		for section in sections: levels.append(w.tiles[21*52+section[0]].level)
		check(levels == baseline.levels, "JavaScript parcel growth parity month %d" % step)
	check(w.year == 2001 and w.month == 1 and w.stats.lastYearNet == -443, "JavaScript year rollover accounting parity")
	check(w.fields.school[21*52+18] > 0 and w.fields.police[21*52+16] > 0, "powered and watered departments provide services")
	var bond_cash = w.cash
	check(w.take_bond() and w.cash == bond_cash+10000 and w.bondMonths == 80, "bond adds capital and repayment term")
	check(not w.take_bond() and w.cash == bond_cash+10000, "only one outstanding bond")
	w.step()
	check(w.bondMonths == 79, "monthly bond term decreases")
	check(w.trigger_disaster("fire",21*52+14) and w.tiles[21*52+14].fire >= 2, "explicit fire event ignites developed building")
	check(not w.events.is_empty() and w.events.back().type == "dispatch", "fire creates dispatch event")
	check(not w.trigger_disaster("unknown",0), "invalid disaster rejected")
	var position_before = 0.0
	w.cars = [{"path":[22*52+4,22*52+5,22*52+6],"p":0.0,"speed":0.7}]
	w.advance_agents(0.25)
	check(w.cars[0].p > position_before, "road agents advance independently of simulation calendar")
	var month_before = w.month
	w.advance_agents(0.25)
	check(w.month == month_before, "agent animation does not advance month")

	w = empty_world()
	w.place(10*52,"plant")
	for x in range(1,52): w.place(10*52+x,"line")
	for x in range(52):
		for y in [9,11]:
			w.tiles[y*52+x].zone = "res"
			w.tiles[y*52+x].level = 4
	w.recalculate()
	check(w.stats.powerUsed <= 550 and w.stats.unpowered > 0, "utility allocation respects finite plant capacity")
	check(w.stats.powerUsed == 544, "nearest consumers consume 34 full legacy building allocations")
	var occupied_import = w.serialize()
	occupied_import.tiles[9*52+10].occupancy = 77
	var preserved = WorldModel.from_dict(occupied_import)
	check(preserved.tiles[9*52+10].occupancy == 77, "version6 import retains stored occupancy until next simulation step")

	var optional_data = empty_world().serialize()
	optional_data.seed = 0
	optional_data.cash = 0
	optional_data.taxes = {"res":0,"com":null}
	optional_data.funding = {"road":0,"fire":null}
	optional_data.stats = null
	optional_data.events = null
	optional_data.tiles[100].elev = null
	optional_data.tiles[100].biome = null
	var optional_world = WorldModel.from_dict(optional_data)
	check(optional_world != null and optional_world.seed == 0 and optional_world.cash == 0, "zero saved seed/treasury survive import")
	check(optional_world.taxes.res == 0 and optional_world.taxes.com == 8 and optional_world.funding.road == 0 and optional_world.funding.fire == 100, "zero budgets survive and null optional budgets default")
	check(optional_world.tiles[100].elev == 0 and optional_world.tiles[100].biome == "grass", "null optional tile fields normalize")

	w = empty_world()
	for i in [530,582,634,635,636]: w.place(i,"apt",false,77)
	w.place(532,"road")
	check(w.parcel_info(530).area == 5 and w.parcel_capacity(w.parcel_info(530),1) == 100, "irregular parcel capacity uses members rather than bounding rectangle")
	check(not w.road_near(530), "road in irregular parcel bounding gap does not provide access")
	w.tiles[532].road = false
	w.tiles[532].civic = "plant"
	w.recalculate()
	check(not w.parcel_has(w.parcel_info(530),"power"), "source in bounding gap does not provide phantom electricity")
	w.place(531,"line")
	w.recalculate()
	check(w.parcel_has(w.parcel_info(530),"power"), "actual adjacent line serves irregular parcel")

	w = empty_world()
	for x in range(25): w.place(25*52+x,"rail")
	w.place(25*52,"station")
	w.place(25*52+24,"station")
	w.recalculate()
	check(w.network.railRoutes.size() == 1 and w.route(25*52,25*52+24,"rail").size() == 25, "connected rail stations produce full native route")
	w.advance_agents(0.6)
	check(w.trains.size() == 1 and w.trains[0].p > 0, "connected rail network spawns and advances train")
	w.tiles[25*52+12].rail = false
	w.recalculate()
	check(w.trains.is_empty() and w.network.railRoutes.is_empty(), "broken rail connection removes route and train")

	optional_data.events = [{"type":"quake","i":100,"age":null}]
	optional_world = WorldModel.from_dict(optional_data)
	optional_world.step()
	check(optional_world.events.size() == 1 and optional_world.events[0].age == 1, "legacy null event age defaults before simulation")
	# Tile invariants must be established before any simulation work on imported data.
	var valid_import = empty_world().serialize()
	var invalid_import = valid_import.duplicate(true)
	invalid_import.tiles[0].level = 1
	invalid_import.tiles[0].zone = null
	invalid_import.tiles[0].line = true
	invalid_import.tiles[1].civic = "plant"
	check(WorldModel.from_dict(invalid_import) == null, "developed tile without zoning is rejected before utility calculation")
	for elevation in [-4, 6, 99, 0.5, "3"]:
		invalid_import = valid_import.duplicate(true)
		invalid_import.tiles[0].elev = elevation
		check(WorldModel.from_dict(invalid_import) == null, "unsupported/noninteger elevation rejected: " + str(elevation))
	for malformed in [{"zone":"res","zoneType":"heavy"}, {"zone":"res","zoneType":[]}, {"resType":{}}, {"biome":"lava"}, {"biome":42}, {"level":1.5}, {"zone":"res","civic":"plant"}]:
		invalid_import = valid_import.duplicate(true)
		invalid_import.tiles[0].merge(malformed, true)
		check(WorldModel.from_dict(invalid_import) == null, "malformed tile structure/type rejected: " + str(malformed))
	var legacy_optional = valid_import.duplicate(true)
	legacy_optional.tiles[0].merge({"zone":"res","level":1,"zoneType":null,"resType":"apt","biome":null,"elev":null}, true)
	var legacy_optional_world = WorldModel.from_dict(legacy_optional)
	check(legacy_optional_world != null and legacy_optional_world.tiles[0].zoneType == "apt" and legacy_optional_world.tiles[0].elev == 0, "legacy nullable type/elevation fields retain residential subtype")

	# Exact baseline Float32 fields cover park relief, service funding, road
	# condition and neighboring traffic together, beyond the monthly growth fixture.
	w = empty_world()
	w.tiles[100].civic = "plant"
	w.tiles[101].civic = "park"
	w.tiles[102].merge({"zone":"res","zoneType":"apt","resType":"apt","level":2},true)
	w.tiles[103].road = true
	w.tiles[103].condition = 0.25
	w.tiles[104].abandoned = 2
	w.fields.police[102] = 0.25
	w.fields.school[102] = 0.5
	w.fields.hospital[102] = 0.75
	w.trafficHeat.resize(w.COUNT)
	w.trafficHeat[102] = 7.25
	w.trafficHeat[103] = 11.5
	w.stats.unemployment = 13
	w._environment_update()
	check(w.fields.pollution[102] == PackedFloat32Array([41.55])[0], "park pollution relief preserves Float32 rounding")
	check(w.fields.crime[102] == PackedFloat32Array([15.9515])[0], "park and police crime effects preserve Float32 rounding")
	check(w.fields.trafficImpact[102] == 11.5 and w.fields.trafficImpact[104] == 0, "traffic includes cardinal roads without wrapping map edges")
	check(w.fields.landValue[102] == PackedFloat32Array([57.507492])[0], "services traffic and road condition preserve exact land value")
	check(w.stats.avgCrime == 18 and w.stats.avgLand == 42, "environment averages preserve baseline rounding")
	print("World model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
