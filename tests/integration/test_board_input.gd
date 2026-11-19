extends GutTest
## BoardView input: tap vs drag, multitouch, cancel, hit testing, focus.

var board: BoardView
var session: PuzzleSession
var tapped: Array = []


func before_each() -> void:
	var lvl := TestBoards.level("input", 6, 5, {
		"a": [[0, 1], [1, 1]],
		"b": [[3, 0], [3, 1]],
		"c": [[2, 4], [3, 4]],
		"d": [[5, 2], [5, 3]],
	}, ["c", "b", "a", "d"])
	session = PuzzleSession.new(TestBoards.via_json(lvl))
	board = BoardView.new()
	board.size = Vector2(600, 500)
	add_child_autofree(board)
	board.bind(session)
	tapped.clear()
	board.arrow_tapped.connect(func(id): tapped.append(id))


func _center(id: String) -> Vector2:
	var cells := session.board.arrow(id).cells
	return board.cell_center(cells[0])


func test_tap_on_arrow_emits_its_id() -> void:
	AppDriver.new(self, "x").tap_at(board, _center("c"))
	assert_eq(tapped, ["c"])


func test_tap_on_empty_space_does_nothing() -> void:
	AppDriver.new(self, "x").tap_at(board, board.cell_center(Vector2i(0, 4)))
	assert_eq(tapped, [])


func test_drag_beyond_threshold_is_not_a_tap() -> void:
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	board._gui_input(AppDriver.drag(p + Vector2(60, 0)))
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, [], "moved away and back: still a drag")
	board._gui_input(AppDriver.touch(p, true))
	board._gui_input(AppDriver.touch(p + Vector2(BoardView.DRAG_THRESHOLD + 5, 0), false))
	assert_eq(tapped, [])


func test_small_jitter_still_taps() -> void:
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	board._gui_input(AppDriver.drag(p + Vector2(6, 4)))
	board._gui_input(AppDriver.touch(p + Vector2(6, 4), false))
	assert_eq(tapped, ["c"])


func test_multitouch_never_taps() -> void:
	board._gui_input(AppDriver.touch(_center("c"), true, 0))
	board._gui_input(AppDriver.touch(_center("d"), true, 1))
	board._gui_input(AppDriver.touch(_center("d"), false, 1))
	board._gui_input(AppDriver.touch(_center("c"), false, 0))
	assert_eq(tapped, [])
	AppDriver.new(self, "x").tap_at(board, _center("c"))
	assert_eq(tapped, ["c"], "single taps work again afterwards")


func test_canceled_touch_never_taps() -> void:
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	board._gui_input(AppDriver.touch(p, false, 0, true))
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, [])


func test_long_press_is_not_a_tap() -> void:
	# A real hold: time passes and the game keeps drawing frames (60 fps).
	var now := [10.0]
	var frame := [100]
	board.clock = func() -> float: return now[0]
	board.frame_clock = func() -> int: return frame[0]
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	now[0] += BoardView.LONG_PRESS + 0.1
	frame[0] += 54
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, [])
	board._gui_input(AppDriver.touch(p, true))
	now[0] += BoardView.LONG_PRESS - 0.2
	frame[0] += 36
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, ["c"], "a quick press still taps")


func test_long_press_still_counts_at_low_frame_rates() -> void:
	# 12.5 fps: a 1 s hold spans 12-13 frames and is still a long press.
	var now := [10.0]
	var frame := [100]
	board.clock = func() -> float: return now[0]
	board.frame_clock = func() -> int: return frame[0]
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	now[0] += 1.0
	frame[0] += 12
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, [])


func test_quick_tap_across_a_slow_frame_still_taps() -> void:
	# Regression (CI run 44595886933, API 36 tablet): a quick tap whose press
	# and release were processed 2 frames apart, but with slow frames in
	# between (0.7 s seen on the software-GPU emulator, more on a hitch), was
	# timed as a long press and dropped, so the tutorial step never finished.
	var now := [10.0]
	var frame := [100]
	board.clock = func() -> float: return now[0]
	board.frame_clock = func() -> int: return frame[0]
	var p := _center("c")
	board._gui_input(AppDriver.touch(p, true))
	now[0] += 1.5    # one long stall (shader compile, GC, software GPU)
	frame[0] += 2
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, ["c"], "a stall between press and release is not a long press")
	board._gui_input(AppDriver.touch(p, true))
	now[0] += 0.0    # press and release delivered in the same frame
	board._gui_input(AppDriver.touch(p, false))
	assert_eq(tapped, ["c", "c"])


