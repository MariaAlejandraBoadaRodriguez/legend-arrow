extends GutTest
## Rewarded-hint state machine and consent gating (spec §16-17, §19 "Ads",
## "Consent"). The mock is manual: each test fires SDK callbacks explicitly.

const S := AdService.RewardState

var mock: MockAdProvider
var prog: Progression
var ads: AdService
var now := [100.0]
var saves := [0]
var results: Array = []
var grants: Array = []
var screen_events: Array = []


func before_each() -> void:
	mock = MockAdProvider.new()
	mock.manual = true
	var c: Campaign = Campaign.from_dict({"schema_version": 1, "realms": [{"id": "r"}],
		"creatures": [{"id": "d", "realm": "r", "levels": ["d1", "d2"]}]}).campaign
	prog = Progression.new(c, SaveSchema.defaults())
	ads = AdService.new(mock, AdConfig.test_config(), prog, EventLog.new())
	ads.debug_build = true
	ads.clock = func() -> float: return now[0]
	ads.persist = func(): saves[0] += 1
	results.clear()
	grants.clear()
	screen_events.clear()
	saves[0] = 0
	ads.rewarded_result.connect(func(r): results.append(r))
	ads.hint_granted.connect(func(pid): grants.append(pid))
	ads.fullscreen_started.connect(func(): screen_events.append("start"))
	ads.fullscreen_ended.connect(func(): screen_events.append("end"))


func _consent(outcome := "not_required") -> void:
	ads.start()
	mock.consent_outcome = outcome
	mock.consent_info_updated.emit(mock.consent_info())


func _pid() -> String:
	return ads._current_pid


func test_success_path_grants_once_and_returns_to_idle() -> void:
	_consent()
	assert_eq(mock.count("initialize"), 1)
	mock.initialized.emit()  # preload starts
	assert_eq(ads.reward_state, S.LOADING)
	mock.rewarded_loaded.emit()
	assert_eq(ads.reward_state, S.READY)
	assert_eq(ads.watch_for_hint(), "started")
	assert_eq(ads.reward_state, S.SHOWING)
	var pid := _pid()
	assert_eq(mock.count("show_rewarded"), 1)
	mock.rewarded_shown.emit(pid)
	mock.rewarded_earned.emit(pid)
	assert_eq(ads.reward_state, S.REWARDED)
	mock.rewarded_closed.emit(pid)
	assert_eq(ads.reward_state, S.IDLE)
	assert_eq(prog.ad_hints_available(), 1)
	assert_eq(grants, [pid])
	assert_eq(results, ["rewarded"])
	assert_eq(saves[0], 1, "grant persisted immediately")
	assert_eq(screen_events, ["start", "end"])


func test_tap_before_load_shows_when_ready() -> void:
	_consent()
	assert_eq(ads.watch_for_hint(), "started")
	assert_eq(ads.reward_state, S.LOADING)
	mock.rewarded_loaded.emit()
	assert_eq(ads.reward_state, S.SHOWING, "shows as soon as it loads")


func test_repeat_taps_while_loading_or_showing_are_ignored() -> void:
	_consent()
	ads.watch_for_hint()
	assert_eq(ads.watch_for_hint(), "busy")
	assert_eq(ads.watch_for_hint(), "busy")
	assert_eq(mock.count("load_rewarded"), 1)
	mock.rewarded_loaded.emit()
	assert_eq(ads.watch_for_hint(), "busy")
	assert_eq(mock.count("show_rewarded"), 1)


func test_no_fill_and_offline_grant_nothing_and_keep_free_hints() -> void:
	_consent()
	prog.spend_hint("d1")
	var free_before := prog.free_hints_left("d1")
	ads.watch_for_hint()
	mock.rewarded_load_failed.emit("no_fill", "No fill")
	assert_eq(ads.reward_state, S.FAILED)
	assert_eq(results, ["no_fill"])
	now[0] += 10.0
	ads.watch_for_hint()
	mock.rewarded_load_failed.emit("network", "Offline")
	assert_eq(results, ["no_fill", "offline"])
	assert_eq(prog.ad_hints_available(), 0)
	assert_eq(prog.free_hints_left("d1"), free_before, "failure never consumes a free hint")
	assert_eq(screen_events, [], "nothing full-screen was shown")


