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
	assert_eq(app.screen().level_id, "forest_drake")
	await _layout()
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "level_complete", "results after every puzzle")
	assert_true(Game.progression.is_creature_unlocked("forest_drake"), "one puzzle awakens its dragon")
	var res: Control = app.screen()
	assert_eq((res.find_child("RecordLabel", true, false) as Label).text, tr("FIRST_CLEAR"))
	assert_between((res.find_child("Stars", true, false) as StarRow).earned, 1, 3)
	assert_eq((res.find_child("TimeLabel", true, false) as Label).text, SpeedTimer.format_ms(int(res.params.time_ms)))
	assert_eq(Game.progression.best_time_ms("forest_drake"), int(res.params.time_ms), "time saved")
	assert_true(app.press("NextButton"), "Next opens the earned awakening")
	assert_eq(Game.current_screen_name(), "awakening")
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
	Game.go("puzzle", {"level_id": "forest_drake"})
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
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	assert_eq(app.screen().session.board.state_key(), expected_key, "board restored exactly")
	assert_eq(app.screen().session.history, [first, second] as Array[String], "undo history restored")


func test_journey_blocked_then_undo_restart_then_complete() -> void:
	Game.progression.data.tutorial_done = true
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake"})
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
	assert_true(Game.progression.is_level_completed("forest_drake"))


func test_hints_spend_free_then_show_sheet() -> void:
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	var pz: Control = app.screen()
	assert_eq(app.button("HintButton").text, tr("HINT_FREE") % 3)
	app.press("HintButton")
	var hinted: String = pz.board.hint_id()
	assert_ne(hinted, "")
	assert_true(pz.session.board.is_removable(hinted), "hint is a removable arrow")
	app.press("HintButton")
	assert_eq(Game.progression.free_hints_left("forest_drake"), 2, "re-pressing while shown costs nothing")
	for i in 2:
		app.tap_arrow(pz.board, pz.board.hint_id())
		await app.board_idle(pz.board)
		app.press("HintButton")
	assert_eq(Game.progression.free_hints_left("forest_drake"), 0)
	app.tap_arrow(pz.board, pz.board.hint_id())
	await app.board_idle(pz.board)
	app.press("HintButton")
	assert_not_null(Dialog.top(pz), "out of free hints: sheet explains")
	assert_eq(Dialog.top(pz).name, "HintSheet")
	assert_true(app.press("KeepPlaying"))
	assert_null(Dialog.top(pz))


func test_awakening_skip_replay_and_bestiary() -> void:
	Game.set_setting("reduce_motion", false)
	Game.progression.complete_level("forest_drake")
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


func test_screens_fit_phone_width_with_full_collection() -> void:
	# 720 is the narrowest logical width (portrait phones, stretch "expand").
	# A full bestiary once needed 782 px for its 12 progress bars.
	for level_id in Game.campaign.level_ids():
		Game.progression.complete_level(level_id)
	Game.progression.data.tutorial_done = true
	var screens := [["home", {}], ["level_select", {}], ["bestiary", {}], ["settings", {}],
		["creature_detail", {"creature_id": "forest_drake"}], ["puzzle", {"level_id": "ancient_dragon"}],
		["tutorial", {}], ["world_select", {}], ["level_select", {"world_id": "w10"}], ["level_complete",
		{"level_id": "ancient_dragon", "stars": 3, "time_ms": 3_599_000, "par_ms": 99_000, "new_record": true}]]
	for entry in screens:
		Game.reset_to(entry[0], entry[1])
		await _layout()
		var pad: Control = app.screen().get_child(0)
		var need := pad.get_combined_minimum_size().x
		assert_lte(need, 720.0, "%s needs %d px of width" % [entry[0], need])


func test_kill_during_awakening_replays_without_duplicate_unlock() -> void:
	Game.progression.data.tutorial_done = true
	Game.persist()
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_true(app.press("NextButton"))
	assert_eq(Game.current_screen_name(), "awakening")
	var tx_count: int = Game.progression.data.transactions.size()
	app.relaunch()  # killed mid-reveal
	assert_eq(Game.progression.pending_awakening(), "forest_drake")
	load("res://scripts/app/main.gd").route_after_boot(Game.boot_result)
	assert_eq(Game.current_screen_name(), "awakening", "reveal replays on relaunch")
	assert_eq(Game.progression.data.transactions.size(), tx_count, "no new transactions")
	assert_eq(Game.progression.unlocked_count(), 1)


