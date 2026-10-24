extends VBoxContainer
const World = preload("res://model/city_world.gd")
## Compact session controls shared by every height/shape tool.
signal appearance_requested
signal settings_changed(radius: int, step: int, flatten_target)
signal shape_settings_changed(shape: String, direction: String, strength: int)
signal sculpt_settings_changed(values: Dictionary)
var settings: Dictionary = {"radius": 0, "step": 1, "flatten_target": null}
var _appearance_rows: Array = []
var _top: OptionButton
var _rock: OptionButton
var _steps: Dictionary = {}
var _step_row: HBoxContainer
var _flatten_row: HBoxContainer
var _height_row: HBoxContainer
var _target_mode: OptionButton
var _target_level: SpinBox
var _brush_row: HBoxContainer
var _smooth_row: HBoxContainer
var _smooth_strength: OptionButton
var _preset_rows: Array = []
var _preset_size: OptionButton
var _peak_button: Button
var _peak_popup: ConfirmationDialog
var _peak_operation: String
var _peak: SpinBox
var _preset_shape: OptionButton
var _profile: OptionButton
var _operation: String = "raise"
var _brush: OptionButton
var _syncing: bool = false
var _shape_row: HBoxContainer
var _slope_row: HBoxContainer
var _shape: OptionButton
var _direction: OptionButton
var _strength: OptionButton
var _edges_row: HBoxContainer
var _edges: OptionButton

