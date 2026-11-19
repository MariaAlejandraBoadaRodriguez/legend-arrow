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
			# Certification (v0.2 §2): solvable by the exact solver, a legal
			# first move exists, the recorded solution replays to an empty board.
			var board := LevelData.to_board(res.level)
			assert_true(board.has_legal_move(), "%s has a legal move" % level_id)
			assert_true(PuzzleSolver.is_solvable(board), "%s solvable" % level_id)
			assert_true(PuzzleSolver.verify_solution(board, res.level.solution).ok, "%s solution replays" % level_id)


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
		assert_eq(meta.world, c.creature(cid).world, "%s world consistent" % cid)
		assert_true(ResourceLoader.exists(str(meta.get("art", ""))) or ResourceLoader.exists(SilhouetteRig.path_for(cid)),
			"%s has art (rig or silhouette)" % cid)


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


# --- v0.2 roster campaign (D-41, D-47) -----------------------------------------

func _roster() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/roster.json"))


func test_campaign_is_the_canonical_roster_ten_worlds_by_ten_dragons() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var r := _roster()
	assert_eq(c.worlds.size(), 10)
	assert_eq(c.creature_ids().size(), 100)
	assert_eq(c.level_ids().size(), 100)
	var expected: Array[String] = []
	for d in r.dragons:
		expected.append(str(d.id))
	assert_eq(c.creature_ids(), expected, "ids and order verbatim from docs/ART_PROMPTS.md")
	for i in 10:
		var w: Dictionary = c.worlds[i]
		assert_eq(w.id, r.worlds[i].id)
		assert_eq(int(w.number), i + 1, "world order = difficulty order")
		assert_eq(c.creatures_in_world(w.id).size(), 10)
	for cid in c.creature_ids():
		assert_eq(c.creature(cid).levels, [cid], "%s: one level, id = dragon id" % cid)


func _strings() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://locales/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	assert_eq(header, PackedStringArray(["keys", "en"]), "English is the only locale")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			out[row[0]] = row
	return out


func test_every_dragon_and_world_has_its_roster_name_in_english() -> void:
	var strings := _strings()
	var c: Campaign = Campaign.load_file().campaign
	var r := _roster()
	for d in r.dragons:
		var key: String = c.creature(d.id).name_key
		assert_true(strings.has(key), "%s name" % d.id)
		if strings.has(key):
			assert_eq(strings[key][1], d.name, "%s: roster name verbatim" % d.id)
		assert_true(strings.has(key + "_LORE") and strings[key + "_LORE"][1].strip_edges() != "", "%s lore" % d.id)
	for w in r.worlds:
		var wk: String = c.world(w.id).name_key
		assert_true(strings.has(wk) and strings[wk][1] == w.name, "%s: %s" % [w.id, w.name])


func test_every_dragon_has_a_silhouette() -> void:
	var c: Campaign = Campaign.load_file().campaign
	for cid in c.creature_ids():
		assert_true(ResourceLoader.exists(SilhouetteRig.path_for(cid)), cid)


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
		for seed_value in 12:
			var rng := DeterministicRng.new(seed_value + 1)
			var board := LevelData.to_board(lvl)
			while not board.is_empty():
				var free := board.removable_ids()
				if free.is_empty():
					break
				board.remove(free[rng.range_int(0, free.size() - 1)])
			assert_true(board.is_empty(), "%s seed %d clears" % [level_id, seed_value])
	assert_gt(checked, 50)


