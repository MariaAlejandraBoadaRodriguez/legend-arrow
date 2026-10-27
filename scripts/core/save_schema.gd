class_name SaveSchema
extends RefCounted
## Shape, defaults, validation and migration of the local save (see
## docs/SAVE_FORMAT.md). Contains no file IO.
##
## Version history:
##   1 - test-only legacy fixture format (flat "completed_levels" list) used to
##       exercise the migration path; never shipped.
##   2 - first shipped format.

const VERSION := 2


static func defaults() -> Dictionary:
	return {
		"schema_version": VERSION,
		"levels": {},            # level_id -> {"completed": true}
		"creatures": {},         # creature_id -> {"unlocked": true, "awakening_seen": bool}
		"transactions": {},      # transaction id -> true (idempotent rewards)
		"in_progress": {},       # PuzzleSession.to_dict() of the unfinished level, or {}
		"hints": {"free_used": {}, "ad_entitlements": 0},
		"ad_receipts": {},       # presentation id -> true (M3)
		"tutorial_done": false,
		"settings": default_settings(),
	}


static func default_settings() -> Dictionary:
	return {
		"music_volume": 0.4,
		"sfx_volume": 0.7,
		"creature_volume": 0.9,
		"reduce_motion": false,
		"haptics": true,
		"language": "",  # "" = follow device language
	}


## Upgrades an older save to VERSION. Returns {} if it cannot be migrated.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema_version", 0))
	if v < 1 or v > VERSION:
		return {}
	var d := data.duplicate(true)
	if v == 1:
		var out := defaults()
		for id in d.get("completed_levels", []):
			out.levels[str(id)] = {"completed": true}
			out.transactions["complete:%s" % id] = true
		for id in d.get("unlocked_creatures", []):
			out.creatures[str(id)] = {"unlocked": true, "awakening_seen": true}
			out.transactions["unlock:%s" % id] = true
		out.tutorial_done = bool(d.get("tutorial_done", false))
		d = out
	return d


## Fills missing keys with defaults and drops values of the wrong type, so the
## rest of the game can trust the structure. Returns a list of problems; a
## non-empty list for a top-level type mismatch means "treat as corrupt".
static func sanitize(d: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if int(d.get("schema_version", -1)) != VERSION:
		problems.append("schema_version mismatch")
		return problems
	var def := defaults()
	for key in def:
		if not d.has(key):
			d[key] = def[key]
		elif not _same_kind(d[key], def[key]):
			problems.append("%s has wrong type" % key)
	if not problems.is_empty():
		return problems
	var hints: Dictionary = d.hints
	if typeof(hints.get("free_used")) != TYPE_DICTIONARY:
		hints.free_used = {}
	hints.ad_entitlements = maxi(0, int(hints.get("ad_entitlements", 0)))
	var s: Dictionary = d.settings
	var ds := default_settings()
	for key in ds:
		if not _same_kind(s.get(key), ds[key]):
			s[key] = ds[key]
	for key in ["music_volume", "sfx_volume", "creature_volume"]:
		s[key] = clampf(float(s[key]), 0.0, 1.0)
	return problems


## JSON has a single number type; Godot parses every number as float. Turn
## integral floats back into ints so counters and versions keep their type.
static func ints_from_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_finite(v) and v == floorf(v) and absf(v) < 9.0e15 else v
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = ints_from_json(v[k])
			return out
		TYPE_ARRAY:
			return (v as Array).map(ints_from_json)
	return v


static func _same_kind(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numeric and typeof(b) in numeric:
		return true
	return typeof(a) == typeof(b)
