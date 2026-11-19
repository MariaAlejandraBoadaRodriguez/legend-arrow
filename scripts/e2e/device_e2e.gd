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
	"awakening_replay", "settings_a", "settings_b", "replay_times", "background_resume", "rotate",
	"world_unlock", "memory_transitions"]
const ACTION_DONE := "user://e2e_action_done"

var journey := ""
var mock: MockAdProvider
var _failed := ""
var _log: Array[String] = []
var _shots := 0
var _frame_ms := {"puzzle": [], "awakening": []}  # per-frame times by screen (spec §14 budgets)


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


var _bg := {}   # background_resume: clock at pause / resume


func _notification(what: int) -> void:
	if journey != "background_resume" or Game.current_screen_name() != "puzzle":
		return
	var t: int = Game.current_screen().session.elapsed_ms()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and not _bg.has("paused"):
		_bg.paused = t
		_bg.paused_at = Time.get_ticks_msec()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and _bg.has("paused") and not _bg.has("resumed"):
		_bg.resumed = t
		_bg.resumed_at = Time.get_ticks_msec()


func _init(p_journey: String) -> void:
	journey = p_journey
	name = "DeviceE2E"


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
	for screen_name in _frame_ms:
		var stats := frame_stats(screen_name)
		if stats.n > 0:
			_log.append("frametime %s p50=%.1f ms p95=%.1f ms n=%d" % [screen_name, stats.p50, stats.p95, stats.n])
			_say("FRAMETIME %s p50=%.1f p95=%.1f n=%d" % [screen_name, stats.p50, stats.p95, stats.n])
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
	if not await solve_current("forest_drake"): return
	if not await wait_screen("level_complete"): return
	if not check(await results_settled("forest_drake"), "results show time and stars, both saved"): return
	await seconds(1.2)  # let the stars appear
	await shot("results")
	if not await tap("NextButton"): return
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
	if not await open_next_puzzle("fern_wyrmling"): return
	var pz: Control = Game.current_screen()
	for id in pz.level.solution.slice(0, 2):
		if not await tap_arrow(pz.board, id): return
	await idle(pz.board)
	var saved: Dictionary = _saved().get("in_progress", {})
	if not check(saved.get("level_id", "") == "fern_wyrmling" and saved.get("removed", []).size() == 2,
			"partial state on disk: %s" % str(saved)): return
	if not check(bool(saved.get("timer_started", false)) and int(saved.get("elapsed_ms", -1)) > 0,
			"timer running and saved: %s" % str(saved)): return
	await shot("partial_before_kill")


## 2b. Relaunch after termination restores the partial puzzle, then finish it.
func partial_b() -> void:
	if not await wait_screen("home"): return
	if not await open_next_puzzle("fern_wyrmling"): return
	var pz: Control = Game.current_screen()
	var total: int = pz.level.arrows.size()
	if not check(pz.session.board.remaining_count() == total - 2,
			"restored %d of %d" % [pz.session.board.remaining_count(), total]): return
	var saved_ms := int(_saved().in_progress.get("elapsed_ms", -1))
	if not check(saved_ms > 0 and pz.session.elapsed_ms() >= saved_ms and pz.session.elapsed_ms() < saved_ms + 5000,
			"timer restored after kill (%d ms saved, %d now)" % [saved_ms, pz.session.elapsed_ms()]): return
	await shot("partial_restored")
	for id in pz.level.solution:
		if pz.session.board.has_arrow(id) and pz.session.board.remaining_ids().has(id):
			if not await tap_arrow(pz.board, id): return
	if not await wait_screen("level_complete"): return
	if not await collect_awakening(): return


## 3. Blocked move -> undo/restart -> successful completion.
func blocked_undo() -> void:
	if not await open_next_puzzle("mossback_drake"): return
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
	if not await solve_current("mossback_drake"): return
	if not await wait_screen("level_complete"): return
	if not await tap("NextButton"): return
	if not await wait_screen("awakening"): return
	if not check(Game.progression.is_creature_unlocked("mossback_drake"), "mossback drake unlocked"): return
	if not await wait_for(func(): return Game.current_screen().get("finished") == true, 30.0, "awakening finishes"): return
	if not await tap("ContinueButton"): return
	if not await wait_screen("creature_detail"): return