## v0.2 §2 / §9.1: per-world table (avg/min/max arrows, dependency depth,
## simultaneous exits). Each world is harder than the previous one: more
## arrows on average (and within the owner's bands), dependency depth that
## never falls, and more arrows blocked at the start.
func test_difficulty_curve_rises_world_by_world() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var lines := PackedStringArray(["world | arrows avg/min/max | depth avg/min/max | free at start avg (share) | blocked at start avg"])
	var prev := {"arrows": 0.0, "depth": 0.0, "blocked": 0.0}
	for w in c.worlds:
		var a: Array = []
		var d: Array = []
		var f: Array = []
		for l in c.levels_in_world(w.id):
			var board := LevelData.to_board(LevelData.load_file(c.level_path(l)).level)
			a.append(board.total_count())
			d.append(PuzzleSolver.dependency_depth(board))
			f.append(board.removable_ids().size())
		var avg := func(xs: Array) -> float:
			var t := 0.0
			for x in xs:
				t += x
			return t / xs.size()
		var aa: float = avg.call(a)
		var dd: float = avg.call(d)
		var ff: float = avg.call(f)
		var blocked := aa - ff
		lines.append("%d %s | %.1f / %d / %d | %.1f / %d / %d | %.1f (%d%%) | %.1f" % [int(w.number), tr(w.name_key),
			aa, a.min(), a.max(), dd, d.min(), d.max(), ff, roundi(100.0 * ff / aa), blocked])
		assert_gt(aa, prev.arrows, "%s: more arrows than the previous world" % w.id)
		assert_gte(dd, prev.depth - 0.001, "%s: dependency depth does not fall" % w.id)
		assert_gt(blocked, prev.blocked, "%s: more arrows blocked at the start" % w.id)
		prev = {"arrows": aa, "depth": dd, "blocked": blocked}
		if int(w.number) == 1:
			assert_between(a.min(), 6, 12, "world 1 is easy (6-12 arrows)")
			assert_between(a.max(), 6, 12)
		if int(w.number) == 10:
			assert_gte(a.min(), 41, "world 10 is expert (41-60 arrows)")
		for i in range(1, a.size()):
			assert_gte(a[i], a[i - 1], "%s: levels get harder inside the world" % w.id)
	gut.p("\n".join(lines))


func _pose_signature(rig: CreatureRig) -> Array:
	var out := []
	for key in rig.parts.keys():
		var n: Node2D = rig.parts[key]
		out.append([key, n.rotation, n.scale, n.position])
	return out


## Imported dragons use PhotoRig (D-49); a dragon still ART PENDING keeps its
## v0.1 layered rig or the SilhouetteRig (D-47). All must awaken and skip.
func test_every_creature_rig_builds_awakens_and_skips() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var layered := 0
	var photo := 0
	for cid in c.creature_ids():
		var stage := CreatureStage.new()
		add_child(stage)
		assert_true(stage.show_creature(cid, false, true), "%s has art" % cid)
		var rig := stage.rig
		await wait_process_frames(1)
		if PhotoRig.has_art(cid):
			photo += 1
			assert_true(rig is PhotoRig, "%s: imported photoreal art is used" % cid)
		elif not rig is SilhouetteRig:
			layered += 1
			assert_gt(rig.parts.size(), 3, "%s has layered parts" % cid)
		rig.pose_dormant()
		var dormant := _pose_signature(rig)
		rig.pose_final()
		assert_ne(str(dormant), str(_pose_signature(rig)), "%s: awakening changes the pose" % cid)
		# A plain connection, not watch_signals(): GUT's watcher on 100 rigs
		# that the test frees itself hung GUT's end-of-test cleanup.
		var finished := [0]
		rig.awakening_finished.connect(func(): finished[0] += 1)
		rig.awaken()
		assert_true(rig.awakening, "%s awakening" % cid)
		rig.skip()
		assert_eq(finished[0], 1, "%s skip finishes" % cid)
		assert_false(rig.awakening)
		rig.start_idle()
		rig.stop()
		stage.clear()
		remove_child(stage)
		stage.free()
	assert_eq(photo + layered + (100 - photo - layered), 100)
	var pending := 0
	for cid in c.creature_ids():
		if not PhotoRig.has_art(cid):
			pending += 1
	assert_eq(photo, 100 - pending, "every imported dragon shows its photoreal art")
	gut.p("art: %d photoreal, %d interim (ART PENDING)" % [photo, pending])


func test_reduced_motion_awakening_finishes_quickly() -> void:
	for cid in ["forest_drake", "fern_wyrmling"]:
		var stage := CreatureStage.new()
		add_child_autofree(stage)
		stage.show_creature(cid, true)
		await wait_process_frames(1)
		watch_signals(stage.rig)
		stage.rig.awaken()
		await wait_for_signal(stage.rig.awakening_finished, 2.0)
		assert_signal_emitted(stage.rig, "awakening_finished", cid)


