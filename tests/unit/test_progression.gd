extends GutTest
## Unlock rules, idempotent rewards and hint wallet.

var p: Progression


func before_each() -> void:
	var res := Campaign.from_dict({
		"schema_version": 2,
		"worlds": [{"id": "mistwood", "name_key": "WORLD_W01"}],
		"dragons": [
			{"id": "drake", "world": "mistwood", "name_key": "X", "levels": ["d1", "d2"]},
			{"id": "owl", "world": "mistwood", "name_key": "Y", "levels": ["o1", "o2"]},
		],
	})
	assert_eq(res.errors, [] as Array[String])
	p = Progression.new(res.campaign, SaveSchema.defaults())


func test_initial_unlocks() -> void:
	assert_true(p.is_level_unlocked("d1"))
	assert_false(p.is_level_unlocked("d2"))
	assert_false(p.is_level_unlocked("o1"))
	assert_false(p.is_level_unlocked("nope"))
	assert_eq(p.next_level(), "d1")


func test_first_puzzle_shows_one_of_two_without_unlocking() -> void:
	var r := p.complete_level("d1")
	assert_true(r.first_completion)
	assert_eq(r.unlocked_creature, "")
	assert_eq(p.creature_progress("drake"), 1)
	assert_false(p.is_creature_unlocked("drake"), "never shown unlocked early")
	assert_true(p.is_level_unlocked("d2"))
	assert_false(p.is_level_unlocked("o1"))


func test_second_puzzle_unlocks_creature_once() -> void:
	p.complete_level("d1")
	var r := p.complete_level("d2")
	assert_eq(r.unlocked_creature, "drake")
	assert_true(p.is_creature_unlocked("drake"))
	assert_true(p.is_level_unlocked("o1"), "next creature opens")
	assert_eq(p.unlocked_count(), 1)


func test_replay_is_idempotent() -> void:
	p.complete_level("d1")
	p.complete_level("d2")
	var tx_before: int = p.data.transactions.size()
	for i in 3:
		var again := p.complete_level("d2")
		assert_false(again.first_completion)
		assert_eq(again.unlocked_creature, "", "no duplicate unlock")
		assert_false(p.complete_level("d1").first_completion)
	assert_eq(p.data.transactions.size(), tx_before)
	assert_eq(p.unlocked_count(), 1)


func test_locked_level_cannot_be_completed() -> void:
	var r := p.complete_level("o1")
	assert_false(r.first_completion)
	assert_false(p.is_level_completed("o1"))


func test_completion_clears_matching_in_progress() -> void:
	p.data.in_progress = {"level_id": "d1", "removed": ["a01"], "completed": false}
	p.complete_level("d1")
	assert_eq(p.data.in_progress, {})


func test_pending_awakening_until_seen() -> void:
	p.complete_level("d1")
	p.complete_level("d2")
	assert_eq(p.pending_awakening(), "drake", "interrupted awakening replays")
	p.mark_awakening_seen("drake")
	assert_eq(p.pending_awakening(), "")
	assert_eq(p.complete_level("d2").unlocked_creature, "", "replay after awakening grants nothing")


func test_next_level_walks_campaign_and_ends_empty() -> void:
	for l in ["d1", "d2", "o1", "o2"]:
		assert_eq(p.next_level(), l)
		p.complete_level(l)
	assert_eq(p.next_level(), "")
	assert_eq(p.unlocked_count(), 2)


func test_free_hints_then_ad_hints_then_none() -> void:
	assert_eq(p.free_hints_left("d1"), 3)
	for i in 3:
		assert_eq(p.spend_hint("d1"), "free")
	assert_eq(p.free_hints_left("d1"), 0)
	assert_eq(p.spend_hint("d1"), "", "no hint without an ad")
	assert_eq(p.free_hints_left("d2"), 3, "free hints are per level")
	assert_true(p.grant_ad_hint("pres-1"))
	assert_eq(p.spend_hint("d1"), "ad")
	assert_eq(p.spend_hint("d1"), "")


func test_ad_hint_grant_is_idempotent_per_presentation() -> void:
	assert_true(p.grant_ad_hint("pres-7"))
	assert_false(p.grant_ad_hint("pres-7"), "duplicate callback")
	assert_false(p.grant_ad_hint(""), "missing id")
	assert_eq(p.ad_hints_available(), 1)


func test_campaign_validation_errors() -> void:
	var bad := Campaign.from_dict({"schema_version": 2, "worlds": [{"id": "r"}], "dragons": [
		{"id": "a", "world": "r", "levels": ["x"]},
		{"id": "a", "world": "r", "levels": ["y", "z"]},
		{"id": "b", "world": "zz", "levels": ["x", "w"]},
		{"id": "c", "world": "r", "levels": []},
	]})
	assert_null(bad.campaign)
	var joined := " | ".join(bad.errors)
	assert_string_contains(joined, "has no level")
	assert_string_contains(joined, "duplicated")
	assert_string_contains(joined, "unknown world")
	assert_string_contains(joined, "listed twice")


func test_progress_survives_save_round_trip() -> void:
	p.complete_level("d1")
	p.spend_hint("d2")
	var path := "user://test_saves/progression_%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var repo := SaveRepository.new(path)
	repo.write(p.data)
	var q := Progression.new(p.campaign, SaveRepository.new(path).load_save().data)
	assert_true(q.is_level_completed("d1"))
	assert_true(q.is_level_unlocked("d2"))
	assert_eq(q.free_hints_left("d2"), 2)
	DirAccess.remove_absolute(path)


