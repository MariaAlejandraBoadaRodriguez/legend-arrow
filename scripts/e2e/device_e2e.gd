class_name DeviceE2E
extends Node
## On-device end-to-end journeys (brief §4 E2E 1-6), run inside the real APK
## on an emulator by scripts/android_e2e.sh. Debug builds only: release builds
## never read the trigger file.
##
## Interaction is real: every tap is an InputEventScreenTouch pushed through
## Input.parse_input_event at the control's on-screen position, so it travels
## the same path as a finger (window -> viewport -> GUI, with touch-to-mouse
## emulation for buttons). Ads use the scripted MockAdProvider: no live ad is
## ever requested. Results go to logcat ("LEGEND_E2E ...") and to
## user://e2e/result_<journey>.txt; screenshots to user://e2e/*.png.
##
## A journey ending in "_a" leaves state for its "_b" half, which runs after the
## CI script force-stops and relaunches the app.

const TRIGGER := "user://e2e_journey.txt"
const OUT_DIR := "user://e2e"
const JOURNEYS := ["fresh_install", "partial_a", "partial_b", "blocked_undo", "hint_ad",
	"awakening_replay", "settings_a", "settings_b"]

var journey := ""
var mock: MockAdProvider
var _failed := ""
var _log: Array[String] = []
var _shots := 0


## The journey to run, or "" (release builds, or no trigger file).
static func requested_journey() -> String:
	if not OS.is_debug_build():
		return ""
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--e2e="):
			return a.substr(6)
	if FileAccess.file_exists(TRIGGER):
		var j := FileAccess.get_file_as_string(TRIGGER).strip_edges()
		DirAccess.remove_absolute(TRIGGER)  # one run per trigger
		return j
	return ""


func _init(p_journey: String) -> void:
	journey = p_journey
	name = "DeviceE2E"


## Called by Main before routing so no live ad SDK is ever touched.
func install_mock_ads() -> void:
	mock = MockAdProvider.new()
	Game.set_ad_provider(mock)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_run.call_deferred()


func _run() -> void:
	_say("START %s user_dir=%s %s" % [journey, OS.get_user_data_dir(), get_viewport().get_visible_rect().size])
	if not JOURNEYS.has(journey):
		_fail("unknown journey")
	else:
		await frames(10)
		await Callable(self, journey).call()
	var verdict := "PASS" if _failed == "" else "FAIL"
	var f := FileAccess.open(OUT_DIR.path_join("result_%s.txt" % journey), FileAccess.WRITE)
	f.store_string("%s %s\n%s\n" % [verdict, journey, "\n".join(_log)])
	f.close()
	_say("%s %s%s" % [verdict, journey, "" if _failed == "" else ": " + _failed])


# --- journeys -----------------------------------------------------------------

## 1. Fresh installation -> tutorial -> first completed creature.
func fresh_install() -> void:
	if not check(not Game.progression.data.tutorial_done, "fresh save"): return
	if not await wait_screen("home"): return
	await shot("home")
	if not await tap("PlayButton"): return
	if not await wait_screen("tutorial"): return
	var tut: Control = Game.current_screen()
	await shot("tutorial_1")
	if not await tap_arrow(tut.board, tut.steps()[0].highlight): return
	if not check(tut.is_step_done(), "step 1 done by tapping the free arrow"): return
	if not await tap("NextButton"): return
	var target: String = tut.steps()[1].highlight
	if not await tap_arrow(tut.board, target): return
	if not check(tut.session.board.remaining_count() == 2, "blocked tap moved nothing"): return
	await shot("tutorial_2_blocked")
	for id in tut.steps()[1].level.solution:
		if not await tap_arrow(tut.board, id): return
	if not await tap("NextButton"): return
	for id in tut.steps()[2].level.solution:
		if not await tap_arrow(tut.board, id): return
	if not await tap("NextButton"): return
	if not await wait_screen("level_select"): return
	await shot("level_select")
	if not await tap("PlayButton"): return
	if not await solve_current("forest_drake_1"): return
	if not await wait_screen("level_complete"): return
	if not check(not Game.progression.is_creature_unlocked("forest_drake"), "1 of 2 does not unlock"): return
	await shot("level_complete")
	if not await tap("ContinueButton"): return
	if not await solve_current("forest_drake_2"): return
	if not await wait_screen("awakening"): return
	if not check(_saved().creatures.forest_drake.unlocked, "unlock on disk before the awakening ends"): return
	await seconds(2.5)
	await shot("awakening")
	if not await wait_for(func(): return Game.current_screen().get("finished") == true, 10.0, "awakening finishes"): return
	await shot("awakening_done")
	if not await tap("ContinueButton"): return
	if not await wait_screen("creature_detail"): return
	await shot("creature_detail")


