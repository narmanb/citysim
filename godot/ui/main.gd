extends Control
## Native game shell. Simulation ownership stays here, outside the city renderer.

const World = preload("res://model/city_world.gd")
const CityView = preload("res://view/isometric_view.gd")
const Store = preload("res://persistence/city_store.gd")
const ConstructionHistory = preload("res://ui/construction_history.gd")
const TerrainEditor = preload("res://model/terrain_editor.gd")
const TerrainSettings = preload("res://ui/terrain_settings.gd")
const PerformanceDisplay = preload("res://ui/performance_display.gd")
const CATEGORIES: Dictionary = {
	"Transport": ["road", "rail", "station"],
	"Zoning": ["res", "shop", "light"],
	"Utilities": ["line", "pipe", "plant", "pump", "tower"],
	"Services": ["police", "fire", "school", "hospital"],
	"Parks": ["park"],
	"Terraform": ["raise", "lower", "flatten", "river", "grass", "desert", "tree", "forest"]
}
const TOOL_LABELS: Dictionary = {
	"pan": "Pan / inspect", "bulldoze": "Bulldoze", "road": "Road", "rail": "Rail",
	"station": "Rail station", "line": "Power line", "pipe": "Water pipe", "res": "Housing zone",
	"apt": "Apartment lots", "shop": "Business zone", "office": "Offices", "light": "Industrial zone",
	"heavy": "Heavy industry", "park": "Park", "plant": "Power plant",
	"pump": "Water pump", "tower": "Water tower", "police": "Police", "fire": "Fire station",
	"school": "School", "hospital": "Hospital", "raise": "Raise terrain", "lower": "Lower terrain", "flatten": "Flatten terrain",
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
	"res": "Zone homes beside roads, then supply utilities. Larger serviced properties may develop apartments as the city grows.",
	"apt": "Larger apartment parcels support larger buildings. Add road access, power, water and jobs.",
	"shop": "Zone businesses for shops and services. Larger suitable properties can develop offices as population and demand grow.",
	"office": "Offices provide denser employment and need a stronger population base.",
	"light": "Zone industrial jobs. Suitable larger properties may develop factories when demand and road access support them. Keep homes away from pollution.",
	"heavy": "Heavy industry provides more jobs per tile and prefers properties of at least four tiles. Keep homes away from pollution.",
	"road": "Paint a road between dry banks to bridge up to eight water tiles. Roads must touch zones.",
	"rail": "Connect two rail stations on one rail line. Paint between dry banks to build a bridge.",
	"station": "Place a station on an existing rail tile. Two connected stations enable trains.",
	"line": "Connect the plant to the first zone tile. Lines cross roads; empty zones cannot relay power.",
	"pipe": "Connect a powered pump to the first zone tile. Pipes run under roads and power lines.",
	"plant": "A plant supplies 550 power. Connect it to zones with power lines.",
	"pump": "Power this pump. Waterfront capacity: 520; inland well: 286. Connect pipes to zones.",
	"tower": "Stores up to 180 surplus water. Join a powered pump by pipe; towers do not create water.",
	"bulldoze": "Remove one layer at a time: fire, building, zoning, road, rail, line, pipe or tree.",
	"raise": "Raise natural terrain one step. Hills can reach elevation +12.",
	"lower": "Lower natural terrain one step. Basins can reach elevation −5.",
	"flatten": "Flatten natural ground to the first touched tile or a chosen height. Protected cells stay unchanged.",
	"river": "Dig a channel. It fills only when connected to existing water.",
	"grass": "Paint grass biome on dry, undeveloped ground.", "desert": "Paint desert biome and clear trees.",
	"tree": "Plant an individual tree on clear land.", "forest": "Paint forest on clear land. Power lines and buildings exclude trees."
}
const GUIDE: String = """1. BUILD A CONNECTED CITY
Choose Housing, Business or Industrial. A tap makes a 1×1 property; one connected Paint-drag stroke makes one larger property. Small properties grow homes, shops or workshops. Larger properties can also grow apartments, offices or factories when demand, services, roads and utilities support them. Lot size allows larger buildings; it does not guarantee them. Painting the same zone family leaves existing properties intact.

2. SUPPLY POWER
Build a power plant and connect a power line to the first zone tile. Developed powered buildings pass electricity to neighboring developed buildings. Empty zoning cannot carry power onward. Lines can cross roads.

3. SUPPLY WATER
Build a pump, power it, and pipe it to the first zone tile. Waterfront pumps provide 520 units; inland wells provide 286. Developed watered buildings relay water; empty zones and roads do not. Pipes run under roads and power lines.

4. STORE A SURPLUS
A water tower holds up to 180 surplus units from a connected powered pump. It supplies the same pipe network during shortages. It does not make water by itself.

5. SUPPORT GROWTH
Balance Housing, Business and Industrial zones. Keep homes away from pollution. Inspect lots and use overlays to diagnose road, power, water, crime and land-value problems. Adjust taxes and department funding in Budget.

6. BUILD WITH TOUCH
Tap + pan places one tile on a tap and pans on a drag. Paint drag draws a connected construction stroke. Pan always moves the map. Two fingers pan and zoom without construction. + / − and Fit also control the camera.

7. CONSTRUCTION HISTORY
Undo and Redo restore a whole construction stroke and its cost. The city clock and monthly income keep running. History retains forty actions. A negative treasury can be repaired with the $10,000 emergency bond: $150 per month for 80 months.

8. TRANSPORT AND EVENTS
Roads and rails can bridge up to eight water tiles with dry land at both ends. Trains need two stations on a connected line. Events contains disasters, fire dispatch and the city message log. Random disasters are optional.

TERRAFORM FLAT TERRACES
Raise/Lower reaches −5 to +12. Terraform offers 1×1, 3×3 or 5×5 brushes and height steps 1/2/4. Flatten uses the first touched tile or Set height. Preview shows cost and skipped cells; each changed cell costs $20. One stroke is one Undo. Buildings, zones, roads, rails, lines, pipes and natural water are protected. Slopes and smoothing are not included yet.

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
var terrain_settings: Dictionary = {"radius": 0, "step": 1, "flatten_target": null}
var _terrain_panel
var _terrain_indices: Dictionary = {}
var _terrain_stroke_settings: Dictionary = {}
var _last_terrain_changed: bool = false
var _linear_start: int = -1
var _linear_end: int = -1
var _auto_overlay: bool = false
var _selected: int = -1
var _stats_label: Label
var _status: Label
var _growth: Label
var _selection: Label
var _selection_panel: PanelContainer
var _tools: GridContainer
var _tool_menu: PanelContainer
var _menu_dismiss: Control
var _stat_labels: Dictionary = {}
var _demand_labels: Dictionary = {}
var _demand_meters: Dictionary = {}
var _quick_buttons: Dictionary = {}
var _tool_name: Label
var _header: PanelContainer
var _tool_dock: PanelContainer
var _footer: PanelContainer
var _full_button: Button
var _tool_buttons: Dictionary = {}
var _category_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _undo_button: Button
var _redo_button: Button
var _pause_button: Button
var _mode_button: Button
var _demand: HBoxContainer
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
	if world == null or paused or delta <= 0 or (_stroke and selected_tool in TerrainEditor.OPERATIONS) or (selected_tool in TerrainEditor.OPERATIONS and view != null and not view._pending_tiles.is_empty()):
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
	_pause_button.text = "▶" if paused else "❚❚"
	_pause_button.button_pressed = paused

func set_world(value) -> bool:
	if value == null:
		return false
	if view != null: view._cancel_pointers()
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
	if view != null: view._cancel_pointers()
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
	_close_tool_menu()
	_refresh_tool_buttons()
	if _tool_name != null:
		_tool_name.text = ("Pan" if tool == "pan" else str(TOOL_LABELS[tool])) + " · " + (_money(World.COST[tool]) if World.COST.has(tool) else "free")
		_tool_name.tooltip_text = _tool_name.text
	if _status != null:
		_status.text = str(TOOL_HELP.get(tool, TOOL_LABELS[tool] + ": " + _money(World.COST.get(tool, 0)) + " per tile."))
		refresh_selection()
	_update_terrain_summary()
	return true

func set_placement_mode(mode: String) -> void:
	if mode not in ["tapPan", "paint"]:
		return
	view._cancel_pointers()
	placement_mode = mode
	view.mode = mode
	_mode_button.text = "Mode: Tap + pan" if mode == "tapPan" else "Mode: Paint drag"
	_mode_button.button_pressed = mode == "paint"
	_close_tool_menu()
	_status.text = "Tap builds one tile; drag pans the map with any tool." if mode == "tapPan" else "Drag paints across tiles; use Pan or two fingers to move the map."

func select_category(value: String) -> void:
	if not CATEGORIES.has(value):
		return
	var was_open: bool = _tool_menu != null and _tool_menu.visible and category == value
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
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(TOOL_HELP.get(tool, TOOL_LABELS[tool]))
		_tool_buttons[tool] = button
	_terrain_panel.visible = category == "Terraform" and selected_tool in TerrainEditor.OPERATIONS
	_terrain_panel.configure(terrain_settings, selected_tool)
	for key in _category_buttons:
		_category_buttons[key].button_pressed = key == category
	_tool_menu.visible = not was_open
	_menu_dismiss.visible = not was_open
	_layout_shell()
	_refresh_tool_buttons()

func _close_tool_menu() -> void:
	if _tool_menu != null:
		_tool_menu.hide()
		_menu_dismiss.hide()

func _refresh_tool_buttons() -> void:
	for tool in _tool_buttons:
		_tool_buttons[tool].button_pressed = tool == selected_tool
	for tool in _quick_buttons:
		_quick_buttons[tool].button_pressed = tool == selected_tool

func begin_stroke() -> void:
	if _stroke or selected_tool == "pan":
		return
	_stroke = true
	_stroke_tiles.clear()
	_terrain_indices.clear()
	_terrain_stroke_settings = terrain_settings.duplicate()
	_last_terrain_changed = false
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
	if selected_tool in TerrainEditor.OPERATIONS:
		_commit_terrain_stroke()
	if selected_tool in ["road", "rail"] and _linear_start >= 0:
		_construct_line_internal(_linear_start, _linear_end)
	_stroke = false
	_stroke_parcel = 0
	if history.finish() and selected_tool not in TerrainEditor.OPERATIONS:
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
	# Generic zone brushes keep existing subtypes within their family intact.
	# This preserves imported apartments, offices and industrial variants.
	if selected_tool in ["res", "shop", "light"] and world.tiles[index].get("zone") == World.ZONE_TOOL[selected_tool].zone:
		return false
	var before: Dictionary = _candidate_snapshot(index)
	var cash_before: float = world.cash
	if not world.place(index, selected_tool, bridge, _stroke_parcel):
		return false
	if selected_tool in CATEGORIES.Zoning:
		world.tiles[index].autoGrow = true
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
	var terrain: bool = selected_tool in TerrainEditor.OPERATIONS
	var placed: bool = _stage_terrain(index) if terrain else _place_one(index, bridge)
	if own_stroke:
		end_stroke()
		if terrain: return _last_terrain_changed
	return placed

func paint_at(index: int) -> void:
	if not _stroke:
		begin_stroke()
	if index < 0:
		return
	if selected_tool in TerrainEditor.OPERATIONS:
		# The view already supplies every traversed center. Interpolating its
		# deduplicated set again would invent cells on retraced/branched paths.
		_stage_terrain(index)
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
		# Emit the horizontal connector before a simultaneous vertical step.
		if doubled > -dy and doubled < dx:
			result.append(y * World.N + x)
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
	_stat_labels.date.text = "%d / %02d" % [world.year, world.month]
	_stat_labels.cash.text = _money(world.cash)
	_stat_labels.cash.add_theme_color_override("font_color", Color("ff9588") if world.cash < 0 else Color("e9f1e8"))
	_stat_labels.population.text = "Pop %s" % s.get("population", 0)
	_stat_labels.jobs.text = "Jobs %s · %s%% idle" % [s.get("jobs", 0), s.get("unemployment", 0)]
	_stat_labels.power.text = "⚡ %s/%s" % [roundi(float(s.get("powerUsed", 0))), roundi(float(s.get("powerGenerated", 0)))]
	_stat_labels.water.text = "◉ %s/%s" % [roundi(float(s.get("waterUsed", 0))), roundi(float(s.get("waterCapacity", 0)))]
	_stat_labels.net.text = ("+" if s.get("net", 0) >= 0 else "") + _money(s.get("net", 0)) + "/mo"
	_stat_labels.net.add_theme_color_override("font_color", Color("ff9588") if s.get("net", 0) < 0 else Color("9ee6aa"))
	for key in _demand_labels:
		var value: float = float(world.demand.get(key, 0))
		_demand_labels[key].text = _signed(world.demand.get(key, 0))
		var meter: ProgressBar = _demand_meters[key]
		meter.value = absf(value)
		meter.position.x = 13 if value >= 0 else 0
		meter.fill_mode = ProgressBar.FILL_BEGIN_TO_END if value >= 0 else ProgressBar.FILL_END_TO_BEGIN
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color("ee897c") if value < 0 else CityView.ZCOL[key]
		meter.add_theme_stylebox_override("fill", fill)
		meter.size = Vector2(13, 9)
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
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _build_ui() -> void:
	name = "MetroForge"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin = Theme.new()
	skin.default_font_size = 13
	skin.set_stylebox("normal", "Button", _style(Color("294052"), Color("536f7f"), 5))
	skin.set_stylebox("hover", "Button", _style(Color("36536a"), Color("88a6a6"), 5))
	skin.set_stylebox("pressed", "Button", _style(Color("a96a36"), Color("ffd27b"), 5))
	skin.set_stylebox("hover_pressed", "Button", _style(Color("bc7940"), Color("ffd27b"), 5))
	skin.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("f6ca69"), 5))
	skin.set_stylebox("disabled", "Button", _style(Color("233646"), Color("3d5360"), 5))
	for control_type in ["Label", "Button", "CheckBox"]:
		skin.set_color("font_color", control_type, Color("e9f1e8"))
	skin.set_color("font_disabled_color", "Button", Color("71818a"))
	skin.set_stylebox("panel", "PanelContainer", _style(Color("223443"), Color("78919b")))
	theme = skin
	var backdrop = ColorRect.new()
	backdrop.color = Color("121b27")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var column = VBoxContainer.new()
	column.name = "Workbench"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_header = _bar("TopBar", Color("223341"), Color("617586"), column)
	var header_row = _row(_header, 8)
	var stats = _horizontal_scroll("Stats", header_row, 0)
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.add_theme_constant_override("separation", 5)
	for key in ["date", "cash", "population", "jobs", "power", "water", "net"]:
		var badge = PanelContainer.new()
		badge.name = key.capitalize() + "Badge"
		var badge_style: StyleBoxFlat = _style(Color("142331"), Color("425c6b"), 3)
		badge_style.content_margin_left = 7
		badge_style.content_margin_right = 7
		badge_style.content_margin_top = 4
		badge_style.content_margin_bottom = 4
		badge.add_theme_stylebox_override("panel", badge_style)
		stats.add_child(badge)
		_stat_labels[key] = _label("", badge)
	_stats_label = _stat_labels.date
	_full_button = _button("⛶ Fullscreen", _toggle_fullscreen, header_row)
	_full_button.name = "Fullscreen"
	_full_button.tooltip_text = "Toggle fullscreen / landscape"
	_full_button.add_theme_stylebox_override("normal", _style(Color("36536a"), Color("536f7f"), 5))
	_button_padding(_full_button, 9, 2)
	_tool_dock = _bar("ToolDock", Color("1a2a38"), Color("5d7783"), column)
	var toolbar = _row(_tool_dock, 6)
	toolbar.name = "ToolNav"
	var quick_tools = _row(toolbar, 5)
	quick_tools.name = "QuickTools"
	for tool in ["pan", "bulldoze"]:
		var button: Button = _button("Pan" if tool == "pan" else "Bulldoze", func(): choose_tool(tool), quick_tools)
		button.toggle_mode = true
		button.tooltip_text = str(TOOL_HELP[tool])
		_quick_buttons[tool] = button
	var divider = VSeparator.new()
	quick_tools.add_child(divider)
	_mode_button = _button("Mode: Tap + pan", func(): set_placement_mode("paint" if placement_mode == "tapPan" else "tapPan"), toolbar)
	_mode_button.name = "PlacementMode"
	_mode_button.toggle_mode = true
	_mode_button.add_theme_stylebox_override("normal", _style(Color("52745f"), Color("a3d6a0"), 5))
	_mode_button.add_theme_stylebox_override("pressed", _style(Color("3b586b"), Color("88a6a6"), 5))
	var categories = _horizontal_scroll("Categories", toolbar, 0)
	categories.add_theme_constant_override("separation", 5)
	for group in CATEGORIES:
		var button: Button = _button(group, func(): select_category(group), categories)
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", _style(Color("446e7a"), Color("92c8cb"), 5))
		button.add_theme_stylebox_override("hover_pressed", _style(Color("446e7a"), Color("92c8cb"), 5))
		_category_buttons[group] = button
	_undo_button = _button("↶", func(): undo(), categories)
	_redo_button = _button("↷", func(): redo(), categories)
	_undo_button.tooltip_text = "Undo last construction stroke"
	_redo_button.tooltip_text = "Redo last construction stroke"
	for button in [_undo_button, _redo_button]:
		button.custom_minimum_size.x = 42
		button.add_theme_font_size_override("font_size", 21)
		_button_padding(button, 7, 2)
	_tool_name = _label("Pan · free", toolbar)
	_tool_name.name = "ToolName"
	_tool_name.custom_minimum_size.x = 140
	_tool_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tool_name.add_theme_color_override("font_color", Color("f6ca69"))
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
	view.terrain_preview_requested.connect(_preview_terrain)
	var camera = HBoxContainer.new()
	camera.name = "CameraControls"
	camera.z_index = 3900
	camera.add_theme_constant_override("separation", 4)
	camera.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	camera.offset_left = -138
	camera.offset_right = -8
	camera.offset_top = -46
	camera.offset_bottom = -8
	map_area.add_child(camera)
	_button("−", func(): view.zoom_at(1.0 / 1.25, view.size / 2), camera).custom_minimum_size.x = 38
	_button("+", func(): view.zoom_at(1.25, view.size / 2), camera).custom_minimum_size.x = 38
	_button("Fit", _fit_view, camera)
	for child in camera.get_children():
		child.add_theme_font_size_override("font_size", 19 if child.text != "Fit" else 12)
	var performance_display = PerformanceDisplay.new()
	performance_display.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	performance_display.offset_left = -156
	performance_display.offset_right = -8
	performance_display.offset_top = -78
	performance_display.offset_bottom = -54
	map_area.add_child(performance_display)
	_status = _label("", map_area)
	_status.name = "Status"
	_status.z_index = 3900
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 7
	_status.offset_top = -32
	_status.offset_bottom = -6
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_stylebox_override("normal", _style(Color("11212ddc"), Color("55707c"), 4))
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_status.gui_input.connect(func(event):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			show_notice(_status.text)
			_status.accept_event()
	)
	_growth = _label("", map_area)
	_growth.name = "GrowthHint"
	_growth.z_index = 3900
	_growth.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_growth.offset_left = 7
	_growth.offset_top = -66
	_growth.offset_bottom = -38
	_growth.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_growth.add_theme_font_size_override("font_size", 12)
	_growth.add_theme_color_override("font_color", Color("ffe3aa"))
	_growth.add_theme_stylebox_override("normal", _style(Color("463b23e8"), Color("d5a85b"), 4))
	_selection_panel = PanelContainer.new()
	_selection_panel.name = "SelectionPanel"
	_selection_panel.z_index = 3900
	_selection_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_selection_panel.offset_left = -238
	_selection_panel.offset_right = -8
	_selection_panel.offset_top = 7
	_selection_panel.visible = false
	map_area.add_child(_selection_panel)
	var selection_row = _row(_selection_panel, 4)
	_selection = _label("", selection_row)
	_selection.name = "Selection"
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection.custom_minimum_size.x = 165
	_selection.add_theme_font_size_override("font_size", 11)
	_button("×", func(): _selected = -1; view.selected = -1; view.refresh(); refresh_selection(), selection_row).custom_minimum_size.x = 24
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.z_index = 3901
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -280
	_toast.offset_right = 280
	_toast.offset_top = 14
	_toast.offset_bottom = 56
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", _style(Color("142431ec"), Color("f6ca69"), 5))
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	map_area.add_child(_toast)
	_menu_dismiss = Control.new()
	_menu_dismiss.name = "ToolMenuDismiss"
	_menu_dismiss.z_index = 3940
	_menu_dismiss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_dismiss.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_dismiss.gui_input.connect(func(event):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_close_tool_menu()
			_menu_dismiss.accept_event()
	)
	_menu_dismiss.hide()
	map_area.add_child(_menu_dismiss)
	_tool_menu = PanelContainer.new()
	_tool_menu.name = "ToolPicker"
	_tool_menu.z_index = 3950
	_tool_menu.position = Vector2(8, 0)
	var picker_style: StyleBoxFlat = _style(Color("172a39f5"), Color("7ca0a6"), 8)
	picker_style.set_border_width_all(2)
	picker_style.set_content_margin_all(8)
	_tool_menu.add_theme_stylebox_override("panel", picker_style)
	map_area.add_child(_tool_menu)
	var picker_scroll = ScrollContainer.new()
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_menu.add_child(picker_scroll)
	var picker_column := VBoxContainer.new()
	picker_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_scroll.add_child(picker_column)
	_tools = GridContainer.new()
	_tools.name = "Tools"
	_tools.columns = 3
	_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.add_theme_constant_override("h_separation", 5)
	_tools.add_theme_constant_override("v_separation", 5)
	picker_column.add_child(_tools)
	_terrain_panel = TerrainSettings.new()
	_terrain_panel.settings_changed.connect(set_terrain_settings)
	picker_column.add_child(_terrain_panel)
	_tool_menu.hide()
	_footer = _bar("Footer", Color("152531"), Color("536d79"), column)
	var footer_row = _row(_footer, 8)
	var playback = _row(footer_row, 4)
	playback.name = "Playback"
	_pause_button = _button("❚❚", toggle_pause, playback)
	_pause_button.toggle_mode = true
	_pause_button.tooltip_text = "Pause / resume city time"
	for multiplier in [1, 3, 8]:
		var button: Button = _button(str(multiplier) + "×", func(): set_speed(multiplier), playback)
		button.toggle_mode = true
		button.custom_minimum_size.x = 40
		_speed_buttons[multiplier] = button
	_demand = _row(footer_row, 5)
	_demand.name = "Demand"
	_demand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["res", "com", "ind"]:
		_build_demand_chip(key)
	var actions = _horizontal_scroll("Actions", footer_row, 0)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END
	for pair in [["Overlays", "overlays"], ["Budget", "budget"], ["Events", "events"], ["Guide", "guide"], ["City / Files", "files"]]:
		_button(pair[0], func(): open_dialog(pair[1]), actions)
	_build_dialog()
	resized.connect(_layout_shell)
	select_category(category)
	_close_tool_menu()
	set_speed(1)
	_layout_shell()

func _bar(node_name: String, color: Color, edge: Color, parent: Node) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = node_name
	var box: StyleBoxFlat = _style(color, edge, 0)
	box.set_border_width_all(0)
	box.border_width_top = 1 if node_name == "Footer" else 0
	box.border_width_bottom = 0 if node_name == "Footer" else 2
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	return panel

func _row(parent: Node, separation: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)
	return row

func _build_demand_chip(key: String) -> void:
	var chip = PanelContainer.new()
	var box: StyleBoxFlat = _style(Color("172c38"), Color("3d6070"), 3)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", box)
	_demand.add_child(chip)
	var row = _row(chip, 3)
	var label: Label = _label(key.substr(0, 1).to_upper(), row)
	label.add_theme_color_override("font_color", CityView.ZCOL[key])
	label.add_theme_font_size_override("font_size", 12)
	chip.tooltip_text = {"res": "Residential demand", "com": "Commercial demand", "ind": "Industrial demand"}[key]
	var meter_base = ColorRect.new()
	meter_base.color = Color("34414c")
	meter_base.custom_minimum_size = Vector2(26, 9)
	meter_base.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(meter_base)
	var meter = ProgressBar.new()
	meter.name = "DemandMeter" + key.capitalize()
	meter.position = Vector2(13, 0)
	meter.size = Vector2(13, 9)
	meter.show_percentage = false
	meter.add_theme_font_size_override("font_size", 1)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	meter_base.add_child(meter)
	_demand_meters[key] = meter
	var center = ColorRect.new()
	center.color = Color("d9d4b3")
	center.position = Vector2(13, 0)
	center.size = Vector2(1, 9)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_base.add_child(center)
	var value: Label = _label("", row)
	value.add_theme_font_size_override("font_size", 11)
	_demand_labels[key] = value

func _layout_shell() -> void:
	if _header == null:
		return
	var compact: bool = size.x <= 950
	theme.default_font_size = 12 if compact else 13
	_header.custom_minimum_size.y = 36 if compact else 40
	_tool_dock.custom_minimum_size.y = 42 if compact else 46
	_footer.custom_minimum_size.y = 42 if compact else 46
	_full_button.custom_minimum_size.y = 32
	for label in _stat_labels.values():
		label.add_theme_font_size_override("font_size", 11 if compact else 12)
	var toolbar = _tool_dock.get_child(0)
	for button in toolbar.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 34 if compact else 38
	_mode_button.custom_minimum_size.x = 115 if compact else 132
	for button in _footer.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 33 if compact else 38
		button.add_theme_font_size_override("font_size", 11 if compact else 13)
	for button in _tool_buttons.values():
		button.custom_minimum_size = Vector2(118 if compact else 136, 36 if compact else 40)
	_tool_name.visible = size.x > 720
	_tool_name.add_theme_font_size_override("font_size", 12)
	_demand.visible = size.x > 720
	_status.offset_right = minf(680, size.x * 0.7)
	_growth.offset_right = minf(680, size.x * 0.72)
	# A bounded scrollable palette overlays the map and never changes its size.
	var picker_width: float = minf(690, size.x - 16)
	_tools.columns = 4 if category == "Terraform" else 3 if compact else 4
	var terrain_height: float = maxf(66, _terrain_panel.get_combined_minimum_size().y) + 5 if _terrain_panel.visible else 0
	_tool_menu.size = Vector2(picker_width, minf(terrain_height + maxf(52, ceilf(float(_tool_buttons.size()) / _tools.columns) * (41 if compact else 45) + 11), maxf(52, size.y - _header.custom_minimum_size.y - _tool_dock.custom_minimum_size.y - _footer.custom_minimum_size.y - 12)))
	_tool_menu.get_child(0).custom_minimum_size = Vector2(0, 0)

func _toggle_fullscreen() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	var fullscreen: bool = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _horizontal_scroll(node_name: String, parent: Node, minimum_height: float) -> HBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minimum_height
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(row)
	return row

func _button_padding(button: Button, horizontal: int, vertical: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = horizontal
		box.content_margin_right = horizontal
		box.content_margin_top = vertical
		box.content_margin_bottom = vertical
		button.add_theme_stylebox_override(state, box)

func _button(text_value: String, callback: Callable, parent: Node) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 38)
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
	_close_tool_menu()
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

func set_terrain_settings(radius: int, step: int, target = null) -> bool:
	if radius not in [0, 1, 2] or step not in [1, 2, 4]: return false
	if target != null and (not World._finite(target) or float(target) != floor(float(target)) or target < World.MIN_TERRAIN_ELEV or target > World.MAX_TERRAIN_ELEV): return false
	if _stroke: end_stroke()
	view._cancel_pointers()
	terrain_settings = {"radius": radius, "step": step, "flatten_target": target}
	_terrain_panel.configure(terrain_settings, selected_tool)
	_update_terrain_summary()
	_layout_shell()
	return true

func _update_terrain_summary() -> void:
	if selected_tool not in TerrainEditor.OPERATIONS: return
	var width: int = int(terrain_settings.radius) * 2 + 1
	var detail: String = "step %s" % terrain_settings.step
	if selected_tool == "flatten": detail = "first tile" if terrain_settings.flatten_target == null else "height %s" % terrain_settings.flatten_target
	_tool_name.text = "%s · %s×%s · %s" % [TOOL_LABELS[selected_tool], width, width, detail]
	_tool_name.tooltip_text = _tool_name.text
	_status.text = _tool_name.text + " · $20 per changed tile. Flat terraces."
	_terrain_panel.configure(terrain_settings, selected_tool)

func _stage_terrain(index: int) -> bool:
	if index < 0 or index >= World.COUNT: return false
	if _terrain_indices.is_empty() and _terrain_stroke_settings.flatten_target == null:
		_terrain_stroke_settings.flatten_target = world.tiles[index].elev
	for cell in TerrainEditor.footprint(index, _terrain_stroke_settings.radius): _terrain_indices[cell] = true
	return true

func _commit_terrain_stroke() -> void:
	var proposal: Dictionary = TerrainEditor.plan(world, _terrain_indices.keys(), selected_tool, _terrain_stroke_settings.step, _terrain_stroke_settings.flatten_target)
	var result: Dictionary = TerrainEditor.commit(world, proposal)
	_last_terrain_changed = result.changed
	if result.changed:
		history.record(result.before, result.after, result.cost)
		_status.text = "%s tiles changed · %s · %s cells skipped." % [proposal.targets.size(), _money(result.cost), proposal.blocked.size()]
	else:
		show_notice(result.reason + (" %s cells skipped: %s." % [proposal.blocked.size(), _terrain_reasons(proposal)] if not proposal.blocked.is_empty() else ""))

func terrain_preview_at(index: int, centers: Array = []) -> Dictionary:
	if index < 0 or index >= World.COUNT or selected_tool not in TerrainEditor.OPERATIONS: return {}
	var stamps: Array = centers if not centers.is_empty() else [index]
	var cells: Dictionary = {}
	for center in stamps:
		for cell in TerrainEditor.footprint(center, terrain_settings.radius): cells[cell] = true
	var target = terrain_settings.flatten_target
	if target == null: target = world.tiles[stamps[0]].elev
	return TerrainEditor.plan(world, cells.keys(), selected_tool, terrain_settings.step, target)

func _terrain_reasons(proposal: Dictionary) -> String:
	var reasons: Dictionary = {}
	for reason in proposal.blocked.values(): reasons[reason] = true
	return ", ".join(reasons.keys())

func _preview_terrain(index: int, centers: Array) -> void:
	view.terrain_preview = terrain_preview_at(index, centers)
	if view.terrain_preview.is_empty(): return
	var p: Dictionary = view.terrain_preview
	_status.text = "%s · %s tiles · %s%s" % [_tool_name.text, p.targets.size(), _money(p.cost), " · insufficient funds; nothing will change" if not p.affordable else ""]
	if not p.blocked.is_empty(): _status.text += " · %s skipped (%s)" % [p.blocked.size(), _terrain_reasons(p)]
