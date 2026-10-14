extends Control
## Native game shell. Simulation ownership stays here, outside the city renderer.

const World = preload("res://model/city_world.gd")
const CityView = preload("res://view/isometric_view.gd")
const Store = preload("res://persistence/city_store.gd")
const ConstructionHistory = preload("res://ui/construction_history.gd")
const CATEGORIES: Dictionary = {
	"Transport": ["road", "rail", "station"],
	"Zoning": ["res", "apt", "shop", "office", "light", "logistics", "heavy"],
	"Utilities": ["line", "pipe", "plant", "pump", "tower"],
	"Services": ["police", "fire", "school", "hospital"],
	"Parks": ["park"],
	"Terraform": ["raise", "lower", "river", "grass", "desert", "tree", "forest"]
}
const TOOL_LABELS: Dictionary = {
	"pan": "Pan / inspect", "bulldoze": "Bulldoze", "road": "Road", "rail": "Rail",
	"station": "Rail station", "line": "Power line", "pipe": "Water pipe", "res": "House lots",
	"apt": "Apartment lots", "shop": "Shops & services", "office": "Offices", "light": "Light industry",
	"logistics": "Logistics", "heavy": "Heavy industry", "park": "Park", "plant": "Power plant",
	"pump": "Water pump", "tower": "Water tower", "police": "Police", "fire": "Fire station",
	"school": "School", "hospital": "Hospital", "raise": "Raise terrain", "lower": "Lower terrain",
	"river": "Dig water channel", "grass": "Grass biome", "desert": "Desert biome", "tree": "Tree", "forest": "Forest brush"
}
const OVERLAYS: Dictionary = {
	"none": "Normal map", "zoning": "Zoning", "traffic": "Traffic", "crime": "Crime",
	"pollution": "Pollution", "landValue": "Land value", "police": "Police coverage",
	"fire": "Fire coverage", "school": "Education", "hospital": "Health", "power": "Power network",
	"water": "Water network", "roadCondition": "Road condition"
}
const TOOL_HELP: Dictionary = {
	"pan": "Drag to pan. Tap a tile to inspect its parcel and services. Pinch or use + / − to zoom.",
	"res": "A tap creates one house lot. In Paint drag, a connected stroke becomes one larger property.",
	"apt": "Larger apartment parcels support larger buildings. Add road access, power, water and jobs.",
	"shop": "Shops need customers, road access and utilities. A paint stroke creates one property.",
	"office": "Offices provide denser employment and need a stronger population base.",
	"light": "Light industry creates jobs with moderate pollution. Keep homes upwind and away.",
	"logistics": "Logistics prefers at least two tiles per property and generates freight traffic.",
	"heavy": "Heavy industry prefers at least four tiles and creates the most pollution.",
	"road": "Paint a road between dry banks to bridge up to eight water tiles. Roads must touch zones.",
	"rail": "Connect two rail stations on one rail line. Paint between dry banks to build a bridge.",
	"station": "Place a station on an existing rail tile. Two connected stations enable trains.",
	"line": "Connect the plant to the first zone tile. Lines cross roads; empty zones cannot relay power.",
	"pipe": "Connect a powered pump to the first zone tile. Pipes run under roads and power lines.",
	"plant": "A plant supplies 550 power. Connect it to zones with power lines.",
	"pump": "Power this pump. Waterfront capacity: 520; inland well: 286. Connect pipes to zones.",
	"tower": "Stores up to 180 surplus water. Join a powered pump by pipe; towers do not create water.",
	"bulldoze": "Remove one layer at a time: fire, building, zoning, road, rail, line, pipe or tree.",
	"raise": "Raise natural terrain one step. Hills can reach elevation 5.",
	"lower": "Lower natural terrain one step. Basins can reach elevation −3.",
	"river": "Dig a channel. It fills only when connected to existing water.",
	"grass": "Paint grass biome on dry, undeveloped ground.", "desert": "Paint desert biome and clear trees.",
	"tree": "Plant an individual tree on clear land.", "forest": "Paint forest on clear land. Power lines and buildings exclude trees."
}
const GUIDE: String = """1. BUILD A CONNECTED CITY
Place roads beside zones. Each property needs adjacent road access. House lots and Apartment lots use parcels: a tap makes a 1×1 lot; one connected Paint-drag stroke makes one larger property.

2. SUPPLY POWER
Build a power plant and connect a power line to the first zone tile. Developed powered buildings pass electricity to neighboring developed buildings. Empty zoning cannot carry power onward. Lines can cross roads.

3. SUPPLY WATER
Build a pump, power it, and pipe it to the first zone tile. Waterfront pumps provide 520 units; inland wells provide 286. Developed watered buildings relay water; empty zones and roads do not. Pipes run under roads and power lines.

4. STORE A SURPLUS
A water tower holds up to 180 surplus units from a connected powered pump. It supplies the same pipe network during shortages. It does not make water by itself.

5. SUPPORT GROWTH
Provide industry for jobs and commercial lots for services. Keep homes away from pollution. Inspect lots and use overlays to diagnose road, power, water, crime and land-value problems. Adjust taxes and department funding in Budget.

6. BUILD WITH TOUCH
Tap + pan places one tile on a tap and pans on a drag. Paint drag draws a connected construction stroke. Pan always moves the map. Two fingers pan and zoom without construction. + / − and Fit also control the camera.

7. CONSTRUCTION HISTORY
Undo and Redo restore a whole construction stroke and its cost. The city clock and monthly income keep running. History retains forty actions. A negative treasury can be repaired with the $10,000 emergency bond: $150 per month for 80 months.

8. TRANSPORT AND EVENTS
Roads and rails can bridge up to eight water tiles with dry land at both ends. Trains need two stations on a connected line. Events contains disasters, fire dispatch and the city message log. Random disasters are optional.

9. KEEP YOUR CITY
Save writes a city in this app. Export makes a complete compatible JSON copy for backup or transfer. Import accepts JSON exported by the earlier MetroForge game. Use the native file picker or the copy/paste JSON fallback. Saves from the old Android app are transferred by exporting there and importing here.
"""

