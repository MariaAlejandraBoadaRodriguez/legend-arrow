class_name SpeedTimer
extends RefCounted
## Puzzle speed timer (v0.2 §3). Pure logic, driven by tick(delta_ms) from the
## puzzle screen, so tests control time exactly.
##
## - Starts on the first tap (start()), never by itself.
## - Runs only while started, not finished and no hold is active. Holds are
##   named reasons (pause menu, overlay, background, ad, awakening); any one
##   of them stops the clock, and the clock resumes once all are released.
## - A single tick adds at most MAX_TICK_MS, so a suspended app, a debugger
##   stop or a clock jump can never add an absurd amount of time.
## - Elapsed time is clamped to [0, MAX_ELAPSED_MS] and survives kill/relaunch
##   through to_dict()/from_dict().

const MAX_TICK_MS := 250
const MAX_ELAPSED_MS := 10 * 60 * 60 * 1000  # 10 h

var elapsed_ms := 0
var started := false
var finished := false
var _holds: Dictionary = {}   # reason -> true


func start() -> void:
	if not finished:
		started = true


func is_running() -> bool:
	return started and not finished and _holds.is_empty()


func hold(reason: String, on: bool = true) -> void:
	if on:
		_holds[reason] = true
	else:
		_holds.erase(reason)


func is_held(reason: String = "") -> bool:
	return not _holds.is_empty() if reason == "" else _holds.has(reason)


func holds() -> Array:
	return _holds.keys()


## Adds `delta_ms` if running. Negative or non-finite deltas add nothing.
func tick(delta_ms: float) -> void:
	if not is_running() or is_nan(delta_ms) or delta_ms <= 0.0:
		return
	elapsed_ms = mini(MAX_ELAPSED_MS, elapsed_ms + mini(MAX_TICK_MS, int(round(delta_ms))))


## Stops the clock for good (level complete). Returns the final time.
func finish() -> int:
	finished = true
	return elapsed_ms


## A fresh attempt (restart): back to 0, waiting for the first tap. Holds stay,
## because they describe the screen, not the attempt.
func reset() -> void:
	elapsed_ms = 0
	started = false
	finished = false


func to_dict() -> Dictionary:
	return {"elapsed_ms": elapsed_ms, "started": started}


## Restores a saved timer. Invalid values (wrong type, negative, huge) are
## clamped, never trusted.
func from_dict(d: Dictionary) -> void:
	var e = d.get("elapsed_ms", 0)
	elapsed_ms = clampi(int(e), 0, MAX_ELAPSED_MS) if typeof(e) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(e)) else 0
	started = bool(d.get("started", false)) and elapsed_ms >= 0
	finished = false


## "m:ss" below an hour, "h:mm:ss" above; tenths are not shown.
static func format_ms(ms: int) -> String:
	var s := maxi(0, ms) / 1000
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
