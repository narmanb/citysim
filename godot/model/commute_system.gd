extends RefCounted
## Aggregate deterministic trips. One search per residential property, never per person.
const Civil = preload("res://model/civil_engineering.gd")
const ROAD_CAPACITY = 120.0

static func road_graph(world) -> Dictionary:
	var roads: Array = []
	var edges: Dictionary = {}
	for i in world.tiles.size():
		if not world.tiles[i].road: continue
		roads.append(i)
		var adjacent: Array = []
		for j in world.neighbors(i):
			if world.tiles[j].road and Civil.road_link(world.tiles,i,j): adjacent.append(j)
		edges[i] = adjacent
	return {"roads":roads,"edges":edges}

static func _signature(world) -> Array:
	# Cache the exact topology and occupied-property inputs. Flat-only edges are
	# unconditionally legal in Civil, so terrain sampling is needed only beside
	# gentle roads. Sampling those actual joins includes authored grade corners,
	# Auto direction, rounded bases and every neighbor used by Civil's geometry.
	var roads = PackedInt32Array()
	var gentle: Array = []
	var properties: Array = []
	for i in world.tiles.size():
		var t = world.tiles[i]
		if t.road:
			roads.append(i)
			if Civil.gentle(t): gentle.append(i)
		if t.zone:
			properties.append(i)
			properties.append(t.zone)
			properties.append(t.level)
			properties.append(t.occupancy)
			properties.append(t.parcel)
	var blocked = PackedInt32Array()
	for i in gentle:
		for j in world.neighbors(i):
			if world.tiles[j].road and not Civil.road_link(world.tiles,i,j):
				blocked.append(mini(i,j)*world.tiles.size()+maxi(i,j))
	blocked.sort()
	return [roads,blocked,properties]

static func calculate(world) -> Dictionary:
	var signature = _signature(world)
	if world._commute_result.get("_signature") == signature: return world._commute_result
	var graph = road_graph(world)
	var properties: Array = []
	var parcels: Dictionary = {}
	for i in world.tiles.size():
		var t = world.tiles[i]
		if not t.zone: continue
		if t.parcel:
			if not parcels.has(t.parcel):
				parcels[t.parcel] = {"root":i,"members":[]}
				properties.append(parcels[t.parcel])
			parcels[t.parcel].members.append(i)
		else: properties.append({"root":i,"members":[i]})
	var origins: Array = []
	var jobs: Array = []
	var job_at: Dictionary = {}
	var population = 0
	for p in properties:
		var t = world.tiles[p.root]
		if not t.level or t.occupancy <= 0: continue
		var entrances: Dictionary = {}
		for member in p.members:
			for j in world.neighbors(member):
				if graph.edges.has(j): entrances[j] = true
		p.entrances = entrances.keys()
		p.entrances.sort()
		p.remaining = int(t.occupancy)
		if t.zone == "res":
			population += p.remaining
			origins.append(p)
		else:
			var id = jobs.size()
			jobs.append(p)
			for entrance in p.entrances:
				if not job_at.has(entrance): job_at[entrance] = []
				job_at[entrance].append(id)
	var flow = PackedInt32Array()
	flow.resize(world.tiles.size())
	var routes: Array = []
	var employed = 0
	var distance_sum = 0
	var searches = 0
	for origin in origins:
		if origin.entrances.is_empty(): continue
		searches += 1
		var previous = PackedInt32Array()
		previous.resize(world.tiles.size())
		previous.fill(-1)
		var queue: Array = origin.entrances.duplicate()
		for entrance in queue: previous[entrance] = entrance
		var head = 0
		while head < queue.size() and origin.remaining > 0:
			var at = queue[head]
			for id in job_at.get(at,[]):
				var job = jobs[id]
				if job.remaining <= 0: continue
				var assigned = mini(origin.remaining,job.remaining)
				var path: Array = [at]
				var cursor = at
				while previous[cursor] != cursor:
					cursor = previous[cursor]
					path.append(cursor)
				path.reverse()
				routes.append({"origin":origin.root,"destination":job.root,"path":path,"flow":assigned})
				for road in path: flow[road] += assigned
				employed += assigned
				distance_sum += assigned*(path.size()-1)
				origin.remaining -= assigned
				job.remaining -= assigned
				if origin.remaining <= 0: break
			for next in graph.edges[at]:
				if previous[next] != -1: continue
				previous[next] = at
				queue.append(next)
			head += 1
	var heat = PackedFloat32Array()
	heat.resize(world.tiles.size())
	var total_heat = 0.0
	for road in graph.roads:
		heat[road] = minf(100.0,flow[road]*100.0/ROAD_CAPACITY)
		total_heat += heat[road]
	return {"employed":employed,"commuters":employed,"commuteUnserved":population-employed,"avgCommute":float(distance_sum)/employed if employed else 0.0,"heat":heat,"flow":flow,"routes":routes,"congestion":roundi(total_heat/graph.roads.size()) if not graph.roads.is_empty() else 0,"searches":searches,"_signature":signature,"_edges":graph.edges}
