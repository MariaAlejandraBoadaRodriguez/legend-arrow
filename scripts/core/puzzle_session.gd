class_name PuzzleSession
extends RefCounted
## One play-through of a level: taps, undo, restart, hints and completion.
## Pure logic, no nodes; the board view observes it via the returned results.

enum TapResult { REMOVED, BLOCKED, IGNORED }

var level_id: String = ""
var board: PuzzleBoard
var history: Array[String] = []  # removed ids, oldest first
var _solution: Array[String] = []
var _completed := false


func _init(p_level: Dictionary = {}) -> void:
	if p_level.is_empty():
		board = PuzzleBoard.new()
		return
	level_id = str(p_level.get("id", ""))
	board = LevelData.to_board(p_level)
	_solution = LevelData.solution_of(p_level)


## Result: {result: TapResult, id: String, blocker: String}
## A blocked tap changes nothing. Taps after completion are ignored.
func tap(id: String) -> Dictionary:
	if _completed or not board.has_arrow(id):
		return {"result": TapResult.IGNORED, "id": id, "blocker": ""}
	var blocker := board.find_blocker(id)
	if blocker != "":
		return {"result": TapResult.BLOCKED, "id": id, "blocker": blocker}
	board.remove(id)
	history.append(id)
	if board.is_empty():
		_completed = true
	return {"result": TapResult.REMOVED, "id": id, "blocker": ""}


func is_complete() -> bool:
	return _completed


func can_undo() -> bool:
	return not _completed and not history.is_empty()


## Restores the most recently removed arrow. Returns its id, or "" if nothing
## can be undone. A completed level cannot be undone (its reward is final).
func undo() -> String:
	if not can_undo():
		return ""
	var id: String = history.pop_back()
	board.restore(id)
	return id


## Puts every arrow back. Allowed after completion so a level can be replayed;
## rewards are tracked by progression, not by the session.
func restart() -> void:
	board.restore_all()
	history.clear()
	_completed = false


## A currently removable arrow, or "" when none (empty board). Prefers the
## earliest arrow of the certified solution that is free now, so hints follow
## a sensible order; any removable arrow is safe because moves never deadlock.
## Does not change state.
func hint() -> String:
	for id in _solution:
		if board.has_arrow(id) and board.is_removable(id):
			return id
	var free := board.removable_ids()
	return "" if free.is_empty() else free[0]


func progress() -> float:
	if board.total_count() == 0:
		return 0.0
	return float(history.size()) / float(board.total_count())


## Minimal state for saves: which arrows were removed, in order.
func to_dict() -> Dictionary:
	return {"level_id": level_id, "removed": history.duplicate(), "completed": _completed}


## Replays a saved removal history on a fresh session. Every move is re-checked
## so a tampered or stale save cannot produce an illegal board. Returns false
## (leaving the session restarted) if the saved history is invalid.
func apply_saved(state: Dictionary) -> bool:
	restart()
	if str(state.get("level_id", "")) != level_id:
		return false
	var removed = state.get("removed", [])
	if typeof(removed) != TYPE_ARRAY:
		return false
	for id in removed:
		if typeof(id) != TYPE_STRING or tap(id)["result"] != TapResult.REMOVED:
			restart()
			return false
	return true
