extends VBoxContainer
const World = preload("res://model/city_world.gd")
## Session preferences only; never serialized into a city.
signal settings_changed(radius: int, step: int, flatten_target)
signal shape_settings_changed(shape: String, direction: String, strength: int)
var settings: Dictionary = {"radius": 0, "step": 1, "flatten_target": null}
var _steps: Dictionary = {}
var _brushes: Dictionary = {}
var _step_row: HBoxContainer
var _flatten_row: HBoxContainer
var _target_mode: OptionButton
var _target_level: SpinBox
var _syncing: bool = false
var _shape_row: HBoxContainer
var _slope_row: HBoxContainer
var _shape: OptionButton
var _direction: OptionButton
var _strength: OptionButton

func _ready() -> void:
	name = "TerrainSettings"
	add_theme_constant_override("separation", 3)
	var common := HBoxContainer.new()
	common.add_theme_constant_override("separation", 5)
	add_child(common)
	_step_row = HBoxContainer.new()
	common.add_child(_step_row)
	_label("Height step ", _step_row)
	for value in [1, 2, 4]:
		_steps[value] = _choice(str(value), func(): settings_changed.emit(settings.radius, value, settings.flatten_target), _step_row)
	_label("   Brush ", common)
	for radius in [0, 1, 2]:
		var width: int = radius * 2 + 1
		_brushes[radius] = _choice("%s×%s" % [width, width], func(): settings_changed.emit(radius, settings.step, settings.flatten_target), common)
	_flatten_row = HBoxContainer.new()
	add_child(_flatten_row)
	_label("Flatten target ", _flatten_row)
	_target_mode = OptionButton.new()
	_target_mode.name = "FlattenTargetMode"
	_target_mode.add_item("First touched tile")
	_target_mode.add_item("Set height")
	_target_mode.custom_minimum_size.y = 34
	_flatten_row.add_child(_target_mode)
	_target_level = SpinBox.new()
	_target_level.name = "FlattenHeight"
	_target_level.min_value = World.MIN_TERRAIN_ELEV
	_target_level.max_value = World.MAX_TERRAIN_ELEV
	_target_level.step = 1
	_target_level.custom_minimum_size = Vector2(85, 34)
	_flatten_row.add_child(_target_level)
	_target_mode.item_selected.connect(func(which):
		if not _syncing: settings_changed.emit(settings.radius, settings.step, null if which == 0 else int(_target_level.value)))
	_target_level.value_changed.connect(func(value):
		if not _syncing: settings_changed.emit(settings.radius, settings.step, int(value)))
	_shape_row = HBoxContainer.new()
	common.add_child(_shape_row)
	_label("  Shape ",_shape_row)
	_shape = _option(["Flat","Sloped","Cliff"],_shape_row,"TerrainShape")
	_shape.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(["flat","slope","cliff"][which],settings.get("direction","auto"),settings.get("strength",1)))
	_slope_row = HBoxContainer.new()
	add_child(_slope_row)
	_label("High edge ",_slope_row)
	_direction = _option(["Auto","N","E","S","W"],_slope_row,"SlopeDirection")
	_direction.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(settings.get("shape","flat"),["auto","N","E","S","W"][which],settings.get("strength",1)))
	_label("  Shape strength ",_slope_row)
	_strength = _option(["Gentle","Medium","Steep"],_slope_row,"ShapeStrength")
	_strength.item_selected.connect(func(which):
		if not _syncing: shape_settings_changed.emit(settings.get("shape","flat"),settings.get("direction","auto"),which+1))
	var note := Label.new()
	note.text = "$20 per changed tile · protected cells skipped · flatten before building"
	note.add_theme_font_size_override("font_size", 11)
	add_child(note)
	configure(settings, "raise")

func configure(value: Dictionary, operation: String) -> void:
	settings = value.duplicate()
	if not is_node_ready(): return
	_syncing = true
	_step_row.visible = operation in ["raise","lower"]
	_shape_row.visible = operation != "flatten"
	_slope_row.visible = operation != "flatten" and settings.get("shape","flat") == "slope"
	_shape.select(["flat","slope","cliff"].find(settings.get("shape","flat")))
	_direction.select(["auto","N","E","S","W"].find(settings.get("direction","auto")))
	_strength.select(settings.get("strength",1)-1)
	_flatten_row.visible = operation == "flatten"
	for key in _steps: _steps[key].button_pressed = key == settings.step
	for key in _brushes: _brushes[key].button_pressed = key == settings.radius
	_target_mode.select(0 if settings.flatten_target == null else 1)
	_target_level.visible = settings.flatten_target != null
	if settings.flatten_target != null: _target_level.value = settings.flatten_target
	_syncing = false

func _label(text: String, parent: Node) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _choice(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(40, 34)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _option(labels: Array, parent: Node, node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.custom_minimum_size.y = 34
	for text in labels: option.add_item(text)
	parent.add_child(option)
	return option
