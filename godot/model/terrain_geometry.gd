extends RefCounted
## Shared deterministic map-space surface contract. No world/UI dependencies.
const N = 52
const MIN_HEIGHT = -5
const MAX_HEIGHT = 40
const SHAPES = ["flat", "slope", "cliff", "rounded"]
const DIRECTIONS = ["auto", "N", "E", "S", "W"]

static func water_height(tile: Dictionary) -> float:
	# Reference elevation is the channel bed; the visible water stays level.
	# Preserve authored positive natural-water levels from existing imports.
	return maxf(0,float(tile.get("elev",0)))

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
	if tile.get("terrain","grass")=="water":
		var surface: float = water_height(tile)
		return PackedFloat64Array([surface,surface,surface,surface])
	if tile.has("gradeCorners"):return PackedFloat64Array(tile.gradeCorners)
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
	if tile.get("terrain","grass")=="water": return water_height(tile)
	if tile.get("terrainShape","flat") == "rounded" and tile.terrain != "water" and not tile.channel:
		return rounded_sample(tiles,index,u,v,overrides).x
	if tile.get("terrainShape","flat") != "slope": return float(tile.elev)
	var h = corners(tiles,index,overrides)
	if tile.has("gradeCorners"):return triangle_height(h,u,v)
	return lerpf(lerpf(h[0],h[1],u),lerpf(h[3],h[2],u),v)

static func triangle_height(h: PackedFloat64Array,u: float,v: float) -> float:
	return h[0]+(h[1]-h[0])*u+(h[2]-h[1])*v if u>=v else h[0]+(h[2]-h[3])*u+(h[3]-h[0])*v

static func valid_grade(tile: Dictionary) -> bool:
	if not tile.has("gradeCorners"):return true
	if tile.get("terrainShape")!="slope" or tile.get("shapeStrength")!=1 or tile.get("slopeDir")=="auto" or tile.get("terrain")=="water" or tile.get("channel",false):return false
	var heights=tile.gradeCorners
	if not heights is Array or heights.size()!=4:return false
	var lo: float=INF
	var hi: float=-INF
	for height in heights:
		if not (height is int or height is float) or not is_finite(float(height)) or height<MIN_HEIGHT or height>MAX_HEIGHT:return false
		lo=minf(lo,height);hi=maxf(hi,height)
	return hi-lo<=1.00001 and tile.elev==floori((lo+hi)*.5+.5)

static func _basis(t: float) -> PackedFloat64Array:
	var t2: float = t*t
	var t3: float = t2*t
	return PackedFloat64Array([pow(1-t,3)/6.,(3*t3-6*t2+4)/6.,(-3*t3+3*t2+3*t+1)/6.,t3/6.])

static func _basis_derivative(t: float) -> PackedFloat64Array:
	return PackedFloat64Array([-.5*(1-t)*(1-t),1.5*t*t-2*t,-1.5*t*t+t+.5,.5*t*t])

static func retain_foundation(before: Dictionary, after: Dictionary, operation: String) -> void:
	if after.get("terrainShape","flat")!="rounded": after.erase("roundedBase")
	elif before.has("roundedBase"): after.roundedBase=mini(before.roundedBase,after.elev)
	elif operation in ["raise","hill","mountain"] and before.get("terrainShape","flat") in ["flat","cliff"]:
		after.roundedBase=before.elev

static func rounded_sample(tiles: Array,index: int,u: float,v: float,overrides: Dictionary = {}) -> Vector3:
	var tile = tile_at(tiles,index,overrides)
	var based: bool = tile.has("roundedBase")
	var result = field_sample(tiles,float(index%N)+u,float(int(index/N))+v,overrides,tile.get("roundedBase"))
	if based:
		var base: float = tile.roundedBase
		var foot: Vector3 = _foot_weight(tiles,float(index%N)+u,float(int(index/N))+v,base,overrides)
		result=Vector3(base+result.x*foot.x,result.y*foot.x+result.x*foot.y,result.z*foot.x+result.x*foot.z)
	if result.x<=MIN_HEIGHT or result.x>=MAX_HEIGHT:
		result.x=clampf(result.x,MIN_HEIGHT,MAX_HEIGHT);result.y=0;result.z=0
	return result

# Compact C1 transition to level dry caps at the same foundation height.
# Evaluate in world coordinates so adjacent rounded caps share every sample.
# Different-height land, authored cliffs and water keep their retaining walls.
static func _foot_weight(tiles: Array,x: float,y: float,base: float,overrides: Dictionary) -> Vector3:
	var result := Vector3(1,0,0)
	for yy in range(maxi(0,floori(y)-1),mini(N,floori(y)+2)):
		for xx in range(maxi(0,floori(x)-1),mini(N,floori(x)+2)):
			var tile = tile_at(tiles,yy*N+xx,overrides)
			if tile.get("terrainShape","flat")!="flat" or tile.terrain=="water" or tile.channel or float(tile.elev)!=base: continue
			var delta := Vector2(x-clampf(x,xx,xx+1),y-clampf(y,yy,yy+1))
			var distance: float = delta.length()
			if distance>=1.: continue
			if distance<=0.: return Vector3.ZERO
			var weight: float = distance*distance*(3.-2.*distance)
			var derivative: Vector2 = delta*(6.*(1.-distance))
			result=Vector3(result.x*weight,result.y*weight+result.x*derivative.x,result.z*weight+result.x*derivative.y)
	return result

static func field_height(tiles: Array,x: float,y: float,overrides: Dictionary = {}) -> float:
	return field_sample(tiles,x,y,overrides).x

# Height and exact map-space derivatives. Based caps filter added relief only;
# their terrace elevation is kept separately, so raising cannot erode its base.
static func field_sample(tiles: Array,x: float,y: float,overrides: Dictionary = {},base = null) -> Vector3:
	var qx: float = x-.5
	var qy: float = y-.5
	var ix: int = floori(qx)
	var iy: int = floori(qy)
	var wx = _basis(qx-ix)
	var wy = _basis(qy-iy)
	var gx = _basis_derivative(qx-ix)
	var gy = _basis_derivative(qy-iy)
	var total := Vector3.ZERO
	var weighted := Vector3.ZERO
	for dy in range(4):
		var yy: int = iy+dy-1
		if yy<0 or yy>=N: continue
		for dx in range(4):
			var xx: int = ix+dx-1
			if xx<0 or xx>=N: continue
			var tile = tile_at(tiles,yy*N+xx,overrides)
			if tile.terrain=="water" or tile.channel or tile.get("terrainShape","flat")=="cliff": continue
			var weights := Vector3(wx[dx]*wy[dy],gx[dx]*wy[dy],wx[dx]*gy[dy])
			var value: float = maxf(0.,float(tile.elev)-float(base)) if base!=null else float(tile.elev)
			total+=weights;weighted+=weights*value
	if total.x<=0: return Vector3.ZERO
	var height: float = weighted.x/total.x
	return Vector3(height,(weighted.y-height*total.y)/total.x,(weighted.z-height*total.z)/total.x)

static func same_surface(tiles: Array, index: int, overrides: Dictionary) -> bool:
	for v in [0.,.25,.5,.75,1.]:
		for u in [0.,.25,.5,.75,1.]:
			if not is_equal_approx(sample(tiles,index,u,v),sample(tiles,index,u,v,overrides)): return false
	return true