func test_settings_persist_across_relaunch_and_ui_stays_english() -> void:
	Game.reset_to("settings")
	await _layout()
	assert_null(app.screen().find_child("LanguageOption", true, false), "no language picker")
	assert_eq(TranslationServer.get_locale(), "en")
	var slider := app.screen().find_child("Slider_music_volume", true, false) as HSlider
	slider.value = 0.0
	var toggle := app.screen().find_child("Toggle_haptics", true, false) as CheckButton
	toggle.button_pressed = false
	app.relaunch()
	assert_false(Game.settings().has("language"), "no language setting is saved")
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(Game.settings().music_volume, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "muted bus restored")
	assert_false(Game.settings().haptics)
	assert_eq(tr("HOME_PLAY"), "Play")


func test_device_language_never_changes_the_ui() -> void:
	TranslationServer.set_locale("es")
	Game.apply_settings()
	assert_eq(TranslationServer.get_locale(), "en", "locale forced back to English")
	assert_eq(tr("HOME_PLAY"), "Play")
	assert_false(TranslationServer.get_loaded_locales().has("es"), "no Spanish translation loaded")


func test_back_navigation_and_overlays() -> void:
	Game.reset_to("home")
	Game.go("level_select")
	Game.go("puzzle", {"level_id": "forest_drake"})
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
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	var pz: Control = app.screen()
	pz.session.tap(pz.level.solution[0])  # model-only move: not yet saved
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var on_disk: Dictionary = SaveRepository.new(app.save_path).load_save().data
	assert_eq(on_disk.in_progress.removed, [pz.level.solution[0]])


func test_corrupt_save_shows_recovery_message_once() -> void:
	Game.progression.complete_level("forest_drake")
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
	assert_true(Game.progression.is_level_completed("forest_drake"), "progress kept")
	assert_eq(Game.events.count("save_recovery"), 1)
	# The awakening earned before the crash follows the message.
	assert_eq(Game.progression.pending_awakening(), "forest_drake")
	assert_true(app.press("RestoredContinue"))
	assert_eq(Game.current_screen_name(), "awakening")
	var again := app.relaunch()
	assert_false(again.recovered, "repaired file loads normally next time")


func test_twenty_transitions_do_not_leak_nodes() -> void:
	# Engine-level proxy for spec §14 (memory settles after 20 transitions).
	# Device PSS measurements are separate and need a physical phone.
	Game.progression.complete_level("forest_drake")
	var cycle := func():
		Game.reset_to("level_select")
		Game.go("puzzle", {"level_id": "forest_drake"})
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


# --- v0.2 timer, stars, results ------------------------------------------

## Opens a puzzle with frame-driven ticking switched off, so the test feeds
## exact time through the screen's own _process().
func _open_timed(level_id: String) -> Control:
	Game.progression.data.tutorial_done = true
	Game.reset_to("level_select")
	var pz: Control = Game.go("puzzle", {"level_id": level_id})
	pz.set_process(false)
	await _layout()
	return pz


func _tick(pz: Control, ms: float) -> void:
	var left := ms
	while left > 0.0:
		var step := minf(left, 200.0)
		pz._process(step / 1000.0)
		left -= step


func _first_tap(pz: Control) -> void:
	app.tap_arrow(pz.board, pz.level.solution[0])
	await app.board_idle(pz.board)


func test_timer_waits_for_the_first_tap_and_shows_discreetly() -> void:
	var pz := await _open_timed("forest_drake")
	_tick(pz, 3000)
	assert_eq(pz.session.elapsed_ms(), 0, "no clock before the first tap")
	assert_eq((pz.find_child("TimerLabel", true, false) as Label).text, "0:00")
	await _first_tap(pz)
	_tick(pz, 2400)
	assert_eq(pz.session.elapsed_ms(), 2400)
	assert_eq((pz.find_child("TimerLabel", true, false) as Label).text, "0:02")


