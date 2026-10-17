extends RefCounted
## Pure target planning followed by one validated, atomic terrain transaction.
const World = preload("res://model/city_world.gd")
const Geometry = preload("res://model/terrain_geometry.gd")
const OPERATIONS = ["raise", "lower", "flatten", "shape"]

static func footprint(center: int, radius: int) -> Array:
	var cells: Array = []
	if center < 0 or center >= World.COUNT or radius not in [0, 1, 2]: return cells
	var x: int = center % World.N
	var y: int = floori(float(center) / World.N)
	for yy in range(maxi(0, y - radius), mini(World.N, y + radius + 1)):
		for xx in range(maxi(0, x - radius), mini(World.N, x + radius + 1)):
			cells.append(yy * World.N + xx)
	return cells

static func plan(world, indices: Array, operation: String, step: int = 1, target = null, shape_settings: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"before": {}, "after": {}, "targets": {}, "blocked": {}, "cost": 0.0, "affordable": false, "error": ""}
	if operation not in OPERATIONS or step not in [1, 2, 4]:
		out.error = "Unsupported terrain setting."
		return out
	if operation == "flatten" and (not World._finite(target) or float(target) != floor(float(target)) or target < World.MIN_TERRAIN_ELEV or target > World.MAX_TERRAIN_ELEV):
		out.error = "Choose a whole-number Flatten height from -5 to +12."
		return out
	if not shape_settings.is_empty() and (shape_settings.get("shape") not in Geometry.SHAPES or shape_settings.get("direction") not in Geometry.DIRECTIONS or shape_settings.get("strength") not in [1,2,3]):
		out.error = "Unsupported shape setting."
		return out
	var seen: Dictionary = {}
	for value in indices:
		if not value is int or value < 0 or value >= world.tiles.size() or seen.has(value): continue
		var i: int = value
		seen[i] = true
		var tile: Dictionary = world.tiles[i]
		var reason: String = _protected_reason(tile)
		if not reason.is_empty():
			out.blocked[i] = reason
			continue
		var desired: int = int(tile.elev) if operation == "shape" else int(target) if operation == "flatten" else clampi(int(tile.elev) + (step if operation == "raise" else -step), World.MIN_TERRAIN_ELEV, World.MAX_TERRAIN_ELEV)
		var after: Dictionary = tile.duplicate(true)
		after.elev = desired
		if operation == "flatten":
			after.merge({"terrainShape":"flat","slopeDir":"auto","shapeStrength":1},true)
		elif not shape_settings.is_empty() and (operation == "shape" or desired != int(tile.elev)):
			if tile.channel and shape_settings.shape != "flat":
				out.blocked[i] = "Water channel"
				continue
			after.terrainShape = shape_settings.shape
			after.slopeDir = shape_settings.direction if shape_settings.shape == "slope" else "auto"
			after.shapeStrength = shape_settings.strength if shape_settings.shape == "slope" else 1
		if after == tile:
			out.blocked[i] = "Already at target" if operation in ["flatten","shape"] else "Height limit"
			continue
		if desired != int(tile.elev) and not world.can_place(i, "raise" if desired > int(tile.elev) else "lower"):
			out.blocked[i] = "Protected terrain"
			continue
		out.before[i] = tile.duplicate(true)
		out.after[i] = after
	# Resolve Auto against the complete target heights, never iteration order.
	for i in out.after.keys():
		var after: Dictionary = out.after[i]
		if after.get("terrainShape","flat") == "slope" and after.get("slopeDir","auto") == "auto" and Geometry.gradient(world.tiles,i,out.after) == Vector2.ZERO:
			if operation == "shape":
				out.blocked[i] = "Level neighbors: choose N/E/S/W"
				out.before.erase(i)
				out.after.erase(i)
				continue
			after.merge({"terrainShape":"flat","slopeDir":"auto","shapeStrength":1},true)
		if after == world.tiles[i]:
			out.before.erase(i)
			out.after.erase(i)
			continue
		out.targets[i] = after.elev
		out.cost += World.COST.raise
	out.affordable = world.cash >= out.cost
	return out

static func _protected_reason(tile: Dictionary) -> String:
	if tile.civic: return "Building"
	if tile.zone or tile.level: return "Zoned property"
	if tile.road or tile.rail: return "Road or rail"
	if tile.line or tile.pipe: return "Power line or pipe"
	if tile.terrain == "water" and not tile.channel: return "Natural water"
	return ""

static func commit(world, proposal: Dictionary) -> Dictionary:
	var failed: Dictionary = {"changed": false, "before": {}, "after": {}, "cost": 0.0, "reason": "No terrain changed."}
	if not proposal.get("error", "").is_empty():
		failed.reason = proposal.error
		return failed
	if proposal.get("before", {}).is_empty(): return failed
	if world.cash < proposal.cost:
		failed.reason = "Need $%d for this whole terrain edit; nothing changed." % proposal.cost
		return failed
	for i in proposal.before:
		if world.tiles[i] != proposal.before[i]:
			failed.reason = "Terrain changed since the preview; try again."
			return failed
	var before: Dictionary = proposal.before.duplicate(true)
	# A dam can dry distant connected channels. Snapshot them once for history;
	# recalculate performs the existing reflow exactly once after the set edit.
	for i in range(world.tiles.size()):
		if world.tiles[i].channel and not before.has(i): before[i] = world.tiles[i].duplicate(true)
	for i in proposal.after: world.tiles[i] = proposal.after[i].duplicate(true)
	world.cash -= proposal.cost
	world.recalculate()
	var after: Dictionary = {}
	for i in before.keys():
		if before[i] == world.tiles[i]: before.erase(i)
		else: after[i] = world.tiles[i].duplicate(true)
	return {"changed": not before.is_empty(), "before": before, "after": after, "cost": proposal.cost, "reason": ""}
