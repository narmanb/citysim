extends RefCounted
## Shared construction eligibility, level pads and shallow road deck geometry.
const G = preload("res://model/terrain_geometry.gd")
const N = G.N
const EPS = 0.00001

static func gentle(tile: Dictionary) -> bool:
	return tile.get("terrain","grass")!="water" and not tile.get("channel",false) and tile.get("terrainShape","flat")=="slope" and tile.get("shapeStrength",1)==1

static func build_height(tile: Dictionary) -> float:
	return float(tile.get("foundationHeight",tile.get("elev",0)))

static func foundation_height(tiles: Array, index: int) -> float:
	var h = G.corners(tiles,index)
	return maxf(maxf(h[0],h[1]),maxf(h[2],h[3]))

static func _edge(a: int, b: int) -> Array:
	if b==a-N: return [[0,1],[3,2]]
	if b==a+1 and a%N<N-1: return [[1,2],[0,3]]
	if b==a+N: return [[3,2],[0,1]]
	if b==a-1 and a%N>0: return [[0,3],[1,2]]
	return []

static func road_link(tiles: Array, a: int, b: int) -> bool:
	var edge = _edge(a,b)
	if edge.is_empty(): return false
	# Preserve the old flat-only road graph, including existing stepped streets.
	if not gentle(tiles[a]) and not gentle(tiles[b]): return true
	var ah = G.corners(tiles,a)
	var bh = G.corners(tiles,b)
	for k in range(2):
		if absf(ah[edge[0][k]]-bh[edge[1][k]])>.5+EPS: return false
	return true

static func vertex_roads(tiles: Array, x: int, y: int, proposed: int = -1) -> Array:
	var out: Array = []
	for yy in range(maxi(0,y-1),mini(N,y+1)):
		for xx in range(maxi(0,x-1),mini(N,x+1)):
			var i: int = yy*N+xx
			if tiles[i].get("road",false) or i==proposed: out.append([i,G.sample(tiles,i,x-xx,y-yy)])
	return out

static func can_road(tiles: Array, index: int) -> bool:
	var tile: Dictionary = tiles[index]
	if tile.get("terrainShape","flat") in ["slope","rounded"] and not gentle(tile): return false
	var x: int = index%N
	var y: int = index/N
	for n in [index-N if y>0 else -1,index+1 if x<N-1 else -1,index+N if y<N-1 else -1,index-1 if x>0 else -1]:
		if n>=0 and tiles[n].get("road",false) and not road_link(tiles,index,n): return false
	for uv in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
		var roads = vertex_roads(tiles,x+uv.x,y+uv.y,index)
		var graded := false
		var lo: float = INF
		var hi: float = -INF
		for entry in roads:
			graded = graded or gentle(tiles[entry[0]])
			lo=minf(lo,entry[1]);hi=maxf(hi,entry[1])
		if graded and hi-lo>.5+EPS: return false
		if graded:
			for entry in roads:
				# Bridges retain a level deck and guards. A flat bank landing
				# separates them from a ramp's lifted road vertices.
				if tiles[entry[0]].get("terrain","grass")=="water" and hi>entry[1]+EPS: return false
	return true

static func road_corners(tiles: Array, index: int) -> PackedFloat64Array:
	var h = G.corners(tiles,index)
	if not graded_nearby(tiles,index): return h
	var x: int = index%N
	var y: int = index/N
	var offsets = [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
	for k in range(4):
		var roads = vertex_roads(tiles,x+offsets[k].x,y+offsets[k].y)
		var graded := gentle(tiles[index])
		var hi: float = h[k]
		for entry in roads:
			graded = graded or gentle(tiles[entry[0]])
			hi=maxf(hi,entry[1])
		if graded: h[k]=hi
	return h

static func road_sample(tiles: Array, index: int, u: float = .5, v: float = .5) -> float:
	var h = road_corners(tiles,index)
	return sample_corners(h,u,v)

static func sample_corners(h: PackedFloat64Array,u: float,v: float) -> float:
	# Match the exact NW/SE diagonal used by the retained road triangles.
	return h[0]+(h[1]-h[0])*u+(h[2]-h[1])*v if u>=v else h[0]+(h[2]-h[3])*u+(h[3]-h[0])*v

static func graded_nearby(tiles: Array, index: int) -> bool:
	if gentle(tiles[index]): return true
	var x: int = index%N
	var y: int = index/N
	for yy in range(maxi(0,y-1),mini(N,y+2)):
		for xx in range(maxi(0,x-1),mini(N,x+2)):
			if tiles[yy*N+xx].get("road",false) and gentle(tiles[yy*N+xx]): return true
	return false

static func freeze_direction(tiles: Array, index: int) -> void:
	if gentle(tiles[index]) and tiles[index].get("slopeDir","auto")=="auto": tiles[index].slopeDir=G.direction(tiles,index)