var world
var view
var history = ConstructionHistory.new()
var paused: bool = false
var speed: int = 1
var selected_tool: String = "pan"
var placement_mode: String = "tapPan"
var category: String = "Transport"
var _elapsed: float = 0.0
var _stroke: bool = false
var _stroke_parcel: int = 0
var _stroke_tiles: Dictionary = {}
var _linear_start: int = -1
var _linear_end: int = -1
var _auto_overlay: bool = false
var _selected: int = -1
var _stats_label: Label
var _status: Label
var _growth: Label
var _selection: Label
var _selection_panel: PanelContainer
var _tools: HBoxContainer
var _tool_buttons: Dictionary = {}
var _category_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _undo_button: Button
var _redo_button: Button
var _pause_button: Button
var _mode_button: Button
var _demand: Label
var _toast: Label
var _toast_time: float = 0.0
var _modal: ColorRect
var _dialog_panel: PanelContainer
var _dialog_body: VBoxContainer
var _dialog_title: Label
var _dialog_kind: String = ""
var _ledger: Label
var _event_log: Label
var _json_text: TextEdit
var _file_dialog: FileDialog
var _native_action: String = ""
var _new_confirm: ConfirmationDialog

func _ready() -> void:
	_build_ui()
	set_world(World.new())
	choose_tool("pan")
	call_deferred("_fit_view")

func _process(delta: float) -> void:
	advance_time(delta)
	if _toast_time > 0:
		_toast_time -= delta
		_toast.visible = _toast_time > 0

func advance_time(delta: float) -> void:
	if world == null or paused or delta <= 0:
		return
	var simulation_delta: float = delta * speed
	_elapsed += simulation_delta
	var changed: bool = false
	while _elapsed >= 4.0:
		world.step()
		_elapsed -= 4.0
		changed = true
	world.advance_agents(simulation_delta)
	if changed:
		view.refresh()
		refresh_ui()

func set_speed(value: int) -> void:
	if value not in [1, 3, 8]:
		return
	speed = value
	for key in _speed_buttons:
		_speed_buttons[key].button_pressed = key == speed

func toggle_pause() -> void:
	paused = not paused
	_pause_button.text = "Resume" if paused else "Pause"
	_pause_button.button_pressed = paused

func set_world(value) -> bool:
	if value == null:
		return false
	world = value
	_elapsed = 0
	_selected = -1
	_stroke = false
	_stroke_tiles.clear()
	history.clear()
	if view != null:
		view.set_world(world)
		view.selected = -1
		view.refresh()
		call_deferred("_fit_view")
	if _stats_label != null:
		refresh_ui()
	return true

func new_city(seed_value: int = 0) -> bool:
	return set_world(World.new(seed_value))

func choose_tool(tool: String) -> bool:
	if not TOOL_LABELS.has(tool):
		return false
	if _stroke:
		end_stroke()
	selected_tool = tool
	if view != null:
		view.tool = tool
		if tool != "pan":
			_selected = -1
			view.selected = -1
	if tool in ["pipe", "pump", "tower"]:
		set_overlay("water", true)
	elif tool in ["line", "plant"]:
		set_overlay("power", true)
	elif _auto_overlay:
		set_overlay("none")
	for group in CATEGORIES:
		if tool in CATEGORIES[group] and category != group:
			select_category(group)
	_refresh_tool_buttons()
	if _status != null:
		_status.text = str(TOOL_HELP.get(tool, TOOL_LABELS[tool] + ": " + _money(World.COST.get(tool, 0)) + " per tile."))
		refresh_selection()
	return true

func set_placement_mode(mode: String) -> void:
	if mode not in ["tapPan", "paint"]:
		return
	placement_mode = mode
	view.mode = mode
	_mode_button.text = "Tap + pan" if mode == "tapPan" else "Paint drag"
	_mode_button.button_pressed = mode == "paint"
	show_notice("Tap builds one tile; drag pans." if mode == "tapPan" else "Drag paints a construction stroke. Two fingers pan and zoom.")