func test_hit_testing_follows_layout_at_any_size() -> void:
	for s in [Vector2(300, 900), Vector2(1200, 700), Vector2(720, 1280)]:
		board.size = s
		await wait_process_frames(1)
		for id in ["a", "b", "c", "d"]:
			for c in session.board.arrow(id).cells:
				assert_eq(board.arrow_at(board.cell_center(c)), id, "size %s cell %s" % [s, c])
		# Board coordinates invert cell_center exactly.
		var back := board.to_board(board.cell_center(Vector2i(4, 3)))
		assert_almost_eq(back.x, 4.0, 0.0001)
		assert_almost_eq(back.y, 3.0, 0.0001)


func test_nearest_path_wins_and_far_points_miss() -> void:
	var cell := board.cell_size()
	var a_head := board.cell_center(Vector2i(1, 1))
	assert_eq(board.arrow_at(a_head + Vector2(0, cell * 0.4)), "a", "padded hit area")
	assert_eq(board.arrow_at(a_head + Vector2(0, cell * 0.9)), "", "beyond the threshold")


func test_input_locked_while_exit_animates() -> void:
	session.tap("c")
	board.play_exit("c")
	AppDriver.new(self, "x").tap_at(board, _center("d"))
	assert_eq(tapped, [], "no taps during an exit")
	board.finish_animations()
	AppDriver.new(self, "x").tap_at(board, _center("d"))
	assert_eq(tapped, ["d"])


func test_keyboard_focus_moves_and_confirms() -> void:
	board.move_focus("ui_right")
	assert_eq(board.focused_id(), "a", "first press focuses the first arrow")
	board.move_focus("ui_right")
	assert_eq(board.focused_id(), "b")
	board.move_focus("ui_down")
	assert_ne(board.focused_id(), "b")
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	board._gui_input(ev)
	assert_eq(tapped, [board.focused_id()])


func test_reduced_motion_shortens_exit() -> void:
	board.reduce_motion = true
	session.tap("c")
	board.play_exit("c")
	await wait_seconds(0.2)
	assert_false(board.is_animating(), "reduced-motion exit is a short fade")
	board.reduce_motion = false
	session.tap("d")
	board.play_exit("d")
	await wait_seconds(0.15)
	assert_true(board.is_animating(), "normal exit lasts 200-400 ms")
	await wait_seconds(0.35)
	assert_false(board.is_animating())


func test_zoom_keeps_focus_point_fixed() -> void:
	var focus := board.size / 2.0
	var before := board.to_board(focus)
	board.zoom_at(2.0, focus)
	assert_almost_eq(board.zoom, 2.0, 0.0001)
	var after := board.to_board(focus)
	assert_almost_eq(after.x, before.x, 0.001, "same board point under the fingers")
	assert_almost_eq(after.y, before.y, 0.001)


func test_zoom_is_clamped_and_resets_pan() -> void:
	board.zoom_at(10.0, Vector2(50, 50))
	assert_eq(board.zoom, BoardView.MAX_ZOOM)
	board.zoom_at(0.01, Vector2(50, 50))
	assert_eq(board.zoom, 1.0)
	assert_eq(board.pan, Vector2.ZERO, "back to fit: no pan")


func test_hits_stay_exact_when_zoomed_and_panned() -> void:
	board.zoom_at(2.5, board.cell_center(Vector2i(3, 1)))
	board.pan_by(Vector2(-40, 25))
	for id in ["a", "b", "c", "d"]:
		for c in session.board.arrow(id).cells:
			var p := board.cell_center(c)
			if Rect2(Vector2.ZERO, board.size).has_point(p):
				assert_eq(board.arrow_at(p), id, "zoomed hit on %s %s" % [id, c])
	var visible := board.cell_center(Vector2i(3, 1))
	AppDriver.new(self, "x").tap_at(board, visible)
	assert_eq(tapped, ["b"], "tap after zoom selects the arrow under the finger")


