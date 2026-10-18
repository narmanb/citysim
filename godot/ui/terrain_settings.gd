extends VBoxContainer
const World = preload("res://model/city_world.gd")
## Compact session controls shared by every height/shape tool.
signal settings_changed(radius: int, step: int, flatten_target)
signal shape_settings_changed(shape: String, direction: String, strength: int)
signal sculpt_settings_changed(values: Dictionary)
var settings: Dictionary = {"radius": 0, "step": 1, "flatten_target": null}
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
	var peak_row := _row("Absolute peak height")
	_preset_rows.append(peak_row)
	_label("Peak",peak_row)
	_peak = SpinBox.new()
	_peak.name="PresetPeak"
	_peak.min_value=World.MIN_TERRAIN_ELEV;_peak.max_value=World.MAX_TERRAIN_ELEV;_peak.step=1
	_peak.custom_minimum_size=Vector2(76,32);_peak.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	peak_row.add_child(_peak)
	_peak.value_changed.connect(func(value):
		if not _syncing: sculpt_settings_changed.emit({_operation+"_peak":int(value)}))
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
	configure(settings, "raise")

func configure(value: Dictionary, operation: String) -> void:
	settings = value.duplicate()
	_operation = operation
	if not is_node_ready(): return
	_syncing = true
	_step_row.visible = operation in ["raise", "lower"]
	_shape_row.visible = operation in ["raise","lower","shape"]
	var preset: bool = operation in ["hill","mountain"]
	_brush_row.visible = not preset
	_smooth_row.visible = operation=="smooth"
	_smooth_strength.select(settings.get("smooth_strength",2)-1)
	for row in _preset_rows: row.visible=preset
	_preset_size.select([1,2,4].find(settings.get("preset_radius",2)))
	_profile.select(settings.get("profile",2)-1)
	_preset_shape.select(1 if settings.get("preset_shape","rounded")=="cliff" else 0)
	if preset: _peak.value=settings.get(operation+"_peak",12 if operation=="mountain" else 6)
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
