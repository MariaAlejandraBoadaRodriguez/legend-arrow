extends GutTest
## Atomic saves, backup recovery, corruption, interrupted writes, migration.

const DIR := "user://test_saves"

var _path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_path = DIR.path_join("save_%d.json" % Time.get_ticks_usec())


func after_each() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt", ".bak.corrupt", ".tmp.corrupt"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _data(marker: int) -> Dictionary:
	var d := SaveSchema.defaults()
	d.levels["level_%d" % marker] = {"completed": true}
	return d


func _write_text(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_first_launch_gives_defaults_without_recovery_message() -> void:
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.NEW)
	assert_false(res.recovered)
	assert_eq(res.data, SaveSchema.defaults())


func test_write_then_load_round_trip() -> void:
	var repo := SaveRepository.new(_path)
	var d := _data(1)
	d.settings.reduce_motion = true
	d.in_progress = {"level_id": "x", "removed": ["a01"], "completed": false}
	assert_eq(repo.write(d), OK)
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.MAIN)
	assert_eq(res.data, d)
	assert_false(FileAccess.file_exists(_path + ".tmp"), "tmp consumed by rename")


func test_second_write_keeps_previous_as_backup() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.write(_data(2))
	assert_true(SaveRepository.read_file(_path + ".bak").ok)
	assert_true(SaveRepository.read_file(_path + ".bak").data.levels.has("level_1"))
	assert_true(SaveRepository.read_file(_path).data.levels.has("level_2"))


func test_corrupt_main_recovers_from_backup_and_quarantines() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.write(_data(2))
	_write_text(_path, "{\"format\":\"legend_arrow_save\",\"sha256\":\"00\",\"payl")  # truncated
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.BACKUP)
	assert_true(res.recovered, "player is told progress was restored")
	assert_true(res.data.levels.has("level_1"))
	assert_true(FileAccess.file_exists(_path + ".corrupt"), "corrupt file kept, not erased")
	assert_true(SaveRepository.read_file(_path).ok, "main file repaired")


func test_checksum_detects_edited_payload() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	var text := FileAccess.get_file_as_string(_path).replace("level_1", "level_9")
	_write_text(_path, text)
	var r := SaveRepository.read_file(_path)
	assert_false(r.ok)
	assert_string_contains(r.error, "checksum")


func test_corrupt_main_and_backup_start_fresh_but_keep_files() -> void:
	_write_text(_path, "garbage")
	_write_text(_path + ".bak", "")
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.NEW)
	assert_eq(res.data, SaveSchema.defaults())
	assert_true(FileAccess.file_exists(_path + ".corrupt"))
	assert_eq(res.problems.size(), 2)


func test_crash_after_temp_write_keeps_previous_complete_save() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.simulate_crash_after_step = 1
	repo.write(_data(2))
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.MAIN)
	assert_true(res.data.levels.has("level_1"), "previous complete transaction")
	assert_false(res.recovered)


func test_crash_between_rotate_and_rename_loads_new_save() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.simulate_crash_after_step = 2
	repo.write(_data(2))
	assert_false(FileAccess.file_exists(_path), "main rotated away")
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.TEMP)
	assert_true(res.data.levels.has("level_2"), "newest complete transaction")
	assert_false(res.recovered, "no data was lost, no message needed")
	assert_true(SaveRepository.read_file(_path).ok, "main restored")


func test_kill_at_every_step_never_yields_half_state() -> void:
	for step in [1, 2]:
		var p := _path + "_k%d" % step
		var repo := SaveRepository.new(p)
		var before := _data(1)
		repo.write(before)
		var after := _data(1)
		after.creatures["forest_drake"] = {"unlocked": true, "awakening_seen": false}
		after.transactions["unlock:forest_drake"] = true
		repo.simulate_crash_after_step = step
		repo.write(after)
		var got: Dictionary = SaveRepository.new(p).load_save().data
		assert_true(got == before or got == after, "step %d: whole old or whole new state" % step)
		var unlocked: bool = got.creatures.has("forest_drake")
		assert_eq(unlocked, got.transactions.has("unlock:forest_drake"), "unlock and its transaction agree")
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(p + suffix):
				DirAccess.remove_absolute(p + suffix)


