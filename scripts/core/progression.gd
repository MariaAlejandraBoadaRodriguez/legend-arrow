class_name Progression
extends RefCounted
## Campaign rules over the save dictionary: unlocks, idempotent rewards and the
## hint wallet. Pure logic; persisting `data` is the caller's job.

const FREE_HINTS_PER_LEVEL := 3

var campaign: Campaign
var data: Dictionary


func _init(p_campaign: Campaign, p_data: Dictionary) -> void:
	campaign = p_campaign
	data = p_data


func is_level_completed(level_id: String) -> bool:
	return data.levels.has(level_id) and bool(data.levels[level_id].get("completed", false))


## First creature's first level is always open; a creature's second level opens
## after its first; the next creature opens once the previous one is unlocked.
func is_level_unlocked(level_id: String) -> bool:
	var cid := campaign.creature_of_level(level_id)
	if cid == "":
		return false
	var slot := campaign.level_slot(level_id)
	if slot == 1:
		return is_level_completed(campaign.creature(cid).levels[0])
	var idx := campaign.creature_index(cid)
	return idx == 0 or is_creature_unlocked(campaign.creatures[idx - 1].id)


func is_creature_unlocked(cid: String) -> bool:
	return data.creatures.has(cid) and bool(data.creatures[cid].get("unlocked", false))


## Number of the creature's puzzles completed (0..2).
func creature_progress(cid: String) -> int:
	var n := 0
	for l in campaign.creature(cid).get("levels", []):
		if is_level_completed(l):
			n += 1
	return n


func unlocked_count() -> int:
	var n := 0
	for cid in campaign.creature_ids():
		if is_creature_unlocked(cid):
			n += 1
	return n


## Records a completed level exactly once. Replays and duplicate calls return
## first_completion = false and never unlock twice.
## Result: {first_completion: bool, unlocked_creature: String}
func complete_level(level_id: String) -> Dictionary:
	var result := {"first_completion": false, "unlocked_creature": ""}
	var cid := campaign.creature_of_level(level_id)
	if cid == "" or not is_level_unlocked(level_id):
		return result
	if data.in_progress.get("level_id", "") == level_id:
		data.in_progress = {}
	var tx := "complete:%s" % level_id
	if not data.transactions.has(tx):
		data.transactions[tx] = true
		var rec: Dictionary = data.levels.get(level_id, {})
		rec.completed = true
		data.levels[level_id] = rec
		result.first_completion = true
	var unlock_tx := "unlock:%s" % cid
	if creature_progress(cid) == 2 and not data.transactions.has(unlock_tx):
		data.transactions[unlock_tx] = true
		data.creatures[cid] = {"unlocked": true, "awakening_seen": false}
		result.unlocked_creature = cid
	return result


## Records one finished run's time and stars (v0.2 §3). Bests only improve:
## a slower or lower-star replay changes nothing. Only completed levels keep a
## record, so call after complete_level(). Calling twice with the same run is
## harmless. Result: {stars, best_time_ms, best_stars, new_record,
## first_record, previous_best_ms}; previous_best_ms is -1 when none existed.
func record_result(level_id: String, time_ms: int, stars: int) -> Dictionary:
	var out := {"stars": clampi(stars, 1, 3), "best_time_ms": -1, "best_stars": 0,
		"new_record": false, "first_record": false, "previous_best_ms": -1}
	if not is_level_completed(level_id):
		return out
	var t := clampi(time_ms, 0, SpeedTimer.MAX_ELAPSED_MS)
	var rec: Dictionary = data.levels[level_id]
	var prev := int(rec.get("best_time_ms", -1))
	out.previous_best_ms = prev
	if prev < 0:
		rec.best_time_ms = t
		out.first_record = true
	elif t < prev:
		rec.best_time_ms = t
		out.new_record = true
	rec.best_stars = maxi(int(rec.get("best_stars", 0)), out.stars)
	out.best_time_ms = int(rec.best_time_ms)
	out.best_stars = int(rec.best_stars)
	return out


func best_time_ms(level_id: String) -> int:
	return int(data.levels.get(level_id, {}).get("best_time_ms", -1))


## 0 = never completed; a v0.1 level migrated without a time counts as 1 star.
func best_stars(level_id: String) -> int:
	if not is_level_completed(level_id):
		return 0
	return clampi(int(data.levels[level_id].get("best_stars", 1)), 1, 3)


func stars_in(level_ids: Array) -> int:
	var n := 0
	for l in level_ids:
		n += best_stars(l)
	return n


func total_stars() -> int:
	return stars_in(campaign.level_ids())


func mark_awakening_seen(cid: String) -> void:
	if is_creature_unlocked(cid):
		data.creatures[cid].awakening_seen = true


## Creature whose awakening was earned but never finished playing (e.g. the app
## was killed mid-animation). The awakening replays; the unlock is not re-granted.
func pending_awakening() -> String:
	for cid in campaign.creature_ids():
		if is_creature_unlocked(cid) and not bool(data.creatures[cid].get("awakening_seen", false)):
			return cid
	return ""


## First unlocked, not yet completed level in campaign order, or "".
func next_level() -> String:
	for l in campaign.level_ids():
		if is_level_unlocked(l) and not is_level_completed(l):
			return l
	return ""


func save_in_progress(session: PuzzleSession) -> void:
	data.in_progress = {} if session.is_complete() else session.to_dict()


# --- hints -----------------------------------------------------------------

func free_hints_left(level_id: String) -> int:
	return maxi(0, FREE_HINTS_PER_LEVEL - int(data.hints.free_used.get(level_id, 0)))


func ad_hints_available() -> int:
	return int(data.hints.ad_entitlements)


## Spends one hint: free hints first, then ad-earned ones.
## Returns "free", "ad" or "" (nothing to spend).
func spend_hint(level_id: String) -> String:
	if free_hints_left(level_id) > 0:
		data.hints.free_used[level_id] = int(data.hints.free_used.get(level_id, 0)) + 1
		return "free"
	if data.hints.ad_entitlements > 0:
		data.hints.ad_entitlements -= 1
		return "ad"
	return ""


## Grants one hint for an earned-reward callback. Idempotent per presentation
## id, so duplicate or late callbacks cannot grant twice. Returns true if granted.
func grant_ad_hint(presentation_id: String) -> bool:
	if presentation_id == "" or data.ad_receipts.has(presentation_id):
		return false
	data.ad_receipts[presentation_id] = true
	data.hints.ad_entitlements += 1
	return true
