class_name CityWorld
extends RefCounted
## UI-independent MetroForge state. All persistent keys retain their legacy spelling.

const N = 52
const COUNT = N * N
const COST = {"bulldoze":18,"road":18,"rail":36,"line":13,"pipe":12,"res":9,"apt":14,"shop":12,"office":16,"light":12,"logistics":18,"heavy":22,"park":95,"plant":3000,"pump":950,"tower":800,"police":1200,"fire":1200,"school":1600,"hospital":1900,"station":550,"raise":20,"lower":20,"river":24,"grass":5,"desert":5,"tree":4,"forest":6}
const CONFIG = {"monthSeconds":4,"startingCash":36000,"powerPlantCapacity":550,"waterPumpCapacity":520,"waterTowerCapacity":180,"waterTowerLoss":1,"bondAmount":10000,"bondPayment":150,"bondTerm":80,"maxCars":70,"maxTrains":9,"bridgeSpan":8,"milestones":[500,1000,2500,5000,10000],"buildingCapacity":{"res":[0,12,28,68,150],"com":[0,10,24,58,125],"ind":[0,12,30,68,130]},"maintenance":{"road":1.5,"rail":2.4,"line":0.4,"pipe":0.45,"park":8,"plant":120,"pump":32,"tower":18,"police":80,"fire":80,"school":110,"hospital":130,"station":28},"serviceRadius":{"police":8,"fire":8,"school":9,"hospital":9}}
const TOOLS = [["pan","✋ Pan"],["bulldoze","▧ Bulldoze"],["road","═ Road"],["rail","≡ Rail"],["line","⚡ Power line"],["pipe","◌ Water pipe"],["res","⌂ House lots"],["apt","▥ Apartment lots"],["shop","▣ Shops & services"],["office","▥ Offices"],["light","▤ Light industry"],["logistics","▰ Logistics"],["heavy","♨ Heavy industry"],["park","♣ Park"],["plant","⚙ Power plant"],["pump","◉ Water pump"],["tower","◍ Water tower"],["police","✦ Police"],["fire","▲ Fire station"],["school","◆ School"],["hospital","✚ Hospital"],["station","▥ Rail station"],["raise","▲ Raise terrain"],["lower","▼ Lower terrain"],["river","≈ Dig water channel"],["grass","· Grass biome"],["desert","░ Desert biome"],["tree","♠ Tree"],["forest","♣ Forest brush"]]
const ZONE_TOOL = {"res":{"zone":"res","type":"house"},"apt":{"zone":"res","type":"apt"},"shop":{"zone":"com","type":"shop"},"office":{"zone":"com","type":"office"},"light":{"zone":"ind","type":"light"},"logistics":{"zone":"ind","type":"logistics"},"heavy":{"zone":"ind","type":"heavy"}}
const CATEGORIES = {"Transport":["road","rail","station"],"Zoning":["res","apt","shop","office","light","logistics","heavy"],"Utilities":["line","pipe","plant","pump","tower"],"Services":["police","fire","school","hospital"],"Parks":["park"],"Terraform":["raise","lower","river","grass","desert","tree","forest"]}
const TERRAIN_TOOLS = ["raise","lower","river","grass","desert","tree","forest"]
const SERVICES = ["police","fire","school","hospital"]

var tiles: Array = []
var cash: float = CONFIG.startingCash
var year: int = 2000
var month: int = 1
var tick: int = 0
var seed: int = 0
var taxes: Dictionary = {"res":8,"com":8,"ind":8}
var funding: Dictionary = {"road":100,"police":100,"fire":100,"school":100,"hospital":100}
var randomDisasters: bool = false
var bondMonths: int = 0
var nextParcelId: int = 1
var milestones: Array = []
var stats: Dictionary = {}
var fields: Dictionary = {}
var demand: Dictionary = {"res":60,"com":25,"ind":70}
var cars: Array = []
var trains: Array = []
var events: Array = []
var messages: Array = []
var network: Dictionary = {}
var selected: int = -1
var trafficHeat = PackedFloat32Array()
var _parcels: Dictionary = {}
var _parcelAt: Array = []
var _spawnElapsed: float = 0.0
var _lastPop: int = 0
var _rng = RandomNumberGenerator.new()

func _init(seed_value: int = 0):
	seed = seed_value if seed_value != 0 else randi_range(1, 99999999)
	_rng.seed = seed
	generate()
	recalculate()

static func blank_tile(terrain: String = "grass", tree: bool = false) -> Dictionary:
	return {"terrain":terrain,"tree":tree,"road":false,"rail":false,"line":false,"pipe":false,"zone":null,"resType":null,"zoneType":null,"parcel":0,"level":0,"occupancy":0,"abandoned":0,"civic":null,"condition":1.0,"fire":0.0,"damage":0.0,"storage":0.0,"elev":0,"biome":"grass","channel":false,"waterSource":terrain == "water"}

static func _hash(x: int, y: int, seed_value: int) -> float:
	var a = ((x + seed_value) * 374761393) & 0xffffffff
	var b = ((y - seed_value) * 668265263) & 0xffffffff
	var n = (a + b) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return float((n ^ (n >> 16)) & 0xffffffff) / 4294967295.0

static func _noise(x: float, y: float, seed_value: int) -> float:
	var xx = int(floor(x))
	var yy = int(floor(y))
	var u = x - xx
	var v = y - yy
	var su = u * u * (3.0 - 2.0 * u)
	var sv = v * v * (3.0 - 2.0 * v)
	var a = _hash(xx, yy, seed_value)
	var b = _hash(xx + 1, yy, seed_value)
	var c = _hash(xx, yy + 1, seed_value)
	var d = _hash(xx + 1, yy + 1, seed_value)
	return a + (b-a)*su + (c-a+(d-c-b+a)*su)*sv

func generate() -> void:
	tiles.clear()
	for i in range(COUNT):
		var x = i % N
		var y = int(i / N)
		var coast = 10 + 5*sin(y*0.16) + 3*sin(y*0.43) + 2*(_noise(x*0.19,y*0.15,seed)-0.5)
		var lake = Vector2((x-41)/9.0,(y-15)/7.0).length() + 0.3*(_noise(x*0.19,y*0.19,seed+2)-0.5) < 1
		var river = x > coast and x < 48 and abs(y-(43+2*sin(x*0.24))) < 1.7
		var terrain = "water" if x < coast or lake or river else "grass"
		var tree = terrain == "grass" and _noise(x*0.28,y*0.28,seed+5) > 0.68 and _hash(x,y,seed+6) > 0.37
		tiles.append(blank_tile(terrain,tree))
	events.clear()
	notify("New terrain generated. Build a plant, a pump, connected networks, roads, and zones.")

func neighbors(i: int) -> Array:
	if i < 0 or i >= COUNT:
		return []
	var out: Array = []
	var x = i % N
	var y = int(i / N)
	if x > 0: out.append(i-1)
	if x < N-1: out.append(i+1)
	if y > 0: out.append(i-N)
	if y < N-1: out.append(i+N)
	return out

