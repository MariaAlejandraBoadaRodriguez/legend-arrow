class_name EventLog
extends RefCounted
## Local, in-memory analytics-style events (spec §17). Nothing is uploaded.
## Only whitelisted names and scalar properties are kept; no identifiers,
## free text or tap streams.

const ALLOWED := ["tutorial_complete", "level_start", "blocked_tap", "level_complete",
	"creature_unlock", "hint_requested", "ad_result", "save_recovery"]
const MAX_EVENTS := 200

var events: Array[Dictionary] = []


func log_event(name: String, props: Dictionary = {}) -> bool:
	if not ALLOWED.has(name):
		push_warning("EventLog: dropped unknown event '%s'" % name)
		return false
	var clean := {}
	for k in props:
		var v = props[k]
		if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] or (typeof(v) == TYPE_STRING and (v as String).length() <= 40):
			clean[str(k)] = v
	events.append({"name": name, "props": clean})
	if events.size() > MAX_EVENTS:
		events.pop_front()
	return true


func count(name: String) -> int:
	return events.filter(func(e): return e.name == name).size()


func clear() -> void:
	events.clear()
