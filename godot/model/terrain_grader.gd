extends RefCounted
## Pure, bounded corner wave for a level platform with continuous Gentle edges.
const G=preload("res://model/terrain_geometry.gd")
const N=G.N
const V=N+1
const EPS=0.00001
const OFFSETS=[Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]

static func _reason(tile: Dictionary,protection: Callable) -> String:
	var reason: String=protection.call(tile)
	if not reason.is_empty():return reason
	if tile.channel:return "Water channel"
	if tile.terrainShape=="cliff":return "Protected cliff"
	if tile.terrainShape=="rounded":return "Rounded ground: Flatten first"
	return ""

static func _corners(tiles: Array,index: int,cache: Dictionary) -> PackedFloat64Array:
	if not cache.has(index):cache[index]=G.corners(tiles,index)
	return cache[index]

static func _incident(vertex: int) -> Array:
	var x: int=vertex%V
	var y: int=vertex/V
	var out: Array=[]
	for yy in range(maxi(0,y-1),mini(N,y+1)):
		for xx in range(maxi(0,x-1),mini(N,x+1)):
			var u: int=x-xx
			var v: int=y-yy
			out.append([yy*N+xx,1 if u else 0] if v==0 else [yy*N+xx,2 if u else 3])
	return out

static func _fail(out: Dictionary,index: int,reason: String) -> Dictionary:
	out.blocked[index]=reason
	out.error="Smooth edges needs more clear, compatible ground: "+reason+". Use a smaller brush or Sharp edges."
	out.before.clear();out.after.clear();out.targets.clear();out.cost=0.;out.affordable=false
	return out

static func _direction(h: PackedFloat64Array) -> String:
	var x: float=h[1]+h[2]-h[0]-h[3]
	var y: float=h[2]+h[3]-h[0]-h[1]
	if absf(x)>=absf(y):return "E" if x>=0 else "W"
	return "S" if y>=0 else "N"