func test_pan_is_clamped_to_the_board() -> void:
	board.zoom_at(3.0, board.size / 2.0)
	board.pan_by(Vector2(100000, 100000))
	var top_left := board.cell_center(Vector2i(0, 0))
	assert_lt(top_left.x, board.size.x, "board cannot be dragged out of view")
	assert_lt(top_left.y, board.size.y)


func test_pinch_zooms_and_never_taps() -> void:
	var a := board.size / 2.0 + Vector2(-40, 0)
	var b := board.size / 2.0 + Vector2(40, 0)
	board._gui_input(AppDriver.touch(a, true, 0))
	board._gui_input(AppDriver.touch(b, true, 1))
	board._gui_input(AppDriver.drag(b + Vector2(80, 0), 1))
	board._gui_input(AppDriver.touch(b + Vector2(80, 0), false, 1))
	board._gui_input(AppDriver.touch(a, false, 0))
	assert_gt(board.zoom, 1.5, "fingers moved apart: zoomed in")
	assert_eq(tapped, [], "a pinch is never a tap")


func test_mouse_wheel_zooms() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = board.size / 2.0
	board._gui_input(e)
	assert_gt(board.zoom, 1.0)


# --- v0.2: 48 dp touch targets on large boards (D-48) ----------------------

func _big_session() -> PuzzleSession:
	var c: Campaign = Campaign.load_file().campaign
	return PuzzleSession.new(LevelData.load_file(c.level_path("ancient_dragon")).level)


func test_large_board_never_shrinks_cells_below_the_touch_minimum() -> void:
	var big := BoardView.new()
	big.size = Vector2(360, 640)   # a narrow phone column
	add_child_autofree(big)
	big.bind(_big_session())
	var min_cell := Ui.dp(BoardView.MIN_CELL_DP, big)
	assert_gte(big.cell_size(), min_cell - 0.01, "cell >= 40 dp")
	assert_gte(big.cell_size() * BoardView.HIT_RADIUS * 2.0, Ui.dp(48.0, big) - 0.01, "hit band >= 48 dp")
	assert_gt(big.min_zoom, 1.0, "an 18-column board opens zoomed on a phone column")
	big.zoom_at(0.1, big.size / 2.0)
	assert_gte(big.cell_size(), min_cell - 0.01, "pinching out cannot go below the minimum")


func test_binding_before_layout_does_not_produce_an_absurd_zoom() -> void:
	var v := BoardView.new()
	add_child_autofree(v)
	v.bind(session)            # size is still zero here
	v.size = Vector2(600, 500)
	v._layout()
	assert_almost_eq(v.zoom, v.min_zoom, 0.001, "follows the minimum zoom, not a zero-size one")
	assert_eq(v.min_zoom, 1.0, "a small board fits without zoom")


func test_reveal_brings_an_off_screen_arrow_into_view_and_taps_hit() -> void:
	var big := BoardView.new()
	big.size = Vector2(360, 640)
	add_child_autofree(big)
	var s := _big_session()
	big.bind(s)
	var hits: Array = []
	big.arrow_tapped.connect(func(id): hits.append(id))
	var target := ""
	for id in s.board.remaining_ids():
		var cells := s.board.arrow(id).cells
		if not big.is_cell_visible(cells[cells.size() / 2]):
			target = id
			break
	assert_ne(target, "", "some arrow starts off screen on a zoomed board")
	big.reveal(target)
	var mid: Vector2i = s.board.arrow(target).cells[s.board.arrow(target).cells.size() / 2]
	assert_true(big.is_cell_visible(mid))
	big._gui_input(AppDriver.touch(big.cell_center(mid), true))
	big._gui_input(AppDriver.touch(big.cell_center(mid), false))
	assert_eq(hits, [target])
