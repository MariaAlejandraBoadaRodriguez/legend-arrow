extends GutTest
## Level schema validation: malformed, overlapping and unsolvable content.

const ARROWS := {"a": [[0, 1], [1, 1]], "b": [[3, 0], [3, 1]], "c": [[2, 4], [3, 4]]}


func _good() -> Dictionary:
	return TestBoards.level("test_level", 6, 5, ARROWS.duplicate(true), ["c", "b", "a"])


func _errors_for(mutate: Callable) -> Array[String]:
	var lvl := _good()
	mutate.call(lvl)
	return LevelValidator.validate(TestBoards.via_json(lvl))


func _assert_rejected(mutate: Callable, expected_fragment: String) -> void:
	var errors := _errors_for(mutate)
	assert_false(errors.is_empty(), "expected rejection containing '%s'" % expected_fragment)
	var joined := " | ".join(errors)
	assert_string_contains(joined, expected_fragment)


func test_valid_level_passes_after_json_round_trip() -> void:
	assert_eq(LevelValidator.validate(TestBoards.via_json(_good())), [] as Array[String])


func test_rejects_non_object() -> void:
	assert_false(LevelValidator.validate([1, 2]).is_empty())
	assert_false(LevelValidator.validate(null).is_empty())


func test_rejects_wrong_schema_version() -> void:
	_assert_rejected(func(l): l["schema_version"] = 2, "schema_version")
	_assert_rejected(func(l): l.erase("schema_version"), "schema_version")


func test_rejects_bad_ids_and_difficulty() -> void:
	_assert_rejected(func(l): l["id"] = "", "id must be")
	_assert_rejected(func(l): l["id"] = "Bad Id", "id must be")
	_assert_rejected(func(l): l["creature_id"] = 7, "creature_id")
	_assert_rejected(func(l): l["difficulty"] = "impossible", "difficulty")


func test_rejects_bad_dimensions() -> void:
	_assert_rejected(func(l): l["width"] = 1, "width and height")
	_assert_rejected(func(l): l["height"] = 2.5, "width and height")
	_assert_rejected(func(l): l["width"] = 41, "width and height")
	_assert_rejected(func(l): l.erase("height"), "width and height")


func test_rejects_empty_or_missing_arrows() -> void:
	_assert_rejected(func(l): l["arrows"] = [], "non-empty")
	_assert_rejected(func(l): l.erase("arrows"), "non-empty")


func test_rejects_out_of_bounds_cell() -> void:
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[5, 1], [6, 1]], "out of bounds")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, -1], [0, 0]], "out of bounds")


func test_rejects_overlapping_paths() -> void:
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[2, 1], [3, 1]], "overlaps arrow 'a' at (3, 1)")


func test_rejects_non_adjacent_and_diagonal_steps() -> void:
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [2, 1]], "not orthogonally adjacent")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [1, 2]], "not orthogonally adjacent")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [0, 1]], "repeats within the path")


func test_rejects_repeated_cell_in_path() -> void:
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [1, 1], [0, 1]], "repeats within the path")


func test_rejects_short_and_malformed_paths() -> void:
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1]], "at least 2 cells")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [1]], "[x, y] integers")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], ["1", 1]], "[x, y] integers")
	_assert_rejected(func(l): l["arrows"][0]["cells"] = [[0, 1], [1.5, 1]], "[x, y] integers")
	_assert_rejected(func(l): l["arrows"][0] = "a", "must be an object")


func test_rejects_duplicate_arrow_ids() -> void:
	_assert_rejected(func(l): l["arrows"][1]["id"] = "a", "duplicate id")


func test_rejects_bad_solutions() -> void:
	_assert_rejected(func(l): l["solution"] = ["a", "b", "c"], "recorded solution fails at step 0")
	_assert_rejected(func(l): l["solution"] = ["c", "b"], "every arrow exactly once")
	_assert_rejected(func(l): l["solution"] = ["c", "b", "a", "a"], "twice")
	_assert_rejected(func(l): l["solution"] = ["c", "b", "zz"], "unknown arrow 'zz'")
	_assert_rejected(func(l): l.erase("solution"), "solution must be an array")


func test_rejects_unsolvable_board() -> void:
	var lvl := TestBoards.level("stuck", 6, 2, {"a": [[0, 0], [1, 0]], "b": [[5, 0], [4, 0]]}, ["a", "b"])
	var joined := " | ".join(LevelValidator.validate(TestBoards.via_json(lvl)))
	assert_string_contains(joined, "not solvable")


func test_difficulty_band_enforced() -> void:
	_assert_rejected(func(l): l["difficulty"] = "easy", "easy levels need 6-12 arrows")
