extends Label
## Rendered-frame rate averaged over real elapsed time, independently of simulation delta.

const SAMPLE_INTERVAL_USEC: int = 750000
const PENDING_TEXT: String = "-- FPS · -- ms"

var _last_frame_usec: int = -1
var _sample_elapsed_usec: int = 0
var _sample_frame_count: int = 0
var _suspended: bool = false

func _init() -> void:
	name = "PerformanceDisplay"
	text = PENDING_TEXT
	z_index = 3900
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clip_text = true
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Color("e9f1e8"))
	var background = StyleBoxFlat.new()
	background.bg_color = Color("11212ddc")
	background.border_color = Color("55707c")
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	background.content_margin_left = 6
	background.content_margin_right = 6
	background.content_margin_top = 3
	background.content_margin_bottom = 3
	add_theme_stylebox_override("normal", background)

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)

func _exit_tree() -> void:
	RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		_reset_sample()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_suspended = false
		_reset_sample()

func _on_frame_post_draw() -> void:
	_record_frame(Time.get_ticks_usec())

func _record_frame(at_usec: int) -> void:
	if _suspended:
		return
	if _last_frame_usec < 0:
		_last_frame_usec = at_usec
		return
	var elapsed_usec: int = at_usec - _last_frame_usec
	if elapsed_usec <= 0:
		return
	_last_frame_usec = at_usec
	# Foreground stalls remain in the sample; only application lifecycle events reset it.
	_sample_elapsed_usec += elapsed_usec
	_sample_frame_count += 1
	if _sample_elapsed_usec < SAMPLE_INTERVAL_USEC:
		return
	var fps: float = float(_sample_frame_count) * 1000000.0 / _sample_elapsed_usec
	var frame_ms: float = float(_sample_elapsed_usec) / _sample_frame_count / 1000.0
	text = "%.1f FPS · %.1f ms" % [fps, frame_ms]
	_sample_elapsed_usec = 0
	_sample_frame_count = 0

func _reset_sample() -> void:
	_last_frame_usec = -1
	_sample_elapsed_usec = 0
	_sample_frame_count = 0
	text = PENDING_TEXT