func select_category(value: String) -> void:
	if not CATEGORIES.has(value):
		return
	category = value
	if _tools == null:
		return
	for child in _tools.get_children():
		_tools.remove_child(child)
		child.queue_free()
	_tool_buttons.clear()
	for tool in CATEGORIES[category]:
		var label: String = str(TOOL_LABELS[tool]) + " · " + _money(World.COST.get(tool, 0))
		var button: Button = _button(label, func(): choose_tool(tool), _tools)
		button.toggle_mode = true
		button.tooltip_text = str(TOOL_HELP.get(tool, TOOL_LABELS[tool]))
		_tool_buttons[tool] = button
	for key in _category_buttons:
		_category_buttons[key].button_pressed = key == category
	_refresh_tool_buttons()

func _refresh_tool_buttons() -> void:
	for tool in _tool_buttons:
		_tool_buttons[tool].button_pressed = tool == selected_tool

func begin_stroke() -> void:
	if _stroke or selected_tool == "pan":
		return
	_stroke = true
	_stroke_tiles.clear()
	_stroke_parcel = 0
	_linear_start = -1
	_linear_end = -1
	history.begin()
	if selected_tool in World.ZONE_TOOL:
		_stroke_parcel = world.nextParcelId
		world.nextParcelId += 1

func end_stroke() -> void:
	if not _stroke:
		return
	if selected_tool in ["road", "rail"] and _linear_start >= 0:
		_construct_line_internal(_linear_start, _linear_end)
	_stroke = false
	_stroke_parcel = 0
	history.finish()
	world.recalculate()
	view.refresh()
	refresh_ui()
	_after_placement()

func _candidate_snapshot(index: int) -> Dictionary:
	var before: Dictionary = {index: world.tiles[index].duplicate(true)}
	var tile: Dictionary = world.tiles[index]
	if selected_tool == "bulldoze" and int(tile.get("parcel", 0)) > 0 and int(tile.get("level", 0)) > 0:
		var parcel: Dictionary = world.parcel_info(index)
		for member in parcel.get("members", []):
			before[member] = world.tiles[member].duplicate(true)
	# Reflow can change distant connected channels, so include every channel.
	if selected_tool in ["bulldoze", "river", "raise", "lower", "grass", "desert", "tree", "forest"]:
		for i in range(world.tiles.size()):
			if world.tiles[i].get("channel", false):
				before[i] = world.tiles[i].duplicate(true)
	return before

func _place_one(index: int, bridge: bool = false) -> bool:
	if index < 0 or index >= world.tiles.size() or _stroke_tiles.has(index):
		return false
	_stroke_tiles[index] = true
	var before: Dictionary = _candidate_snapshot(index)
	var cash_before: float = world.cash
	if not world.place(index, selected_tool, bridge, _stroke_parcel):
		return false
	var after: Dictionary = {}
	for key in before:
		after[key] = world.tiles[key].duplicate(true)
	history.record(before, after, cash_before - world.cash)
	return true

func construct_at(index: int, bridge: bool = false) -> bool:
	if world == null or selected_tool == "pan" or index < 0 or index >= world.tiles.size():
		return false
	var own_stroke: bool = not _stroke
	if own_stroke:
		begin_stroke()
	var placed: bool = _place_one(index, bridge)
	if own_stroke:
		end_stroke()
	return placed

func paint_at(index: int) -> void:
	if not _stroke:
		begin_stroke()
	if index < 0:
		return
	if selected_tool in ["road", "rail"]:
		if _linear_start < 0:
			_linear_start = index
		_linear_end = index
		return
	if _linear_end >= 0:
		for tile in _tile_line(_linear_end, index):
			_place_one(tile)
	else:
		_place_one(index)
	_linear_end = index
	view.refresh()

func construct_line(first: int, last: int) -> int:
	if selected_tool not in ["road", "rail"] or first < 0 or last < 0 or first >= World.COUNT or last >= World.COUNT:
		return 0
	var own_stroke: bool = not _stroke
	if own_stroke:
		begin_stroke()
	var count: int = _construct_line_internal(first, last)
	if own_stroke:
		end_stroke()
	return count

func _construct_line_internal(first: int, last: int) -> int:
	var path: Array = _tile_line(first, last)
	var bridges: Dictionary = {}
	var position: int = 0
	var has_water: bool = false
	while position < path.size():
		if world.tiles[path[position]].terrain != "water":
			position += 1
			continue
		has_water = true
		var start: int = position
		while position < path.size() and world.tiles[path[position]].terrain == "water":
			position += 1
		if position - start <= 8 and start > 0 and position < path.size() and world.tiles[path[start - 1]].terrain != "water" and world.tiles[path[position]].terrain != "water":
			for j in range(start, position):
				bridges[path[j]] = true
	var placed: int = 0
	for index in path:
		if _place_one(index, bridges.has(index)):
			placed += 1
	if has_water and bridges.is_empty():
		show_notice("Bridge needs dry land at both ends and at most 8 water tiles.")
	return placed

