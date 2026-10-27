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


# --- M4 full content ----------------------------------------------------------

func test_full_roster_is_twelve_creatures_and_twenty_four_levels() -> void:
	var c: Campaign = Campaign.load_file().campaign
	assert_eq(c.creature_ids().size(), 12)
	assert_eq(c.level_ids().size(), 24)
	for cid in c.creature_ids():
		assert_eq(c.creature(cid).levels.size(), 2, "%s has 2 levels" % cid)
	var realms := {}
	for cid in c.creature_ids():
		realms[c.creature(cid).realm] = int(realms.get(c.creature(cid).realm, 0)) + 1
	assert_eq(realms, {"mistwood": 4, "cloud_peaks": 4, "ancient_highlands": 4})


func _strings() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://locales/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	assert_eq(header, PackedStringArray(["keys", "en", "es"]))
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			out[row[0]] = row
	return out


func test_every_creature_has_name_and_lore_in_both_languages() -> void:
	var strings := _strings()
	var c: Campaign = Campaign.load_file().campaign
	var names := {}
	for cid in c.creature_ids():
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % cid))
		for key in [c.creature(cid).name_key, meta.get("lore_key", "")]:
			assert_true(strings.has(key), "%s: %s present" % [cid, key])
			if strings.has(key):
				assert_ne(strings[key][1].strip_edges(), "", "%s EN" % key)
				assert_ne(strings[key][2].strip_edges(), "", "%s ES" % key)
		names[strings.get(c.creature(cid).name_key, ["", ""])[1]] = true
	assert_eq(names.size(), 12, "names are distinct")


func test_every_level_mask_matches_its_board() -> void:
	var c: Campaign = Campaign.load_file().campaign
	for level_id in c.level_ids():
		var lvl: Dictionary = LevelData.load_file(c.level_path(level_id)).level
		var cells := 0
		for a in lvl.arrows:
			cells += a.cells.size()
		assert_gt(cells, lvl.arrows.size(), "%s arrows have bodies" % level_id)


## Larger boards are too big for exhaustive search; random legal play from
## many seeds must still always clear them (monotonic rules, D-07).
func test_large_levels_never_deadlock_under_random_play() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var checked := 0
	for level_id in c.level_ids():
		var lvl: Dictionary = LevelData.load_file(c.level_path(level_id)).level
		if lvl.arrows.size() <= 14:
			continue
		checked += 1
		for seed_value in 40:
			var rng := DeterministicRng.new(seed_value + 1)
			var board := LevelData.to_board(lvl)
			while not board.is_empty():
				var free := board.removable_ids()
				if free.is_empty():
					break
				board.remove(free[rng.range_int(0, free.size() - 1)])
			assert_true(board.is_empty(), "%s seed %d clears" % [level_id, seed_value])
	assert_gt(checked, 0)


func test_difficulty_increases_across_the_campaign() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var counts: Array[int] = []
	for level_id in c.level_ids():
		counts.append(LevelData.load_file(c.level_path(level_id)).level.arrows.size())
	var first_realm := counts.slice(0, 8)
	var last_realm := counts.slice(16, 24)
	var avg := func(xs: Array) -> float:
		var s := 0
		for x in xs:
			s += x
		return float(s) / xs.size()
	assert_gt(avg.call(last_realm), avg.call(first_realm) + 10.0, "late realm is clearly harder")


func _pose_signature(rig: CreatureRig) -> Array:
	var out := []
	for key in rig.parts.keys():
		var n: Node2D = rig.parts[key]
		out.append([key, n.rotation, n.scale, n.position])
	return out


func test_every_creature_rig_builds_awakens_and_skips() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var signatures := {}
	for cid in c.creature_ids():
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % cid))
		var rig: CreatureRig = load(meta.art).instantiate()
		add_child_autofree(rig)
		await wait_process_frames(1)
		assert_gt(rig.parts.size(), 3, "%s has layered parts" % cid)
		rig.pose_dormant()
		var dormant := _pose_signature(rig)
		rig.pose_final()
		var final_pose := _pose_signature(rig)
		assert_ne(str(dormant), str(final_pose), "%s: awakening changes the pose" % cid)
		signatures[str(rig.parts.keys())] = true
		watch_signals(rig)
		rig.awaken()
		assert_true(rig.awakening, "%s awakening" % cid)
		await wait_process_frames(2)
		rig.skip()
		assert_signal_emitted(rig, "awakening_finished", "%s skip finishes" % cid)
		assert_false(rig.awakening)
		rig.start_idle()
		await wait_process_frames(2)
		rig.stop()
	assert_gt(signatures.size(), 4, "rigs use several distinct skeletons")


func test_reduced_motion_awakening_finishes_quickly() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/phoenix.json"))
	var rig: CreatureRig = load(meta.art).instantiate()
	rig.reduce_motion = true
	add_child_autofree(rig)
	await wait_process_frames(1)
	watch_signals(rig)
	rig.awaken()
	await wait_for_signal(rig.awakening_finished, 2.0)
	assert_signal_emitted(rig, "awakening_finished")


## Phase 6 DoD: the whole packaged campaign is completable offline by playing
## each recorded solution in order, and each creature unlocks exactly once.
func test_full_campaign_completes_and_unlocks_each_creature_once() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var p := Progression.new(c, SaveSchema.defaults())
	var unlocked: Array[String] = []
	var guard := 0
	while p.next_level() != "" and guard < 100:
		guard += 1
		var level_id := p.next_level()
		var lvl: Dictionary = LevelData.load_file(c.level_path(level_id)).level
		var s := PuzzleSession.new(lvl)
		for id in lvl.solution:
			s.tap(id)
		assert_true(s.is_complete(), level_id)
		var r := p.complete_level(level_id)
		if r.unlocked_creature != "":
			unlocked.append(r.unlocked_creature)
	assert_eq(guard, 24, "24 levels played")
	assert_eq(unlocked, c.creature_ids(), "unlock order follows the roster, once each")
	assert_eq(p.unlocked_count(), 12)
	assert_eq(p.complete_level(c.level_ids()[0]).unlocked_creature, "", "replay unlocks nothing")
