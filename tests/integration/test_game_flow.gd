extends GutTest
## Critical journeys driven through the real screens (brief §4 E2E list),
## in-engine. Android-instrumented versions of these run in M5.

var app: AppDriver


func before_each() -> void:
	app = AppDriver.new(self, "flow")
	app.start()
	Game.set_setting("reduce_motion", true)  # short animations keep tests fast
	await wait_process_frames(1)


func after_each() -> void:
	app.stop()
	await wait_process_frames(3)  # let queue_free() of the last screen run


func _layout() -> void:
	await wait_process_frames(3)


func test_journey_fresh_install_tutorial_to_first_creature() -> void:
	Game.reset_to("home")
	await _layout()
	assert_false(Game.progression.data.tutorial_done)
	assert_true(app.press("PlayButton"))
	assert_eq(Game.current_screen_name(), "tutorial", "first Play opens the tutorial")
	await _layout()
	var tut: Control = app.screen()
	# Step 1: tap the arrow with a clear way out.
	assert_false(app.press("NextButton"), "Next is locked until the step is done")
	app.tap_arrow(tut.board, tut.steps()[0].highlight)
	assert_true(tut.is_step_done())
	assert_true(app.press("NextButton"))
	await _layout()
	# Step 2: the highlighted arrow is blocked; a harmless blocked tap first.
	var target: String = tut.steps()[1].highlight
	app.tap_arrow(tut.board, target)
	assert_eq(tut.session.board.remaining_count(), 2, "blocked tap moved nothing")
	assert_eq(tut._feedback.text, "BLOCKED_MESSAGE")
	for id in tut.steps()[1].level.solution:
		await app.board_idle(tut.board)
		app.tap_arrow(tut.board, id)
	assert_true(tut.is_step_done())
	assert_true(app.press("NextButton"))
	await _layout()
	for id in tut.steps()[2].level.solution:
		await app.board_idle(tut.board)
		app.tap_arrow(tut.board, id)
	assert_true(tut.is_step_done())
	assert_true(app.press("NextButton"))
	assert_eq(Game.current_screen_name(), "level_select")
	assert_true(Game.progression.data.tutorial_done)
	assert_eq(Game.events.count("tutorial_complete"), 1)
	await _layout()
	assert_true(app.press("PlayButton"))
	assert_eq(Game.current_screen_name(), "puzzle")
	assert_eq(app.screen().level_id, "forest_drake_1")
	await _layout()
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_false(Game.progression.is_creature_unlocked("forest_drake"), "1 of 2 does not unlock")
	assert_eq((app.screen().find_child("Status", true, false) as Label).text, tr("N_OF_2_COMPLETE") % 1)
	assert_true(app.press("ContinueButton"))
	assert_eq(app.screen().level_id, "forest_drake_2")
	await _layout()
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "awakening")
	assert_true(Game.progression.is_creature_unlocked("forest_drake"))
	# Unlock is on disk before the awakening finishes.
	var on_disk: Dictionary = SaveRepository.new(app.save_path).load_save().data
	assert_true(on_disk.creatures.forest_drake.unlocked)
	await wait_until(func():
		var c: Control = Game.current_screen()
		return c != null and c.get("finished") == true, 3.0)
	assert_true(app.press("ContinueButton"))
	assert_eq(Game.current_screen_name(), "creature_detail")
	assert_eq(Game.events.count("creature_unlock"), 1)