func _tile_line(first: int, last: int) -> Array:
	var result: Array = []
	var x: int = first % World.N
	var y: int = int(first / World.N)
	var target_x: int = last % World.N
	var target_y: int = int(last / World.N)
	var dx: int = absi(target_x - x)
	var dy: int = absi(target_y - y)
	var sx: int = 1 if x < target_x else -1
	var sy: int = 1 if y < target_y else -1
	var error: int = dx - dy
	while true:
		result.append(y * World.N + x)
		if x == target_x and y == target_y:
			break
		var doubled: int = 2 * error
		if doubled > -dy:
			error -= dy
			x += sx
		if doubled < dx:
			error += dx
			y += sy
	return result

func undo() -> bool:
	end_stroke()
	var changed: bool = history.undo(world)
	if changed:
		view.refresh()
		refresh_ui()
		show_notice("Undid construction. City time is unchanged.")
	return changed

func redo() -> bool:
	end_stroke()
	var changed: bool = history.redo(world)
	if changed:
		view.refresh()
		refresh_ui()
		show_notice("Redid construction.")
	elif not history.redo_stack.is_empty():
		show_notice("The treasury cannot afford this construction yet.")
	return changed

func clear_history() -> void:
	history.clear()
	_refresh_history()

func set_overlay(key: String, automatic: bool = false) -> void:
	if not OVERLAYS.has(key):
		return
	_auto_overlay = automatic
	if view != null:
		view.overlay = key
		view.refresh()

func set_tax(key: String, value: int) -> void:
	if key not in ["res", "com", "ind"]:
		return
	world.taxes[key] = clampi(value, 0, 20)
	world.recalculate()
	refresh_ui()

func set_funding(key: String, value: int) -> void:
	if key not in ["road", "police", "fire", "school", "hospital"]:
		return
	world.funding[key] = clampi(value, 25, 150)
	world.recalculate()
	refresh_ui()

func request_bond() -> bool:
	var accepted: bool = world.take_bond()
	refresh_ui()
	show_notice("Emergency bond: +$10,000; $150/month for 80 months." if accepted else "Repay the current bond before taking another.")
	if _dialog_kind == "budget":
		open_dialog("budget")
	return accepted

func trigger_event(kind: String) -> bool:
	var triggered: bool = world.trigger_disaster(kind)
	world.recalculate()
	view.refresh()
	refresh_ui()
	show_notice("Event triggered: " + kind if triggered else "Build part of a city before triggering an event.")
	return triggered

func dispatch_at(index: int = -1) -> bool:
	var target: int = _selected if index < 0 else index
	if target < 0:
		for i in range(world.tiles.size()):
			if world.tiles[i].get("fire", 0) > 0:
				target = i
				break
	if target < 0 or target >= world.tiles.size():
		show_notice("Select a tile to dispatch crews, or wait for a reported fire.")
		return false
	world.events.append({"type": "dispatch", "i": target, "age": 0})
	world.messages.push_front({"text": "Fire response dispatched to " + str(target % World.N + 1) + ", " + str(int(target / World.N) + 1) + ". Department coverage determines containment.", "kind": "info"})
	view.refresh()
	refresh_ui()
	show_notice("Crews dispatched. Fire station coverage and funding determine response.")
	return true

func save_city(path: String = "user://city.json") -> bool:
	var error: Error = Store.save_city(world, path)
	show_notice("City saved." if error == OK else "Save failed: " + Store.last_error)
	return error == OK

func load_city(path: String = "user://city.json") -> bool:
	var loaded = Store.load_city(path)
	if loaded == null:
		show_notice("Load failed: " + Store.last_error)
		return false
	set_world(loaded)
	show_notice("Saved city loaded.")
	return true

func import_city_text(value: String) -> bool:
	var imported = Store.import_json(value)
	if imported == null:
		show_notice("Import failed: " + Store.last_error)
		return false
	set_world(imported)
	show_notice("City imported. Previous construction history cleared.")
	return true

func export_city_text() -> String:
	return Store.export_json(world)

func _fit_view() -> void:
	if view != null:
		view.fit_city()

func _on_selection(index: int) -> void:
	_selected = index
	refresh_selection()

func refresh_ui() -> void:
	if world == null or _stats_label == null:
		return
	var s: Dictionary = world.stats
	_stats_label.text = "METROFORGE · %d/%02d   %s   Pop %s   Jobs %s (%s%% idle)   Power %s/%s   Water %s/%s   %s/mo" % [world.year, world.month, _money(world.cash), s.get("population", 0), s.get("jobs", 0), s.get("unemployment", 0), roundi(float(s.get("powerUsed", 0))), roundi(float(s.get("powerGenerated", 0))), roundi(float(s.get("waterUsed", 0))), roundi(float(s.get("waterCapacity", 0))), _money(s.get("net", 0))]
	_demand.text = "Demand   R %s   C %s   I %s" % [_signed(world.demand.get("res", 0)), _signed(world.demand.get("com", 0)), _signed(world.demand.get("ind", 0))]
	_refresh_history()
	refresh_selection()
	_refresh_growth()
	if is_instance_valid(_ledger):
		_ledger.text = "Taxes: +%s\nServices and infrastructure: %s\nNet per month: %s\nYear to date: %s · Last year: %s\nAnnual projection: %s\nBond: %s\n\nPopulation: %s / capacity %s\nCommercial jobs: %s · industrial jobs: %s\nEmployed: %s · unemployment: %s%%\nAverage land value: %s · crime: %s" % [_money(s.get("revenue", 0)), _money(s.get("expenses", 0)), _money(s.get("net", 0)), _money(s.get("yearToDate", 0)), _money(s.get("lastYearNet", 0)), _money(s.get("net", 0) * 12), "$150/month · %s months left" % world.bondMonths if world.bondMonths > 0 else "none", s.get("population", 0), s.get("resCapacity", 0), s.get("commercialJobs", 0), s.get("industrialJobs", 0), s.get("employed", 0), s.get("unemployment", 0), s.get("avgLand", 0), s.get("avgCrime", 0)]
	if is_instance_valid(_event_log):
		var notes: PackedStringArray = []
		for item in world.messages.slice(0, 16):
			notes.append(str(item.get("text", "")) if item is Dictionary else str(item))
		_event_log.text = "\n\n".join(notes) if not notes.is_empty() else "No city events reported yet."

