extends GutTest
## The on-device E2E harness only starts from an explicit one-shot trigger.


func after_each() -> void:
	if FileAccess.file_exists(DeviceE2E.TRIGGER):
		DirAccess.remove_absolute(DeviceE2E.TRIGGER)


func test_no_trigger_means_normal_launch() -> void:
	assert_eq(DeviceE2E.requested_journey(), "")


func test_trigger_file_is_consumed_once() -> void:
	var f := FileAccess.open(DeviceE2E.TRIGGER, FileAccess.WRITE)
	f.store_string("partial_b\n")
	f.close()
	assert_eq(DeviceE2E.requested_journey(), "partial_b")
	assert_false(FileAccess.file_exists(DeviceE2E.TRIGGER), "deleted so a later launch is normal")
	assert_eq(DeviceE2E.requested_journey(), "")


func test_every_journey_exists() -> void:
	var e2e := DeviceE2E.new("fresh_install")
	for j in DeviceE2E.JOURNEYS:
		assert_true(e2e.has_method(j), j)
	e2e.free()


## E2E runs must never start the real ads SDK: Main sets the flag before boot.
func test_e2e_mode_uses_the_mock_provider_from_boot() -> void:
	Game.force_mock_ads = true
	var p := Game._default_ad_provider()
	assert_true(p is MockAdProvider)
	Game.force_mock_ads = false