func test_journey_partial_puzzle_survives_termination() -> void:
	Game.progression.data.tutorial_done = true
	Game.reset_to("home")
	Game.go("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await _layout()
	var pz: Control = app.screen()
	var first: String = pz.level.solution[0]
	var second: String = pz.level.solution[1]
	app.tap_arrow(pz.board, first)
	await app.board_idle(pz.board)
	app.tap_arrow(pz.board, second)
	var expected_key: String = pz.session.board.state_key()
	# Process killed without any further save call.
	var res := app.relaunch()
	assert_eq(res.source, SaveRepository.Source.MAIN)
	Game.reset_to("home")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await _layout()
	assert_eq(app.screen().session.board.state_key(), expected_key, "board restored exactly")
	assert_eq(app.screen().session.history, [first, second] as Array[String], "undo history restored")


func test_journey_blocked_then_undo_restart_then_complete() -> void:
	Game.progression.data.tutorial_done = true
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_1"})
	await _layout()
	var pz: Control = app.screen()
	var blocked := ""
	for id in pz.session.board.remaining_ids():
		if not pz.session.board.is_removable(id):
			blocked = id
			break
	assert_ne(blocked, "", "level has a blocked arrow at the start")
	var start_key: String = pz.session.board.state_key()
	app.tap_arrow(pz.board, blocked)
	assert_eq(pz.session.board.state_key(), start_key)
	assert_eq(pz._message.text, "BLOCKED_MESSAGE")
	assert_eq(Game.events.count("blocked_tap"), 1)
	app.tap_arrow(pz.board, pz.level.solution[0])
	await app.board_idle(pz.board)
	assert_true(app.press("UndoButton"))
	assert_eq(pz.session.board.state_key(), start_key, "undo restores the board")
	app.tap_arrow(pz.board, pz.level.solution[0])
	await app.board_idle(pz.board)
	assert_true(app.press("RestartButton"))
	assert_eq(pz.session.board.state_key(), start_key, "restart restores the board")
	assert_eq(Game.progression.data.in_progress.removed, [], "restart is saved")
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_true(Game.progression.is_level_completed("forest_drake_1"))


func test_hints_spend_free_then_show_sheet() -> void:
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await _layout()
	var pz: Control = app.screen()
	assert_eq(app.button("HintButton").text, tr("HINT_FREE") % 3)
	app.press("HintButton")
	var hinted: String = pz.board.hint_id()
	assert_ne(hinted, "")
	assert_true(pz.session.board.is_removable(hinted), "hint is a removable arrow")
	app.press("HintButton")
	assert_eq(Game.progression.free_hints_left("forest_drake_2"), 2, "re-pressing while shown costs nothing")
	for i in 2:
		app.tap_arrow(pz.board, pz.board.hint_id())
		await app.board_idle(pz.board)
		app.press("HintButton")
	assert_eq(Game.progression.free_hints_left("forest_drake_2"), 0)
	app.tap_arrow(pz.board, pz.board.hint_id())
	await app.board_idle(pz.board)
	app.press("HintButton")
	assert_not_null(Dialog.top(pz), "out of free hints: sheet explains")
	assert_eq(Dialog.top(pz).name, "HintSheet")
	assert_true(app.press("KeepPlaying"))
	assert_null(Dialog.top(pz))


func test_awakening_skip_replay_and_bestiary() -> void:
	Game.set_setting("reduce_motion", false)
	for l in ["forest_drake_1", "forest_drake_2"]:
		Game.progression.complete_level(l)
	Game.reset_to("home")
	Game.go("awakening", {"creature_id": "forest_drake", "replay": false})
	await _layout()
	var aw: Control = app.screen()
	assert_false(aw.can_skip(), "not skippable during the first second")
	assert_false(app.button("SkipButton").visible)
	await wait_seconds(1.1)
	assert_true(app.button("SkipButton").visible, "Skip shows while playing")
	assert_false(app.button("ContinueButton").visible)
	assert_true(app.press("SkipButton"))
	assert_true(aw.finished)
	assert_false(app.button("SkipButton").visible, "Skip hidden at the end")
	assert_true(app.button("ContinueButton").visible)
	assert_eq(Game.progression.pending_awakening(), "")
	app.press("ContinueButton")
	assert_eq(Game.current_screen_name(), "creature_detail")
	await _layout()
	var unlocked_before := Game.progression.unlocked_count()
	app.press("ReplayAwakening")
	assert_eq(Game.current_screen_name(), "awakening")
	await wait_seconds(1.1)
	app.press("SkipButton")
	app.press("ContinueButton")
	assert_eq(Game.current_screen_name(), "creature_detail", "replay returns to detail")
	assert_eq(Game.progression.unlocked_count(), unlocked_before, "replay grants nothing")
	app.press("OpenBestiary")
	assert_eq(Game.current_screen_name(), "bestiary")
	await _layout()
	var tile := app.button("Tile_forest_drake")
	assert_false(tile.disabled)
	assert_null(tile.find_child("Locked", true, false))


func test_bestiary_shows_locked_creature_as_locked() -> void:
	Game.reset_to("bestiary")
	await _layout()
	var tile := app.button("Tile_forest_drake")
	assert_true(tile.disabled, "locked creature cannot be opened")
	assert_not_null(tile.find_child("Locked", true, false))


func test_kill_during_awakening_replays_without_duplicate_unlock() -> void:
	Game.progression.data.tutorial_done = true
	Game.progression.complete_level("forest_drake_1")
	Game.persist()
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await _layout()
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "awakening")
	var tx_count: int = Game.progression.data.transactions.size()
	app.relaunch()  # killed mid-reveal
	assert_eq(Game.progression.pending_awakening(), "forest_drake")
	load("res://scripts/app/main.gd").route_after_boot(Game.boot_result)
	assert_eq(Game.current_screen_name(), "awakening", "reveal replays on relaunch")
	assert_eq(Game.progression.data.transactions.size(), tx_count, "no new transactions")
	assert_eq(Game.progression.unlocked_count(), 1)