## 4. Rewarded hint success, then the ad-unavailable fallback.
func hint_ad() -> void:
	if not await open_next_puzzle("thornclaw_whelp"): return
	var pz: Control = Game.current_screen()
	for i in 3:  # spend the three free hints by following them
		if not await tap("HintButton"): return
		var h: String = pz.board.hint_id()
		if not check(h != "" and pz.session.board.is_removable(h), "free hint %d points at a free arrow" % (i + 1)): return
		if not await tap_arrow(pz.board, h): return
		# The hint only clears once its arrow has left; on a zoomed board a
		# missed touch would leave it showing (and Hint does nothing while
		# a hint is shown), so make sure, retrying the tap once.
		if not await poll(func(): return not pz.session.board.has_arrow(h), 2.0):
			_say("hinted arrow %s still on the board after the tap; tapping again" % h)
			if not await tap_arrow(pz.board, h): return
			if not await wait_for(func(): return not pz.session.board.has_arrow(h), 3.0, "hinted arrow %s leaves (retry)" % h): return
		await idle(pz.board)
	if not check(pz.board.hint_id() == "", "no hint left showing (hint=%s, free=%d, ad=%d)" % [pz.board.hint_id(),
			Game.progression.free_hints_left(pz.level_id), Game.progression.ad_hints_available()]): return
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
	if not await solve_current("thornclaw_whelp"): return
	if not await wait_screen("level_complete"): return
	if not check(int(Game.current_screen().params.get("stars", 3)) <= 2, "a run with hints earns at most 2 stars"): return
	if not await collect_awakening(): return


## 5. Creature awakening -> skip/replay -> bestiary.
func awakening_replay() -> void:
	if not await reach_home(): return
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


## 6a. Change sound and reduced motion through the settings UI.
func settings_a() -> void:
	if not await reach_home(): return
	if not await tap("SettingsButton"): return
	if not await wait_screen("settings"): return
	if not check(find("LanguageOption") == null, "no language picker (English only)"): return
	var before: bool = Game.settings().reduce_motion
	if not await tap("Toggle_reduce_motion"): return
	if not check(Game.settings().reduce_motion != before, "reduce motion toggled"): return
	# Touch the far left end of the music slider: volume goes to 0 (muted).
	var slider := find("Slider_music_volume") as HSlider
	if not check(slider != null, "music slider present"): return
	await touch(to_window(slider, Vector2(2.0, slider.size.y * 0.5)))
	if not await wait_for(func(): return Game.settings().music_volume <= 0.001, 2.0, "music muted by touch"): return
	if not check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music bus muted"): return
	await shot("settings_changed")


## 6b. After a restart the preferences are still there.
func settings_b() -> void:
	if not await reach_home(): return
	if not check(Game.settings().music_volume <= 0.001, "music mute persisted"): return
	if not check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music bus muted after restart"): return
	if not check(Game.settings().reduce_motion == true, "reduce motion persisted"): return
	if not check(TranslationServer.get_locale() == "en", "UI in English"): return
	await shot("home_after_restart")


## 7. (v0.2 §9.3-3) Play a level slowly, replay it faster: best time and
## stars improve; replay slowly again: they do not drop.
func replay_times() -> void:
	if not await open_next_puzzle("dewwing_drake"): return
	var pz: Control = Game.current_screen()
	var par: int = pz.session.par_ms
	if not await solve_paced("dewwing_drake", par * 1.15 / 1000.0): return  # over par: not 3 stars
	if not await wait_screen("level_complete"): return
	var first: Dictionary = Game.current_screen().params
	if not check(int(first.stars) <= 2, "slow first run earns < 3 stars (got %d, %d ms, par %d)" % [int(first.stars), int(first.time_ms), par]): return
	var best1 := Game.progression.best_time_ms("dewwing_drake")
	if not await tap("RetryButton"): return
	if not await solve_current("dewwing_drake"): return
	if not await wait_screen("level_complete"): return
	var fast: Dictionary = Game.current_screen().params
	await seconds(1.2)
	await shot("results_new_record")
	if not check(bool(fast.new_record) and int(fast.stars) == 3, "fast replay: new record and 3 stars (%s)" % str(fast)): return
	var best2 := Game.progression.best_time_ms("dewwing_drake")
	if not check(best2 < best1 and Game.progression.best_stars("dewwing_drake") == 3, "best improved %d -> %d ms" % [best1, best2]): return
	if not await tap("RetryButton"): return
	if not await solve_paced("dewwing_drake", par * 1.15 / 1000.0): return
	if not await wait_screen("level_complete"): return
	if not check(not bool(Game.current_screen().params.new_record), "slow replay is not a record"): return
	if not check(Game.progression.best_time_ms("dewwing_drake") == best2 and Game.progression.best_stars("dewwing_drake") == 3,
			"slow replay lowers nothing"): return
	var saved: Dictionary = _saved().levels.dewwing_drake
	if not check(int(saved.best_time_ms) == best2 and int(saved.best_stars) == 3, "bests on disk"): return
	if not await collect_awakening(): return