func _refresh_history() -> void:
	if _undo_button != null:
		_undo_button.disabled = history.undo_stack.is_empty()
		_redo_button.disabled = history.redo_stack.is_empty()

func refresh_selection() -> void:
	if _selection == null or world == null:
		return
	_selection_panel.visible = _selected >= 0 and _selected < world.tiles.size()
	if not _selection_panel.visible:
		return
	var i: int = _selected
	var tile: Dictionary = world.tiles[i]
	var parcel: Dictionary = world.parcel_info(i)
	var root: Dictionary = world.tiles[parcel.get("root", i)] if not parcel.is_empty() else tile
	var kind: String = str(tile.get("civic") if tile.get("civic") else root.get("zoneType") if root.get("zoneType") else tile.get("terrain", "grass"))
	var power: bool = world.parcel_has(parcel, "power") if not parcel.is_empty() else _field("power", i) > 0
	var water: bool = world.parcel_has(parcel, "water") if not parcel.is_empty() else _field("water", i) > 0
	_selection.text = "Tile %d, %d · %s · level %s%s\nOccupants/jobs %s · Road %s · Rail %s · Power %s · Water %s\nTerrain %s · elevation %s · Land %d · pollution %d · crime %d" % [i % World.N + 1, int(i / World.N) + 1, kind, root.get("level", 0), " · ABANDONED" if root.get("abandoned", 0) else "", root.get("occupancy", 0), "yes" if world.road_near(i) or tile.get("road", false) else "no", "yes" if tile.get("rail", false) else "no", "yes" if power else "no", "yes" if water else "no", tile.get("biome", "grass"), tile.get("elev", 0), _field("landValue", i), _field("pollution", i), _field("crime", i)]
	if not parcel.is_empty():
		_selection.text += "\nParcel %s × %s · %s tiles · capacity %s" % [parcel.get("width", 1), parcel.get("height", 1), parcel.get("area", 1), world.parcel_capacity(parcel, int(root.get("level", 0)))]
	if tile.get("civic") == "tower":
		_selection.text += " · stored water %d/180" % tile.get("storage", 0)
	elif tile.get("civic") == "pump":
		var waterfront: bool = false
		for j in world.neighbors(i):
			if world.tiles[j].terrain == "water":
				waterfront = true
		_selection.text += "\nPump output %s · needs electricity" % ((520 if waterfront else 286) if power else 0)
	if tile.get("channel", false):
		_selection.text += " · " + ("water-filled channel" if tile.terrain == "water" else "dry channel")

func _field(key: String, index: int) -> float:
	var values = world.fields.get(key, [])
	return float(values[index]) if index >= 0 and index < values.size() else 0.0

func _refresh_growth() -> void:
	if world.stats.get("population", 0) > 0:
		_growth.text = ""
		_growth.visible = false
		return
	_growth.visible = true
	var homes: Array = []
	for i in range(world.tiles.size()):
		if world.tiles[i].get("zone") == "res" and not world.tiles[i].get("level", 0):
			homes.append(i)
	var has_road: bool = false
	var has_power: bool = false
	var has_water: bool = false
	for i in homes:
		if not world.road_near(i):
			continue
		has_road = true
		var p: Dictionary = world.parcel_info(i)
		if not (world.parcel_has(p, "power") if not p.is_empty() else _field("power", i) > 0):
			continue
		has_power = true
		if world.parcel_has(p, "water") if not p.is_empty() else _field("water", i) > 0:
			has_water = true
	_growth.text = "Zone homes beside roads to start a city." if homes.is_empty() else "No home lots touch a road." if not has_road else "Homes need power. Connect a plant with a line to the first zone tile." if not has_power else "Homes need water. Power a pump, then pipe it to a zone tile." if not has_water else "Homes have road, power and water. Add jobs and let a few months pass; inspect demand and land value."
	if world.cash < 0:
		_growth.text += " Budget → Emergency bond can fund repairs."