## 2a. Partial puzzle, then the CI script kills the app.
func partial_a() -> void:
	if not await open_next_puzzle("moon_owl_1"): return
	var pz: Control = Game.current_screen()
	for id in pz.level.solution.slice(0, 2):
		if not await tap_arrow(pz.board, id): return
	await idle(pz.board)
	var saved: Dictionary = _saved().get("in_progress", {})
	if not check(saved.get("level_id", "") == "moon_owl_1" and saved.get("removed", []).size() == 2,
			"partial state on disk: %s" % str(saved)): return
	await shot("partial_before_kill")


## 2b. Relaunch after termination restores the partial puzzle, then finish it.
func partial_b() -> void:
	if not await wait_screen("home"): return
	if not await open_next_puzzle("moon_owl_1"): return
	var pz: Control = Game.current_screen()
	var total: int = pz.level.arrows.size()
	if not check(pz.session.board.remaining_count() == total - 2,
			"restored %d of %d" % [pz.session.board.remaining_count(), total]): return
	await shot("partial_restored")
	for id in pz.level.solution:
		if pz.session.board.has_arrow(id) and pz.session.board.remaining_ids().has(id):
			if not await tap_arrow(pz.board, id): return
	if not await wait_screen("level_complete"): return


## 3. Blocked move -> undo/restart -> successful completion.
func blocked_undo() -> void:
	if not await open_next_puzzle("moon_owl_2"): return
	var pz: Control = Game.current_screen()
	var board: PuzzleBoard = pz.session.board
	var blocked := ""
	for id in board.remaining_ids():
		if not board.is_removable(id):
			blocked = id
			break
	if not check(blocked != "", "level starts with a blocked arrow"): return
	var total := board.remaining_count()
	if not await tap_arrow(pz.board, blocked): return
	if not check(board.remaining_count() == total, "blocked tap leaves the board unchanged"): return
	await shot("blocked_message")
	var free_id: String = board.removable_ids()[0]
	if not await tap_arrow(pz.board, free_id): return
	if not check(board.remaining_count() == total - 1, "free arrow exits"): return
	await idle(pz.board)
	if not await tap("UndoButton"): return
	if not check(board.remaining_count() == total and board.remaining_ids().has(free_id), "undo restores it"): return
	await idle(pz.board)
	for id in pz.level.solution.slice(0, 3):
		if not await tap_arrow(pz.board, id): return
	await idle(pz.board)
	if not await tap("RestartButton"): return
	if not check(board.remaining_count() == total, "restart restores every arrow"): return
	if not await solve_current("moon_owl_2"): return
	if not await wait_screen("awakening"): return
	if not check(Game.progression.is_creature_unlocked("moon_owl"), "moon owl unlocked"): return
	if not await wait_for(func(): return Game.current_screen().get("finished") == true, 30.0, "awakening finishes"): return
	if not await tap("ContinueButton"): return
	if not await wait_screen("creature_detail"): return


