extends GutTest
## Swept-body movement rules (spec §4, §19 "Puzzle rules").


func test_exit_right_on_empty_row() -> void:
	var b := TestBoards.make(5, 3, {"a": [[1, 1], [2, 1]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.RIGHT)
	assert_true(b.is_removable("a"))
	assert_true(b.remove("a"))
	assert_true(b.is_empty())


func test_exit_left() -> void:
	var b := TestBoards.make(5, 3, {"a": [[3, 1], [2, 1]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.LEFT)
	assert_true(b.remove("a"))


func test_exit_up() -> void:
	var b := TestBoards.make(3, 5, {"a": [[1, 3], [1, 2]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.UP)
	assert_true(b.remove("a"))


func test_exit_down() -> void:
	var b := TestBoards.make(3, 5, {"a": [[1, 1], [1, 2]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.DOWN)
	assert_true(b.remove("a"))


func test_blocked_in_each_direction() -> void:
	var cases := {
		"right": {"a": [[0, 1], [1, 1]], "w": [[4, 0], [4, 1]]},
		"left": {"a": [[4, 1], [3, 1]], "w": [[0, 0], [0, 1]]},
		"up": {"a": [[1, 4], [1, 3]], "w": [[0, 0], [1, 0]]},
		"down": {"a": [[1, 0], [1, 1]], "w": [[1, 4], [2, 4]]},
	}
	for name in cases:
		var b := TestBoards.make(5, 5, cases[name])
		assert_eq(b.find_blocker("a"), "w", "blocked moving %s" % name)
		assert_false(b.remove("a"), "cannot remove when blocked moving %s" % name)


func test_far_blocker_at_board_edge_still_blocks() -> void:
	var b := TestBoards.make(10, 2, {"a": [[0, 0], [1, 0]], "w": [[9, 0], [9, 1]]})
	assert_eq(b.find_blocker("a"), "w")


func test_arrow_behind_head_does_not_block() -> void:
	# w sits behind the tail, opposite to the exit direction.
	var b := TestBoards.make(6, 2, {"w": [[0, 0], [0, 1]], "a": [[1, 0], [2, 0]]})
	assert_true(b.is_removable("a"))


func test_clear_head_but_blocked_body() -> void:
	# a: L shape, tail (0,2) -> (1,2) -> head (1,1) moving UP.
	# The head's ray (1,0) is clear, but the tail cell (0,2) sweeps up through
	# (0,1) and (0,0), where w sits.
	var b := TestBoards.make(4, 3, {"a": [[0, 2], [1, 2], [1, 1]], "w": [[0, 0], [0, 1]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.UP)
	assert_eq(b.occupant(Vector2i(1, 0)), "", "nothing directly in front of the head")
	assert_eq(b.find_blocker("a"), "w")
	assert_false(b.remove("a"))


func test_body_ray_blocked_by_cell_outside_heads_column() -> void:
	# Long horizontal body moving down; only the last body cell is blocked.
	var b := TestBoards.make(5, 4, {"a": [[0, 0], [1, 0], [2, 0], [3, 0], [3, 1]], "w": [[0, 3], [1, 3]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.DOWN)
	assert_eq(b.find_blocker("a"), "w")


func test_own_cells_are_ignored() -> void:
	# U-turn: tail cells lie in the head's exit path; the arrow still leaves.
	var b := TestBoards.make(5, 3, {"a": [[0, 0], [1, 0], [1, 1], [0, 1]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.LEFT)
	assert_true(b.is_removable("a"))
	var spiral := TestBoards.make(5, 5, {"s": [[2, 0], [3, 0], [3, 1], [3, 2], [2, 2], [1, 2], [1, 1], [1, 0]]})
	assert_eq(spiral.arrow("s").direction(), ArrowPath.UP)
	assert_true(spiral.is_removable("s"), "self-overlapping sweep is allowed")


func test_bent_arrow_exits_in_final_segment_direction() -> void:
	var b := TestBoards.make(5, 5, {"a": [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]]})
	assert_eq(b.arrow("a").direction(), ArrowPath.RIGHT)
	assert_eq(b.exit_steps("a"), 5, "tail at x=0 needs 5 steps to clear a width-5 board")
	assert_true(b.remove("a"))


func test_exit_steps_until_fully_off_board() -> void:
	var b := TestBoards.make(4, 6, {"a": [[1, 4], [1, 3]]})
	# Moving up: the tail at y=4 needs 5 steps to reach y=-1.
	assert_eq(b.exit_steps("a"), 5)


func test_blocked_move_leaves_state_unchanged() -> void:
	var b := TestBoards.make(5, 3, {"a": [[0, 1], [1, 1]], "w": [[3, 0], [3, 1], [3, 2]]})
	var before := b.state_key()
	var cells_before := {}
	for c in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)]:
		cells_before[c] = b.occupant(c)
	assert_false(b.remove("a"))
	assert_eq(b.state_key(), before)
	assert_eq(b.remaining_count(), 2)
	for c in cells_before:
		assert_eq(b.occupant(c), cells_before[c], "cell %s unchanged" % c)


func test_removing_unknown_or_removed_arrow_is_rejected() -> void:
	var b := TestBoards.make(4, 2, {"a": [[0, 0], [1, 0]]})
	assert_false(b.remove("nope"))
	assert_true(b.remove("a"))
	assert_false(b.remove("a"), "already removed")
	assert_true(b.is_empty())


func test_removal_frees_cells_and_unblocks() -> void:
	var b := TestBoards.make(5, 3, {"a": [[0, 1], [1, 1]], "w": [[3, 1], [3, 2]]})
	assert_false(b.is_removable("a"))
	assert_true(b.remove("w"), "w moves down unobstructed")
	assert_eq(b.occupant(Vector2i(3, 1)), "")
	assert_true(b.is_removable("a"))


func test_add_arrow_rejects_overlap_out_of_bounds_and_duplicates() -> void:
	var b := TestBoards.make(4, 4, {"a": [[0, 0], [1, 0]]})
	assert_false(b.add_arrow(ArrowPath.new("b", [Vector2i(1, 0), Vector2i(1, 1)])), "overlap")
	assert_false(b.add_arrow(ArrowPath.new("c", [Vector2i(3, 3), Vector2i(4, 3)])), "out of bounds")
	assert_false(b.add_arrow(ArrowPath.new("a", [Vector2i(2, 2), Vector2i(2, 3)])), "duplicate id")
	assert_false(b.add_arrow(ArrowPath.new("d", [Vector2i(2, 2)])), "single cell")
	assert_eq(b.total_count(), 1)
	assert_eq(b.occupant(Vector2i(1, 1)), "", "failed add leaves no cells behind")


func test_restore_and_duplicate() -> void:
	var b := TestBoards.make(4, 4, {"a": [[0, 0], [1, 0]], "b": [[0, 2], [0, 3]]})
	b.remove("a")
	var copy := b.duplicate_board()
	assert_eq(copy.state_key(), b.state_key())
	copy.restore("a")
	assert_false(b.has_arrow("a"), "copy is independent")
	assert_true(copy.has_arrow("a"))
	assert_false(copy.restore("a"), "cannot restore a present arrow")
	b.restore_all()
	assert_eq(b.remaining_count(), 2)


func test_off_board_completion_on_empty_board() -> void:
	var b := PuzzleBoard.new(3, 3)
	assert_true(b.is_empty())
	assert_false(b.has_legal_move())
	assert_eq(b.removable_ids(), [] as Array[String])


func test_discard_arrow_forgets_definition() -> void:
	var b := TestBoards.make(4, 4, {"a": [[0, 0], [1, 0]]})
	b.discard_arrow("a")
	assert_eq(b.total_count(), 0)
	assert_eq(b.occupant(Vector2i(0, 0)), "")
	assert_true(b.add_arrow(ArrowPath.new("a", [Vector2i(0, 0), Vector2i(0, 1)])), "id reusable")