func test_timer_pauses_for_pause_menu_overlays_background_and_ads() -> void:
	var pz := await _open_timed("forest_drake")
	await _first_tap(pz)
	_tick(pz, 1000)
	var d: Dialog = pz.open_pause()
	_tick(pz, 5000)
	assert_eq(pz.session.elapsed_ms(), 1000, "pause menu")
	d.close()
	await _layout()
	_tick(pz, 1000)
	assert_eq(pz.session.elapsed_ms(), 2000)
	pz.open_hint_sheet()
	_tick(pz, 5000)
	assert_eq(pz.session.elapsed_ms(), 2000, "hint / ad sheet overlay")
	Dialog.top(pz).close()
	await _layout()
	Game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_tick(pz, 5000)
	assert_eq(pz.session.elapsed_ms(), 2000, "background")
	assert_eq(int(SaveRepository.new(app.save_path).load_save().data.in_progress.elapsed_ms), 2000,
		"time saved when the app goes to the background")
	Game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_tick(pz, 1000)
	assert_eq(pz.session.elapsed_ms(), 3000, "resumes after background")
	Game._on_ad_fullscreen_started()
	_tick(pz, 5000)
	assert_eq(pz.session.elapsed_ms(), 3000, "full-screen ad")
	Game._on_ad_fullscreen_ended()
	_tick(pz, 1000)
	assert_eq(pz.session.elapsed_ms(), 4000)


func test_timer_survives_kill_and_relaunch() -> void:
	var pz := await _open_timed("forest_drake")
	await _first_tap(pz)
	_tick(pz, 7000)
	app.tap_arrow(pz.board, pz.level.solution[1])  # a move saves time + board
	await app.board_idle(pz.board)
	var saved_ms: int = pz.session.elapsed_ms()
	app.relaunch()
	Game.reset_to("level_select")
	var again: Control = Game.go("puzzle", {"level_id": "forest_drake"})
	again.set_process(false)  # before its first frame, so only the test feeds time
	await _layout()
	assert_eq(again.session.history.size(), 2)
	assert_eq(again.session.elapsed_ms(), saved_ms, "time restored exactly")
	_tick(again, 1000)
	assert_eq(again.session.elapsed_ms(), saved_ms + 1000, "and keeps counting")


func _solve_timed(pz: Control, ms_per_arrow: float) -> void:
	var pid := pz.get_instance_id()
	for id in pz.level.solution:
		await app.board_idle(pz.board)
		app.tap_arrow(pz.board, id)
		if not pz.session.is_complete():
			_tick(pz, ms_per_arrow)
	await app.screen_changed_from(pid)


func test_results_and_replays_only_improve_bests() -> void:
	var pz := await _open_timed("forest_drake")
	var par: int = pz.session.par_ms
	await _solve_timed(pz, float(par) / pz.level.solution.size() * 1.5)  # ~1.5x par: 2 stars
	assert_eq(Game.current_screen_name(), "level_complete")
	var r: Control = app.screen()
	assert_eq(int(r.params.stars), 2)
	assert_eq((r.find_child("Stars", true, false) as StarRow).earned, 2)
	var slow_ms := Game.progression.best_time_ms("forest_drake")
	assert_gt(slow_ms, par)
	# Faster replay from the results screen: 3 stars, new record.
	assert_true(app.press("RetryButton"))
	await _layout()
	pz = app.screen()
	pz.set_process(false)
	await _solve_timed(pz, 200.0)
	r = app.screen()
	assert_eq(int(r.params.stars), 3)
	assert_true(r.params.new_record)
	assert_eq((r.find_child("RecordLabel", true, false) as Label).text, tr("NEW_RECORD"))
	var fast_ms := Game.progression.best_time_ms("forest_drake")
	assert_lt(fast_ms, slow_ms)
	assert_eq(Game.progression.best_stars("forest_drake"), 3)
	# Slower replay with a hint: nothing drops.
	assert_true(app.press("RetryButton"))
	await _layout()
	pz = app.screen()
	pz.set_process(false)
	pz._on_hint()
	await _solve_timed(pz, float(par))
	r = app.screen()
	assert_eq(int(r.params.stars), 1)
	assert_false(r.params.new_record)
	assert_eq(Game.progression.best_time_ms("forest_drake"), fast_ms, "best time kept")
	assert_eq(Game.progression.best_stars("forest_drake"), 3, "best stars kept")
	var on_disk: Dictionary = SaveRepository.new(app.save_path).load_save().data
	assert_eq(int(on_disk.levels.forest_drake.best_time_ms), fast_ms)
	assert_eq(int(on_disk.levels.forest_drake.best_stars), 3)
	assert_eq(Game.events.count("creature_unlock"), 1, "the first clear awakens the dragon; replays never unlock again")
	# Level select shows them.
	Game.reset_to("level_select", {"world_id": "w01"})
	await _layout()
	var line := app.screen().find_child("Best_forest_drake", true, false)
	assert_not_null(line)
	assert_eq((line.find_child("Stars", true, false) as StarRow).earned, 3)
	assert_eq((line.find_child("BestTime", true, false) as Label).text, SpeedTimer.format_ms(fast_ms))
	assert_eq((app.screen().find_child("TotalStars", true, false) as Label).text, tr("TOTAL_STARS") % [3, 3 * Game.campaign.level_ids().size()])


