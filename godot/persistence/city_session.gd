extends RefCounted
## A separate automatic checkpoint; manual city.json remains the player's slot.
const Store = preload("res://persistence/city_store.gd")
var path: String
var message: String = ""
var enabled: bool = true
var _generation: int = 0
var _saved: int = 0
var _job_generation: int = 0
var _thread: Thread
var _elapsed: float = 0

func _init(save_path: String = "user://resume-city.json"):
	path = save_path

func restore():
	message = ""
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var result = Store.decode_json(FileAccess.get_file_as_string(candidate))
		if result.world != null:
			if candidate.ends_with(".bak"): message = "Recovered your last city from backup."
			return result.world
	# Preserve all unreadable bytes before allowing replacement. Never overwrite
	# an earlier recovery copy; support diagnoses and later manual recovery.
	var preserved: bool = false
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var destination: String = candidate + ".recovery"
		var number: int = 1
		while FileAccess.file_exists(destination):
			destination = candidate + ".recovery-" + str(number)
			number += 1
		var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(candidate), ProjectSettings.globalize_path(destination))
		if error != OK:
			enabled = false
			message = "Could not recover the last city. Automatic saving is disabled to protect its files."
			return null
		preserved = true
	if preserved: message = "Last city could not load; damaged files were preserved for recovery."
	return null

func mark_dirty() -> void:
	_generation += 1

func update(world, delta: float, editing: bool = false) -> void:
	_poll()
	_elapsed += maxf(0, delta)
	if _elapsed >= 15 and not editing: checkpoint(world)

func checkpoint(world) -> void:
	_poll()
	if not enabled or world == null or _thread != null or _generation == _saved: return
	var snapshot: Dictionary = world.serialize()
	_job_generation = _generation
	_elapsed = 0
	_thread = Thread.new()
	var error = _thread.start(Store.write_snapshot.bind(snapshot, path))
	if error != OK:
		_thread = null
		message = "Automatic checkpoint could not start."

func _poll(wait: bool = false) -> void:
	if _thread == null or (_thread.is_alive() and not wait): return
	var result = _thread.wait_to_finish()
	_thread = null
	if result.code == OK: _saved = _job_generation
	message = result.message

func flush(world) -> Error:
	_poll(true)
	if not enabled: return ERR_CANT_CREATE
	if world == null or _saved == _generation: return OK
	var result = Store.write_snapshot(world.serialize(), path)
	message = result.message
	if result.code == OK: _saved = _generation
	return result.code