func _ready() -> void:
	name = "TerrainSettings"
	add_theme_constant_override("separation", 2)
	_step_row = _row("Height step")
	_label("Step", _step_row)
	for value in [1, 2, 4]:
		var button := Button.new()
		button.text = str(value)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(27, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Height step: %s" % value
		button.pressed.connect(func(): settings_changed.emit(settings.radius, value, settings.flatten_target))
		_step_row.add_child(button)
		_steps[value] = button
	_brush_row = _row("Brush size")
	_label("Brush", _brush_row)
	_brush = _option(["1×1", "3×3", "5×5"], _brush_row, "TerrainBrush")
	_brush.item_selected.connect(func(which):
		if not _syncing: settings_changed.emit(which, settings.step, settings.flatten_target))
	_appearance_button(_brush_row,"TerrainAppearanceButton")
	_flatten_row = _row("Flatten target")
	_label("Target", _flatten_row)
	_target_mode = _option(["First tile", "Set height"], _flatten_row, "FlattenTargetMode")
	_height_row = _row("Explicit Flatten height")
	_label("Height", _height_row)
	_target_level = SpinBox.new()
	_target_level.name = "FlattenHeight"
	_target_level.min_value = World.MIN_TERRAIN_ELEV
	_target_level.max_value = World.MAX_TERRAIN_ELEV
	_target_level.step = 1
	_live_integer(_target_level)
	_target_level.custom_minimum_size = Vector2(76, 32)
	_target_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_height_row.add_child(_target_level)
	_target_mode.item_selected.connect(func(which):
		if not _syncing: settings_changed.emit(settings.radius, settings.step, null if which == 0 else int(_target_level.value)))
	_target_level.value_changed.connect(func(value):
		if not _syncing: settings_changed.emit(settings.radius, settings.step, int(value)))
	_shape_row = _row("Terrain shape")
	_label("Shape", _shape_row)
	_shape = _option(["Flat", "Sloped", "Cliff", "Rounded"], _shape_row, "TerrainShape")
	_shape.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(["flat", "slope", "cliff", "rounded"][which], settings.get("direction", "auto"), settings.get("strength", 1)))
	_edges_row=_row("Keep the top level and grade its perimeter into clear ground; preview includes transition cost")
	_label("Edges",_edges_row)
	_edges=_option(["Sharp","Smooth"],_edges_row,"TerrainEdges")
	_edges.item_selected.connect(func(which):
		if not _syncing:sculpt_settings_changed.emit({"smooth_edges":which==1}))
	_slope_row = _row("Slope direction and strength")
	var edge := VBoxContainer.new()
	edge.add_theme_constant_override("separation", 0)
	edge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slope_row.add_child(edge)
	_label("High edge", edge)
	_direction = _option(["Auto", "N", "E", "S", "W"], edge, "SlopeDirection")
	_direction.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(settings.get("shape", "flat"), ["auto", "N", "E", "S", "W"][which], settings.get("strength", 1)))
	var strength := VBoxContainer.new()
	strength.add_theme_constant_override("separation", 0)
	strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slope_row.add_child(strength)
	_label("Strength", strength)
	_strength = _option(["Gentle", "Medium", "Steep"], strength, "ShapeStrength")
	_strength.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(settings.get("shape", "flat"), settings.get("direction", "auto"), which + 1))
	_smooth_row = _row("Smoothing strength")
	_label("Strength",_smooth_row)
	_smooth_strength = _option(["Gentle","Medium","Strong"],_smooth_row,"SmoothStrength")
	_smooth_strength.item_selected.connect(func(which):
		if not _syncing: sculpt_settings_changed.emit({"smooth_strength":which+1}))
	var size_row := _row("Preset footprint")
	_preset_rows.append(size_row)
	_label("Size",size_row)
	_preset_size = _option(["3×3","5×5","9×9"],size_row,"PresetSize")
	_preset_size.item_selected.connect(func(which):
		if not _syncing: sculpt_settings_changed.emit({"preset_radius":[1,2,4][which]}))
	_appearance_button(size_row,"PresetAppearanceButton")
	var peak_row := _row("Absolute summit elevation, not height added. Higher existing ground is preserved.")
	_preset_rows.append(peak_row)
	_label("Peak",peak_row)
	_peak_button=Button.new()
	_peak_button.name="PeakPickerButton"
	_peak_button.custom_minimum_size=Vector2(76,32)
	_peak_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_peak_button.pressed.connect(_show_peak_picker)
	peak_row.add_child(_peak_button)
	_peak_popup=ConfirmationDialog.new()
	_peak_popup.name="PeakPicker"
	_peak_popup.title="Choose peak elevation"
	_peak_popup.ok_button_text="Apply custom"
	add_child(_peak_popup)
	var choices:=VBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	_peak_popup.add_child(choices)
	var hint:=Label.new();hint.text="Absolute elevation · maximum 40"
	choices.add_child(hint)
	var grid:=GridContainer.new();grid.columns=5
	choices.add_child(grid)
	for height in [1,4,8,12,16,20,25,30,35,40]:
		var choice:=Button.new();choice.text=str(height);choice.name="PeakPreset"+str(height)
		choice.custom_minimum_size=Vector2(48,44)
		choice.pressed.connect(func():
			_peak_popup.hide()
			sculpt_settings_changed.emit({_peak_operation+"_peak":height}))
		grid.add_child(choice)
	var custom:=HBoxContainer.new();choices.add_child(custom)
	_label("Custom",custom)
	_peak=SpinBox.new();_peak.name="PresetPeak"
	_peak.min_value=World.MIN_TERRAIN_ELEV;_peak.max_value=World.MAX_TERRAIN_ELEV;_peak.step=1
	_peak.custom_minimum_size=Vector2(120,44);_peak.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_live_integer(_peak);custom.add_child(_peak)
	_peak_popup.confirmed.connect(func():
		_peak_popup.hide()
		sculpt_settings_changed.emit({_peak_operation+"_peak":int(_peak.value)}))
	var preset_shape_row := _row("Preset terrain shape")
	_preset_rows.append(preset_shape_row)
	_label("Shape",preset_shape_row)
	_preset_shape = _option(["Rounded","Cliff"],preset_shape_row,"PresetShape")
	_preset_shape.item_selected.connect(func(which):
		if not _syncing: sculpt_settings_changed.emit({"preset_shape":["rounded","cliff"][which]}))
	var profile_row := _row("Radial falloff profile")
	_preset_rows.append(profile_row)
	_label("Profile",profile_row)
	_profile = _option(["Broad","Balanced","Sharp"],profile_row,"PresetProfile")
	_profile.item_selected.connect(func(which):
		if not _syncing: sculpt_settings_changed.emit({"profile":which+1}))
	var top_row := _row("Summit material")
	_appearance_rows.append(top_row);_label("Top",top_row)
	_top=_option(["Biome","Grass","Sand","Rock","Snow"],top_row,"SurfaceTop")
	_top.item_selected.connect(func(which):
		if not _syncing:sculpt_settings_changed.emit({"surface_top":World.Surfaces.TOPS[which]}))
	var rock_row := _row("Exposed slope material")
	_appearance_rows.append(rock_row);_label("Slopes",rock_row)
	_rock=_option(["Brown rock","Gray rock","Sand","Grass"],rock_row,"SurfaceRock")
	_rock.item_selected.connect(func(which):
		if not _syncing:sculpt_settings_changed.emit({"surface_rock":World.Surfaces.ROCKS[which]}))
	configure(settings, "raise")