func test_retry_is_rate_limited_without_auto_loop() -> void:
	_consent()
	ads.watch_for_hint()
	mock.rewarded_load_failed.emit("no_fill", "")
	var loads := mock.count("load_rewarded")
	assert_eq(ads.watch_for_hint(), "cooldown")
	assert_gt(ads.retry_wait(), 0.0)
	now[0] += RemoteConfig.RETRY_COOLDOWN_SECONDS - 0.1
	assert_eq(ads.watch_for_hint(), "cooldown")
	now[0] += 0.2
	assert_eq(ads.watch_for_hint(), "started")
	assert_eq(mock.count("load_rewarded"), loads + 1, "exactly one new request per allowed retry")


func test_failure_to_show_restores_and_grants_nothing() -> void:
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	mock.rewarded_show_failed.emit(_pid(), "boom")
	assert_eq(ads.reward_state, S.FAILED)
	assert_eq(results, ["failed"])
	assert_eq(prog.ad_hints_available(), 0)
	assert_eq(screen_events, ["start", "end"], "audio/fullscreen restored")


func test_early_dismiss_grants_nothing() -> void:
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	mock.rewarded_shown.emit(pid)
	mock.rewarded_closed.emit(pid)
	assert_eq(results, ["dismissed"])
	assert_eq(prog.ad_hints_available(), 0)
	assert_eq(ads.reward_state, S.IDLE)


func test_duplicate_reward_callbacks_grant_once() -> void:
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	for i in 3:
		mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	mock.rewarded_closed.emit(pid)
	mock.rewarded_earned.emit(pid)
	assert_eq(prog.ad_hints_available(), 1)
	assert_eq(grants.size(), 1)
	assert_eq(results, ["rewarded"])


func test_late_reward_after_close_grants_once() -> void:
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	mock.rewarded_closed.emit(pid)
	assert_eq(results, ["dismissed"])
	mock.rewarded_earned.emit(pid)
	assert_eq(prog.ad_hints_available(), 1, "the SDK said the reward was earned")
	mock.rewarded_earned.emit(pid)
	assert_eq(prog.ad_hints_available(), 1)
	assert_eq(ads.reward_state, S.IDLE)


func test_unknown_or_stale_callbacks_are_harmless() -> void:
	_consent()
	mock.rewarded_earned.emit("rw-forged-1")
	mock.rewarded_closed.emit("rw-forged-1")
	mock.rewarded_loaded.emit()  # nothing was loading
	mock.rewarded_load_failed.emit("no_fill", "")
	assert_eq(prog.ad_hints_available(), 0)
	assert_eq(ads.reward_state, S.IDLE)
	assert_eq(results, [])


func test_receipt_survives_restart_so_redelivery_cannot_regrant() -> void:
	# Activity recreation / process restart re-delivering an old callback.
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	var restored := Progression.new(prog.campaign, JSON.parse_string(JSON.stringify(prog.data)))
	var mock2 := MockAdProvider.new()
	mock2.manual = true
	var ads2 := AdService.new(mock2, AdConfig.test_config(), restored, EventLog.new())
	ads2.debug_build = true
	mock2.rewarded_earned.emit(pid)
	assert_eq(int(restored.ad_hints_available()), 1, "no second grant after restart")
	assert_false(restored.grant_ad_hint(pid), "receipt persisted")


func test_navigation_away_keeps_entitlement() -> void:
	_consent()
	var listener := Node.new()  # stands in for a puzzle screen
	add_child(listener)
	var seen := [0]
	ads.hint_granted.connect(func(_p): seen[0] += 1)
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	listener.queue_free()  # player left the puzzle mid-ad
	await wait_process_frames(1)
	mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	assert_eq(prog.ad_hints_available(), 1, "entitlement kept for the next board")
	assert_eq(prog.spend_hint("d1"), "free", "free hints are spent first")


func test_consent_refused_blocks_ads_but_not_the_game() -> void:
	_consent("required_refused")
	assert_false(ads.rewarded_available())
	assert_eq(ads.watch_for_hint(), "unavailable")
	assert_eq(mock.count("initialize"), 0)
	assert_eq(mock.count("load_rewarded"), 0)
	assert_eq(prog.spend_hint("d1"), "free", "free hints still work")


func test_consent_error_or_offline_blocks_ads() -> void:
	ads.start()
	mock.consent_error.emit("offline")
	assert_eq(ads.consent.state, ConsentService.State.ERROR)
	assert_false(ads.rewarded_available())
	assert_eq(mock.count("initialize"), 0)