static func plan(world,indices: Array,operation: String,step: int,protection: Callable) -> Dictionary:
	var out: Dictionary={"before":{},"after":{},"targets":{},"blocked":{},"cost":0.,"affordable":true,"error":"","core_count":0,"level_top":0,"vertices_visited":0}
	var core: Dictionary={}
	var old: Dictionary={}
	var rising: bool=operation=="raise"
	var extreme: float=-INF if rising else INF
	for i in indices:
		if not i is int or i<0 or i>=N*N or core.has(i):continue
		var reason: String=_reason(world.tiles[i],protection)
		if not reason.is_empty():out.blocked[i]=reason;continue
		core[i]=true
		for height in _corners(world.tiles,i,old):extreme=maxf(extreme,height) if rising else minf(extreme,height)
	if core.is_empty():return out
	var level: int=clampi(ceili(extreme)+step if rising else floori(extreme)-step,G.MIN_HEIGHT,G.MAX_HEIGHT)
	out.level_top=level;out.core_count=core.size()
	var core_indices: Array=core.keys();core_indices.sort()
	var changed:=false
	for i in core_indices:
		if world.tiles[i].terrainShape!="flat" or world.tiles[i].elev!=level:changed=true;break
	if not changed:return out
	var distances:=PackedInt32Array();distances.resize(V*V);distances.fill(-1)
	var queue: Array[int]=[]
	var seeds: Dictionary={}
	for i in core_indices:
		for offset in OFFSETS:
			var vertex: int=(int(i/N)+offset.y)*V+i%N+offset.x
			if distances[vertex]>=0:continue
			distances[vertex]=0;seeds[vertex]=true;queue.append(vertex)
	var candidates: Dictionary={}
	var head:=0
	while head<queue.size():
		var vertex: int=queue[head];head+=1
		var value: float=level+distances[vertex]*(-1 if rising else 1)
		var incident: Array=_incident(vertex)
		var active: bool=seeds.has(vertex)
		for entry in incident:
			var height: float=_corners(world.tiles,entry[0],old)[entry[1]]
			if value>height+EPS if rising else value<height-EPS:active=true
		if not active:continue
		for entry in incident:candidates[entry[0]]=true
		if value<G.MIN_HEIGHT or value>G.MAX_HEIGHT:continue
		var x: int=vertex%V
		var y: int=vertex/V
		for yy in range(maxi(0,y-1),mini(V,y+2)):
			for xx in range(maxi(0,x-1),mini(V,x+2)):
				var neighbor: int=yy*V+xx
				if distances[neighbor]>=0:continue
				distances[neighbor]=distances[vertex]+1;queue.append(neighbor)
	out.vertices_visited=queue.size()
	var ordered: Array=candidates.keys();ordered.sort()
	for i in ordered:
		var before: Dictionary=world.tiles[i]
		var heights: PackedFloat64Array=_corners(world.tiles,i,old).duplicate()
		for k in range(4):
			var vertex: int=(int(i/N)+OFFSETS[k].y)*V+i%N+OFFSETS[k].x
			if core.has(i):heights[k]=level
			elif distances[vertex]>=0:
				var value: float=clampf(level+distances[vertex]*(-1 if rising else 1),G.MIN_HEIGHT,G.MAX_HEIGHT)
				heights[k]=maxf(heights[k],value) if rising else minf(heights[k],value)
		var shape_change: bool=core.has(i) and before.terrainShape!="flat"
		if heights==old[i] and not shape_change:continue
		var reason: String=_reason(before,protection)
		if not reason.is_empty():return _fail(out,i,reason)
		var lo: float=minf(minf(heights[0],heights[1]),minf(heights[2],heights[3]))
		var hi: float=maxf(maxf(heights[0],heights[1]),maxf(heights[2],heights[3]))
		if hi-lo>1.+EPS:return _fail(out,i,"Steep transition")
		var after: Dictionary=before.duplicate(true)
		after.erase("roundedBase");after.erase("gradeCorners")
		after.shapeStrength=1
		if hi-lo<EPS and absf(lo-roundf(lo))<EPS:
			after.elev=roundi(lo);after.terrainShape="flat";after.slopeDir="auto"
		else:
			after.elev=floori((lo+hi)*.5+.5);after.terrainShape="slope";after.slopeDir=_direction(heights)
			after.gradeCorners=Array(heights)
		out.before[i]=before.duplicate(true);out.after[i]=after;out.targets[i]=after.elev
	# Corner overrides are frozen; don't let outside Auto/Rounded dependencies move.
	var dependent: Dictionary={}
	for i in out.after:
		for yy in range(maxi(0,int(i/N)-2),mini(N,int(i/N)+3)):
			for xx in range(maxi(0,i%N-2),mini(N,i%N+3)):
				var j: int=yy*N+xx
				if not out.after.has(j) and (world.tiles[j].terrainShape=="rounded" or (world.tiles[j].terrainShape=="slope" and world.tiles[j].slopeDir=="auto")):dependent[j]=true
	for j in dependent:
		for uv in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN,Vector2(.5,.5)]:
			if absf(G.sample(world.tiles,j,uv.x,uv.y)-G.sample(world.tiles,j,uv.x,uv.y,out.after))>EPS:return _fail(out,j,"Existing shaped ground")
	# Every newly changed edge must meet its neighbor, or retain an untouched old edge.
	for i in out.after:
		var x: int=i%N
		var y: int=i/N
		for entry in [[i-N,0],[i+1,1],[i+N,2],[i-1,3]]:
			var j: int=entry[0]
			var side: int=entry[1]
			if (side==0 and y==0) or (side==1 and x==N-1) or (side==2 and y==N-1) or (side==3 and x==0):continue
			for along in [0.,.25,.5,.75,1.]:
				var a:=Vector2(along,0) if side==0 else Vector2(1,along) if side==1 else Vector2(along,1) if side==2 else Vector2(0,along)
				var b:=Vector2(along,1) if side==0 else Vector2(0,along) if side==1 else Vector2(along,0) if side==2 else Vector2(1,along)
				var delta: float=G.sample(world.tiles,i,a.x,a.y,out.after)-G.sample(world.tiles,j,b.x,b.y,out.after)
				var old_delta: float=G.sample(world.tiles,i,a.x,a.y)-G.sample(world.tiles,j,b.x,b.y)
				if absf(delta)>EPS and absf(delta-old_delta)>EPS:return _fail(out,j,"Height break at transition boundary")
	# Unchanged neighbors also determine compatibility (Auto/Rounded sample up
	# to two cells away). Freeze their inputs without charging or recording Undo.
	out.guards={}
	# A disjoint selected tile may already be at the final level and still
	# determine that level, even when far from every changed transition.
	for i in core:
		if not out.after.has(i):out.guards[i]=world.tiles[i].duplicate(true)
	for i in out.after:
		for yy in range(maxi(0,int(i/N)-4),mini(N,int(i/N)+5)):
			for xx in range(maxi(0,i%N-4),mini(N,i%N+5)):
				var j: int=yy*N+xx
				if not out.after.has(j) and not out.guards.has(j):out.guards[j]=world.tiles[j].duplicate(true)
	out.cost=out.after.size()*20.
	out.affordable=world.cash>=out.cost
	return out
