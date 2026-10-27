extends GutTest
## Property tests over 1,000 deterministic generated boards (spec §5, §19).
## Each property aggregates violations across all boards and reports the first
## few, so a failure names the seed to reproduce it.

const BOARD_COUNT := 1000
const FIRST_SEED := 1
const RANDOM_BOARD_COUNT := 300

var _levels: Array = []   # [{seed, level}]
var _gen_failures: Array = []


func before_all() -> void:
	for i in BOARD_COUNT:
		var seed_value := FIRST_SEED + i
		var p := params_for(seed_value)
		var lvl := LevelGenerator.generate(seed_value, p.w, p.h, p.n, {"min_len": 2, "max_len": p.max_len})
		if lvl.is_empty():
			_gen_failures.append(seed_value)
			continue
		lvl["id"] = "gen_%d" % seed_value
		lvl["creature_id"] = "test"
		lvl["difficulty"] = LevelGenerator.difficulty_for(p.n)
		_levels.append({"seed": seed_value, "level": lvl})


## Deterministic size/density mix covering tutorial..hard boards.
static func params_for(seed_value: int) -> Dictionary:
	var r := DeterministicRng.new(seed_value * 7919)
	var w := r.range_int(4, 12)
	var h := r.range_int(5, 14)
	var n := clampi((w * h) / r.range_int(5, 9), 2, 40)
	return {"w": w, "h": h, "n": n, "max_len": r.range_int(3, 7)}


func _report(name: String, violations: Array) -> void:
	assert_eq(violations.size(), 0, "%s: %d violations, first: %s" % [name, violations.size(), str(violations.slice(0, 5))])


func test_every_seed_generates_a_board() -> void:
	_report("generation", _gen_failures)
	assert_eq(_levels.size(), BOARD_COUNT)


func test_generated_levels_pass_validator_after_json_round_trip() -> void:
	var bad := []
	for entry in _levels:
		var errors := LevelValidator.validate(TestBoards.via_json(entry.level))
		if not errors.is_empty():
			bad.append({"seed": entry.seed, "errors": errors.slice(0, 2)})
	_report("validator", bad)


func test_recorded_solutions_succeed_and_solver_agrees() -> void:
	var bad := []
	for entry in _levels:
		var board := LevelData.to_board(entry.level)
		var res := PuzzleSolver.verify_solution(board, entry.level.solution)
		if not res.ok:
			bad.append({"seed": entry.seed, "error": res.error})
		elif not PuzzleSolver.is_solvable(board):
			bad.append({"seed": entry.seed, "error": "solver disagrees"})
		elif not PuzzleSolver.verify_solution(board, PuzzleSolver.solve(board)).ok:
			bad.append({"seed": entry.seed, "error": "solver output invalid"})
	_report("solutions", bad)


func test_removal_is_monotone_and_random_play_never_deadlocks() -> void:
	# Plays every board to the end choosing random legal moves. After each
	# removal, no arrow may gain a blocker and every previously free arrow stays
	# free. Reaching a non-empty state with no move would be a deadlock.
	var bad := []
	var moves_checked := 0
	for entry in _levels:
		var board := LevelData.to_board(entry.level)
		var rng := DeterministicRng.new(entry.seed + 100003)
		while not board.is_empty():
			var free := board.removable_ids()
			if free.is_empty():
				bad.append({"seed": entry.seed, "error": "deadlock with %d arrows" % board.remaining_count()})
				break
			var before := {}
			for id in board.remaining_ids():
				before[id] = board.blockers_of(id)
			var pick: String = free[rng.range_int(0, free.size() - 1)]
			board.remove(pick)
			moves_checked += 1
			for id in board.remaining_ids():
				for b in board.blockers_of(id):
					if not (before[id] as Array).has(b):
						bad.append({"seed": entry.seed, "error": "%s gained blocker %s" % [id, b]})
				if free.has(id) and not board.is_removable(id):
					bad.append({"seed": entry.seed, "error": "%s stopped being free" % id})
	_report("monotonicity/deadlock", bad)
	assert_gt(moves_checked, BOARD_COUNT * 2, "property exercised many moves")


func test_exhaustive_search_on_small_boards_finds_no_deadlock() -> void:
	var bad := []
	var explored := 0
	for entry in _levels:
		if entry.level.arrows.size() > 10:
			continue
		var res := PuzzleSolver.explore(LevelData.to_board(entry.level))
		explored += 1
		if res.truncated or not res.complete or res.deadlocks != 0:
			bad.append({"seed": entry.seed, "result": res})
	_report("exhaustive", bad)
	assert_gt(explored, 50, "enough small boards explored")


func test_serialization_round_trips_preserve_state() -> void:
	var bad := []
	for entry in _levels:
		var lvl: Dictionary = TestBoards.via_json(entry.level)
		var a := LevelData.to_board(entry.level)
		var b := LevelData.to_board(lvl)
		for id in a.all_ids():
			if a.arrow(id).cells != b.arrow(id).cells:
				bad.append({"seed": entry.seed, "error": "cells differ for %s" % id})
		var s := PuzzleSession.new(lvl)
		var half: int = lvl.solution.size() / 2
		for i in half:
			s.tap(lvl.solution[i])
		var t := PuzzleSession.new(lvl)
		if not t.apply_saved(TestBoards.via_json(s.to_dict())) or t.board.state_key() != s.board.state_key():
			bad.append({"seed": entry.seed, "error": "session state did not round-trip"})
	_report("serialization", bad)


func test_generation_is_deterministic() -> void:
	var bad := []
	for i in range(0, _levels.size(), 10):
		var entry: Dictionary = _levels[i]
		var p := params_for(entry.seed)
		var again := LevelGenerator.generate(entry.seed, p.w, p.h, p.n, {"min_len": 2, "max_len": p.max_len})
		again["id"] = entry.level.id
		again["creature_id"] = entry.level.creature_id
		again["difficulty"] = entry.level.difficulty
		if JSON.stringify(again, "", true) != JSON.stringify(entry.level, "", true):
			bad.append(entry.seed)
	_report("determinism", bad)


func test_solver_matches_brute_force_on_random_boards() -> void:
	# Random boards are often unsolvable; the fast graph solver must agree with
	# exhaustive search on every one of them.
	var bad := []
	var unsolvable := 0
	for i in RANDOM_BOARD_COUNT:
		var seed_value := 500000 + i
		var board := LevelGenerator.random_board(seed_value, 5 + i % 4, 5 + i % 5, 4 + i % 6)
		var res := PuzzleSolver.explore(board)
		var fast := PuzzleSolver.is_solvable(board)
		if res.truncated or fast != res.complete or (not fast and res.deadlocks == 0) or (fast and res.deadlocks != 0):
			bad.append({"seed": seed_value, "fast": fast, "brute": res})
		if not fast:
			unsolvable += 1
	_report("solver vs brute force", bad)
	assert_gt(unsolvable, 10, "sample includes unsolvable boards")