func _after_placement() -> void:
	if selected_tool in ["line", "plant"]:
		_status.text = "Power %s/%s · %s buildings missing power. Connect lines to the first zones." % [world.stats.get("powerUsed", 0), world.stats.get("powerGenerated", 0), world.stats.get("unpowered", 0)]
	elif selected_tool in ["pipe", "pump", "tower"]:
		_status.text = "Water %s/%s · %s pumped · %s stored · %s buildings missing water." % [world.stats.get("waterUsed", 0), world.stats.get("waterCapacity", 0), world.stats.get("waterPumped", 0), world.stats.get("waterStored", 0), world.stats.get("unwatered", 0)]

func show_notice(message: String) -> void:
	if _toast == null:
		return
	_toast.text = message
	_toast.visible = true
	_toast_time = 5.0

func _money(value) -> String:
	var amount: int = roundi(float(value))
	var digits: String = str(absi(amount))
	var result: String = ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return ("−$" if amount < 0 else "$") + result

func _signed(value) -> String:
	return ("+" if float(value) > 0 else "") + str(value)

func _style(background: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _build_ui() -> void:
	name = "MetroForge"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin = Theme.new()
	skin.default_font_size = 14
	skin.set_stylebox("normal", "Button", _style(Color("233a48"), Color("3a5665")))
	skin.set_stylebox("hover", "Button", _style(Color("335365"), Color("89c7cf")))
	skin.set_stylebox("pressed", "Button", _style(Color("477d83"), Color("a1e3d7")))
	skin.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("f5d599")))
	skin.set_stylebox("disabled", "Button", _style(Color("1d2c36"), Color("293d48")))
	skin.set_color("font_color", "Label", Color("e2eaf0"))
	skin.set_color("font_color", "Button", Color("e2eaf0"))
	skin.set_color("font_disabled_color", "Button", Color("71818b"))
	skin.set_color("font_color", "CheckBox", Color("e2eaf0"))
	skin.set_stylebox("panel", "PanelContainer", _style(Color("172b36"), Color("3a5665")))
	theme = skin
	var backdrop = ColorRect.new()
	backdrop.color = Color("10212b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var stats = _horizontal_scroll("Stats", column, 26)
	_stats_label = _label("METROFORGE", stats)
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color("c8dfdf"))
	var categories = _horizontal_scroll("Categories", column, 42)
	for group in CATEGORIES:
		var button: Button = _button(group, func(): select_category(group), categories)
		button.toggle_mode = true
		_category_buttons[group] = button
	_undo_button = _button("Undo", func(): undo(), categories)
	_redo_button = _button("Redo", func(): redo(), categories)
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	column.add_child(toolbar)
	var quick_pan: Button = _button("Pan", func(): choose_tool("pan"), toolbar)
	quick_pan.tooltip_text = "Pan and inspect tiles"
	_button("Bulldoze", func(): choose_tool("bulldoze"), toolbar)
	_mode_button = _button("Tap + pan", func(): set_placement_mode("paint" if placement_mode == "tapPan" else "tapPan"), toolbar)
	_mode_button.toggle_mode = true
	_tools = _horizontal_scroll("Tools", toolbar, 42)
	_tools.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_area = Control.new()
	map_area.name = "MapArea"
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_area.custom_minimum_size = Vector2(0, 80)
	map_area.clip_contents = true
	column.add_child(map_area)
	view = CityView.new()
	view.name = "CityView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(view)
	view.tile_pressed.connect(func(index): construct_at(index))
	view.stroke_started.connect(begin_stroke)
	view.tile_painted.connect(paint_at)
	view.stroke_finished.connect(end_stroke)
	view.selection_changed.connect(_on_selection)
	var camera = HBoxContainer.new()
	camera.name = "CameraControls"
	camera.z_index = 3900
	camera.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera.offset_left = -192
	camera.offset_right = -8
	camera.offset_top = 8
	camera.offset_bottom = 48
	map_area.add_child(camera)
	_button("−", func(): view.zoom_at(1.0 / 1.25, view.size / 2), camera).custom_minimum_size.x = 48
	_button("+", func(): view.zoom_at(1.25, view.size / 2), camera).custom_minimum_size.x = 48
	_button("Fit", _fit_view, camera)
	_selection_panel = PanelContainer.new()
	_selection_panel.z_index = 3900
	_selection_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_selection_panel.offset_left = 8
	_selection_panel.offset_right = 528
	_selection_panel.offset_top = -130
	_selection_panel.offset_bottom = -8
	_selection_panel.visible = false
	map_area.add_child(_selection_panel)
	var selection_row = HBoxContainer.new()
	_selection_panel.add_child(selection_row)
	_selection = _label("", selection_row)
	_selection.name = "Selection"
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection.custom_minimum_size = Vector2(405, 0)
	_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection.add_theme_font_size_override("font_size", 12)
	_button("×", func(): _selected = -1; view.selected = -1; view.refresh(); refresh_selection(), selection_row)
	_toast = Label.new()
	_toast.z_index = 3901
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -290
	_toast.offset_right = 290
	_toast.offset_top = -48
	_toast.offset_bottom = -8
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", _style(Color("172b36"), Color("9bccba")))
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	map_area.add_child(_toast)
	_status = _label("", column)
	_status.name = "Status"
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size.y = 20
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("a7beca"))
	_growth = _label("", column)
	_growth.name = "GrowthHint"
	_growth.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_growth.custom_minimum_size.y = 18
	_growth.add_theme_font_size_override("font_size", 12)
	_growth.add_theme_color_override("font_color", Color("e4c98e"))
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)
	var playback = HBoxContainer.new()
	playback.name = "Playback"
	playback.add_theme_constant_override("separation", 3)
	footer.add_child(playback)
	_pause_button = _button("Pause", toggle_pause, playback)
	_pause_button.toggle_mode = true
	for multiplier in [1, 3, 8]:
		var button: Button = _button(str(multiplier) + "×", func(): set_speed(multiplier), playback)
		button.toggle_mode = true
		button.custom_minimum_size.x = 44
		_speed_buttons[multiplier] = button
	_demand = _label("", playback)
	_demand.custom_minimum_size.x = 154
	_demand.add_theme_font_size_override("font_size", 12)
	_demand.add_theme_color_override("font_color", Color("a9d7c0"))
	var actions = _horizontal_scroll("Actions", footer, 42)
	actions.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair in [["Overlays", "overlays"], ["Budget", "budget"], ["Events", "events"], ["Guide", "guide"], ["City / Files", "files"]]:
		_button(pair[0], func(): open_dialog(pair[1]), actions)
	_build_dialog()
	select_category(category)
	set_speed(1)