func test_no_duplicate_consent_requests_or_initialization() -> void:
	ads.start()
	ads.start()
	ads.consent.request_update()
	assert_eq(mock.count("request_consent_update"), 1, "one request while in flight")
	mock.consent_info_updated.emit(mock.consent_info())
	mock.consent_info_updated.emit(mock.consent_info())
	ads.consent.request_update()
	assert_eq(mock.count("request_consent_update"), 1, "none after an answer")
	assert_eq(mock.count("initialize"), 1, "SDK initialized once")


func test_privacy_options_entry() -> void:
	_consent("obtained")
	assert_true(ads.consent.privacy_options_required)
	assert_true(ads.consent.show_privacy_options())
	assert_eq(mock.count("show_privacy_options"), 1)
	var other := AdService.new(MockAdProvider.new(), AdConfig.test_config(), prog, null)
	assert_false(other.consent.show_privacy_options(), "not required -> app's own page")


func test_unknown_audience_is_restricted() -> void:
	ads.start()
	var cfg: Dictionary = mock.config
	assert_eq(cfg.audience, "unknown")
	assert_true(cfg.child_directed)
	assert_true(cfg.under_age_of_consent)
	assert_eq(cfg.max_ad_content_rating, "G")
	assert_true(cfg.test, "debug/CI use test IDs")
	assert_eq(cfg.rewarded_unit, AdConfig.TEST_REWARDED_ID)


func test_unavailable_provider_never_rewards() -> void:
	var none := AdService.new(AdProvider.new(), AdConfig.test_config(), prog, null)
	none.debug_build = true
	none.start()
	assert_false(none.rewarded_available())
	assert_eq(none.watch_for_hint(), "unavailable")
	assert_eq(prog.ad_hints_available(), 0)


func test_release_build_rejects_test_ids() -> void:
	ads.debug_build = false
	assert_false(ads.config_usable(), "test config in a release build")
	ads.start()
	assert_eq(mock.calls.size(), 0, "no SDK call at all")
	assert_eq(ads.watch_for_hint(), "unavailable")


func test_release_config_validation() -> void:
	var good := AdConfig.from_dict({"app_id": "ca-app-pub-1111111111111111~2222222222",
		"rewarded_unit": "ca-app-pub-1111111111111111/3333333333",
		"interstitial_unit": "ca-app-pub-1111111111111111/4444444444",
		"audience": "unknown", "consent_configured": true})
	assert_eq(good.release_errors(), [] as Array[String])
	var test_ids := AdConfig.from_dict({"app_id": AdConfig.TEST_APP_ID, "rewarded_unit": AdConfig.TEST_REWARDED_ID,
		"interstitial_unit": AdConfig.TEST_INTERSTITIAL_ID, "consent_configured": true})
	assert_string_contains(" | ".join(test_ids.release_errors()), "test ID")
	var missing := AdConfig.from_dict({})
	var joined := " | ".join(missing.release_errors())
	assert_string_contains(joined, "app_id is missing")
	assert_string_contains(joined, "consent (UMP) message is not configured")
	var bad_aud := AdConfig.from_dict({"app_id": "ca-app-pub-1~2", "rewarded_unit": "ca-app-pub-1/3",
		"interstitial_unit": "ca-app-pub-1/4", "audience": "teens", "consent_configured": true})
	assert_string_contains(" | ".join(bad_aud.release_errors()), "audience")
	assert_true(AdConfig.load_for_build(true).is_test, "debug builds always use test IDs")


func test_events_are_logged_without_identifiers() -> void:
	var ev := EventLog.new()
	ads.events = ev
	_consent()
	ads.watch_for_hint()
	mock.rewarded_loaded.emit()
	var pid := _pid()
	mock.rewarded_earned.emit(pid)
	mock.rewarded_closed.emit(pid)
	assert_eq(ev.count("ad_result"), 1)
	assert_false(JSON.stringify(ev.events).contains(pid), "presentation ids not logged")


func test_mock_auto_mode_runs_full_flow() -> void:
	mock.manual = false
	mock.consent_outcome = "not_required"
	ads.start()
	await wait_process_frames(3)
	assert_true(ads.rewarded_available())
	await wait_until(func(): return ads.reward_state == S.READY, 1.0)
	assert_eq(ads.watch_for_hint(), "started")
	await wait_until(func(): return ads.reward_state == S.IDLE, 1.0)
	assert_eq(prog.ad_hints_available(), 1)
	mock.show_outcome = "earn_twice"
	ads.watch_for_hint()
	await wait_until(func(): return results.size() == 2, 1.0)
	assert_eq(prog.ad_hints_available(), 2, "earn_twice still grants once")