func _show_peak_picker() -> void:
	_peak_operation=_operation
	_peak.value=settings.get(_operation+"_peak",12 if _operation=="mountain" else 6)
	_peak_popup.popup_centered(Vector2i(300,220))

func configure(value: Dictionary, operation: String) -> void:
	settings = value.duplicate()
	_operation = operation
	if not is_node_ready(): return
	_syncing = true
	for row in _appearance_rows:row.visible=operation=="surface"
	_top.select(World.Surfaces.TOPS.find(settings.get("surface_top","auto")))
	_rock.select(World.Surfaces.ROCKS.find(settings.get("surface_rock","brown")))
	_step_row.visible = operation in ["raise", "lower"]
	var graded: bool=operation in ["raise","lower"] and settings.get("smooth_edges",false)
	_shape_row.visible = operation in ["raise","lower","shape"] and not graded
	_edges_row.visible=operation in ["raise","lower"] and (settings.get("shape","flat")=="flat" or graded)
	_edges.select(1 if settings.get("smooth_edges",false) else 0)
	var preset: bool = operation in ["hill","mountain"]
	_brush_row.visible = not preset
	_smooth_row.visible = operation=="smooth"
	_smooth_strength.select(settings.get("smooth_strength",2)-1)
	for row in _preset_rows: row.visible=preset
	_preset_size.select([1,2,4].find(settings.get("preset_radius",2)))
	_profile.select(settings.get("profile",2)-1)
	_preset_shape.select(1 if settings.get("preset_shape","rounded")=="cliff" else 0)
	if preset: _peak_button.text=str(settings.get(operation+"_peak",12 if operation=="mountain" else 6))+" ▾"
	if _peak_popup.visible and (not preset or operation!=_peak_operation):_peak_popup.hide()
	_slope_row.visible = operation in ["raise","lower","shape"] and settings.get("shape", "flat") == "slope"
	_shape.select(["flat", "slope", "cliff", "rounded"].find(settings.get("shape", "flat")))
	_direction.select(["auto", "N", "E", "S", "W"].find(settings.get("direction", "auto")))
	_strength.select(settings.get("strength", 1) - 1)
	_flatten_row.visible = operation == "flatten"
	_height_row.visible = operation == "flatten" and settings.flatten_target != null
	for key in _steps: _steps[key].button_pressed = key == settings.step
	_brush.select(settings.radius)
	_target_mode.select(0 if settings.flatten_target == null else 1)
	if settings.flatten_target != null: _target_level.value = settings.flatten_target
	_syncing = false

# Keep complete typed heights authoritative before a map tap, while allowing
# incomplete negative input ("-") to remain editable until its digit arrives.
func _live_integer(spin: SpinBox) -> void:
	var edit: LineEdit = spin.get_line_edit()
	edit.text_changed.connect(func(text: String):
		if _syncing or not text.is_valid_int(): return
		var value: int = clampi(text.to_int(),int(spin.min_value),int(spin.max_value))
		if text.to_int()!=value:
			edit.text=str(value)
			edit.caret_column=edit.text.length()
		spin.value=value)

func _row(description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.tooltip_text = description
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	return row

func _label(text: String, parent: Node) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(label)

func _option(labels: Array, parent: Node, node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.custom_minimum_size.y = 32
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 11)
	for text in labels: option.add_item(text)
	parent.add_child(option)
	return option

func _appearance_button(parent: Node, node_name: String) -> void:
	var button:=Button.new()
	button.name=node_name;button.text="…";button.tooltip_text="Terrain surface materials"
	button.custom_minimum_size=Vector2(26,32)
	button.pressed.connect(func():appearance_requested.emit())
	parent.add_child(button)
