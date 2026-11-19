extends GutTest
## v0.1 -> v0.2 migration on a REAL v0.1.1 save (tests/fixtures/save_v0_1_1.json,
## written by the v0.1.1 code; see tests/fixtures/README.md). No lost progress,
## no duplicated rewards, atomic write + backup recovery still work.

const FIXTURE := "res://tests/fixtures/save_v0_1_1.json"
const DIR := "user://test_saves"

var _path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_path = DIR.path_join("mig_%d.json" % Time.get_ticks_usec())


func after_each() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _install(at: String) -> void:
	var f := FileAccess.open(at, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()


func test_fixture_is_a_genuine_v0_1_save() -> void:
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_eq(env.format, "legend_arrow_save")
	assert_eq(str(env.payload).sha256_text(), env.sha256, "checksum written by v0.1.1")
	var payload: Dictionary = JSON.parse_string(env.payload)
	assert_eq(int(payload.schema_version), 2)
	assert_eq(payload.settings.language, "es")


func test_migrated_progress_settings_and_wallet() -> void:
	_install(_path)
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.MAIN)
	assert_false(res.recovered)
	var d: Dictionary = res.data
	assert_eq(d.schema_version, SaveSchema.VERSION)
	# Forest Drake: both v0.1 puzzles + unlock -> its single roster level.
	assert_true(d.levels.forest_drake.completed)
	assert_eq(d.levels.forest_drake.best_stars, 1, "no v0.1 timer: completed = 1 star")
	assert_false(d.levels.forest_drake.has("best_time_ms"))
	assert_true(d.creatures.forest_drake.unlocked)
	# Moon Owl had 1 of 2 puzzles -> its roster dragon keeps that progress.
	assert_eq(SaveSchema.V01_CREATURE_MAP.moon_owl, "fern_wyrmling")
	assert_true(d.levels.fern_wyrmling.completed)
	assert_true(d.creatures.fern_wyrmling.unlocked)
	assert_true(d.creatures.forest_drake.awakening_seen, "no replay queue after the update")
	for old in ["forest_drake_1", "forest_drake_2", "moon_owl_1", "moon_owl_2"]:
		assert_false(d.levels.has(old), "%s replaced by a roster id" % old)
		assert_false(d.hints.free_used.has(old))
	assert_false(d.creatures.has("moon_owl"))
	assert_eq(d.levels.size(), 2)
	assert_eq(d.creatures.size(), 2)
	# Earned ad hint and receipts kept.
	assert_eq(d.hints.ad_entitlements, 1)
	assert_true(d.ad_receipts.has("receipt-0001"))
	assert_true(d.ad_receipts.has("receipt-0002"))
	# Settings and tutorial kept; language gone; old board dropped.
	assert_true(d.tutorial_done)
	assert_almost_eq(float(d.settings.music_volume), 0.2, 0.0001)
	assert_true(d.settings.reduce_motion)
	assert_false(d.settings.has("language"))
	assert_eq(d.in_progress, {})


func test_no_reward_can_be_granted_twice_after_migration() -> void:
	_install(_path)
	var d: Dictionary = SaveRepository.new(_path).load_save().data
	for dragon in ["forest_drake", "fern_wyrmling"]:
		assert_true(d.transactions.has("complete:%s" % dragon))
		assert_true(d.transactions.has("unlock:%s" % dragon))
	assert_eq(d.transactions.size(), 4, "one completion + one unlock per migrated dragon")
	# A roster campaign: completing the migrated levels again unlocks nothing new.
	var c: Campaign = Campaign.from_dict({"schema_version": 2, "worlds": [{"id": "w1", "name_key": "W"}],
		"dragons": [
			{"id": "forest_drake", "world": "w1", "name_key": "A", "levels": ["forest_drake", "forest_drake_b"]},
			{"id": "fern_wyrmling", "world": "w1", "name_key": "B", "levels": ["fern_wyrmling", "fern_wyrmling_b"]},
		]}).campaign
	var p := Progression.new(c, d)
	var tx: Dictionary = d.transactions.duplicate()
	assert_false(p.complete_level("forest_drake").first_completion)
	assert_eq(p.complete_level("forest_drake").unlocked_creature, "")
	assert_false(p.grant_ad_hint("receipt-0001"), "old receipt still blocks a duplicate grant")
	assert_eq(d.transactions, tx)
	assert_eq(d.hints.ad_entitlements, 1)


func test_migration_is_stable_and_written_atomically() -> void:
	_install(_path)
	var repo := SaveRepository.new(_path)
	var first: Dictionary = repo.load_save().data
	assert_eq(repo.write(first), OK)
	var again := SaveRepository.new(_path).load_save()
	assert_eq(again.source, SaveRepository.Source.MAIN)
	assert_eq(again.data, first, "a migrated save reloads unchanged")
	assert_eq(SaveSchema.migrate(first), first, "migrating v3 is a no-op")
	assert_true(SaveRepository.read_file(_path + ".bak").ok, "the original v0.1 file became the backup")
	assert_false(FileAccess.file_exists(_path + ".tmp"))


func test_corrupt_v0_2_save_recovers_from_v0_1_backup() -> void:
	_install(_path + ".bak")
	var f := FileAccess.open(_path, FileAccess.WRITE)
	f.store_string("{ truncated")
	f.close()
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.BACKUP)
	assert_true(res.recovered)
	assert_true(res.data.creatures.forest_drake.unlocked, "progress recovered and migrated")
	assert_true(FileAccess.file_exists(_path + ".corrupt"), "corrupt file kept")


func test_hostile_v2_shapes_do_not_crash_or_grant() -> void:
	for bad in [
		{"schema_version": 2, "levels": [], "creatures": "x"},
		{"schema_version": 2, "levels": {"nonsense": {"completed": true}, "ghost_1": {"completed": true}}},
		{"schema_version": 2, "creatures": {"griffin": {"unlocked": false}}, "hints": {"ad_entitlements": -4}},
	]:
		var d := SaveSchema.migrate(bad)
		assert_eq(d.schema_version, SaveSchema.VERSION)
		assert_eq(d.levels, {}, "nothing granted for %s" % str(bad))
		assert_eq(d.creatures, {})
		assert_eq(d.hints.ad_entitlements, 0)