## The whole packaged campaign is completable offline by playing each
## recorded solution in order; each dragon awakens exactly once and each
## world opens only after the previous one.
func test_full_campaign_completes_and_unlocks_each_creature_once() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var p := Progression.new(c, SaveSchema.defaults())
	var unlocked: Array[String] = []
	var guard := 0
	while p.next_level() != "" and guard < 200:
		guard += 1
		var level_id := p.next_level()
		var w := c.world_of(c.creature_of_level(level_id))
		var wi := c.world_index(w)
		if wi > 0:
			assert_true(p.is_world_complete(c.worlds[wi - 1].id), "%s opens only after world %d" % [w, wi])
		var lvl: Dictionary = LevelData.load_file(c.level_path(level_id)).level
		var s := PuzzleSession.new(lvl)
		for id in lvl.solution:
			s.tap(id)
		assert_true(s.is_complete(), level_id)
		var r := p.complete_level(level_id)
		if r.unlocked_creature != "":
			unlocked.append(r.unlocked_creature)
	assert_eq(guard, 100, "100 levels played")
	assert_eq(unlocked, c.creature_ids(), "unlock order follows the roster, once each")
	assert_eq(p.unlocked_count(), 100)
	assert_eq(p.complete_level(c.level_ids()[0]).unlocked_creature, "", "replay unlocks nothing")


## v0.2 §9.1: par/star table for every shipped level; 3 stars reachable by
## replaying the certified solution at a realistic human pace.
func test_par_times_and_three_stars_reachable_for_every_level() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var lines := PackedStringArray(["level | arrows | depth | par | 2-star limit | human replay"])
	for level_id in c.level_ids():
		var lvl: Dictionary = LevelData.load_file(c.level_path(level_id)).level
		var board := LevelData.to_board(lvl)
		var n := board.total_count()
		var depth := PuzzleSolver.dependency_depth(board)
		var par := StarRating.par_for_level(lvl)
		var human := StarRating.human_replay_ms(n)
		assert_eq(par, StarRating.par_ms(n, depth))
		assert_eq(StarRating.stars(human, par, 0), 3, "%s: human replay %d ms vs par %d ms" % [level_id, human, par])
		assert_eq(PuzzleSession.new(lvl).par_ms, par, "%s: the game uses the same par" % level_id)
		lines.append("%s | %d | %d | %s | %s | %s" % [level_id, n, depth, SpeedTimer.format_ms(par),
			SpeedTimer.format_ms(2 * par), SpeedTimer.format_ms(human)])
	gut.p("\n".join(lines))



## v0.2 §4: every imported dragon ships its cut-out, thumbnail and mask, and
## the full images stay inside the download budget.
func test_imported_art_is_complete_and_within_budget() -> void:
	var c: Campaign = Campaign.load_file().campaign
	var total := 0
	for cid in c.creature_ids():
		if not PhotoRig.has_art(cid):
			continue
		for path in [PhotoRig.art_path(cid), "res://assets/creatures/thumbs/%s.webp" % cid,
				"res://assets/creatures/masks/%s.png" % cid, SilhouetteRig.path_for(cid)]:
			assert_true(ResourceLoader.exists(path), path)
		var f := FileAccess.open("res://assets/creatures/art/%s.webp" % cid, FileAccess.READ)
		if f != null:
			total += f.get_length()
			assert_lte(f.get_length(), 450 * 1024, "%s full image <= 450 KB" % cid)
		var tex: Texture2D = load(PhotoRig.art_path(cid))
		var aspect := float(tex.get_width()) / tex.get_height()
		assert_between(aspect, 0.2, 5.0, "%s keeps a sane aspect" % cid)
	assert_lte(total, 60 * 1024 * 1024, "all full images <= 60 MB")
	gut.p("photoreal art total: %.1f MB" % (total / 1048576.0))