## 8. (v0.2 §9.3-4) Mid-puzzle -> Home button -> back: the clock held while
## in the background and the board is intact. (Kill + relaunch: partial_a/b.)
func background_resume() -> void:
	if not await open_next_puzzle("barkhide_wyvern"): return
	var pz: Control = Game.current_screen()
	if not await tap_arrow(pz.board, pz.level.solution[0]): return
	await seconds(1.5)
	var key: String = pz.session.board.state_key()
	_bg = {}
	if not await host_action("home"): return     # script: HOME, wait 8 s, relaunch
	if not await wait_screen("puzzle"): return
	pz = Game.current_screen()
	# The clock is read at the app's own pause and resume notifications (the
	# CI script polls every 2 s, so the app legitimately keeps timing in the
	# foreground until HOME is actually pressed).
	if not check(_bg.has("paused") and _bg.has("resumed"), "pause and resume seen (%s)" % str(_bg)): return
	var away: int = _bg.resumed_at - _bg.paused_at
	var drift: int = _bg.resumed - _bg.paused
	if not check(away >= 5000 and drift <= 300, "timer held in background (%d ms away, clock moved %d ms)" % [away, drift]): return
	if not check(pz.session.board.state_key() == key, "board intact after resume"): return
	await shot("resumed")


## 9. (v0.2 §9.3-9) Rotate mid-puzzle: the game stays portrait, state intact.
func rotate() -> void:
	if not await open_next_puzzle("barkhide_wyvern"): return
	var pz: Control = Game.current_screen()
	var key: String = pz.session.board.state_key()
	var size_before := get_viewport().get_visible_rect().size
	if not await host_action("rotate"): return   # script: landscape for 4 s, back
	await seconds(1.0)
	var size_after := get_viewport().get_visible_rect().size
	if not check(size_after.y > size_after.x and size_after == size_before, "still portrait (%s -> %s)" % [size_before, size_after]): return
	if not check(Game.current_screen_name() == "puzzle" and Game.current_screen().session.board.state_key() == key, "state intact"): return
	if not await solve_current("barkhide_wyvern"): return
	if not await wait_screen("level_complete"): return
	if not await collect_awakening(): return


## 10. (v0.2 §9.3-2) Complete world 1 -> world 2 unlocks. Dragons 1-6 were
## played by taps in earlier journeys (1-4 on desktop); the rest except the
## last are recorded through the real progression rules (to keep the
## emulator run short) and the world's last dragon is solved by taps.
func world_unlock() -> void:
	if not await reach_home(): return
	for l in Game.campaign.levels_in_world("w01"):
		if l != "mistwood_elder" and not Game.progression.is_level_completed(l):
			Game.progression.complete_level(l)
			Game.progression.mark_awakening_seen(l)
	Game.persist()
	if not check(not Game.progression.is_world_unlocked("w02"), "world 2 locked before the last dragon"): return
	if not await open_next_puzzle("mistwood_elder"): return
	if not await solve_current("mistwood_elder"): return
	if not await wait_screen("level_complete"): return
	if not check(Game.progression.is_world_unlocked("w02"), "completing world 1 unlocks world 2"): return
	if not check(_saved().levels.has("mistwood_elder"), "on disk"): return
	if not await collect_awakening(): return
	Game.go("world_select")
	if not await wait_screen("world_select"): return
	await shot("world_select_w02_open")
	if not await tap("World_w02"): return
	if not await wait_screen("level_select"): return
	if not check(Game.current_screen().world_id == "w02", "world 2 opens"): return
	if not check(not (find("Card_heather_drake") as Button).disabled, "its first dragon is playable"): return


