extends GutTest
## Solver, dependency graph and exhaustive exploration.


func test_solve_returns_dependency_order() -> void:
	# a (right) blocked by b; b (down) blocked by c; c free.
	var b := TestBoards.make(6, 5, {
		"a": [[0, 1], [1, 1]],
		"b": [[3, 0], [3, 1]],
		"c": [[2, 4], [3, 4]],
	})
	assert_eq(b.blockers_of("a"), ["b"] as Array[String])
	assert_eq(b.blockers_of("b"), ["c"] as Array[String])
	assert_eq(PuzzleSolver.solve(b), ["c", "b", "a"] as Array[String])
	assert_eq(PuzzleSolver.dependency_depth(b), 3)
	assert_true(PuzzleSolver.is_solvable(b))
	assert_eq(b.remaining_count(), 3, "solve does not mutate the board")


func test_mutual_block_is_unsolvable() -> void:
	# Two arrows facing each other on one row.
	var b := TestBoards.make(6, 1, {"a": [[0, 0], [1, 0]], "b": [[5, 0], [4, 0]]})
	assert_eq(PuzzleSolver.solve(b), [] as Array[String])
	assert_false(PuzzleSolver.is_solvable(b))
	assert_false(b.has_legal_move(), "a deadlocked start state")


func test_four_cycle_is_unsolvable_even_with_free_arrow() -> void:
	var cyc := TestBoards.make(5, 5, {
		"p": [[0, 0], [1, 0]],  # right, sweeps into q at (4,0)
		"q": [[4, 0], [4, 1]],  # down, sweeps into r at (4,4)
		"r": [[4, 4], [3, 4]],  # left, sweeps into s at (0,4)
		"s": [[0, 4], [0, 3]],  # up, sweeps into p at (0,0)
		"f": [[2, 2], [2, 1]],  # up, free
	})
	assert_eq(cyc.find_blocker("f"), "")
	assert_eq(cyc.find_blocker("p"), "q")
	assert_eq(cyc.find_blocker("s"), "p")
	assert_false(PuzzleSolver.is_solvable(cyc), "4-cycle cannot be broken")
	var result := PuzzleSolver.explore(cyc)
	assert_false(result.complete)
	assert_eq(result.deadlocks, 1, "only the state after f leaves is reachable and stuck")


func test_verify_solution_accepts_valid_and_rejects_invalid() -> void:
	var b := TestBoards.make(6, 5, {"a": [[0, 1], [1, 1]], "b": [[3, 0], [3, 1]], "c": [[2, 4], [3, 4]]})
	assert_true(PuzzleSolver.verify_solution(b, ["c", "b", "a"]).ok)
	var wrong := PuzzleSolver.verify_solution(b, ["a", "b", "c"])
	assert_false(wrong.ok)
	assert_eq(wrong.step, 0)
	assert_string_contains(wrong.error, "blocked by 'b'")
	assert_false(PuzzleSolver.verify_solution(b, ["c", "b"]).ok, "incomplete")
	assert_false(PuzzleSolver.verify_solution(b, ["c", "c", "b", "a"]).ok, "duplicate")
	assert_false(PuzzleSolver.verify_solution(b, ["c", "zz", "b", "a"]).ok, "unknown")
	assert_eq(b.remaining_count(), 3, "verification works on a copy")


func test_explore_small_solvable_board_has_no_deadlocks() -> void:
	var b := TestBoards.make(6, 5, {"a": [[0, 1], [1, 1]], "b": [[3, 0], [3, 1]], "c": [[2, 4], [3, 4]], "d": [[5, 2], [5, 3]]})
	var result := PuzzleSolver.explore(b)
	assert_true(result.complete)
	assert_eq(result.deadlocks, 0)
	assert_false(result.truncated)
	assert_gt(result.states, 4)


func test_empty_board_is_solved() -> void:
	var b := PuzzleBoard.new(4, 4)
	assert_true(PuzzleSolver.is_solvable(b))
	assert_eq(PuzzleSolver.dependency_depth(b), 0)
	assert_true(PuzzleSolver.verify_solution(b, []).ok)
	assert_true(PuzzleSolver.explore(b).complete)


func test_solve_from_partial_state() -> void:
	var b := TestBoards.make(6, 5, {"a": [[0, 1], [1, 1]], "b": [[3, 0], [3, 1]], "c": [[2, 4], [3, 4]]})
	b.remove("c")
	assert_eq(PuzzleSolver.solve(b), ["b", "a"] as Array[String])