func test_migrates_v1_save() -> void:
	var v1 := {"schema_version": 1, "completed_levels": ["forest_drake_1", "forest_drake_2"], "unlocked_creatures": ["forest_drake"], "tutorial_done": true}
	var payload := JSON.stringify(v1)
	_write_text(_path, JSON.stringify({"format": "legend_arrow_save", "sha256": payload.sha256_text(), "payload": payload}))
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.MAIN)
	var d: Dictionary = res.data
	assert_eq(d.schema_version, SaveSchema.VERSION)
	assert_true(d.levels.forest_drake.completed, "v0.1 levels map to the roster dragon's level")
	assert_false(d.levels.has("forest_drake_2"))
	assert_true(d.creatures.forest_drake.unlocked)
	assert_true(d.transactions.has("unlock:forest_drake"), "migrated unlock cannot be granted again")
	assert_true(d.tutorial_done)
	assert_eq(d.settings, SaveSchema.default_settings())


func test_rejects_future_schema() -> void:
	var payload := JSON.stringify({"schema_version": 99})
	_write_text(_path, JSON.stringify({"format": "legend_arrow_save", "sha256": payload.sha256_text(), "payload": payload}))
	var r := SaveRepository.read_file(_path)
	assert_false(r.ok)
	assert_string_contains(r.error, "unsupported")


func test_sanitize_repairs_settings_and_fills_missing_keys() -> void:
	var d := SaveSchema.defaults()
	d.erase("hints")
	d.settings.music_volume = 7.0
	d.settings.language = "es"  # written by v0.1; obsolete since D-41
	assert_eq(SaveSchema.sanitize(d), [] as Array[String])
	assert_eq(d.hints, {"free_used": {}, "ad_entitlements": 0})
	assert_eq(d.settings.music_volume, 1.0)
	assert_false(d.settings.has("language"), "obsolete language setting dropped")
	var bad := SaveSchema.defaults()
	bad.levels = []
	assert_false(SaveSchema.sanitize(bad).is_empty(), "wrong top-level type is corrupt")


# --- v0.2 API 26 investigation: a bad tmp must never replace a good main ---

func _assert_bad_tmp_keeps_previous(kind: String) -> void:
	var repo := SaveRepository.new(_path)
	assert_eq(repo.write(_data(1)), OK)
	repo.simulate_bad_tmp = kind
	assert_ne(repo.write(_data(2)), OK, "%s: write reports the failure" % kind)
	assert_true(SaveRepository.read_file(_path).ok, "%s: main still readable" % kind)
	assert_true(SaveRepository.read_file(_path).data.levels.has("level_1"), "%s: main is the previous save" % kind)
	assert_false(FileAccess.file_exists(_path + ".bak"), "%s: no rotation happened" % kind)
	assert_false(FileAccess.file_exists(_path + ".tmp"), "%s: broken tmp removed" % kind)
	var res := SaveRepository.new(_path).load_save()
	assert_eq(res.source, SaveRepository.Source.MAIN, kind)
	assert_false(res.recovered, "%s: nothing to restore, no message" % kind)
	repo.simulate_bad_tmp = ""
	assert_eq(repo.write(_data(3)), OK, "%s: the next write lands" % kind)
	assert_true(SaveRepository.new(_path).load_save().data.levels.has("level_3"), kind)


func test_short_write_never_replaces_main() -> void:
	_assert_bad_tmp_keeps_previous("truncate")


func test_stale_tmp_never_replaces_main() -> void:
	_assert_bad_tmp_keeps_previous("stale")


func test_missing_tmp_after_close_never_rotates_main() -> void:
	_assert_bad_tmp_keeps_previous("missing")


func test_peek_reads_without_quarantine_or_repair() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.write(_data(2))
	_write_text(_path, "{broken")
	var res := SaveRepository.new(_path).peek()
	assert_eq(res.source, SaveRepository.Source.BACKUP)
	assert_true(res.data.levels.has("level_1"))
	assert_eq(FileAccess.get_file_as_string(_path), "{broken", "main untouched")
	assert_false(FileAccess.file_exists(_path + ".corrupt"), "nothing quarantined")


func test_envelope_records_writer() -> void:
	var repo := SaveRepository.new(_path)
	repo.write(_data(1))
	repo.write(_data(2))
	var info := SaveRepository.envelope_info(_path)
	assert_eq(int(info.pid), OS.get_process_id())
	assert_eq(int(info.seq), 2)
	assert_gt(int(info.unix_ms), 0)