## 4. Rewarded hint success, then the ad-unavailable fallback.
func hint_ad() -> void:
	if not await open_next_puzzle("antler_fox_1"): return
	var pz: Control = Game.current_screen()
	for i in 3:  # spend the three free hints by following them
		if not await tap("HintButton"): return
		var h: String = pz.board.hint_id()
		if not check(h != "" and pz.session.board.is_removable(h), "free hint %d points at a free arrow" % (i + 1)): return
		if not await tap_arrow(pz.board, h): return
		await idle(pz.board)
	if not await tap("HintButton"): return
	if not await wait_dialog(pz, "HintSheet"): return
	await shot("hint_sheet")
	if not await tap("WatchAdButton"): return
	if not await wait_for(func(): return pz.board.hint_id() != "", 5.0, "earned hint appears"): return
	if not check(not Game.progression.data.ad_receipts.is_empty(), "receipt saved"): return
	if not check(not _saved().ad_receipts.is_empty(), "receipt on disk"): return
	await shot("ad_hint_shown")
	if not await tap_arrow(pz.board, pz.board.hint_id()): return
	await idle(pz.board)
	# Fallback: the network goes away.
	mock.load_outcome = "offline"
	Game.ads._last_failure_at = -INF
	if Game.ads.reward_state == AdService.RewardState.READY:
		Game.ads.reward_state = AdService.RewardState.IDLE  # drop the preloaded ad so the next load fails
	if not await tap("HintButton"): return
	if not await wait_dialog(pz, "HintSheet"): return
	if pz.find_child("WatchAdButton", true, false) != null:
		if not await tap("WatchAdButton"): return
		if not await wait_dialog(pz, "NoAdSheet"): return
		await shot("no_ad_sheet")
		if not await tap("ReturnToPuzzle"): return
	else:
		if not await tap("KeepPlaying"): return
	if not await wait_for(func(): return Dialog.top(pz) == null, 2.0, "sheet closes"): return
	if not await solve_current("antler_fox_1"): return
	if not await wait_screen("level_complete"): return


## 5. Creature awakening -> skip/replay -> bestiary.
func awakening_replay() -> void:
	if not await wait_screen("home"): return
	if not await tap("BestiaryButton"): return
	if not await wait_screen("bestiary"): return
	await shot("bestiary")
	if not await tap("Tile_forest_drake"): return
	if not await wait_screen("creature_detail"): return
	if not await tap("ReplayAwakening"): return
	if not await wait_screen("awakening"): return
	await seconds(1.3)
	if not await tap("SkipButton"): return
	if not await wait_for(func(): return Game.current_screen().get("finished") == true, 2.0, "skip finishes"): return
	if not await tap("ContinueButton"): return
	if not await wait_screen("creature_detail"): return
	if not check(Game.events.count("creature_unlock") == 0, "replay unlocks nothing"): return
	Game.back()
	if not await wait_screen("bestiary"): return


## 6a. Change language and reduced motion through the settings UI.
func settings_a() -> void:
	if not await wait_screen("home"): return
	if not await tap("SettingsButton"): return
	if not await wait_screen("settings"): return
	var before: bool = Game.settings().reduce_motion
	if not await tap("Toggle_reduce_motion"): return
	if not check(Game.settings().reduce_motion != before, "reduce motion toggled"): return
	if not await tap("LanguageOption"): return
	var opt := find("LanguageOption") as OptionButton
	var popup := opt.get_popup()
	if not await wait_for(func(): return popup.visible, 2.0, "language list opens"): return
	await shot("language_popup")
	# Choose "Español" with the keyboard/D-pad path inside the open list.
	popup.set_focused_item(0)
	for i in 2:
		await key_action("ui_down")
	await key_action("ui_accept")
	if not await wait_for(func(): return Game.settings().language == "es", 2.0, "language saved as es"): return
	if not check(TranslationServer.get_locale().begins_with("es"), "UI switched to Spanish"): return
	await shot("settings_es")


## 6b. After a restart the preferences are still there.
func settings_b() -> void:
	if not await wait_screen("home"): return
	if not check(Game.settings().language == "es", "language persisted"): return
	if not check(TranslationServer.get_locale().begins_with("es"), "Spanish after restart"): return
	if not check(Game.settings().reduce_motion == true, "reduce motion persisted"): return
	await shot("home_es")


# --- helpers ------------------------------------------------------------------

func _say(msg: String) -> void:
	print("LEGEND_E2E %s" % msg)