static func _man(a: int, b: int) -> int:
	return abs(a % N - b % N) + abs(int(a / N) - int(b / N))

func notify(text: String, kind: String = "info") -> void:
	if not messages.is_empty() and messages[0].get("text") == text and tick - int(messages[0].get("tick",0)) < 8:
		return
	messages.push_front({"text":text,"tick":tick,"kind":kind})
	if messages.size() > 35: messages.resize(35)

func spend(amount: float) -> bool:
	if cash < amount:
		notify("Need $%d; treasury has $%d" % [roundi(amount),roundi(cash)], "warn")
		return false
	cash -= amount
	return true

func refund(amount: float) -> void:
	cash += amount

func take_bond() -> bool:
	if bondMonths > 0:
		notify("Repay the existing bond before issuing another.","warn")
		return false
	cash += CONFIG.bondAmount
	bondMonths = CONFIG.bondTerm
	notify("Municipal bond issued: $10,000. Repayment is $150 per month for 80 months.")
	_economy_calculate()
	return true

func can_place(i: int, tool: String, bridge: bool = false) -> bool:
	if i < 0 or i >= tiles.size() or not COST.has(tool): return false
	var t = tiles[i]
	if tool in TERRAIN_TOOLS:
		if tool in ["grass","desert"]: return t.terrain != "water" and not t.civic and not t.level
		if tool in ["tree","forest"]: return t.terrain != "water" and not t.civic and not t.road and not t.rail and not t.line and not t.level
		return not t.civic and not t.road and not t.rail and not t.level and not t.zone
	if tool == "bulldoze": return bool(t.road or t.rail or t.line or t.pipe or t.zone or t.civic or t.fire or t.tree or t.channel)
	if tool == "pipe": return true
	if tool in ["road","rail"]: return not t.civic and (t.terrain != "water" or bridge)
	if t.terrain == "water": return false
	if tool == "line": return not t.civic
	if ZONE_TOOL.has(tool): return not t.civic and not t.road and not t.rail
	if tool == "park": return not t.civic and not t.road and not t.rail and not t.zone
	if tool == "station": return t.rail and not t.civic
	return not t.civic and not t.road and not t.rail and not t.zone

func place(i: int, tool: String, bridge: bool = false, parcel_id: int = 0) -> bool:
	if not can_place(i,tool,bridge): return false
	var t = tiles[i]
	var cost = float(COST[tool]) * (5 if t.terrain == "water" and tool in ["road","rail"] else 1)
	var meta = ZONE_TOOL.get(tool,{})
	if tool in ["road","rail","line","pipe"] and t[tool]: return false
	if not meta.is_empty() and t.zone == meta.zone and t.zoneType == meta.type: return false
	if tool == "raise" and t.elev >= 5: return false
	if tool == "lower" and t.elev <= -3: return false
	if tool == "grass" and t.biome == "grass": return false
	if tool == "desert" and t.biome == "desert" and not t.tree: return false
	if tool in ["tree","forest"] and t.tree and t.biome == "grass": return false
	if tool == "river" and t.channel and not t.waterSource and t.elev <= -1 and not t.tree: return false
	if not spend(cost): return false
	if tool == "bulldoze":
		if t.fire: t.fire = 0
		elif t.civic:
			t.civic = null
			t.storage = 0
		elif t.zone and t.level:
			var p = parcel_info(i)
			for j in p.get("members",[i]):
				tiles[j].level = 0
				tiles[j].occupancy = 0
				tiles[j].abandoned = 0
				tiles[j].damage = 0
		elif t.zone:
			t.zone = null
			t.resType = null
			t.zoneType = null
			t.parcel = 0
		elif t.road: t.road = false
		elif t.rail: t.rail = false
		elif t.line: t.line = false
		elif t.pipe: t.pipe = false
		elif t.channel:
			t.channel = false
			t.terrain = "grass"
		else: t.tree = false
		_terrain_reflow()
	elif tool in TERRAIN_TOOLS:
		if tool == "raise": t.elev = clampi(int(t.elev)+1,-3,5)
		elif tool == "lower": t.elev = clampi(int(t.elev)-1,-3,5)
		elif tool == "river":
			t.channel = true
			t.waterSource = false
			t.elev = mini(-1,int(t.elev))
			t.terrain = "grass"
			t.tree = false
		elif tool == "grass": t.biome = "grass"
		elif tool == "desert":
			t.biome = "desert"
			t.tree = false
		else:
			t.tree = true
			t.biome = "grass"
		_terrain_reflow()
	elif tool in ["road","rail"]:
		t[tool] = true
		t.tree = false
		t.zone = null
		t.resType = null
		t.zoneType = null
		t.parcel = 0
		t.level = 0
		t.occupancy = 0
		if tool == "road": t.condition = 1.0
	elif tool == "line":
		t.line = true
		t.tree = false
	elif tool == "pipe": t.pipe = true
	elif not meta.is_empty():
		t.zone = meta.zone
		t.zoneType = meta.type
		t.resType = meta.type if meta.zone == "res" else null
		t.parcel = parcel_id if parcel_id > 0 else nextParcelId
		if parcel_id <= 0: nextParcelId += 1
		else: nextParcelId = maxi(nextParcelId,parcel_id+1)
		t.level = 0
		t.occupancy = 0
		t.abandoned = 0
		t.tree = false
	else:
		t.civic = tool
		t.tree = false
		if tool == "tower": t.storage = 0
	_parcelAt.clear()
	_parcels.clear()
	return true

func _terrain_reflow() -> void:
	var queue: Array = []
	var seen = PackedByteArray()
	seen.resize(COUNT)
	for i in range(COUNT):
		var t = tiles[i]
		if t.terrain == "water" and not t.channel: t.waterSource = true
		if t.waterSource and t.terrain == "water":
			seen[i] = 1
			queue.append(i)
	var head = 0
	while head < queue.size():
		for j in neighbors(queue[head]):
			var t = tiles[j]
			if seen[j] or not t.channel or t.elev > 0: continue
			seen[j] = 1
			queue.append(j)
		head += 1
	for i in range(COUNT):
		if tiles[i].channel: tiles[i].terrain = "water" if seen[i] else "grass"

static func _default_type(zone) -> String:
	return "house" if zone == "res" else "shop" if zone == "com" else "light"

func _parcel_rebuild() -> void:
	_parcels.clear()
	_parcelAt.resize(COUNT)
	_parcelAt.fill(null)
	for i in range(COUNT):
		var t = tiles[i]
		if not t.zone or not t.parcel: continue
		if not t.zoneType: t.zoneType = t.resType if t.resType else _default_type(t.zone)
		if t.zone == "res": t.resType = t.zoneType
		if not _parcels.has(t.parcel):
			_parcels[t.parcel] = {"id":t.parcel,"zone":t.zone,"type":t.zoneType,"members":[],"root":i,"anchor":i,"minX":N,"minY":N,"maxX":0,"maxY":0}
		var p = _parcels[t.parcel]
		p.members.append(i)
		p.minX = mini(p.minX,i%N)
		p.minY = mini(p.minY,int(i/N))
		p.maxX = maxi(p.maxX,i%N)
		p.maxY = maxi(p.maxY,int(i/N))
		p.root = mini(p.root,i)
		p.anchor = maxi(p.anchor,i)
	for p in _parcels.values():
		p.width = p.maxX-p.minX+1
		p.height = p.maxY-p.minY+1
		p.area = p.members.size()
		for i in p.members: _parcelAt[i] = p

