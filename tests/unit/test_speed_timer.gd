extends GutTest
## SpeedTimer: first-tap start, holds, capped ticks, finish, persistence.


func test_does_not_run_before_start() -> void:
	var t := SpeedTimer.new()
	t.tick(1000)
	assert_eq(t.elapsed_ms, 0)
	assert_false(t.is_running())


func test_runs_after_start_and_accumulates() -> void:
	var t := SpeedTimer.new()
	t.start()
	for i in 10:
		t.tick(100)
	assert_eq(t.elapsed_ms, 1000)


func test_each_hold_stops_the_clock_until_all_are_released() -> void:
	var t := SpeedTimer.new()
	t.start()
	for reason in ["menu", "overlay", "background", "ad", "awakening"]:
		t.hold(reason)
		t.tick(200)
		assert_eq(t.elapsed_ms, 0, "%s holds" % reason)
	t.hold("menu", false)
	t.tick(200)
	assert_eq(t.elapsed_ms, 0, "other holds still active")
	for reason in ["overlay", "background", "ad", "awakening"]:
		t.hold(reason, false)
	t.tick(200)
	assert_eq(t.elapsed_ms, 200, "resumes when every hold is released")
	assert_true(t.is_running())


func test_large_negative_and_invalid_ticks_are_bounded() -> void:
	var t := SpeedTimer.new()
	t.start()
	t.tick(3600 * 1000.0)   # app suspended without a notification
	assert_eq(t.elapsed_ms, SpeedTimer.MAX_TICK_MS, "one tick adds at most MAX_TICK_MS")
	t.tick(-5000)
	t.tick(NAN)
	t.tick(0)
	assert_eq(t.elapsed_ms, SpeedTimer.MAX_TICK_MS, "negative/NaN/zero add nothing")


func test_elapsed_is_capped() -> void:
	var t := SpeedTimer.new()
	t.start()
	t.elapsed_ms = SpeedTimer.MAX_ELAPSED_MS - 10
	t.tick(200)
	assert_eq(t.elapsed_ms, SpeedTimer.MAX_ELAPSED_MS)


func test_finish_freezes_and_start_cannot_restart() -> void:
	var t := SpeedTimer.new()
	t.start()
	t.tick(150)
	assert_eq(t.finish(), 150)
	t.start()
	t.tick(150)
	assert_eq(t.elapsed_ms, 150)
	assert_false(t.is_running())


func test_reset_keeps_holds() -> void:
	var t := SpeedTimer.new()
	t.start()
	t.tick(100)
	t.hold("overlay")
	t.reset()
	assert_eq(t.elapsed_ms, 0)
	assert_false(t.started)
	t.start()
	t.tick(100)
	assert_eq(t.elapsed_ms, 0, "overlay hold survives a reset")


func test_round_trip_and_hostile_values() -> void:
	var t := SpeedTimer.new()
	t.start()
	t.tick(240)
	var u := SpeedTimer.new()
	u.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	assert_eq(u.elapsed_ms, 240)
	assert_true(u.started)
	for bad in [{"elapsed_ms": -50}, {"elapsed_ms": "12"}, {"elapsed_ms": 1e300}, {}, {"elapsed_ms": NAN}]:
		var v := SpeedTimer.new()
		v.from_dict(bad)
		assert_between(v.elapsed_ms, 0, SpeedTimer.MAX_ELAPSED_MS, "clamped: %s" % str(bad))
	var w := SpeedTimer.new()
	w.from_dict({"elapsed_ms": -50})
	assert_eq(w.elapsed_ms, 0, "no negative time")


func test_format() -> void:
	assert_eq(SpeedTimer.format_ms(0), "0:00")
	assert_eq(SpeedTimer.format_ms(59_999), "0:59")
	assert_eq(SpeedTimer.format_ms(61_000), "1:01")
	assert_eq(SpeedTimer.format_ms(3_661_000), "1:01:01")
	assert_eq(SpeedTimer.format_ms(-5), "0:00")
