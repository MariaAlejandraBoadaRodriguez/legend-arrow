class_name PuzzleSession
extends RefCounted
## One play-through of a level: taps, undo, restart, hints and completion.
## Pure logic, no nodes; the board view observes it via the returned results.

enum TapResult { REMOVED, BLOCKED, IGNORED }

var level_id: String = ""
var board: PuzzleBoard
var history: Array[String] = []  # removed ids, oldest first
var timer := SpeedTimer.new()    # starts on the first tap (v0.2 §3)
var hints_used := 0              # hints shown in this attempt (3 stars needs 0)
var par_ms := 0
var _solution: Array[String] = []
var _completed := false


func _init(p_level: Dictionary = {}) -> void:
	if p_level.is_empty():
		board = PuzzleBoard.new()
		return
	level_id = str(p_level.get("id", ""))
	board = LevelData.to_board(p_level)
	_solution = LevelData.solution_of(p_level)
	par_ms = StarRating.par_ms(board.total_count(), PuzzleSolver.dependency_depth(board))


## Result: {result: TapResult, id: String, blocker: String}
## A blocked tap changes nothing. Taps after completion are ignored.
func tap(id: String) -> Dictionary:
	if _completed or not board.has_arrow(id):
		return {"result": TapResult.IGNORED, "id": id, "blocker": ""}
	timer.start()  # any tap on an arrow, blocked or not, starts the clock
	var blocker := board.find_blocker(id)
	if blocker != "":
		return {"result": TapResult.BLOCKED, "id": id, "blocker": blocker}
	board.remove(id)
	history.append(id)
	if board.is_empty():
		_completed = true
		timer.finish()
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
	timer.reset()
	hints_used = 0


## Called when a hint is actually shown to the player.
func note_hint_shown() -> void:
	hints_used += 1


func elapsed_ms() -> int:
	return timer.elapsed_ms


func stars() -> int:
	return StarRating.stars(timer.elapsed_ms, par_ms, hints_used)


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
	return {"level_id": level_id, "removed": history.duplicate(), "completed": _completed,
		"elapsed_ms": timer.elapsed_ms, "timer_started": timer.started, "hints_used": hints_used}


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
	# Replaying the moves started the clock; the saved time is the truth.
	timer.from_dict({"elapsed_ms": state.get("elapsed_ms", 0),
		"started": bool(state.get("timer_started", false)) or not history.is_empty()})
	var h = state.get("hints_used", 0)
	hints_used = clampi(int(h), 0, 1000) if typeof(h) in [TYPE_INT, TYPE_FLOAT] else 0
	if _completed:
		timer.finish()
	return true
