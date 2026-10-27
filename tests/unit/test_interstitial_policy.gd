extends GutTest
## Interstitial pacing boundaries and remote-config clamping (spec §16-17).

const BETWEEN := InterstitialPolicy.CONTEXT_BETWEEN_LEVELS


func _adult() -> InterstitialPolicy:
	return InterstitialPolicy.new(RemoteConfig.new(), false)


func _complete(p: InterstitialPolicy, n: int, tutorial := false) -> void:
	for i in n:
		p.on_level_completed(tutorial)


func test_never_for_child_or_unknown_audience() -> void:
	var p := InterstitialPolicy.new(RemoteConfig.new(), true)
	_complete(p, 50)
	assert_eq(p.blocked_reason(10000.0, BETWEEN), "restricted_audience")


func test_level_cap_boundary() -> void:
	var p := _adult()
	_complete(p, 4)
	assert_eq(p.blocked_reason(1000.0, BETWEEN), "level_cap", "4 levels is not enough")
	_complete(p, 1)
	assert_true(p.allowed(1000.0, BETWEEN), "5 completed levels")


func test_tutorial_levels_do_not_count() -> void:
	var p := _adult()
	_complete(p, 10, true)
	assert_eq(p.blocked_reason(1000.0, BETWEEN), "level_cap")


func test_first_launch_is_covered_by_level_cap() -> void:
	var p := _adult()
	assert_false(p.allowed(1e9, BETWEEN), "fresh install never qualifies")


func test_cooldown_boundary_after_any_fullscreen_ad() -> void:
	var p := _adult()
	_complete(p, 5)
	p.on_fullscreen_ad_shown(1000.0, false)  # a rewarded ad
	assert_eq(p.blocked_reason(1179.9, BETWEEN), "cooldown", "not right after a rewarded ad")
	assert_true(p.allowed(1180.0, BETWEEN), "180 s later")


func test_showing_resets_level_counter() -> void:
	var p := _adult()
	_complete(p, 5)
	p.on_fullscreen_ad_shown(0.0, true)
	_complete(p, 4)
	assert_eq(p.blocked_reason(10000.0, BETWEEN), "level_cap")


func test_only_between_levels() -> void:
	var p := _adult()
	_complete(p, 9)
	for ctx in ["first_launch", "tutorial", "failure", "back", "resume", "awakening"]:
		assert_eq(p.blocked_reason(10000.0, ctx), "context", ctx)


func test_remote_config_can_only_reduce_pressure() -> void:
	var rc := RemoteConfig.new()
	rc.apply({"min_levels_between_interstitials": 1, "min_seconds_between_fullscreen": 10,
		"rewarded_enabled": true, "interstitials_enabled": true, "run_code": "x"})
	assert_eq(rc.min_levels_between_interstitials, 5, "cannot go below hard minimum")
	assert_eq(rc.min_seconds_between_fullscreen, 180)
	assert_true(rc.rewarded_enabled)
	rc.apply({"min_levels_between_interstitials": 8, "min_seconds_between_fullscreen": 600, "interstitials_enabled": false, "rewarded_enabled": false})
	assert_eq(rc.min_levels_between_interstitials, 8)
	assert_eq(rc.min_seconds_between_fullscreen, 600)
	assert_false(rc.interstitials_enabled)
	assert_false(rc.rewarded_enabled)
	rc.apply({"interstitials_enabled": true, "rewarded_enabled": true})
	assert_false(rc.interstitials_enabled, "cannot be switched back on remotely")
	assert_false(rc.rewarded_enabled)


func test_disabled_interstitials() -> void:
	var rc := RemoteConfig.new()
	rc.apply({"interstitials_enabled": false})
	var p := InterstitialPolicy.new(rc, false)
	_complete(p, 20)
	assert_eq(p.blocked_reason(10000.0, BETWEEN), "disabled")


func test_ad_service_never_waits_for_interstitial() -> void:
	var mock := MockAdProvider.new()
	mock.manual = true
	var prog := Progression.new(Campaign.from_dict({"schema_version": 1, "realms": [{"id": "r"}],
		"creatures": [{"id": "d", "realm": "r", "levels": ["a", "b"]}]}).campaign, SaveSchema.defaults())
	var cfg := AdConfig.test_config()
	cfg.audience = "adult"
	var ads := AdService.new(mock, cfg, prog, null)
	ads.debug_build = true
	ads.start()
	mock.consent_info_updated.emit(mock.consent_info())
	var t := [0.0]
	ads.clock = func() -> float: return t[0]
	for i in 5:
		ads.on_level_completed(false)
	assert_eq(mock.count("load_interstitial"), 1, "one load, no duplicates")
	t[0] = 1000.0
	assert_false(ads.maybe_show_interstitial(BETWEEN), "not loaded yet: continue immediately")
	mock.interstitial_loaded.emit()
	assert_true(ads.maybe_show_interstitial(BETWEEN))
	assert_false(ads.maybe_show_interstitial(BETWEEN), "one per load")
	mock.interstitial_closed.emit()
	assert_eq(ads.interstitials.levels_since_last, 0)
