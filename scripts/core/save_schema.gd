class_name SaveSchema
extends RefCounted
## Shape, defaults, validation and migration of the local save (see
## docs/SAVE_FORMAT.md). Contains no file IO.
##
## Version history:
##   1 - test-only legacy fixture format (flat "completed_levels" list) used to
##       exercise the migration path; never shipped.
##   2 - first shipped format (v0.1.x: 12 creatures, 24 levels "<creature>_<n>").
##   3 - v0.2: roster ids (docs/ART_PROMPTS.md), one level per dragon whose
##       level id is the dragon id, per-level best_time_ms / best_stars, no
##       language setting. See migrate_v2_to_v3() and D-46.

const VERSION := 3

## v0.1 creature -> v0.2 roster dragon. Same-named ids keep their name; the four
## non-dragon creatures map to a dragon of their old realm (D-46).
const V01_CREATURE_MAP := {
	"forest_drake": "forest_drake", "moon_owl": "fern_wyrmling", "antler_fox": "mossback_drake",
	"basilisk": "basilisk", "wyvern": "wyvern", "arctic_drake": "arctic_drake",
	"griffin": "eagle_wyvern", "cloud_serpent": "cloud_serpent", "stone_wyrm": "stone_wyrm",
	"unicorn": "runeback_dragon", "phoenix": "phoenix_drake", "ancient_dragon": "ancient_dragon",
}


static func defaults() -> Dictionary:
	return {
		"schema_version": VERSION,
		"levels": {},            # level_id -> {"completed": true, "best_time_ms": int, "best_stars": 1..3}
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
	}

## Settings keys that older builds wrote and this build no longer uses.
const OBSOLETE_SETTINGS := ["language"]  # v0.1 language picker (removed, D-41)


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
		out.schema_version = 2
		d = out
		v = 2
	if v == 2:
		d = migrate_v2_to_v3(d)
	return d


## v0.1 (schema 2) -> v0.2 (schema 3). Keeps every bit of earned progress and
## grants nothing twice:
## - a v0.1 creature with ANY completed puzzle -> its roster dragon's single
##   level is completed (1 star, no time: v0.1 had no timer) and the dragon is
##   unlocked; awakening_seen = true, so the update does not queue a string of
##   replays (they stay available from the bestiary);
## - one transaction per new level/unlock, so later play cannot re-grant them;
## - earned ad hints and ad receipts are kept (receipts keep callbacks
##   idempotent); free-hint counters were per old level and are reset;
## - the unfinished v0.1 board is dropped (its layout no longer exists);
## - tutorial status and audio/accessibility settings are kept; language dropped.
static func migrate_v2_to_v3(old: Dictionary) -> Dictionary:
	var out := defaults()
	var dragons := {}   # roster id -> true
	var levels: Dictionary = old.get("levels", {}) if typeof(old.get("levels")) == TYPE_DICTIONARY else {}
	for level_id in levels:
		var rec = levels[level_id]
		if typeof(rec) == TYPE_DICTIONARY and bool(rec.get("completed", false)):
			var cid := _v01_creature_of_level(str(level_id))
			if V01_CREATURE_MAP.has(cid):
				dragons[V01_CREATURE_MAP[cid]] = true
	var creatures: Dictionary = old.get("creatures", {}) if typeof(old.get("creatures")) == TYPE_DICTIONARY else {}
	for cid in creatures:
		var c = creatures[cid]
		if typeof(c) == TYPE_DICTIONARY and bool(c.get("unlocked", false)) and V01_CREATURE_MAP.has(str(cid)):
			dragons[V01_CREATURE_MAP[str(cid)]] = true
	for dragon in dragons:
		out.levels[dragon] = {"completed": true, "best_stars": 1}
		out.transactions["complete:%s" % dragon] = true
		out.creatures[dragon] = {"unlocked": true, "awakening_seen": true}
		out.transactions["unlock:%s" % dragon] = true
	var hints = old.get("hints", {})
	if typeof(hints) == TYPE_DICTIONARY:
		out.hints.ad_entitlements = maxi(0, int(hints.get("ad_entitlements", 0)))
	var receipts = old.get("ad_receipts", {})
	if typeof(receipts) == TYPE_DICTIONARY:
		out.ad_receipts = receipts.duplicate(true)
	out.tutorial_done = bool(old.get("tutorial_done", false))
	var s = old.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		for key in out.settings:
			if s.has(key):
				out.settings[key] = s[key]
	return out


## "forest_drake_2" -> "forest_drake"; "" when it is not a v0.1 level id.
static func _v01_creature_of_level(level_id: String) -> String:
	var i := level_id.rfind("_")
	if i <= 0 or not level_id.substr(i + 1).is_valid_int():
		return ""
	return level_id.substr(0, i)


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
	for level_id in d.levels.keys():
		var rec = d.levels[level_id]
		if typeof(rec) != TYPE_DICTIONARY:
			d.levels.erase(level_id)
			continue
		if rec.has("best_time_ms"):
			var t = rec.best_time_ms
			if typeof(t) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(t)) or float(t) < 0.0:
				rec.erase("best_time_ms")
			else:
				rec.best_time_ms = mini(int(t), SpeedTimer.MAX_ELAPSED_MS)
		if rec.has("best_stars"):
			var st = rec.best_stars
			rec.best_stars = clampi(int(st), 1, 3) if typeof(st) in [TYPE_INT, TYPE_FLOAT] else 1
	var hints: Dictionary = d.hints
	if typeof(hints.get("free_used")) != TYPE_DICTIONARY:
		hints.free_used = {}
	hints.ad_entitlements = maxi(0, int(hints.get("ad_entitlements", 0)))
	var s: Dictionary = d.settings
	for key in OBSOLETE_SETTINGS:
		s.erase(key)
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