func parcel_info(i: int) -> Dictionary:
	if i < 0 or i >= COUNT: return {}
	if _parcelAt.is_empty(): _parcel_rebuild()
	return _parcelAt[i] if _parcelAt[i] != null else {}

func _parcel_roads(p: Dictionary) -> Array:
	var roads: Dictionary = {}
	for i in p.get("members",[]):
		for j in neighbors(i):
			if tiles[j].road: roads[j] = true
	return roads.keys()

func road_near(i: int) -> bool:
	if i < 0 or i >= COUNT: return false
	if tiles[i].parcel:
		return not _parcel_roads(parcel_info(i)).is_empty()
	for j in neighbors(i):
		if tiles[j].road: return true
	return false

func _parcel_avg(p: Dictionary, field: String) -> float:
	if p.is_empty() or not fields.has(field): return 0.0
	var total = 0.0
	for i in p.members: total += fields[field][i]
	return total/maxi(1,p.members.size())

func parcel_has(p: Dictionary, field: String) -> bool:
	if p.is_empty() or not fields.has(field): return false
	for i in p.members:
		if fields[field][i]: return true
	return false

func parcel_capacity(p: Dictionary, level: int) -> int:
	if p.is_empty() or level <= 0: return 0
	var t = tiles[p.root]
	var type = t.zoneType if t.zoneType else t.resType if t.resType else p.get("type",_default_type(t.zone))
	var area = int(p.area)
	var lv = mini(4,level)
	var base: float
	if t.zone == "res":
		if type == "apt":
			base = 14 if area == 1 else 30 if area == 2 else 48 if area == 3 else area*20
			return _js_round(base*[0,1,1.55,2.3,3.4][lv])
		base = 5 if area == 1 else 8 if area == 2 else 12 if area == 3 else 16+maxi(0,area-4)*3
		return _js_round(base*(1+(mini(3,lv)-1)*0.12))
	if t.zone == "com":
		base = maxi(10,area*18) if type == "office" else maxi(7,area*11)
		return _js_round(base*[0,1,1.45,2.05,2.8][lv])
	base = maxi(16,area*20) if type == "heavy" else maxi(12,area*16) if type == "logistics" else maxi(9,area*12)
	return _js_round(base*[0,1,1.35,1.8,2.35][lv])

static func _js_round(value: float) -> int:
	return int(floor(value+0.5))

func serialize() -> Dictionary:
	return {"version":6,"seed":seed,"tiles":tiles.duplicate(true),"cash":cash,"year":year,"month":month,"tick":tick,"taxes":taxes.duplicate(true),"funding":funding.duplicate(true),"randomDisasters":randomDisasters,"bondMonths":bondMonths,"milestones":milestones.duplicate(true),"messages":messages.duplicate(true),"events":events.duplicate(true),"stats":stats.duplicate(true),"cars":cars.duplicate(true),"trains":trains.duplicate(true),"nextParcelId":nextParcelId}

