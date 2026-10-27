extends GutTest
## Taps, undo, restart, hints, completion and saved-state replay.

const T := PuzzleSession.TapResult


func _session() -> PuzzleSession:
	# a blocked by b, b blocked by c, d independent. Solution: c, b, a, d.
	var lvl := TestBoards.level("lvl", 6, 5, {
		"a": [[0, 1], [1, 1]],
		"b": [[3, 0], [3, 1]],
		"c": [[2, 4], [3, 4]],
		"d": [[5, 2], [5, 3]],
	}, ["c", "b", "a", "d"])
	assert_eq(LevelValidator.validate(TestBoards.via_json(lvl)), [] as Array[String], "fixture valid")
	return PuzzleSession.new(TestBoards.via_json(lvl))


func test_legal_tap_removes_and_records_history() -> void:
	var s := _session()
	var r := s.tap("c")
	assert_eq(r.result, T.REMOVED)
	assert_false(s.board.has_arrow("c"))
	assert_eq(s.history, ["c"] as Array[String])


func test_blocked_tap_changes_nothing_and_names_blocker() -> void:
	var s := _session()
	var before := s.board.state_key()
	var r := s.tap("a")
	assert_eq(r.result, T.BLOCKED)
	assert_eq(r.blocker, "b")
	assert_eq(s.board.state_key(), before)
	assert_true(s.history.is_empty())


func test_repeated_taps_on_removed_arrow_are_ignored() -> void:
	var s := _session()
	s.tap("c")
	for i in 3:
		assert_eq(s.tap("c").result, T.IGNORED)
	assert_eq(s.history, ["c"] as Array[String], "no duplicate history entries")


func test_undo_restores_exactly_previous_arrow() -> void:
	var s := _session()
	var start := s.board.state_key()
	s.tap("c")
	var after_one := s.board.state_key()
	s.tap("b")
	assert_eq(s.undo(), "b")
	assert_eq(s.board.state_key(), after_one)
	assert_eq(s.undo(), "c")
	assert_eq(s.board.state_key(), start)
	assert_eq(s.undo(), "", "nothing left to undo")
	assert_false(s.can_undo())


func test_undo_after_blocked_tap_only_undoes_real_moves() -> void:
	var s := _session()
	s.tap("c")
	s.tap("a")  # blocked by b
	assert_eq(s.undo(), "c")


func test_restart_after_partial_progress() -> void:
	var s := _session()
	var start := s.board.state_key()
	s.tap("c")
	s.tap("b")
	s.restart()
	assert_eq(s.board.state_key(), start)
	assert_true(s.history.is_empty())
	assert_false(s.is_complete())
	assert_eq(s.tap("a").result, T.BLOCKED, "rules apply again after restart")


func test_completion_happens_once_and_locks_undo() -> void:
	var s := _session()
	for id in ["c", "b", "a"]:
		s.tap(id)
	assert_false(s.is_complete())
	assert_eq(s.tap("d").result, T.REMOVED)
	assert_true(s.is_complete())
	assert_true(s.board.is_empty())
	assert_eq(s.undo(), "", "a completed level cannot be undone")
	assert_eq(s.tap("d").result, T.IGNORED)


func test_restart_after_completion_allows_replay() -> void:
	var s := _session()
	for id in ["c", "b", "a", "d"]:
		s.tap(id)
	s.restart()
	assert_false(s.is_complete())
	assert_eq(s.board.remaining_count(), 4)


func test_hint_returns_removable_arrow_without_changing_state() -> void:
	var s := _session()
	var before := s.board.state_key()
	var h := s.hint()
	assert_eq(h, "c", "first solution arrow that is free")
	assert_true(s.board.is_removable(h))
	assert_eq(s.board.state_key(), before)
	s.tap("d")  # player deviates from the recorded order
	assert_eq(s.hint(), "c")
	s.tap("c")
	assert_eq(s.hint(), "b")


func test_hint_follows_any_order_and_is_empty_when_done() -> void:
	var s := _session()
	while not s.is_complete():
		var h := s.hint()
		assert_ne(h, "")
		assert_eq(s.tap(h).result, T.REMOVED)
	assert_eq(s.hint(), "")


func test_undo_after_hint() -> void:
	var s := _session()
	var h := s.hint()
	s.tap(h)
	assert_eq(s.undo(), h)
	assert_eq(s.hint(), h, "hint is stable after undo")


func test_progress_fraction() -> void:
	var s := _session()
	assert_eq(s.progress(), 0.0)
	s.tap("c")
	assert_almost_eq(s.progress(), 0.25, 0.0001)


func test_saved_state_round_trip() -> void:
	var s := _session()
	s.tap("c")
	s.tap("d")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := _session()
	assert_true(t.apply_saved(saved))
	assert_eq(t.board.state_key(), s.board.state_key())
	assert_eq(t.history, s.history)
	assert_eq(t.undo(), "d", "undo history survives reload")


func test_tampered_save_is_rejected_safely() -> void:
	var t := _session()
	assert_false(t.apply_saved({"level_id": "lvl", "removed": ["a"]}), "illegal first move")
	assert_eq(t.board.remaining_count(), 4)
	assert_false(t.apply_saved({"level_id": "other", "removed": []}))
	assert_false(t.apply_saved({"level_id": "lvl", "removed": "c"}))
	assert_false(t.apply_saved({"level_id": "lvl", "removed": ["c", "c"]}))
	assert_eq(t.board.remaining_count(), 4)
	assert_true(t.history.is_empty())