## 11. (v0.2 §9.5) Memory settles over 20 level-list / dragon-detail /
## bestiary transitions: each cycle opens a different dragon's full image.
## After a 3-cycle warm-up, static + texture memory stays within 10% of the
## warmed baseline and the node count does not grow.
func memory_transitions() -> void:
	if not await reach_home(): return
	var ids: Array[String] = []
	for w in Game.campaign.worlds.slice(0, 3):
		for l in Game.campaign.levels_in_world(w.id):
			if not Game.progression.is_level_completed(l):
				Game.progression.complete_level(l)
			Game.progression.mark_awakening_seen(Game.campaign.creature_of_level(l))
			ids.append(Game.campaign.creature_of_level(l))
	Game.persist()
	var base := {}
	var peak := {}
	for cycle in 23:
		var world_id: String = Game.campaign.worlds[cycle % 3].id
		Game.go("level_select", {"world_id": world_id})
		if not await wait_screen("level_select"): return
		Game.go("creature_detail", {"creature_id": ids[cycle % ids.size()]})
		if not await wait_screen("creature_detail"): return
		await seconds(0.4)
		Game.go("bestiary")
		if not await wait_screen("bestiary"): return
		await seconds(0.3)
		Game.reset_to("home")
		if not await wait_screen("home"): return
		await frames(10)
		var m := _mem()
		if cycle == 2:
			base = m
			_log.append("memory warmed: %s" % str(m))
		elif cycle > 2:
			for k in m:
				peak[k] = maxf(peak.get(k, 0.0), m[k])
	_log.append("memory peak after 20 transitions: %s" % str(peak))
	_say("MEMORY base=%s peak=%s" % [str(base), str(peak)])
	var total0: float = base.static_mb + base.texture_mb
	var total1: float = peak.static_mb + peak.texture_mb
	if not check(total1 <= total0 * 1.10, "memory within 10%% of warmed baseline (%.1f -> %.1f MB)" % [total0, total1]): return
	if not check(peak.nodes <= base.nodes * 1.10, "no node growth (%d -> %d)" % [base.nodes, peak.nodes]): return


func _mem() -> Dictionary:
	return {
		"static_mb": OS.get_static_memory_usage() / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


## Asks the CI script for a device action ("home", "rotate") and waits until
## the script reports it done (it creates ACTION_DONE inside the app's files).
func host_action(action: String) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTION_DONE))
	_say("ACTION %s" % action)
	var ok := await poll(func(): return FileAccess.file_exists(ACTION_DONE), 90.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTION_DONE))
	return check(ok, "host action %s done" % action)


## Solves the current puzzle waiting `pause_s` seconds after the first tap.
func solve_paced(level_id: String, pause_s: float) -> bool:
	if not await wait_screen("puzzle"): return false
	var pz: Control = Game.current_screen()
	if not check(pz.level_id == level_id, "puzzle %s" % level_id): return false
	var first := true
	for id in pz.level.solution:
		if pz.session.board.remaining_ids().has(id):
			if not await tap_arrow(pz.board, id): return false
			if first:
				first = false
				await seconds(pause_s)
	return check(pz.session.is_complete(), "%s solved by taps" % level_id)


# --- helpers ------------------------------------------------------------------

func _process(delta: float) -> void:
	var screen_name := Game.current_screen_name()
	if _frame_ms.has(screen_name):
		_frame_ms[screen_name].append(delta * 1000.0)


func frame_stats(screen_name: String) -> Dictionary:
	var xs: Array = _frame_ms[screen_name].duplicate()
	if xs.size() > 10:
		xs = xs.slice(5)  # drop the screen's first frames (scene build)
	xs.sort()
	if xs.is_empty():
		return {"n": 0, "p50": 0.0, "p95": 0.0}
	return {"n": xs.size(), "p50": xs[int(xs.size() * 0.5)], "p95": xs[mini(xs.size() - 1, int(xs.size() * 0.95))]}


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


