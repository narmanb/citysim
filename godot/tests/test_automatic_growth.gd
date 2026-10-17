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

func growth_world():
	var world = WorldModel.new(24)
	for i in range(world.COUNT): world.tiles[i] = world.blank_tile()
	world.recalculate()
	world.cash = 1000000
	world.stats.population = 1000
	world.stats.jobs = 1000
	world.demand = {"res":80,"com":80,"ind":80}
	return world

# Fields are the model's computed suitability inputs. Set them explicitly to
# isolate growth from the city's separate network/environment calculations.
func suitable(world, p: Dictionary):
	for i in p.members:
		for entry in [["power",1],["water",1],["landValue",78],["pollution",0],["crime",0],["school",0.8],["hospital",0.8]]:
			world.fields[entry[0]][i] = entry[1]

func lot(world, x: int, y: int, width: int, height: int, tool: String = "res", parcel_id: int = 1, level: int = 0, automatic: bool = true):
	for yy in range(y,y+height):
		for xx in range(x,x+width):
			var i = yy*world.N+xx
			world.place(i,tool,false,parcel_id)
			world.tiles[i].autoGrow = automatic
			world.tiles[i].level = level
	for xx in range(x,x+width): world.place((y+height)*world.N+xx,"road")
	var p = world.parcel_info(y*world.N+x)
	suitable(world,p)
	return p

func types(world) -> Dictionary:
	var counts = {"house":0,"apt":0,"shop":0,"office":0,"light":0,"heavy":0}
	for p in world._parcels.values(): counts[world.tiles[p.root].zoneType] += 1
	return counts

func mature_network_world():
	# A fixed developed district supplies real residents, jobs and services.
	# Seed 17 and ordinary sequential parcel 8 give stable apartment suitability.
	var world = WorldModel.new(17)
	for i in range(world.COUNT): world.tiles[i] = world.blank_tile()
	world.cash = 1000000
	for x in range(1,23): world.place(13*world.N+x,"road")
	for y in [10,16]:
		for x in range(23):
			world.place(y*world.N+x,"line")
			world.place(y*world.N+x,"pipe")
	for y in range(11,16):
		world.place(y*world.N,"line")
		world.place(y*world.N,"pipe")
	world.place(10*world.N,"plant")
	world.place(16*world.N,"plant")
	world.place(9*world.N+1,"pump")
	world.place(17*world.N+1,"pump")
	for x in range(16,21):
		world.place(9*world.N+x,"line")
		world.place(9*world.N+x,"pipe")
	world.place(8*world.N+17,"school")
	world.place(8*world.N+19,"hospital")
	world.place(8*world.N+16,"park")
	world.place(8*world.N+18,"park")
	var parcel_id = 1
	for section in [[2,11,"apt"],[5,11,"apt"],[8,11,"apt"],[2,14,"office"],[5,14,"office"],[8,14,"office"],[11,14,"office"]]:
		for y in range(section[1],section[1]+2):
			for x in range(section[0],section[0]+2):
				var i = y*world.N+x
				world.place(i,section[2],false,parcel_id)
				world.tiles[i].level = 3 if section[2] == "apt" else 4
		parcel_id += 1
	for y in range(10,13):
		for x in range(17,20):
			var i = y*world.N+x
			world.place(i,"res",false,parcel_id)
			world.tiles[i].autoGrow = true
			world.tiles[i].level = 2
	world.recalculate()
	return world

