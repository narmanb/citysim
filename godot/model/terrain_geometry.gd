extends RefCounted
## Shared deterministic map-space surface contract. No world/UI dependencies.
const N = 52
const MIN_HEIGHT = -5
const MAX_HEIGHT = 12
const SHAPES = ["flat", "slope", "cliff", "rounded"]
const DIRECTIONS = ["auto", "N", "E", "S", "W"]

static func tile_at(tiles: Array, index: int, overrides: Dictionary = {}) -> Dictionary:
	return overrides.get(index, tiles[index])

static func gradient(tiles: Array, index: int, overrides: Dictionary = {}) -> Vector2:
	var e: float = tile_at(tiles,index,overrides).elev
	var x: int = index % N
	var y: int = index / N
	var west: float = tile_at(tiles,index-1,overrides).elev if x > 0 else e
	var east: float = tile_at(tiles,index+1,overrides).elev if x < N-1 else e
	var north: float = tile_at(tiles,index-N,overrides).elev if y > 0 else e
	var south: float = tile_at(tiles,index+N,overrides).elev if y < N-1 else e
	return Vector2(east-west,south-north)

static func direction(tiles: Array, index: int, overrides: Dictionary = {}) -> String:
	var authored: String = tile_at(tiles,index,overrides).get("slopeDir","auto")
	if authored != "auto": return authored
	var g = gradient(tiles,index,overrides)
	if g == Vector2.ZERO: return "N"
	if absf(g.x) >= absf(g.y): return "E" if g.x > 0 else "W"
	return "S" if g.y > 0 else "N"

static func corners(tiles: Array, index: int, overrides: Dictionary = {}) -> PackedFloat64Array:
	var tile = tile_at(tiles,index,overrides)
	var elevation: float = tile.elev
	if tile.get("terrainShape","flat") == "rounded" and tile.terrain != "water" and not tile.channel:
		return PackedFloat64Array([sample(tiles,index,0,0,overrides),sample(tiles,index,1,0,overrides),sample(tiles,index,1,1,overrides),sample(tiles,index,0,1,overrides)])
	if tile.get("terrainShape","flat") != "slope" or tile.terrain == "water" or tile.channel:
		return PackedFloat64Array([elevation,elevation,elevation,elevation])
	var half: float = float(tile.get("shapeStrength",1)) * .5
	var high: float = minf(MAX_HEIGHT,elevation+half)
	var low: float = maxf(MIN_HEIGHT,elevation-half)
	match direction(tiles,index,overrides):
		"N": return PackedFloat64Array([high,high,low,low])
		"E": return PackedFloat64Array([low,high,high,low])
		"S": return PackedFloat64Array([low,low,high,high])
	return PackedFloat64Array([high,low,low,high])

static func sample(tiles: Array, index: int, u: float = .5, v: float = .5, overrides: Dictionary = {}) -> float:
	var tile = tile_at(tiles,index,overrides)
	if tile.get("terrainShape","flat") == "rounded" and tile.terrain != "water" and not tile.channel:
		return field_height(tiles,float(index%N)+u,float(index / N as int)+v,overrides)
	if tile.get("terrainShape","flat") != "slope": return float(tile.elev)
	var h = corners(tiles,index,overrides)
	return lerpf(lerpf(h[0],h[1],u),lerpf(h[3],h[2],u),v)

static func _basis(t: float) -> PackedFloat64Array:
	var t2: float = t*t
	var t3: float = t2*t
	return PackedFloat64Array([pow(1-t,3)/6.,(3*t3-6*t2+4)/6.,(-3*t3+3*t2+3*t+1)/6.,t3/6.])

static func field_height(tiles: Array, x: float, y: float, overrides: Dictionary = {}) -> float:
	var qx: float = x-.5
	var qy: float = y-.5
	var ix: int = floori(qx)
	var iy: int = floori(qy)
	var wx = _basis(qx-ix)
	var wy = _basis(qy-iy)
	var total: float = 0
	var weighted: float = 0
	for dy in range(4):
		var yy: int = iy+dy-1
		if yy < 0 or yy >= N: continue
		for dx in range(4):
			var xx: int = ix+dx-1
			if xx < 0 or xx >= N: continue
			var tile = tile_at(tiles,yy*N+xx,overrides)
			# No construction/utility/tree/biome flags: placement cannot deform land.
			if tile.terrain == "water" or tile.channel or tile.get("terrainShape","flat") == "cliff": continue
			var weight: float = wx[dx]*wy[dy]
			total += weight
			weighted += float(tile.elev)*weight
	return clampf(weighted/total,MIN_HEIGHT,MAX_HEIGHT) if total > 0 else 0.

static func same_surface(tiles: Array, index: int, overrides: Dictionary) -> bool:
	for v in [0.,.5,1.]:
		for u in [0.,.5,1.]:
			if not is_equal_approx(sample(tiles,index,u,v),sample(tiles,index,u,v,overrides)): return false
	return true