func test_language_and_settings_persist_across_relaunch() -> void:
	Game.reset_to("settings")
	await _layout()
	var lang := app.screen().find_child("LanguageOption", true, false) as OptionButton
	lang.select(2)
	lang.item_selected.emit(2)
	assert_eq(TranslationServer.get_locale(), "es")
	var slider := app.screen().find_child("Slider_music_volume", true, false) as HSlider
	slider.value = 0.0
	var toggle := app.screen().find_child("Toggle_haptics", true, false) as CheckButton
	toggle.button_pressed = false
	app.relaunch()
	assert_eq(Game.settings().language, "es")
	assert_eq(TranslationServer.get_locale(), "es")
	assert_eq(Game.settings().music_volume, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "muted bus restored")
	assert_false(Game.settings().haptics)
	assert_eq(tr("HOME_PLAY"), "Jugar")
	Game.set_setting("language", "en")


func test_back_navigation_and_overlays() -> void:
	Game.reset_to("home")
	Game.go("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_1"})
	await _layout()
	var pz: Control = app.screen()
	assert_true(Game.back())
	assert_eq(Game.current_screen_name(), "puzzle", "Back pauses first")
	assert_eq(Dialog.top(pz).name, "PauseDialog")
	# Overlay blocks the board: a tap underneath changes nothing.
	var key: String = pz.session.board.state_key()
	app.tap_arrow(pz.board, pz.level.solution[0])
	assert_eq(pz.session.board.state_key(), key, "no input through the modal")
	assert_true(Game.back())
	assert_null(Dialog.top(pz), "Back closes the overlay")
	pz.open_pause()
	assert_true(app.press("PauseLevelSelect"))
	assert_eq(Game.current_screen_name(), "level_select")
	assert_true(Game.back())
	assert_eq(Game.current_screen_name(), "home")
	assert_false(Game.back(), "nothing behind Home")


func test_app_pause_saves_in_progress_state() -> void:
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await _layout()
	var pz: Control = app.screen()
	pz.session.tap(pz.level.solution[0])  # model-only move: not yet saved
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var on_disk: Dictionary = SaveRepository.new(app.save_path).load_save().data
	assert_eq(on_disk.in_progress.removed, [pz.level.solution[0]])


func test_corrupt_save_shows_recovery_message_once() -> void:
	Game.progression.complete_level("forest_drake_1")
	Game.persist()
	Game.persist()  # second write rotates a valid backup
	var f := FileAccess.open(app.save_path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var res := app.relaunch()
	assert_true(res.recovered)
	load("res://scripts/app/main.gd").route_after_boot(res)
	assert_not_null(Dialog.top(app.screen()))
	assert_eq(Dialog.top(app.screen()).name, "SaveRestoredDialog")
	assert_true(Game.progression.is_level_completed("forest_drake_1"), "progress kept")
	assert_eq(Game.events.count("save_recovery"), 1)
	var again := app.relaunch()
	assert_false(again.recovered, "repaired file loads normally next time")


func test_twenty_transitions_do_not_leak_nodes() -> void:
	# Engine-level proxy for spec §14 (memory settles after 20 transitions).
	# Device PSS measurements are separate and need a physical phone.
	for l in ["forest_drake_1", "forest_drake_2"]:
		Game.progression.complete_level(l)
	var cycle := func():
		Game.reset_to("level_select")
		Game.go("puzzle", {"level_id": "forest_drake_1"})
		Game.go("creature_detail", {"creature_id": "forest_drake"})
		Game.go("bestiary")
	cycle.call()  # warm caches (theme, fonts, scripts)
	await wait_process_frames(4)
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 5:  # 5 cycles x 4 screens = 20 transitions
		cycle.call()
		await wait_process_frames(2)
	await wait_process_frames(4)
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_eq(nodes_after, nodes_before, "node count back to the warmed baseline")
	assert_lte(objects_after, objects_before * 1.10, "objects within 10%% (%d -> %d)" % [objects_before, objects_after])
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0, "no orphan nodes")
