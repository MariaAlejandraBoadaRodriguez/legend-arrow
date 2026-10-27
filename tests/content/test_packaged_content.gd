extends GutTest
## Validates every packaged level, recorded solution, tutorial board and the
## campaign catalog exactly as the game will load them.

const LEVELS_DIR := "res://data/levels"


func _level_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(LEVELS_DIR):
		if f.ends_with(".json"):
			out.append(LEVELS_DIR.path_join(f))
	out.sort()
	return out


func test_campaign_loads() -> void:
	var res := Campaign.load_file()
	assert_eq(res.errors, [] as Array[String])
	assert_not_null(res.campaign)


func test_every_campaign_level_is_packaged_valid_and_owned() -> void:
	var c: Campaign = Campaign.load_file().campaign
	assert_gt(c.level_ids().size(), 0)
	for level_id in c.level_ids():
		var res := LevelData.load_file(c.level_path(level_id))
		assert_eq(res.errors, [] as Array[String], "%s valid" % level_id)
		if res.errors.is_empty():
			assert_eq(res.level.id, level_id, "file name matches id")
			assert_eq(res.level.creature_id, c.creature_of_level(level_id), "%s owned by its creature" % level_id)


func test_no_orphan_level_files() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var listed := c.level_ids()
	var files := _level_files()
	assert_gt(files.size(), 0)
	for f in files:
		assert_has(listed, f.get_file().get_basename(), "%s is referenced by campaign.json" % f)


func test_recorded_solutions_play_through_a_session() -> void:
	for f in _level_files():
		var lvl: Dictionary = LevelData.load_file(f).level
		var s := PuzzleSession.new(lvl)
		for id in lvl.solution:
			assert_eq(s.tap(id).result, PuzzleSession.TapResult.REMOVED, "%s: %s" % [f, id])
		assert_true(s.is_complete(), "%s completes" % f)


func test_packaged_levels_have_no_reachable_deadlock() -> void:
	for f in _level_files():
		var lvl: Dictionary = LevelData.load_file(f).level
		if lvl.arrows.size() > 14:
			continue  # exhaustive search only for small boards; larger ones rely on D-07
		var res := PuzzleSolver.explore(LevelData.to_board(lvl), 50000)
		assert_false(res.truncated, f)
		assert_true(res.complete, f)
		assert_eq(res.deadlocks, 0, f)


func test_creature_metadata_exists_for_each_creature() -> void:
	var c: Campaign = Campaign.load_file().campaign
	for cid in c.creature_ids():
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % cid))
		assert_typeof(meta, TYPE_DICTIONARY, cid)
		assert_eq(meta.id, cid)
		assert_eq(meta.realm, c.creature(cid).realm, "%s realm consistent" % cid)
		assert_true(ResourceLoader.exists(meta.art), "%s art scene exists" % cid)


func test_tutorial_has_three_valid_steps() -> void:
	var t = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))
	assert_eq(t.steps.size(), 3)
	for i in t.steps.size():
		var step: Dictionary = t.steps[i]
		assert_eq(step.text_key, "TUTORIAL_STEP_%d" % (i + 1))
		assert_eq(LevelValidator.validate(step.level), [] as Array[String], "step %d board valid" % (i + 1))
		assert_has(["first_removal", "board_empty"], step.complete_when)
		if step.highlight != "":
			var board := LevelData.to_board(step.level)
			assert_true(board.has_arrow(step.highlight), "step %d highlight exists" % (i + 1))
	# Step 2 must demonstrate a harmless blocked move on the highlighted arrow.
	var b2 := LevelData.to_board(t.steps[1].level)
	assert_ne(b2.find_blocker(t.steps[1].highlight), "", "step 2 target starts blocked")
	# Step 1's highlighted arrow must be free.
	var b1 := LevelData.to_board(t.steps[0].level)
	assert_true(b1.is_removable(t.steps[0].highlight))