# --- v0.2 best time / stars -----------------------------------------------

func test_record_requires_a_completed_level() -> void:
	var r := p.record_result("d1", 5000, 3)
	assert_eq(r.best_time_ms, -1)
	assert_false(p.data.levels.has("d1"))


func test_bests_only_improve_and_replays_never_lower_them() -> void:
	p.complete_level("d1")
	var first := p.record_result("d1", 20000, 2)
	assert_true(first.first_record)
	assert_false(first.new_record)
	assert_eq(p.best_time_ms("d1"), 20000)
	assert_eq(p.best_stars("d1"), 2)
	var slower := p.record_result("d1", 30000, 1)
	assert_false(slower.new_record)
	assert_eq(p.best_time_ms("d1"), 20000, "slower replay keeps the best time")
	assert_eq(p.best_stars("d1"), 2, "1-star replay keeps 2 stars")
	var faster := p.record_result("d1", 12000, 3)
	assert_true(faster.new_record)
	assert_eq(faster.previous_best_ms, 20000)
	assert_eq(p.best_time_ms("d1"), 12000)
	assert_eq(p.best_stars("d1"), 3)
	var same := p.record_result("d1", 12000, 3)
	assert_false(same.new_record, "equal time is not a new record")
	# Independent maxima: a faster 2-star run lowers time but keeps 3 stars.
	p.record_result("d1", 9000, 2)
	assert_eq(p.best_time_ms("d1"), 9000)
	assert_eq(p.best_stars("d1"), 3)


func test_replays_grant_nothing_twice() -> void:
	p.complete_level("d1")
	p.complete_level("d2")
	var tx: Dictionary = p.data.transactions.duplicate()
	for i in 3:
		p.complete_level("d2")
		p.record_result("d2", 1000 * (i + 1), 3)
	assert_eq(p.data.transactions, tx)
	assert_eq(p.unlocked_count(), 1)


func test_star_totals() -> void:
	assert_eq(p.total_stars(), 0)
	p.complete_level("d1")
	assert_eq(p.best_stars("d1"), 1, "completed without a record counts 1 star (v0.1 migration)")
	p.record_result("d1", 1000, 3)
	p.complete_level("d2")
	p.record_result("d2", 1000, 2)
	assert_eq(p.stars_in(["d1", "d2"]), 5)
	assert_eq(p.total_stars(), 5)


func test_records_survive_sanitize_and_bad_values_are_repaired() -> void:
	p.complete_level("d1")
	p.record_result("d1", 4321, 3)
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.data))
	d = SaveSchema.ints_from_json(d)
	assert_eq(SaveSchema.sanitize(d), [] as Array[String])
	assert_eq(d.levels.d1.best_time_ms, 4321)
	d.levels.d1.best_time_ms = -7
	d.levels.d1.best_stars = 9
	SaveSchema.sanitize(d)
	assert_false(d.levels.d1.has("best_time_ms"), "negative time dropped")
	assert_eq(d.levels.d1.best_stars, 3, "stars clamped")



# --- v0.2 worlds ------------------------------------------------------------

func _worlds() -> Progression:
	var c: Campaign = Campaign.from_dict({"schema_version": 2,
		"worlds": [{"id": "w01", "number": 1}, {"id": "w02", "number": 2}],
		"dragons": [
			{"id": "a", "world": "w01", "levels": ["a"]}, {"id": "b", "world": "w01", "levels": ["b"]},
			{"id": "c", "world": "w02", "levels": ["c"]}, {"id": "d", "world": "w02", "levels": ["d"]},
		]}).campaign
	return Progression.new(c, SaveSchema.defaults())


func test_world_unlocks_after_the_previous_world_is_complete() -> void:
	var q := _worlds()
	assert_true(q.is_world_unlocked("w01"))
	assert_false(q.is_world_unlocked("w02"))
	assert_false(q.is_world_unlocked("nope"))
	assert_true(q.is_level_unlocked("a"))
	assert_false(q.is_level_unlocked("b"), "dragons open one by one")
	assert_false(q.is_level_unlocked("c"), "next world locked")
	var r := q.complete_level("a")
	assert_eq(r.unlocked_creature, "a", "one level awakens its dragon")
	assert_true(q.is_level_unlocked("b"))
	assert_false(q.is_world_unlocked("w02"))
	assert_eq(q.world_completed_count("w01"), 1)
	q.complete_level("b")
	assert_true(q.is_world_complete("w01"))
	assert_true(q.is_world_unlocked("w02"), "completing world 1 opens world 2")
	assert_true(q.is_level_unlocked("c"))
	assert_false(q.is_level_unlocked("d"))
	assert_eq(q.next_level(), "c")


func test_completed_levels_stay_open_and_locked_ones_cannot_complete() -> void:
	var q := _worlds()
	assert_false(q.complete_level("c").first_completion, "locked world cannot be completed")
	assert_eq(q.data.transactions, {})
	q.complete_level("a")
	assert_true(q.is_level_unlocked("a"), "replay allowed")
	assert_false(q.complete_level("a").first_completion)
	assert_eq(q.unlocked_count(), 1)
