extends GutTest
## Rewarded-hint journeys through the real puzzle screen with a manual mock
## SDK (brief §4 E2E #4, in-engine). Android-instrumented versions: M5.

var app: AppDriver
var mock: MockAdProvider


func before_each() -> void:
	app = AppDriver.new(self, "ads")
	app.start()
	Game.set_setting("reduce_motion", true)
	mock = MockAdProvider.new()
	mock.manual = true
	Game.set_ad_provider(mock)
	await wait_process_frames(1)


func after_each() -> void:
	app.stop()
	await wait_process_frames(3)


func _consent(outcome := "not_required") -> void:
	mock.consent_outcome = outcome
	mock.consent_info_updated.emit(mock.consent_info())


## Opens forest_drake_2 with all free hints already used.
func _puzzle_without_free_hints() -> Control:
	for i in 3:
		Game.progression.spend_hint("forest_drake_2")
	Game.reset_to("level_select")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await wait_process_frames(3)
	return app.screen()


func _dialog(pz: Control) -> String:
	var d := Dialog.top(pz)
	return "" if d == null else String(d.name)


func test_rewarded_hint_success_journey() -> void:
	_consent()
	mock.initialized.emit()
	mock.rewarded_load_failed.emit("no_fill", "")  # preload missed; no sheet shown for it
	var pz: Control = await _puzzle_without_free_hints()
	assert_eq(_dialog(pz), "", "a failed silent preload shows nothing")
	Game.ads._last_failure_at = -INF  # skip the retry cooldown left by the preload
	assert_true(app.press("HintButton"))
	assert_eq(_dialog(pz), "HintSheet")
	assert_true(app.press("WatchAdButton"))
	assert_eq(_dialog(pz), "AdLoading", "loading state while the ad loads")
	assert_eq(Game.ads.watch_for_hint(), "busy", "a repeat request while loading is ignored")
	assert_eq(mock.count("load_rewarded"), 2, "preload + this request; the repeat added none")
	mock.rewarded_loaded.emit()
	var pid: String = Game.ads._current_pid
	assert_ne(pid, "")
	assert_true(AudioServer.is_bus_mute(0), "game audio paused under the ad")
	mock.rewarded_shown.emit(pid)
	mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	assert_false(AudioServer.is_bus_mute(0), "audio restored")
	assert_eq(_dialog(pz), "", "sheets closed")
	assert_ne(pz.board.hint_id(), "", "earned hint is shown on the board")
	assert_true(pz.session.board.is_removable(pz.board.hint_id()))
	assert_eq(Game.progression.ad_hints_available(), 0, "entitlement spent on this board")
	assert_true(Game.progression.data.ad_receipts.has(pid), "receipt saved")
	var on_disk: Dictionary = SaveRepository.new(app.save_path).load_save().data
	assert_true(on_disk.ad_receipts.has(pid), "receipt persisted to disk")


func test_ad_unavailable_fallback_keeps_playing() -> void:
	_consent()
	var pz: Control = await _puzzle_without_free_hints()
	app.press("HintButton")
	app.press("WatchAdButton")
	mock.rewarded_load_failed.emit("network", "Offline")
	assert_eq(_dialog(pz), "NoAdSheet", "No ad available. You can keep playing.")
	var retry := Dialog.top(pz).find_child("TryAgain", true, false) as Button
	assert_true(retry.disabled, "retry is rate limited")
	assert_eq(mock.count("load_rewarded"), 1, "no automatic retry")
	assert_true(app.press("ReturnToPuzzle"))
	assert_eq(_dialog(pz), "")
	var before: int = pz.session.board.remaining_count()
	app.tap_arrow(pz.board, pz.level.solution[0])
	assert_eq(pz.session.board.remaining_count(), before - 1, "game continues normally")
	assert_eq(Game.progression.ad_hints_available(), 0)


func test_retry_becomes_available_after_cooldown() -> void:
	_consent()
	var pz: Control = await _puzzle_without_free_hints()
	app.press("HintButton")
	app.press("WatchAdButton")
	mock.rewarded_load_failed.emit("no_fill", "")
	await wait_seconds(RemoteConfig.RETRY_COOLDOWN_SECONDS + 0.2)
	var retry := Dialog.top(pz).find_child("TryAgain", true, false) as Button
	assert_false(retry.disabled)
	assert_true(app.press("TryAgain"))
	assert_eq(mock.count("load_rewarded"), 2)


func test_dismissed_ad_grants_nothing() -> void:
	_consent()
	var pz: Control = await _puzzle_without_free_hints()
	app.press("HintButton")
	app.press("WatchAdButton")
	mock.rewarded_loaded.emit()
	var pid: String = Game.ads._current_pid
	mock.rewarded_closed.emit(pid)
	assert_eq(pz.board.hint_id(), "")
	assert_eq(Game.progression.ad_hints_available(), 0)
	assert_false(AudioServer.is_bus_mute(0))


func test_consent_refused_hides_ad_option() -> void:
	_consent("required_refused")
	var pz: Control = await _puzzle_without_free_hints()
	app.press("HintButton")
	assert_eq(_dialog(pz), "HintSheet")
	assert_null(Dialog.top(pz).find_child("WatchAdButton", true, false), "no ad offered")
	assert_true(app.press("KeepPlaying"))
	assert_eq(mock.count("load_rewarded"), 0)


func test_reward_after_leaving_puzzle_is_kept_for_next_board() -> void:
	_consent()
	var pz: Control = await _puzzle_without_free_hints()
	app.press("HintButton")
	app.press("WatchAdButton")
	mock.rewarded_loaded.emit()
	var pid: String = Game.ads._current_pid
	Game.leave()  # player navigates away while the ad is up
	await wait_process_frames(2)
	mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	assert_eq(Game.progression.ad_hints_available(), 1, "entitlement retained")
	Game.go("puzzle", {"level_id": "forest_drake_2"})
	await wait_process_frames(3)
	app.press("HintButton")
	assert_ne(app.screen().board.hint_id(), "", "used on the next valid board")
	assert_eq(Game.progression.ad_hints_available(), 0)


func test_privacy_options_open_consent_form_when_required() -> void:
	_consent("obtained")
	Game.reset_to("settings")
	await wait_process_frames(2)
	assert_true(app.press("PrivacyOptions"))
	assert_eq(mock.count("show_privacy_options"), 1)
	assert_eq(Game.current_screen_name(), "settings", "SDK form, not our page")
	var other := MockAdProvider.new()
	other.manual = true
	Game.set_ad_provider(other)
	other.consent_info_updated.emit(other.consent_info())  # not required
	Game.reset_to("settings")
	await wait_process_frames(2)
	app.press("PrivacyOptions")
	assert_eq(Game.current_screen_name(), "privacy")