static func _finite(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func from_dict(data: Dictionary) -> CityWorld:
	if not data.get("tiles") is Array or data.tiles.size() != COUNT: return null
	var normalized: Array = []
	var saved_occupancy: Array = []
	var parcel_types: Dictionary = {}
	var defaults = blank_tile()
	var zone_types = {"res":["house","apt"],"com":["shop","office"],"ind":["light","logistics","heavy"]}
	for value in data.tiles:
		if not value is Dictionary: return null
		var q = blank_tile()
		q.merge(value,true)
		if not q.terrain in ["grass","water"]: return null
		if q.zone != null and not q.zone in ["res","com","ind"]: return null
		if q.civic != null and not q.civic in ["park","plant","pump","tower","police","fire","school","hospital","station"]: return null
		# Optional legacy fields may be absent/null. Present structural values must
		# be supported integers; guessing a height or building level loses state.
		for key in ["level","parcel","elev"]:
			if q[key] == null: q[key] = defaults[key]
			if not _finite(q[key]) or float(q[key]) != floor(float(q[key])): return null
		if q.level < 0 or q.level > 4 or q.parcel < 0 or q.elev < -3 or q.elev > 5: return null
		q.level = int(q.level)
		q.parcel = int(q.parcel)
		q.elev = int(q.elev)
		if q.level > 0 and q.zone == null: return null
		if q.civic != null and q.zone != null: return null
		for key in ["zoneType","resType"]:
			if q[key] != null and not q[key] is String: return null
		if q.resType != null and not q.resType in ["house","apt"]: return null
		if q.zoneType != null and not q.zoneType in ["house","apt","shop","office","light","logistics","heavy"]: return null
		if q.zone != null:
			if q.zoneType == null: q.zoneType = q.resType if q.zone == "res" and q.resType != null else _default_type(q.zone)
			if not q.zoneType in zone_types[q.zone]: return null
			q.resType = q.zoneType if q.zone == "res" else null
			if q.parcel > 0:
				var signature: Array = [q.zone,q.zoneType]
				if parcel_types.has(q.parcel) and parcel_types[q.parcel] != signature: return null
				parcel_types[q.parcel] = signature
		else:
			q.zoneType = null
			q.resType = null
			q.parcel = 0
		if q.biome == null: q.biome = "grass"
		if not q.biome in ["grass","desert"]: return null
		for key in ["tree","road","rail","line","pipe","channel","waterSource"]: q[key] = bool(q[key])
		if q.zone != null and (q.road or q.rail): return null
		if q.civic != null and (q.road or (q.rail and q.civic != "station")): return null
		for key in ["occupancy","abandoned","fire","damage","storage","condition"]:
			if not _finite(q[key]): q[key] = defaults[key]
		q.occupancy = maxi(0,int(q.occupancy))
		q.condition = clampf(float(q.condition),0.0,1.0)
		if q.line: q.tree = false
		if q.terrain == "water" and not q.channel: q.waterSource = true
		normalized.append(q.duplicate(true))
		saved_occupancy.append(q.occupancy)
	var world = CityWorld.new(int(data.seed) if _finite(data.get("seed")) else 24)
	world.seed = int(data.seed) if _finite(data.get("seed")) else 24
	world._rng.seed = world.seed
	world.tiles = normalized
	world.cash = float(data.cash) if _finite(data.get("cash")) else CONFIG.startingCash
	world.year = int(data.year) if _finite(data.get("year")) and data.year != 0 else 2000
	world.month = clampi(int(data.month),1,12) if _finite(data.get("month")) else 1
	world.tick = maxi(0,int(data.tick)) if _finite(data.get("tick")) else 0
	for key in ["taxes","funding"]:
		if data.get(key) is Dictionary:
			for k in world.get(key):
				if _finite(data[key].get(k)): world.get(key)[k] = data[key][k]
	world.randomDisasters = bool(data.get("randomDisasters",false))
	world.bondMonths = clampi(int(data.bondMonths),0,CONFIG.bondTerm) if _finite(data.get("bondMonths")) else 0
	for key in ["milestones","messages","events","cars","trains"]:
		if data.get(key) is Array: world.set(key,data[key].duplicate(true))
	world.messages = world.messages.filter(func(m): return m is Dictionary and m.get("text") is String)
	world.events = world.events.filter(func(e): return e is Dictionary and _finite(e.get("i")) and e.i >= 0 and e.i < COUNT)
	for event in world.events:
		event.i = int(event.i)
		event.age = int(event.age) if _finite(event.get("age")) else 0
	for key in ["cars","trains"]:
		var safe_agents: Array = []
		for agent in world.get(key):
			if not agent is Dictionary or not agent.get("path") is Array or agent.path.size() < 2: continue
			var valid = true
			for index in agent.path:
				if not _finite(index) or index < 0 or index >= COUNT: valid = false
			if not valid: continue
			agent.p = float(agent.p) if _finite(agent.get("p")) else 0.0
			agent.speed = float(agent.speed) if _finite(agent.get("speed")) else 0.55
			safe_agents.append(agent)
		world.set(key,safe_agents)
	var saved_stats = data.get("stats",{})
	world.stats = {"yearToDate":0,"lastYearNet":0}
	if saved_stats is Dictionary:
		for key in ["yearToDate","lastYearNet"]:
			if _finite(saved_stats.get(key)): world.stats[key] = saved_stats[key]
	world.fields = {}
	world.demand = {"res":50,"com":35,"ind":50}
	world.nextParcelId = maxi(1,int(data.nextParcelId)) if _finite(data.get("nextParcelId")) else 1
	for t in world.tiles: world.nextParcelId = maxi(world.nextParcelId,int(t.parcel)+1)
	world.recalculate()
	if _finite(data.get("version")) and data.version >= 3 and saved_stats is Dictionary:
		for i in range(COUNT): world.tiles[i].occupancy = saved_occupancy[i]
		world._environment_update()
		world._population_update(false)
		world._traffic_prepare()
		world._economy_calculate()
		# Preserve historical statistics; recompute current derived fields from the imported map.
		for key in ["yearToDate","lastYearNet"]:
			if _finite(saved_stats.get(key)): world.stats[key] = saved_stats[key]
		world._demand_update()
	return world

func recalculate() -> void:
	_terrain_reflow()
	_parcel_rebuild()
	_utility_update()
	_service_update()
	_environment_update()
	_population_update()
	_demand_update()
	_traffic_prepare()
	_economy_calculate()

func step() -> void:
	tick += 1
	month += 1
	if month > 12:
		month = 1
		year += 1
		stats.lastYearNet = stats.get("yearToDate",0)
		stats.yearToDate = 0
	_utility_update()
	_service_update()
	_environment_update()
	_population_update()
	_demand_update()
	_population_develop()
	_utility_update(true)
	_service_update()
	_environment_update()
	_population_update()
	_demand_update()
	_traffic_prepare()
	_infrastructure_update()
	_disaster_update()
	_economy_update()
	_alerts()

func _conduct(i: int, kind: String) -> bool:
	var t = tiles[i]
	if kind == "power": return bool(t.line or t.civic == "plant" or (t.level and not t.abandoned))
	return bool(t.pipe or t.civic in ["pump","tower"] or (t.level and not t.abandoned))

func _utility_component(kind: String, power_covered = null, commit: bool = false) -> Dictionary:
	var covered = PackedByteArray()
	var seen = PackedByteArray()
	var group_at = PackedInt32Array()
	covered.resize(COUNT)
	seen.resize(COUNT)
	group_at.resize(COUNT)
	group_at.fill(-1)
	var groups: Array = []
	for i in range(COUNT):
		if seen[i] or not _conduct(i,kind): continue
		var g = {"part":[],"sources":[],"pumps":[],"towers":[],"consumers":[],"pumpOutput":0,"stored":0.0,"capacity":0.0,"used":0}
		var id = groups.size()
		var queue: Array = [i]
		var head = 0
		seen[i] = 1
		while head < queue.size():
			var j = queue[head]
			var t = tiles[j]
			g.part.append(j)
			group_at[j] = id
			if kind == "power" and t.civic == "plant": g.sources.append(j)
			if kind == "water" and t.civic == "pump" and power_covered[j]:
				g.pumps.append(j)
				g.sources.append(j)
				var waterside = false
				for k in neighbors(j):
					if tiles[k].terrain == "water": waterside = true
				g.pumpOutput += _js_round(CONFIG.waterPumpCapacity*(1 if waterside else 0.55))
			if kind == "water" and t.civic == "tower":
				g.towers.append(j)
				g.stored += clampf(float(t.storage),0.0,CONFIG.waterTowerCapacity)
			for k in neighbors(j):
				if not seen[k] and _conduct(k,kind):
					seen[k] = 1
					queue.append(k)
			head += 1
		if kind == "water" and g.stored > 0:
			for j in g.towers:
				if tiles[j].storage > 0: g.sources.append(j)
		g.capacity = g.sources.size()*CONFIG.powerPlantCapacity if kind == "power" else g.pumpOutput+g.stored
		groups.append(g)
	var parcel_consumers: Dictionary = {}
	for i in range(COUNT):
		var t = tiles[i]
		var p = parcel_info(i) if t.parcel else {}
		if not p.is_empty():
			if parcel_consumers.has(p.id) or i != p.root: continue
			parcel_consumers[p.id] = true
		var candidate: Dictionary = {}
		for m in p.get("members",[i]):
			if group_at[m] >= 0: candidate[group_at[m]] = true
			for j in neighbors(m):
				if group_at[j] >= 0: candidate[group_at[j]] = true
		if candidate.is_empty(): continue
		var id = candidate.keys()[0]
		for possible in candidate:
			if groups[possible].capacity > groups[id].capacity: id = possible
		if not t.level and not t.civic: continue
		var units = 0
		if t.level:
			var capacity = parcel_capacity(p,int(t.level)) if not p.is_empty() else CONFIG.buildingCapacity[t.zone][t.level]
			units = maxi(2,ceili(capacity*0.105))
		elif kind == "power" and t.civic == "pump": units = 10
		elif t.civic in SERVICES or t.civic == "station": units = 15 if t.civic == "hospital" else 9
		if units: groups[id].consumers.append({"i":i,"n":units,"members":p.get("members",[])})
	var production = 0.0
	for g in groups:
		production += g.capacity
		var left = g.capacity
		var sources = g.sources
		g.consumers.sort_custom(func(a,b):
			var da = COUNT*2
			var db = COUNT*2
			for j in sources:
				da = mini(da,_man(a.i,j))
				db = mini(db,_man(b.i,j))
			return a.i < b.i if da == db else da < db)
		for consumer in g.consumers:
			if left < consumer.n: continue
			if not consumer.members.is_empty():
				for j in consumer.members: covered[j] = 1
			else: covered[consumer.i] = 1
			left -= consumer.n
	# Capacity allocation does not let a powerless building relay utility service.
	var reached = PackedByteArray()
	reached.resize(COUNT)
	var queue: Array = []
	for g in groups:
		if g.capacity > 0:
			for i in g.sources:
				if not reached[i]:
					reached[i] = 1
					queue.append(i)
	var head = 0
	while head < queue.size():
		for j in neighbors(queue[head]):
			if reached[j] or not _conduct(j,kind): continue
			var t = tiles[j]
			var wire = (t.line or t.civic == "plant") if kind == "power" else (t.pipe or t.civic in ["pump","tower"])
			if not wire and not covered[j]: continue
			reached[j] = 1
			queue.append(j)
		head += 1
	for i in range(COUNT):
		var t = tiles[i]
		var touch = bool(reached[i])
		for j in neighbors(i):
			if reached[j]: touch = true
		if t.level:
			if not reached[i]: covered[i] = 0
		elif (t.civic and (t.civic in SERVICES or t.civic == "station")) or (kind == "power" and t.civic == "pump"):
			covered[i] = 1 if covered[i] and touch else 0
		elif t.zone or t.line or t.pipe or t.civic:
			covered[i] = 1 if touch else 0
	var usage = 0
	var pumped = 0
	for g in groups:
		g.used = 0
		pumped += g.pumpOutput
		for consumer in g.consumers:
			if covered[consumer.i]:
				usage += consumer.n
				g.used += consumer.n
		if kind == "water" and commit:
			var balance = g.pumpOutput-g.used
			if balance < 0:
				var need = -balance
				for i in g.towers:
					var units = minf(need,float(tiles[i].storage))
					tiles[i].storage -= units
					need -= units
					if need <= 0: break
			elif balance > 0 and g.pumpOutput > 0:
				for i in g.towers:
					var units = minf(balance,CONFIG.waterTowerCapacity-float(tiles[i].storage))
					tiles[i].storage += units
					balance -= units
					if balance <= 0: break
			if not g.pumpOutput:
				for i in g.towers: tiles[i].storage = maxf(0.0,float(tiles[i].storage)-CONFIG.waterTowerLoss)
	var stored = 0.0
	for t in tiles:
		if t.civic == "tower": stored += t.storage
	return {"covered":covered,"production":production,"usage":usage,"groups":groups.size(),"pumped":pumped,"stored":stored}

func _utility_update(commit: bool = false) -> void:
	var power = _utility_component("power")
	var water = _utility_component("water",power.covered,commit)
	fields.power = power.covered
	fields.water = water.covered
	var unpowered = 0
	var unwatered = 0
	var seen: Dictionary = {}
	for i in range(COUNT):
		var t = tiles[i]
		if not t.level: continue
		if t.parcel:
			var p = parcel_info(i)
			if p.is_empty() or seen.has(p.id) or i != p.root: continue
			seen[p.id] = true
			if not parcel_has(p,"power"): unpowered += 1
			if not parcel_has(p,"water"): unwatered += 1
		else:
			if not power.covered[i]: unpowered += 1
			if not water.covered[i]: unwatered += 1
	stats.merge({"powerGenerated":power.production,"powerUsed":power.usage,"waterCapacity":water.production,"waterUsed":water.usage,"waterPumped":water.pumped,"waterStored":water.stored,"unpowered":unpowered,"unwatered":unwatered},true)

func _service_update() -> void:
	for type in SERVICES:
		var values = PackedFloat32Array()
		values.resize(COUNT)
		var radius = CONFIG.serviceRadius[type]*pow(maxf(0.0,funding[type]/100.0),0.7)
		for i in range(COUNT):
			if tiles[i].civic != type or not fields.power[i] or not fields.water[i]: continue
			var x = i%N
			var y = int(i/N)
			var r = ceili(radius)
			for yy in range(maxi(0,y-r),mini(N-1,y+r)+1):
				for xx in range(maxi(0,x-r),mini(N-1,x+r)+1):
					var distance = Vector2(x-xx,y-yy).length()
					var value = clampf(1-distance/(radius+1),0.0,1.0)*(funding[type]/100.0)
					values[yy*N+xx] = maxf(values[yy*N+xx],value)
		fields[type] = values

func _environment_update() -> void:
	for name in ["pollution","crime","landValue","trafficImpact"]:
		var values = PackedFloat32Array()
		values.resize(COUNT)
		fields[name] = values
	var parks: Array = []
	var stations: Array = []
	for i in range(COUNT):
		var t = tiles[i]
		if t.civic == "park": parks.append(i)
		if t.civic == "station" and t.rail: stations.append(i)
		var strength = 70.0 if t.civic == "plant" else t.level*(15+t.occupancy*0.08) if t.zone == "ind" else 0.0
		if not strength: continue
		var x = i%N
		var y = int(i/N)
		for yy in range(maxi(0,y-6),mini(N-1,y+6)+1):
			for xx in range(maxi(0,x-6),mini(N-1,x+6)+1):
				var distance = abs(x-xx)+abs(y-yy)
				if distance <= 7: fields.pollution[yy*N+xx] += strength*maxf(0,1-distance/7.0)
	var total_crime = 0.0
	var total_land = 0.0
	for i in range(COUNT):
		var t = tiles[i]
		var park = 0.0
		var abandoned = 0.0
		var bad_road = 0.0
		for j in neighbors(i):
			var neighbor = tiles[j]
			if neighbor.civic == "park": park += 9
			if neighbor.abandoned: abandoned += 9
			if neighbor.road: bad_road += 1-neighbor.condition
		for p in parks:
			if _man(i,p) <= 5: park += maxi(0,5-_man(i,p))
		fields.pollution[i] = clampf(fields.pollution[i]-park*0.65,0.0,100.0)
		var transport = 12 if road_near(i) else 0
		for j in stations:
			if _man(i,j) <= 5:
				transport += 8
				break
		var local_traffic = trafficHeat[i] if trafficHeat.size() == COUNT else 0.0
		for j in neighbors(i):
			if tiles[j].road and trafficHeat.size() == COUNT: local_traffic = maxf(local_traffic,trafficHeat[j])
		fields.trafficImpact[i] = local_traffic
		var economic = stats.get("unemployment",0)
		fields.crime[i] = clampf(15+t.level*4+economic*0.2+abandoned+fields.pollution[i]*0.13-fields.police[i]*55-park*0.1,0.0,100.0)
		fields.landValue[i] = clampf(48+park+transport+fields.school[i]*20+fields.hospital[i]*13+fields.police[i]*8-fields.pollution[i]*0.48-fields.crime[i]*0.34-fields.trafficImpact[i]*0.25-bad_road*12-(45 if t.fire else 0),0.0,100.0)
		total_crime += fields.crime[i]
		total_land += fields.landValue[i]
	stats.avgCrime = _js_round(total_crime/COUNT)
	stats.avgLand = _js_round(total_land/COUNT)

func _population_update(update_occupancy: bool = true) -> void:
	_parcel_rebuild()
	var capacity = {"res":0,"com":0,"ind":0}
	var occupied = {"res":0,"com":0,"ind":0}
	var developed = {"res":0,"com":0,"ind":0}
	var abandoned = 0
	var seen: Dictionary = {}
	for i in range(COUNT):
		var t = tiles[i]
		if t.parcel:
			var p = parcel_info(i)
			if p.is_empty() or seen.has(p.id): continue
			seen[p.id] = true
			t = tiles[p.root]
			if t.abandoned: abandoned += 1
			if not t.level: continue
			var units = parcel_capacity(p,int(t.level))
			capacity[t.zone] += units
			developed[t.zone] += 1
			var access = road_near(p.root)
			var utilities = parcel_has(p,"power") and parcel_has(p,"water")
			var value = _parcel_avg(p,"landValue")
			var pollution = _parcel_avg(p,"pollution")
			var crime = _parcel_avg(p,"crime")
			var penalty = pollution*0.002 if t.zone == "res" else pollution*0.0007
			var quality = clampf(0.88+(value-50)*0.004-penalty-crime*0.0015,0.35,1.0)
			var occupancy = t.occupancy
			if update_occupancy:
				occupancy = _js_round(units*quality) if utilities and access and not t.abandoned and not t.fire else _js_round(t.occupancy*0.65)
			t.occupancy = occupancy
			for j in p.members:
				if j != p.root and update_occupancy: tiles[j].occupancy = 0
			occupied[t.zone] += occupancy
			continue
		if t.abandoned: abandoned += 1
		if not t.zone or not t.level: continue
		var units = CONFIG.buildingCapacity[t.zone][t.level]
		capacity[t.zone] += units
		developed[t.zone] += 1
		var viable = road_near(i) and fields.power[i] and fields.water[i] and not t.abandoned and not t.fire
		var quality = clampf(0.88+(fields.landValue[i]-50)*0.004-fields.pollution[i]*0.002-fields.crime[i]*0.0015,0.35,1.0)
		if update_occupancy: t.occupancy = _js_round(units*quality) if viable else _js_round(t.occupancy*0.65)
		occupied[t.zone] += t.occupancy
	var group = PackedInt32Array()
	group.resize(COUNT)
	group.fill(-1)
	var parts: Array = []
	for i in range(COUNT):
		if not tiles[i].road or group[i] >= 0: continue
		var id = parts.size()
		var queue: Array = [i]
		parts.append({"res":0,"jobs":0})
		group[i] = id
		var head = 0
		while head < queue.size():
			for j in neighbors(queue[head]):
				if tiles[j].road and group[j] < 0:
					group[j] = id
					queue.append(j)
			head += 1
	var counted: Dictionary = {}
	for i in range(COUNT):
		var t = tiles[i]
		var p = parcel_info(i) if t.parcel else {}
		if not p.is_empty():
			if counted.has(p.id) or i != p.root: continue
			counted[p.id] = true
		if not t.zone or not t.occupancy: continue
		var roads: Array = _parcel_roads(p) if not p.is_empty() else []
		if p.is_empty():
			for k in neighbors(i):
				if tiles[k].road: roads.append(k)
		if roads.is_empty(): continue
		var id = group[roads[0]]
		if id < 0: continue
		parts[id]["res" if t.zone == "res" else "jobs"] += t.occupancy
	var jobs = occupied.com+occupied.ind
	var population = occupied.res
	var employed = 0
	for p in parts: employed += mini(p.res,p.jobs)
	var unemployment = _js_round(100.0*(population-employed)/population) if population else 0
	stats.merge({"population":population,"resCapacity":capacity.res,"commercialCapacity":capacity.com,"industrialCapacity":capacity.ind,"jobs":jobs,"commercialJobs":occupied.com,"industrialJobs":occupied.ind,"employed":employed,"unemployment":unemployment,"developed":developed,"abandoned":abandoned,"capacity":capacity,"occupied":occupied},true)

func _growth_score(i: int) -> float:
	var t = tiles[i]
	var p = parcel_info(i) if t.parcel else {}
	var value = _parcel_avg(p,"landValue") if not p.is_empty() else fields.landValue[i]
	var pollution = _parcel_avg(p,"pollution") if not p.is_empty() else fields.pollution[i]
	var crime = _parcel_avg(p,"crime") if not p.is_empty() else fields.crime[i]
	var utility = (parcel_has(p,"power") and parcel_has(p,"water")) if not p.is_empty() else (fields.power[i] and fields.water[i])
	var service = (_parcel_avg(p,"school")+_parcel_avg(p,"hospital"))*0.5 if not p.is_empty() else (fields.school[i]+fields.hospital[i])*0.5
	var traffic = _parcel_avg(p,"trafficImpact") if not p.is_empty() else fields.trafficImpact[i]
	var pollution_factor = 0.30 if t.zone == "res" else 0.035 if t.zone == "ind" else 0.1
	var score = 18+demand[t.zone]*0.65+(value-48)*0.53+service*11-pollution*pollution_factor-crime*0.10-(taxes[t.zone]-8)*3-traffic*0.12
	if not utility: score -= 100
	if t.zone == "com" and stats.population < 35: score -= 28
	if t.zone == "ind" and stats.population < 10: score -= 10
	if t.zone == "res" and stats.jobs < 10: score -= 20
	if not p.is_empty():
		var type = t.zoneType if t.zoneType else t.resType
		if type == "office" and stats.population < 90: score -= 24
		if type == "logistics" and p.area < 2: score -= 55
		if type == "heavy" and p.area < 4: score -= 80
		if type == "apt" and p.area > 1: score += 5
		if type == "shop" and stats.population > 80: score += 5
	if t.fire: score -= 120
	return score

func _population_develop() -> void:
	var candidates: Array = []
	var seen: Dictionary = {}
	for i in range(COUNT):
		var t = tiles[i]
		var p = parcel_info(i) if t.parcel else {}
		var target = i
		if not p.is_empty():
			if seen.has(p.id): continue
			seen[p.id] = true
			target = p.root
			t = tiles[target]
		if not t.zone or not road_near(target): continue
		candidates.append({"i":target,"score":_growth_score(target)+_hash(target,tick,seed)*16-8})
	candidates.sort_custom(func(a,b): return a.score > b.score)
	var limit = clampi(ceili(candidates.size()*0.05),2,14)
	var grown = 0
	for candidate in candidates:
		var t = tiles[candidate.i]
		var p = parcel_info(candidate.i) if t.parcel else {}
		var type = t.zoneType if t.zoneType else t.resType
		var maximum = (4 if type == "apt" else 3) if t.zone == "res" else 4 if type in ["office","heavy"] else 3
		var level = int(t.level)
		var abandoned = int(t.abandoned)
		var damage = float(t.damage)
		var score = candidate.score
		if score > 17 and grown < limit:
			if abandoned and score > 20:
				abandoned = 0
				level = maxi(1,level)
				damage = 0
				grown += 1
			elif not abandoned and level < maximum and score > (22+level*19 if level else 17):
				level += 1
				grown += 1
		elif score < -38 and level:
			damage += 0.18
			if damage > 1:
				abandoned = 1
				damage = 0
		else: damage = maxf(0.0,damage-0.08)
		for j in p.get("members",[candidate.i]):
			tiles[j].level = level
			if not level: tiles[j].occupancy = 0
			tiles[j].abandoned = abandoned
		t.damage = damage

func _demand_update() -> void:
	var capacity = stats.get("capacity",{"res":0,"com":0,"ind":0})
	var occupied = stats.get("occupied",{"res":0,"com":0,"ind":0})
	var developed = 0
	for value in stats.get("developed",{}).values(): developed += value
	var utilities = float(stats.unpowered+stats.unwatered)/maxi(1,developed)
	var jobs = stats.get("jobs",0)
	var population = stats.get("population",0)
	var unemployment = stats.get("unemployment",0)
	var score = {
		"res":55+(jobs-population)*0.17-((unemployment-15)*0.9 if unemployment > 15 else 0)-(taxes.res-8)*6-(capacity.res-population)*0.042+(stats.avgLand-45)*0.16-utilities*52,
		"com":30+population*0.055-(capacity.com-occupied.com)*0.075-(taxes.com-8)*6-(float(occupied.com)/maxi(1,population)-0.3)*35+(stats.avgLand-45)*0.12-utilities*50,
		"ind":51+population*0.045-(capacity.ind-occupied.ind)*0.06-(taxes.ind-8)*6-(unemployment*0.3 if unemployment > 12 else 0)-utilities*44}
	if population < 20:
		score.res = maxf(score.res,38)
		score.ind = maxf(score.ind,44)
	for zone in ["res","com","ind"]: demand[zone] = _js_round(clampf(score[zone],-100,100))

func _economy_calculate() -> void:
	var count: Dictionary = {}
	for t in tiles:
		for kind in ["road","rail","line","pipe"]:
			if t[kind]: count[kind] = count.get(kind,0)+1
		if t.civic: count[t.civic] = count.get(t.civic,0)+1
	var tax = stats.population*taxes.res*0.14+stats.commercialJobs*taxes.com*0.32+stats.industrialJobs*taxes.ind*0.27
	var maintenance = 0.0
	for kind in CONFIG.maintenance:
		maintenance += count.get(kind,0)*CONFIG.maintenance[kind]*(funding.road/100.0 if kind == "road" else 1.0)
	var departments = 0.0
	for kind in SERVICES: departments += count.get(kind,0)*CONFIG.maintenance[kind]*(funding[kind]/100.0-1)
	stats.revenue = _js_round(tax)
	stats.expenses = _js_round(maintenance+departments+(CONFIG.bondPayment if bondMonths > 0 else 0))
	stats.net = stats.revenue-stats.expenses
	stats.maintenance = maintenance
	stats.count = count

func _economy_update() -> void:
	_economy_calculate()
	cash += stats.net
	stats.yearToDate = stats.get("yearToDate",0)+stats.net
	if bondMonths > 0:
		bondMonths -= 1
		if bondMonths == 0: _economy_calculate()

func _infrastructure_update() -> void:
	var fund = funding.road/100.0
	for i in range(COUNT):
		var t = tiles[i]
		if not t.road: continue
		var usage = (trafficHeat[i] if trafficHeat.size() == COUNT else 0.0)/100.0
		var delta = (fund-0.73)*0.016-usage*0.016
		t.condition = clampf(t.condition+delta,0.1,1.0)
		if t.condition < 0.23 and _hash(i,tick,seed) > 0.995: t.road = false

func _alerts() -> void:
	if tick%7 == 1:
		if stats.unpowered > 3: notify("%d developed buildings have no electricity." % stats.unpowered,"warn")
		if stats.unwatered > 3: notify("%d developed buildings lack water." % stats.unwatered,"warn")
		if stats.population > 100 and stats.unemployment > 28: notify("Unemployment is %d%%. Zone jobs and improve transport." % stats.unemployment,"warn")
		if stats.net < -400: notify("The monthly deficit is $%d. Review taxes and funding." % -stats.net,"warn")
		if cash < 0: notify("The treasury is bankrupt. Construction is blocked until revenue recovers.","warn")
		if stats.population > 300 and stats.avgCrime > 64: notify("Crime is damaging neighborhood demand.","warn")
		if stats.congestion > 65: notify("Road congestion is slowing commutes.","warn")
	for milestone in CONFIG.milestones:
		if stats.population >= milestone and not milestone in milestones:
			milestones.append(milestone)
			var grant = _js_round(milestone*0.9+350)
			cash += grant
			notify("%d residents! Civic grant $%d." % [milestone,grant],"good")
	if stats.population > 150 and stats.population < _lastPop*0.86 and tick%3 == 0:
		notify("Population is falling. Inspect utilities, jobs, taxes, and overlays.","warn")
	_lastPop = stats.population

func _ignite(i: int) -> void:
	var t = tiles[i]
	if t.level or t.civic:
		t.fire = maxf(t.fire,2)
		notify("Fire reported near %d, %d." % [i%N+1,int(i/N)+1],"warn")
		events.append({"type":"dispatch","i":i,"age":0})

func trigger_disaster(type: String, index: int = -1) -> bool:
	if not type in ["fire","quake","tornado","flood"]: return false
	if index < 0:
		var candidates: Array = []
		for i in range(COUNT):
			if tiles[i].level or tiles[i].civic or tiles[i].road: candidates.append(i)
		if candidates.is_empty():
			notify("Build part of a city before triggering an event.")
			return false
		index = candidates[_rng.randi_range(0,candidates.size()-1)]
	if index >= COUNT: return false
	_disaster_impact(type,index)
	return true

func _disaster_impact(type: String, i: int) -> void:
	if type == "fire":
		_ignite(i)
		return
	var radius = 5 if type == "quake" else 3 if type == "tornado" else 4
	var x = i%N
	var y = int(i/N)
	var hits = 0
	for yy in range(maxi(0,y-radius),mini(N-1,y+radius)+1):
		for xx in range(maxi(0,x-radius),mini(N-1,x+radius)+1):
			var j = yy*N+xx
			var t = tiles[j]
			if Vector2(x-xx,y-yy).length() > radius or _hash(j,tick,seed+13) < 0.55: continue
			if type == "flood" and t.terrain != "water":
				var near_water = false
				for k in neighbors(j):
					if tiles[k].terrain == "water": near_water = true
				if not near_water: continue
			if t.level:
				t.level = maxi(0,int(t.level)-1)
				t.occupancy = 0
				t.abandoned = 1
				hits += 1
			if t.road and _hash(j,tick,5) > 0.65:
				t.road = false
				hits += 1
			if t.line and _hash(j,tick,6) > 0.7: t.line = false
			if t.pipe and _hash(j,tick,7) > 0.8: t.pipe = false
			if t.civic and _hash(j,tick,9) > 0.75:
				t.civic = null
				hits += 1
	notify("%s damaged %d structures." % [type.capitalize(),hits],"warn")
	events.append({"type":type,"i":i,"age":0})

func _disaster_update() -> void:
	for i in range(COUNT):
		var t = tiles[i]
		if not t.fire: continue
		var response = fields.fire[i]*(funding.fire/100.0)
		if response > 0.28:
			t.fire = maxf(0.0,t.fire-1.4*response)
			if t.fire < 0.4:
				t.fire = 0
				notify("Fire crews contained a blaze.","good")
		else:
			t.fire += 0.43
			if t.fire > 5:
				t.level = maxi(0,int(t.level)-1)
				if t.civic: t.civic = null
				t.abandoned = 3 if t.level else 0
				t.fire = 0
				notify("An uncontrolled fire destroyed a building.","warn")
			elif t.fire > 3 and _hash(i,tick,seed) > 0.72:
				for j in neighbors(i):
					if tiles[j].level and not tiles[j].fire:
						_ignite(j)
						break
	if tick%4 == 0:
		var buildings: Array = []
		for i in range(COUNT):
			if tiles[i].level and not tiles[i].fire: buildings.append(i)
		if not buildings.is_empty():
			var i = buildings[mini(buildings.size()-1,int(_hash(tick,4,seed)*buildings.size()))]
			var t = tiles[i]
			var risk = (0.022 if t.zone == "ind" else 0.009)*t.level*(1-fields.fire[i]*0.85)*(1-funding.fire/450.0)*(0.35 if stats.population < 100 else 1.0)
			if _hash(tick,3,seed+9) < risk: _ignite(i)
	if randomDisasters and tick%18 == 0 and _hash(tick,11,seed) > 0.88:
		trigger_disaster(["tornado","quake","flood"][int(tick/18)%3])
	var active_events: Array = []
	for event in events:
		event.age = event.get("age",0)+1
		if event.age < 9: active_events.append(event)
	events = active_events

func _road_entrances(i: int) -> Array:
	var t = tiles[i]
	if t.zone == "res" and t.parcel: return _parcel_roads(parcel_info(i))
	var out: Array = []
	for j in neighbors(i):
		if tiles[j].road: out.append(j)
	return out

func route(a: int, b: int, allowed: String = "road") -> Array:
	if a < 0 or b < 0 or a >= COUNT or b >= COUNT or not allowed in ["road","rail"]: return []
	if a == b: return [a]
	var queue: Array = [a]
	var previous = PackedInt32Array()
	previous.resize(COUNT)
	previous.fill(-1)
	previous[a] = a
	var head = 0
	while head < queue.size() and head < 900:
		var k = queue[head]
		if k == b: break
		for j in neighbors(k):
			if previous[j] != -1 or not tiles[j][allowed]: continue
			previous[j] = k
			queue.append(j)
		head += 1
	if previous[b] == -1: return []
	var out: Array = [b]
	var at = b
	while at != a and out.size() < COUNT:
		at = previous[at]
		out.append(at)
	out.reverse()
	return out

func _traffic_prepare() -> void:
	var roads: Array = []
	var homes: Array = []
	var work: Array = []
	var rails: Array = []
	var stations: Array = []
	for i in range(COUNT):
		var t = tiles[i]
		if t.road: roads.append(i)
		if t.rail: rails.append(i)
		if t.civic == "station" and t.rail: stations.append(i)
		if t.level and t.occupancy > 0:
			if t.zone == "res": homes.append(i)
			else: work.append(i)
	var rail_routes: Array = []
	for a in range(mini(stations.size(),12)):
		for b in range(a+1,mini(stations.size(),12)):
			var path = route(stations[a],stations[b],"rail")
			if path.size() >= 8: rail_routes.append(path)
	network = {"roads":roads,"homes":homes,"work":work,"rails":rails,"stations":stations,"railRoutes":rail_routes}
	var valid_cars: Array = []
	for agent in cars:
		var valid = true
		for i in agent.path:
			if not tiles[i].road: valid = false
		if valid: valid_cars.append(agent)
	cars = valid_cars
	var valid_trains: Array = []
	for agent in trains:
		var valid = true
		for i in agent.path:
			if not tiles[i].rail: valid = false
		if valid: valid_trains.append(agent)
	trains = valid_trains
	var heat = PackedFloat32Array()
	heat.resize(COUNT)
	for agent in cars:
		var unique: Dictionary = {}
		for j in agent.path: unique[j] = true
		for j in unique: heat[j] += 2
	if not rail_routes.is_empty():
		for i in roads:
			for j in stations:
				if _man(i,j) <= 5:
					heat[i] *= 0.65
					break
	trafficHeat = heat
	var total = 0.0
	for i in roads: total += heat[i]
	stats.congestion = _js_round(clampf(total/roads.size()*8 if not roads.is_empty() else 0.0,0.0,100.0))
	stats.railRidership = mini(stats.get("employed",0),stations.size()*45) if not rail_routes.is_empty() else 0

func _traffic_spawn() -> void:
	if network.is_empty(): return
	var target = mini(CONFIG.maxCars,floori(minf(stats.employed/25.0,network.roads.size()/3.0)))
	if cars.size() < target and not network.homes.is_empty() and not network.work.is_empty():
		for trial in range(6):
			var a = network.homes[_rng.randi_range(0,network.homes.size()-1)]
			var b = network.work[_rng.randi_range(0,network.work.size()-1)]
			var starts = _road_entrances(a)
			var ends = _road_entrances(b)
			if starts.is_empty() or ends.is_empty(): continue
			var path = route(starts[0],ends[0])
			if path.size() > 2:
				var back = path.slice(1,path.size()-1)
				back.reverse()
				path.append_array(back)
				cars.append({"path":path,"p":0.0,"speed":0.55+_rng.randf()*0.35})
				break
	var train_target = mini(mini(CONFIG.maxTrains,network.railRoutes.size()),floori(network.rails.size()/20.0))
	if trains.size() < train_target:
		var path = network.railRoutes[trains.size()%network.railRoutes.size()].duplicate()
		var back = path.slice(1,path.size()-1)
		back.reverse()
		path.append_array(back)
		trains.append({"path":path,"p":0.0,"speed":0.46})

func advance_agents(dt: float) -> void:
	if not is_finite(dt) or dt <= 0: return
	_spawnElapsed += dt
	if _spawnElapsed > 0.55:
		_traffic_spawn()
		_spawnElapsed = 0.0
	for kind in ["car","train"]:
		var agents = cars if kind == "car" else trains
		for agent in agents:
			if agent.path.is_empty(): continue
			var at = agent.path[clampi(int(agent.p),0,agent.path.size()-1)]
			var penalty = (1-(trafficHeat[at] if trafficHeat.size() == COUNT else 0)*0.01)*(0.45+tiles[at].condition*0.55) if kind == "car" else 1.0
			agent.p += dt*agent.speed*(1.6 if kind == "car" else 2.4)*maxf(0.2,penalty)
			if agent.p >= agent.path.size()-1: agent.p = 0.0