func _horizontal_scroll(node_name: String, parent: Node, minimum_height: float) -> HBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minimum_height
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	return row

func _button(text_value: String, callback: Callable, parent: Node) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(text_value: String, parent: Node) -> Label:
	var label = Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _paragraph(text_value: String) -> Label:
	var label: Label = _label(text_value, _dialog_body)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _build_dialog() -> void:
	_modal = ColorRect.new()
	_modal.name = "DialogBackdrop"
	_modal.z_index = 4000
	_modal.color = Color(0.015, 0.035, 0.055, 0.82)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	add_child(_modal)
	_dialog_panel = PanelContainer.new()
	_dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal.add_child(_dialog_panel)
	var dialog_column = VBoxContainer.new()
	dialog_column.add_theme_constant_override("separation", 8)
	_dialog_panel.add_child(dialog_column)
	var heading = HBoxContainer.new()
	dialog_column.add_child(heading)
	_dialog_title = _label("", heading)
	_dialog_title.add_theme_font_size_override("font_size", 21)
	_dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("Close", close_dialog, heading)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_column.add_child(scroll)
	_dialog_body = VBoxContainer.new()
	_dialog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_dialog_body)
	resized.connect(_layout_dialog)
	_layout_dialog()
	_file_dialog = FileDialog.new()
	_file_dialog.use_native_dialog = true
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json ; MetroForge city JSON"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	_new_confirm = ConfirmationDialog.new()
	_new_confirm.title = "Generate a new city?"
	_new_confirm.dialog_text = "Save or export this city first if you want to keep it."
	_new_confirm.ok_button_text = "New city"
	_new_confirm.confirmed.connect(func(): new_city(); close_dialog(); show_notice("New city generated."))
	add_child(_new_confirm)

func _layout_dialog() -> void:
	if _dialog_panel == null:
		return
	var dimensions: Vector2 = Vector2(minf(700, size.x - 32), minf(650, size.y - 24))
	_dialog_panel.offset_left = -dimensions.x / 2
	_dialog_panel.offset_right = dimensions.x / 2
	_dialog_panel.offset_top = -dimensions.y / 2
	_dialog_panel.offset_bottom = dimensions.y / 2

