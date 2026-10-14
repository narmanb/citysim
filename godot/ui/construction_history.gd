extends RefCounted
## Construction-only history. Calendar, economy income and agents are never restored.

const LIMIT: int = 40
var undo_stack: Array = []
var redo_stack: Array = []
var active: Dictionary = {}

func begin() -> void:
	if active.is_empty():
		active = {"before": {}, "after": {}, "spent": 0.0}

func record(before: Dictionary, after: Dictionary, spent: float) -> void:
	if active.is_empty():
		begin()
	for index in before:
		if before[index] == after[index]:
			continue
		if not active.before.has(index):
			active.before[index] = before[index].duplicate(true)
		active.after[index] = after[index].duplicate(true)
	active.spent += spent

func finish() -> bool:
	if active.is_empty():
		return false
	var action: Dictionary = active
	active = {}
	if action.before.is_empty():
		return false
	undo_stack.append(action)
	if undo_stack.size() > LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	return true

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
	active = {}

func undo(world) -> bool:
	finish()
	if undo_stack.is_empty():
		return false
	var action: Dictionary = undo_stack.pop_back()
	for index in action.before:
		world.tiles[index] = action.before[index].duplicate(true)
	world.cash += action.spent
	redo_stack.append(action)
	world.recalculate()
	return true

func redo(world) -> bool:
	finish()
	if redo_stack.is_empty():
		return false
	var action: Dictionary = redo_stack.back()
	if world.cash < action.spent:
		return false
	redo_stack.pop_back()
	for index in action.after:
		world.tiles[index] = action.after[index].duplicate(true)
	world.cash -= action.spent
	undo_stack.append(action)
	world.recalculate()
	return true
