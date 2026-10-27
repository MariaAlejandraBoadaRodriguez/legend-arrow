extends GutTest
## Unlock rules, idempotent rewards and hint wallet.

var p: Progression


func before_each() -> void:
	var res := Campaign.from_dict({
		"schema_version": 1,
		"realms": [{"id": "mistwood", "name_key": "REALM_MISTWOOD"}],
		"creatures": [
			{"id": "drake", "realm": "mistwood", "name_key": "X", "levels": ["d1", "d2"]},
			{"id": "owl", "realm": "mistwood", "name_key": "Y", "levels": ["o1", "o2"]},
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
	var bad := Campaign.from_dict({"schema_version": 1, "realms": [{"id": "r"}], "creatures": [
		{"id": "a", "realm": "r", "levels": ["x"]},
		{"id": "a", "realm": "r", "levels": ["y", "z"]},
		{"id": "b", "realm": "zz", "levels": ["x", "w"]},
	]})
	assert_null(bad.campaign)
	var joined := " | ".join(bad.errors)
	assert_string_contains(joined, "exactly 2 levels")
	assert_string_contains(joined, "duplicated")
	assert_string_contains(joined, "unknown realm")
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
