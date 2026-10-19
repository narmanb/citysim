extends RefCounted
## Frozen, bounded set operations. No mutation, renderer or UI dependencies.
const W = preload("res://model/city_world.gd")
const Surfaces = preload("res://model/terrain_surfaces.gd")
const G = preload("res://model/terrain_geometry.gd")

static func preset_footprint(center: int, radius: int) -> Array:
	var out: Array = []
	if center < 0 or center >= W.COUNT or radius not in [1,2,4]: return out
	var x: int = center%W.N
	var y: int = center/W.N
	for yy in range(maxi(0,y-radius),mini(W.N,y+radius+1)):
		for xx in range(maxi(0,x-radius),mini(W.N,x+radius+1)): out.append(yy*W.N+xx)
	return out

static func _reason(tile: Dictionary, protection: Callable) -> String:
	var reason: String = protection.call(tile)
	if not reason.is_empty(): return reason
	if tile.channel: return "Water channel"
	if tile.get("terrainShape","flat") == "cliff": return "Protected cliff"
	return ""

static func plan(world, indices: Array, operation: String, settings: Dictionary, centers: Array, protection: Callable) -> Dictionary:
	var out: Dictionary = {"before":{},"after":{},"targets":{},"blocked":{},"cost":0.,"affordable":false,"error":""}
	var strength = settings.get("smooth_strength",2)
	var radius = settings.get("preset_radius",2)
	var peak = settings.get("peak",12 if operation == "mountain" else 6)
	var profile = settings.get("profile",2)
	var shape = settings.get("preset_shape","rounded")
	if not Surfaces.valid_settings(settings) or strength not in [1,2,3] or radius not in [1,2,4] or not W._finite(peak) or float(peak)!=floor(float(peak)) or peak<W.MIN_TERRAIN_ELEV or peak>W.MAX_TERRAIN_ELEV or profile not in [1,2,3] or shape not in ["rounded","cliff"]:
		out.error="Unsupported sculpting setting."
		return out
	var desired: Dictionary = {}
	if operation == "smooth":
		for i in indices:
			if not i is int or i<0 or i>=W.COUNT or desired.has(i): continue
			var reason = _reason(world.tiles[i],protection)
			if not reason.is_empty(): out.blocked[i]=reason
			else: desired[i]=float(world.tiles[i].elev)
		for iteration in range(strength):
			var previous: Dictionary = desired.duplicate()
			for i in previous:
				var weighted: float = previous[i]*2.
				var count: float = 2.
				for neighbor in world.neighbors(i):
					if not _reason(world.tiles[neighbor],protection).is_empty(): continue
					weighted += float(previous.get(neighbor,world.tiles[neighbor].elev))
					count += 1.
				desired[i]=weighted/count
		for i in desired:
			desired[i]=clampi(roundi(desired[i]),maxi(W.MIN_TERRAIN_ELEV,world.tiles[i].elev-strength),mini(W.MAX_TERRAIN_ELEV,world.tiles[i].elev+strength))
	else:
		var seen: Dictionary = {}
		for center in centers:
			if not center is int or center<0 or center>=W.COUNT or seen.has(center): continue
			seen[center]=true
			var base: int = world.tiles[center].elev
			if peak<=base: continue
			for i in preset_footprint(center,radius):
				var reason = _reason(world.tiles[i],protection)
				if not reason.is_empty(): out.blocked[i]=reason;continue
				var distance: float = Vector2(i%W.N-center%W.N,int(i/W.N)-int(center/W.N)).length()
				var t: float = clampf(distance/(float(radius)+.5),0,1)
				var weight: float = pow(1.-t*t*(3.-2.*t),[.7,1.,1.6][profile-1])
				var value: int = maxi(world.tiles[i].elev,roundi(lerpf(base,peak,weight)))
				desired[i]=maxi(desired.get(i,world.tiles[i].elev),value)
	for i in desired:
		var before: Dictionary = world.tiles[i]
		# Radial Cliff stamps preserve untouched shoulders and zero-weight corners.
		if operation!="smooth" and shape=="cliff" and int(desired[i])==before.elev: continue
		var after: Dictionary = before.duplicate(true)
		after.erase("gradeCorners")
		after.elev=int(desired[i])
		after.merge({"terrainShape":"rounded" if operation=="smooth" else shape,"slopeDir":"auto","shapeStrength":1},true)
		G.retain_foundation(before,after,operation)
		if before.get("terrainShape","flat")!="rounded" and after.terrainShape=="rounded": Surfaces.apply(after,settings)
		out.before[i]=before.duplicate(true)
		out.after[i]=after
	for i in out.after.keys():
		var before: Dictionary = out.before[i]
		var after: Dictionary = out.after[i]
		if before==after or ((operation=="smooth" or not Surfaces.changed(after,before)) and after.elev==before.elev and after.terrainShape=="rounded" and G.same_surface(world.tiles,i,out.after)):
			out.before.erase(i);out.after.erase(i)
			continue
		out.targets[i]=after.elev
		out.cost+=W.COST.raise
	out.affordable=world.cash>=out.cost
	return out