func test_results_stars_reveal_one_by_one_or_fade_with_reduced_motion() -> void:
	for rm in [true, false]:
		Game.set_setting("reduce_motion", rm)
		Game.reset_to("level_complete", {"level_id": "forest_drake", "stars": 3, "time_ms": 1000, "par_ms": 9000})
		await _layout()
		var st: StarRow = app.screen().find_child("Stars", true, false)
		assert_false(st.revealed, "starts hidden")
		await wait_until(func(): return st.revealed, 3.0)
		assert_true(st.revealed, "reveal finishes (reduce_motion=%s)" % rm)


# --- v0.2 §4 / §9.5: photoreal art memory -----------------------------------

func test_detail_releases_its_full_image_and_grid_uses_thumbnails() -> void:
	Game.progression.complete_level("forest_drake")
	Game.reset_to("bestiary")
	await _layout()
	var tile := app.button("Tile_forest_drake")
	var thumb := tile.find_child("Thumb", true, false) as TextureRect
	assert_string_contains(thumb.texture.resource_path, "/thumbs/", "grid shows the still thumbnail")
	assert_true(app.press("Tile_forest_drake"))
	await _layout()
	var rig = app.screen().stage.rig
	assert_true(rig is PhotoRig, "detail shows the photoreal art")
	var full: Texture2D = rig._sprite.texture
	assert_string_contains(full.resource_path, "/art/")
	var ref: WeakRef = weakref(full)
	full = null
	rig = null
	Game.back()   # leave the detail screen
	await wait_process_frames(4)
	assert_null(ref.get_ref(), "the full image is released after leaving the detail screen")


# --- 0.2.1 save hardening and the "Storage full" message (D-52) -------------

func _banner() -> Control:
	return app.host.find_child("StorageBanner", true, false) as Control


func _set_free_space(bytes: int) -> void:
	Game.storage.space_left = func() -> int: return bytes
	Game.storage.check_space()


func _report_save_errors() -> int:
	var reported := 0
	for e in get_errors():
		if not e.handled and "save failed" in e.to_s():
			e.handled = true
			reported += 1
	return reported