func check(ok: bool, what: String) -> bool:
	_log.append(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_fail(what)
	return ok


func _fail(what: String) -> void:
	if _failed == "":
		_failed = "%s (screen=%s)" % [what, Game.current_screen_name()]
		_say("STEP FAILED %s" % _failed)
		shot.call_deferred("failure")


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func wait_for(cond: Callable, timeout: float, what: String) -> bool:
	var start := Time.get_ticks_msec()
	var end := start + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if Game.current_screen() != null and cond.call():
			return check(true, "%s (%.1f s, %d fps)" % [what, (Time.get_ticks_msec() - start) / 1000.0, Engine.get_frames_per_second()])
		await get_tree().process_frame
	return check(false, what + " (timeout)")


func wait_screen(screen_name: String, timeout := 5.0) -> bool:
	var ok := await wait_for(func(): return Game.current_screen_name() == screen_name, timeout, "screen " + screen_name)
	await frames(3)  # let layout settle before tapping
	return ok


func wait_dialog(screen: Control, dialog_name: String) -> bool:
	return await wait_for(func():
		var d := Dialog.top(screen)
		return d != null and String(d.name) == dialog_name, 3.0, "dialog " + dialog_name)


func idle(board: BoardView) -> void:
	var w: WeakRef = weakref(board)
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		var b = w.get_ref()
		if b == null or not b.is_animating():
			return
		await get_tree().process_frame


## Visible control by name in the top dialog or the current screen.
func find(node_name: String) -> Control:
	var screen := Game.current_screen()
	if screen == null:
		return null
	var d := Dialog.top(screen)
	if d != null:
		var in_dialog := d.find_child(node_name, true, false) as Control
		if in_dialog != null:
			return in_dialog
	return screen.find_child(node_name, true, false) as Control


## A finger tap on the middle of a control.
func tap(node_name: String) -> bool:
	var c := find(node_name)
	if not check(c != null and c.is_visible_in_tree(), "find %s" % node_name):
		return false
	if c is BaseButton and not check(not c.disabled, "%s enabled" % node_name):
		return false
	var scroll := _scroll_parent(c)
	if scroll != null:
		scroll.ensure_control_visible(c)
		await frames(2)
	await touch(to_window(c, c.size * 0.5))
	return check(true, "tap %s" % node_name)


func tap_arrow(board: BoardView, id: String) -> bool:
	if not check(board.session.board.remaining_ids().has(id), "arrow %s on board" % id):
		return false
	await idle(board)
	var cells := board.session.board.arrow(id).cells
	var local := board.cell_center(cells[cells.size() / 2])
	await touch(to_window(board, local))
	return true


## Control-local point -> window pixels (what a finger reports), including the
## canvas_items stretch scale/offset of the root viewport.
func to_window(c: CanvasItem, local: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * local)


func touch(screen_pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = screen_pos
	down.pressed = true
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = screen_pos
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)


func key_action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


func _scroll_parent(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## From Home: Play -> level select (which preselects the next level) -> Play.
func open_next_puzzle(level_id: String) -> bool:
	if not await wait_screen("home"): return false
	if not await tap("PlayButton"): return false
	if not await wait_screen("level_select"): return false
	if not await tap("PlayButton"): return false
	if not await wait_screen("puzzle"): return false
	return check(Game.current_screen().level_id == level_id, "next level is %s (got %s)" % [level_id, Game.current_screen().level_id])


## Taps the remaining arrows of the current puzzle in recorded-solution order.
func solve_current(level_id: String) -> bool:
	if not await wait_screen("puzzle"): return false
	var pz: Control = Game.current_screen()
	if not check(pz.level_id == level_id, "puzzle %s" % level_id): return false
	await shot("puzzle_" + level_id)
	for id in pz.level.solution:
		if pz.session.board.remaining_ids().has(id):
			if not await tap_arrow(pz.board, id): return false
	return check(pz.session.is_complete(), "%s solved by taps" % level_id)


func _saved() -> Dictionary:
	return SaveRepository.new(Game.repository.path).load_save().data


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shots += 1
	img.save_png(OUT_DIR.path_join("%s_%02d_%s.png" % [journey, _shots, label]))