## Like wait_for, but a timeout is not a failure (for retries).
func poll(cond: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if Game.current_screen() != null and cond.call():
			return true
		await get_tree().process_frame
	return false


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
	if not board.is_cell_visible(cells[cells.size() / 2]):
		board.reveal(id)  # zoomed board: bring the arrow into view first
		await frames(2)
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
## Home, as a player reaches it. On the emulator the save carries over between
## journeys, and an earlier journey may have finished a level without watching
## its awakening; the app then (correctly) replays that awakening at launch.
## Watch it out, as a player would, before going on.
func reach_home() -> bool:
	var end := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < end and Game.current_screen_name() not in ["home", "awakening"]:
		await frames(5)
	if Game.current_screen_name() == "awakening":
		_say("launch replays a pending awakening (%s)" % Game.current_screen().creature_id)
		await seconds(1.2)
		if Game.current_screen().get("finished") != true:
			if not await tap("SkipButton"): return false
		if not await wait_for(func(): return Game.current_screen().get("finished") == true, 3.0, "pending awakening finished"): return false
		if not await tap("ContinueButton"): return false
		await seconds(0.5)
		Game.reset_to("home")
	return await wait_screen("home")


func open_next_puzzle(level_id: String) -> bool:
	if not await reach_home(): return false
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


## Results -> Next -> the earned awakening -> skip -> continue. One puzzle
## awakens its dragon (v0.2), so a journey that ends on results would leave
## an awakening pending and the next launch would open it instead of Home.
func collect_awakening() -> bool:
	if not await tap("NextButton"): return false
	if not await wait_screen("awakening"): return false
	await seconds(1.2)
	if Game.current_screen().get("finished") != true:   # reduced motion may already be done
		if not await tap("SkipButton"): return false
	if not await wait_for(func(): return Game.current_screen().get("finished") == true, 3.0, "awakening finished"): return false
	if not await tap("ContinueButton"): return false
	return await wait_screen("creature_detail")


## The results screen shows this run's time and stars and they match the save.
func results_ok(level_id: String) -> bool:
	return results_problem(level_id) == ""


## Why the results screen does not (yet) show this run's time and stars, or
## does not match the save; "" when everything is right.
func results_problem(level_id: String) -> String:
	var r: Control = Game.current_screen()
	if r == null or Game.current_screen_name() != "level_complete":
		return "not on results (screen=%s)" % Game.current_screen_name()
	var t := r.find_child("TimeLabel", true, false) as Label
	var st := r.find_child("Stars", true, false) as StarRow
	if t == null or st == null:
		return "TimeLabel=%s Stars=%s" % [t, st]
	if t.text == "":
		return "empty time label"
	var rec: Dictionary = _saved().levels.get(level_id, {})
	if st.earned < 1 or int(rec.get("best_stars", 0)) < st.earned or int(rec.get("best_time_ms", -1)) < 0:
		return "stars shown %d, saved %s; %s" % [st.earned, str(rec), _save_forensics(level_id)]
	return ""


## Where the save on disk came from and what is next to it (for a mismatch
## between the screen and the file).
func _save_forensics(level_id: String) -> String:
	var path: String = Game.repository.path
	var loaded := SaveRepository.new(path).load_save()
	var files: Array[String] = []
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		for f in dir.get_files():
			if f.begins_with(path.get_file()):
				var fa := FileAccess.open(path.get_base_dir().path_join(f), FileAccess.READ)
				files.append("%s=%d" % [f, fa.get_length() if fa != null else -1])
	return "source=%s problems=%s files=%s last_persist_error=%d in_memory=%s" % [
		loaded.get("source"), str(loaded.get("problems")), ",".join(files),
		Game.last_persist_error, str(Game.progression.data.levels.get(level_id, {}))]


## Results check that allows a slow device a moment to build the screen, and
## logs exactly what was wrong if it never becomes right (same conditions).
func results_settled(level_id: String) -> bool:
	var end := Time.get_ticks_msec() + 3000
	var why := results_problem(level_id)
	while why != "" and Time.get_ticks_msec() < end:
		await get_tree().process_frame
		why = results_problem(level_id)
	if why != "":
		_log.append("results problem: " + why)
		_say("RESULTS %s" % why)
	return why == ""


func _saved() -> Dictionary:
	return SaveRepository.new(Game.repository.path).load_save().data


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shots += 1
	img.save_png(OUT_DIR.path_join("%s_%02d_%s.png" % [journey, _shots, label]))