func run():
	check(WorldModel.blank_tile().get("autoGrow") == false,"Automatic growth is opt-in on blank tiles")
	var w = growth_world()
	var p = lot(w,3,3,3,3)
	var saved = w.serialize()
	var restored = WorldModel.from_dict(saved)
	check(restored != null and restored.tiles[p.root].get("autoGrow") == true,"Automatic zoning persists through save/import")
	saved.tiles[p.root].erase("autoGrow")
	restored = WorldModel.from_dict(saved)
	check(restored != null and restored.tiles[p.root].get("autoGrow") == false,"Absent legacy automatic flag defaults to manual")
	for invalid in [1,"true",[],{}]:
		saved.tiles[p.root].autoGrow = invalid
		check(WorldModel.from_dict(saved) == null,"Nonboolean automatic flag is rejected: " + str(invalid))
	saved.tiles[p.root].autoGrow = null
	restored = WorldModel.from_dict(saved)
	check(restored != null and restored.tiles[p.root].get("autoGrow") == false,"Nullable optional automatic flag defaults to manual")

	# Monthly integration uses real utilities and derived demand rather than the
	# controlled suitability fields used by the subtype tests below.
	w = growth_world()
	p = lot(w,14,3,3,3)
	w.place(2*w.N+2,"plant")
	w.place(3*w.N+3,"pump")
	for x in range(3,17):
		w.place(2*w.N+x,"line")
		w.place(2*w.N+x,"pipe")
	w.recalculate()
	check(w.parcel_has(p,"power") and w.parcel_has(p,"water"),"Real adjacent utility networks serve an automatic parcel")
	for elapsed in range(12):
		w.step()
		if w.tiles[p.root].level > 0: break
	check(w.tiles[p.root].level > 0 and w.tiles[p.root].zoneType == "house" and w.stats.population > 0,"An early town grows an automatic 3x3 house cluster through the monthly simulation")

	w = mature_network_world()
	var mature_root = 10*w.N+17
	p = w.parcel_info(mature_root)
	check(w.stats.population >= 120 and w.demand.res >= 28,"Occupied mature neighbors generate actual population and housing demand")
	check(w.tiles[11*w.N+2].occupancy > 0 and w.tiles[14*w.N+2].occupancy > 0,"Manual neighboring apartments and offices are occupied")
	check(w.road_near(mature_root) and w.parcel_has(p,"power") and w.parcel_has(p,"water") and w.stats.unpowered == 0 and w.stats.unwatered == 0,"Mature promotion fixture has actual road access and adequate connected utilities")
	check(w.fields.school[8*w.N+17] > 0 and w.fields.hospital[8*w.N+19] > 0 and (w._parcel_avg(p,"school")+w._parcel_avg(p,"hospital"))*0.5 >= 0.15,"Powered watered departments provide actual service coverage")
	check(w._parcel_avg(p,"landValue") >= 48 and w._growth_score(mature_root) >= 48,"Real amenities and demand meet apartment land-value and growth-score thresholds")
	check(w.tiles[mature_root].zoneType == "house" and w.tiles[mature_root].level == 2,"Mature monthly fixture begins with a level-two automatic house cluster")
	var mature_reload = WorldModel.from_dict(w.serialize())
	check(mature_reload != null,"Mature actual-network fixture imports before promotion")
	for elapsed in range(6):
		w.step()
		if mature_reload != null: mature_reload.step()
		if w.tiles[mature_root].zoneType == "apt": break
	check(w.tiles[mature_root].zoneType == "apt","Actual mature population utilities and services promote housing through the monthly simulation")
	if mature_reload != null:
		check(mature_reload.tiles[mature_root] == w.tiles[mature_root],"Save/reload before promotion produces the same monthly subtype level and occupancy")
	var promoted_reload = WorldModel.from_dict(w.serialize())
	check(promoted_reload != null and promoted_reload.tiles[mature_root].zoneType == "apt","A monthly promoted apartment survives saving and importing")
	if promoted_reload != null:
		for elapsed in range(3):
			w.step()
			promoted_reload.step()
		check(promoted_reload.tiles[mature_root] == w.tiles[mature_root] and promoted_reload.tiles[mature_root].zoneType == "apt","Subsequent actual monthly simulation remains deterministic after promoted-apartment reload")

	# Actual usable dimensions matter, including holes and elevation changes.
	for shape in ["tiny","thin","ring","slope"]:
		w = growth_world()
		p = lot(w,3,3,1 if shape == "tiny" else 9 if shape == "thin" else 3,1 if shape in ["tiny","thin"] else 3)
		if shape == "ring":
			w.tiles[4*w.N+4] = w.blank_tile()
			w._parcel_rebuild()
			p = w.parcel_info(p.root)
		if shape == "slope":
			for i in p.members: w.tiles[i].elev = (i%w.N+int(i/w.N))%2
		for iteration in range(8): w._population_develop()
		check(w.tiles[p.root].zoneType == "house",shape + " lot cannot become an apartment complex")

	for obstacle in ["early","land","services","demand","power","water","road"]:
		w = growth_world()
		p = lot(w,3,3,3,3)
		if obstacle == "early": w.stats.population = 0
		if obstacle == "demand": w.demand.res = 0
		for i in p.members:
			if obstacle == "land": w.fields.landValue[i] = 25
			if obstacle == "services":
				w.fields.school[i] = 0
				w.fields.hospital[i] = 0
			if obstacle in ["power","water"]: w.fields[obstacle][i] = 0
		if obstacle == "road":
			for i in w._parcel_roads(p): w.tiles[i].road = false
		for iteration in range(8): w._population_develop()
		check(w.tiles[p.root].zoneType == "house",obstacle + " prevents automatic high density")
		if obstacle in ["power","water","road"]: check(w.tiles[p.root].level == 0,obstacle + " prevents unserviced lot growth")
	for missing in ["power","water"]:
		w = growth_world()
		p = lot(w,3,3,3,3)
		w.demand.res = 100
		for i in p.members:
			w.fields[missing][i] = 0
			w.fields.landValue[i] = 100
			w.fields.school[i] = 1
			w.fields.hospital[i] = 1
		w._population_develop()
		check(w.tiles[p.root].level == 0,"Extreme demand cannot override missing " + missing + " for automatic zoning")

	# Identical high-quality 3x3 lots keep deterministic variety across parcels.
	w = growth_world()
	for n in range(36): lot(w,2+(n%9)*5,2+int(n/9)*5,3,3,"res",n+1)
	var rng_state = w._rng.state
	w._population_develop()
	check(types(w).apt == 2,"Initial development in a mature city can choose apartments directly")
	# Two actions per pass need enough passes to finish all 36 lots.
	for iteration in range(80): w._population_develop()
	var variety = types(w)
	check(variety.house > 0 and variety.apt > 0,"Serviced mature 3x3 housing supports both houses and apartment complexes")
	check(w._rng.state == rng_state,"Subtype selection does not consume simulation RNG")
	for parcel in w._parcels.values():
		var root = w.tiles[parcel.root]
		check(parcel.type == root.zoneType,"Promoted parcel metadata matches its subtype")
		for i in parcel.members:
			check(w.tiles[i].zoneType == root.zoneType and w.tiles[i].resType == root.zoneType,"Residential parcel members share subtype")
			check(w.tiles[i].level == root.level,"Residential parcel members share level")
	w._population_update()
	var capacity = 0
	for parcel in w._parcels.values(): capacity += w.parcel_capacity(parcel,w.tiles[parcel.root].level)
	check(w.stats.resCapacity == capacity,"Population pass uses promoted capacity exactly once per parcel")
	var before = w.serialize()
	restored = WorldModel.from_dict(before)
	check(restored != null and types(restored) == variety,"Save/import preserves chosen subtypes")
	if restored != null:
		for parcel in restored._parcels.values(): suitable(restored,parcel)
		restored.stats.population = 1000
		restored.stats.jobs = 1000
		restored.demand = {"res":80,"com":80,"ind":80}
		for iteration in range(12):
			restored.tick += 1
			restored._population_develop()
		check(types(restored) == variety,"Different months and reload do not reroll suitable housing styles")
		for parcel in restored._parcels.values():
			for i in parcel.members:
				restored.fields.landValue[i] = 0
				restored.fields.power[i] = 0
		for iteration in range(4): restored._population_develop()
		check(types(restored) == variety,"Temporary loss of suitability never downgrades subtypes")

	for pair in [["shop","office"],["light","heavy"]]:
		w = growth_world()
		for n in range(20): lot(w,2+(n%9)*5,2+int(n/9)*5,3,3,pair[0],n+1)
		for iteration in range(24): w._population_develop()
		check(types(w)[pair[0]] > 0 and types(w)[pair[1]] > 0,"Automatic " + pair[0] + " lots support varied " + pair[1] + " growth")
		for obstacle in ["tiny","population","demand","roads"]:
			w = growth_world()
			p = lot(w,3,3,1 if obstacle == "tiny" else 3,1 if obstacle == "tiny" else 3,pair[0])
			if obstacle == "population": w.stats.population = 50
			if obstacle == "demand": w.demand[p.zone] = 10
			if obstacle == "roads":
				for i in w._parcel_roads(p): w.tiles[i].condition = 0.2
			for iteration in range(12): w._population_develop()
			check(w.tiles[p.root].zoneType == pair[0],obstacle + " prevents automatic " + pair[1] + " growth")

	# Mature existing houses promote gradually and consume the level-growth budget.
	w = growth_world()
	p = lot(w,37,2,3,3,"res",8,1)
	w._population_develop()
	check(w.tiles[p.root].zoneType == "house" and w.tiles[p.root].level == 2,"A young house cluster matures before promotion")
	w._population_develop()
	check(w.tiles[p.root].zoneType == "apt" and w.tiles[p.root].level == 2,"A mature eligible house cluster can later promote without a level jump")
	w = growth_world()
	for n in range(20): lot(w,2+(n%9)*5,2+int(n/9)*5,3,3,"res",n+1,3)
	var fresh = lot(w,3,25,1,1,"res",100)
	w._population_develop()
	check(types(w).apt == 2,"At most two existing lots promote in a monthly growth pass")
	check(w.tiles[fresh.root].level == 0,"Two promotions consume the shared two-lot monthly growth budget")
	for parcel in w._parcels.values():
		if w.tiles[parcel.root].zoneType == "apt": check(w.tiles[parcel.root].level == 3,"Promotion does not also raise a building level")
	w = growth_world()
	for n in range(45): lot(w,2+(n%9)*5,2+int(n/9)*5,3,3,"res",n+1,3)
	w._population_develop()
	check(types(w).apt == 2,"Promotion cap remains two when the normal monthly budget exceeds two")

	w = growth_world()
	var manual_index = 0
	for pair in [["res","house"],["apt","apt"],["shop","shop"],["office","office"],["light","light"],["heavy","heavy"]]:
		p = lot(w,3+manual_index*5,3,3,3,pair[0],w.nextParcelId,2,false)
		manual_index += 1
	for iteration in range(20): w._population_develop()
	var manual = types(w)
	check(manual == {"house":1,"apt":1,"shop":1,"office":1,"light":1,"heavy":1},"Explicit manual subtypes never change automatically")
	print("Automatic growth: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