func open_dialog(kind: String) -> void:
	_dialog_kind = kind
	_ledger = null
	_event_log = null
	_json_text = null
	for child in _dialog_body.get_children():
		_dialog_body.remove_child(child)
		child.queue_free()
	_modal.visible = true
	match kind:
		"overlays":
			_dialog_title.text = "City overlays"
			var grid = GridContainer.new()
			grid.columns = 3
			_dialog_body.add_child(grid)
			for key in OVERLAYS:
				var button: Button = _button(OVERLAYS[key], func(): set_overlay(key); close_dialog(), grid)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"budget":
			_dialog_title.text = "Budget and departments"
			_paragraph("Tax rates (%)").add_theme_font_size_override("font_size", 18)
			for pair in [["res", "Residential"], ["com", "Commercial"], ["ind", "Industrial"]]:
				_budget_slider(pair[0], pair[1], true)
			_paragraph("Department funding (%)").add_theme_font_size_override("font_size", 18)
			for pair in [["road", "Roads / Transport"], ["police", "Police"], ["fire", "Fire"], ["school", "Education"], ["hospital", "Health"]]:
				_budget_slider(pair[0], pair[1], false)
			_paragraph("Monthly ledger").add_theme_font_size_override("font_size", 18)
			_ledger = _paragraph("")
			var bond: Button = _button("Emergency bond +$10,000 · $150/mo" if world.bondMonths == 0 else "Bond: %s months remaining" % world.bondMonths, func(): request_bond(), _dialog_body)
			bond.disabled = world.bondMonths > 0
		"events":
			_dialog_title.text = "Events and dispatch"
			var random_toggle = CheckBox.new()
			random_toggle.text = "Allow random disasters"
			random_toggle.custom_minimum_size.y = 42
			random_toggle.button_pressed = world.randomDisasters
			random_toggle.toggled.connect(func(value): world.randomDisasters = value)
			_dialog_body.add_child(random_toggle)
			var row = GridContainer.new()
			row.columns = 3
			_dialog_body.add_child(row)
			for pair in [["fire", "Start fire"], ["quake", "Earthquake"], ["tornado", "Tornado"], ["flood", "Flood"]]:
				_button(pair[1], func(): trigger_event(pair[0]), row)
			_button("Dispatch fire crews", func(): dispatch_at(), _dialog_body)
			_paragraph("Select a tile with Pan, then dispatch crews. Fire station coverage and department funding determine containment.")
			_paragraph("City message log").add_theme_font_size_override("font_size", 18)
			_event_log = _paragraph("")
		"guide":
			_dialog_title.text = "Getting started"
			_paragraph(GUIDE)
		"files":
			_dialog_title.text = "City / Files"
			_paragraph("Save keeps a city in this app. Export JSON to move a city between the original MetroForge and this Godot preview.")
			var row = GridContainer.new()
			row.columns = 3
			_dialog_body.add_child(row)
			_button("Save city", func(): save_city(), row)
			_button("Load saved", func(): load_city(), row)
			_button("New city", func(): _new_confirm.popup_centered(), row)
			_button("Import JSON file", func(): _open_native_file("import"), row)
			_button("Export JSON file", func(): _open_native_file("export"), row)
			_button("Copy / paste JSON", func(): open_dialog("json"), row)
			_paragraph("The native file picker is used where supported. Copy / paste JSON is always available if file access is unavailable.")
		"json":
			_dialog_title.text = "City JSON / copy and paste"
			_paragraph("Paste a complete city JSON below and choose Import. Invalid JSON leaves the running city intact. Export fills the box with your current city.")
			_json_text = TextEdit.new()
			_json_text.custom_minimum_size = Vector2(0, 150)
			_json_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_json_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			_json_text.placeholder_text = "Paste MetroForge city JSON here…"
			_dialog_body.add_child(_json_text)
			var row = GridContainer.new()
			row.columns = 3
			_dialog_body.add_child(row)
			_button("Export to text", func(): _json_text.text = export_city_text(), row)
			_button("Copy JSON", func(): _json_text.text = export_city_text(); DisplayServer.clipboard_set(_json_text.text); show_notice("City JSON copied."), row)
			_button("Paste", func(): _json_text.text = DisplayServer.clipboard_get(), row)
			_button("Import this JSON", func(): if import_city_text(_json_text.text): close_dialog(), row)
	refresh_ui()
	_layout_dialog()

func close_dialog() -> void:
	_modal.visible = false
	_dialog_kind = ""

func _budget_slider(key: String, text_value: String, tax: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_dialog_body.add_child(row)
	var title: Label = _label(text_value, row)
	title.custom_minimum_size.x = 145
	var slider = HSlider.new()
	slider.min_value = 0 if tax else 25
	slider.max_value = 20 if tax else 150
	slider.step = 1 if tax else 5
	slider.value = world.taxes[key] if tax else world.funding[key]
	slider.custom_minimum_size = Vector2(170, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var amount: Label = _label(str(int(slider.value)) + "%", row)
	amount.custom_minimum_size.x = 42
	slider.value_changed.connect(func(value):
		amount.text = str(int(value)) + "%"
		if tax:
			set_tax(key, int(value))
		else:
			set_funding(key, int(value))
	)

func _open_native_file(action: String) -> void:
	_native_action = action
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "import" else FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Import MetroForge city" if action == "import" else "Export MetroForge city"
	if action == "export":
		_file_dialog.current_file = "MetroForge-%d-%02d.json" % [world.year, world.month]
	_file_dialog.popup_centered_ratio(0.85)

func _on_file_selected(path: String) -> void:
	if _native_action == "import":
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			show_notice("Cannot read file. Use Copy / paste JSON in City / Files.")
			return
		if file.get_length() > 32 * 1024 * 1024:
			show_notice("City file is too large (maximum 32 MB).")
			return
		var value: String = file.get_as_text()
		file.close()
		if import_city_text(value):
			close_dialog()
	else:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			show_notice("Cannot write file. Use Copy / paste JSON in City / Files.")
			return
		file.store_string(export_city_text())
		file.flush()
		var error: Error = file.get_error()
		file.close()
		show_notice("City JSON exported." if error == OK else "Export failed. Use Copy / paste JSON to retain a backup.")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			close_dialog()
			get_viewport().set_input_as_handled()
		elif not _modal.visible and event.keycode == KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif not _modal.visible and event.ctrl_pressed and event.keycode == KEY_Z:
			if event.shift_pressed:
				redo()
			else:
				undo()
			get_viewport().set_input_as_handled()