## The results screen shows the in-memory run; if the save write fails at
## that moment the save must catch up (retry now, then in the background)
## and never fall behind what was shown.
func test_completion_saved_even_if_the_first_write_fails() -> void:
	Game.progression.data.tutorial_done = true
	Game.persist()
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	Game.repository.simulate_bad_tmp = "truncate"   # every write fails for now
	await app.solve_current_puzzle()
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_true(Game.save_pending, "failure is known, progress kept in memory")
	assert_ne(Game.last_persist_error, OK)
	var on_disk: Dictionary = Game.repository.peek().data
	assert_false(on_disk.levels.has("forest_drake"), "disk still has the previous save")
	assert_true(on_disk.tutorial_done, "and that previous save is intact")
	assert_false(_banner().visible, "an I/O failure with free space is not 'storage full'")
	Game.repository.simulate_bad_tmp = ""             # the condition clears
	await wait_seconds(Game.SAVE_RETRY_S + 0.5)
	assert_false(Game.save_pending, "background retry landed")
	var rec: Dictionary = Game.repository.peek().data.levels.get("forest_drake", {})
	var shown: Dictionary = app.screen().params
	assert_eq(int(rec.get("best_stars", 0)), int(shown.stars), "saved stars = shown stars")
	assert_eq(int(rec.get("best_time_ms", -1)), int(shown.time_ms), "saved time = shown time")
	assert_gt(_report_save_errors(), 0, "save failures are reported")


func test_storage_full_message_shows_hides_during_awakening_and_clears_on_recovery() -> void:
	Game.progression.data.tutorial_done = true
	Game.persist()
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	assert_false(_banner().visible)
	# The disk fills up: writes really fail and almost no space is left.
	_set_free_space(0)
	Game.repository.simulate_bad_tmp = "truncate"
	await app.solve_current_puzzle()
	await wait_process_frames(2)
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_true(Game.save_pending)
	assert_true(Game.storage.save_failed)
	assert_true(_banner().visible, "storage full: the message is on screen")
	var msg := _banner().find_child("StorageMessage", true, false) as Label
	assert_eq(tr(msg.text), "Storage full. Free up some space to save your progress.")
	assert_eq(_banner().mouse_filter, Control.MOUSE_FILTER_IGNORE, "never blocks input")
	assert_eq(msg.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	# Play goes on: Next still works with the message up.
	assert_true(app.press("NextButton"))
	await wait_process_frames(2)
	assert_eq(Game.current_screen_name(), "awakening")
	assert_false(_banner().visible, "never over the awakening")
	await wait_seconds(1.1)   # Skip is offered after 1 s
	Game.current_screen().skip()
	for i in 300:
		if Game.current_screen().get("finished") == true:
			break
		assert_false(_banner().visible, "never over the awakening")
		await wait_process_frames(1)
	assert_true(Game.current_screen().get("finished"), "awakening finished")
	assert_false(_banner().visible, "not even on the finished awakening")
	assert_true(app.press("ContinueButton"))
	await wait_process_frames(2)
	assert_true(_banner().visible, "back after the awakening while the problem lasts")
	# The player frees space; the background retry lands and the message goes.
	Game.repository.simulate_bad_tmp = ""
	_set_free_space(2000 * 1024 * 1024)
	await wait_seconds(Game.SAVE_RETRY_S + 0.5)
	await wait_process_frames(2)
	assert_false(Game.save_pending, "saved")
	assert_false(_banner().visible, "gone on its own once a save succeeds")
	assert_true(Game.repository.peek().data.levels.has("forest_drake"), "progress on disk")
	assert_gt(_report_save_errors(), 0)


func test_low_storage_warning_at_launch_does_not_block_play() -> void:
	Game.progression.data.tutorial_done = true
	Game.persist()
	app.relaunch()
	_set_free_space(StorageStatus.LOW_SPACE_BYTES / 2)
	Game.reset_to("home")
	await _layout()
	assert_true(_banner().visible, "warned before progress is at risk")
	assert_false(Game.save_pending, "saves still work")
	assert_true(app.press("PlayButton"), "play is not blocked")
	await _layout()
	assert_eq(Game.current_screen_name(), "level_select")
	_set_free_space(2000 * 1024 * 1024)
	await wait_process_frames(2)
	assert_false(_banner().visible, "space freed: warning gone")


func test_no_storage_message_with_normal_storage() -> void:
	_set_free_space(2000 * 1024 * 1024)
	Game.progression.data.tutorial_done = true
	Game.persist()
	Game.go("puzzle", {"level_id": "forest_drake"})
	await _layout()
	await app.solve_current_puzzle()
	await wait_process_frames(2)
	assert_eq(Game.current_screen_name(), "level_complete")
	assert_false(Game.save_pending)
	assert_false(_banner().visible)
	assert_false(Game.storage.visible)
