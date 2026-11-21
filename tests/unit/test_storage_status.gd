extends GutTest
## When "Storage full. Free up some space to save your progress." shows
## (StorageStatus, 0.2.1, D-52).

const MB := 1024 * 1024
const PLENTY := 2000 * MB

var st: StorageStatus
var free_bytes := PLENTY
var changes: Array = []


func before_each() -> void:
	free_bytes = PLENTY
	changes.clear()
	st = StorageStatus.new()
	st.space_left = func() -> int: return free_bytes
	st.changed.connect(func(v): changes.append(v))


func test_normal_storage_never_shows_the_message() -> void:
	st.check_space()
	st.on_save_result(OK)
	st.on_save_result(OK)
	assert_false(st.visible)
	assert_eq(changes, [], "never toggled")


func test_full_storage_save_failure_shows_the_message() -> void:
	free_bytes = 0
	st.on_save_result(ERR_FILE_CANT_WRITE)
	assert_true(st.save_failed)
	assert_true(st.visible)
	assert_eq(changes, [true])


func test_low_storage_warns_before_a_save_fails() -> void:
	free_bytes = StorageStatus.LOW_SPACE_BYTES - 1
	st.check_space()          # at launch / before a save
	assert_true(st.visible, "warning while saves still succeed")
	st.on_save_result(OK)
	assert_false(st.save_failed)
	assert_true(st.visible, "still at risk: the warning stays")


func test_threshold_is_exclusive_and_documented() -> void:
	assert_eq(StorageStatus.LOW_SPACE_BYTES, 10 * MB)
	free_bytes = StorageStatus.LOW_SPACE_BYTES
	st.check_space()
	assert_false(st.visible, "exactly 10 MB free is enough")


func test_recovery_after_space_is_freed_hides_the_message() -> void:
	free_bytes = 4096
	st.on_save_result(ERR_FILE_CORRUPT)
	assert_true(st.visible)
	free_bytes = PLENTY
	st.on_save_result(OK)    # the background retry lands
	assert_false(st.visible)
	assert_eq(changes, [true, false])


func test_space_freed_without_a_save_hides_a_low_space_warning() -> void:
	free_bytes = MB
	st.check_space()
	assert_true(st.visible)
	free_bytes = PLENTY
	st.check_space()          # periodic recheck while the message is up
	assert_false(st.visible)


func test_failed_save_stays_shown_until_a_save_succeeds() -> void:
	free_bytes = 0
	st.on_save_result(ERR_FILE_CANT_WRITE)
	free_bytes = PLENTY
	st.check_space()
	assert_true(st.visible, "space is back but progress is not on disk yet")
	st.on_save_result(OK)
	assert_false(st.visible)


func test_io_error_with_plenty_of_space_is_not_storage_full() -> void:
	st.on_save_result(ERR_FILE_CANT_WRITE)
	assert_false(st.visible, "not a storage problem: no storage message")


func test_unknown_free_space_is_not_low() -> void:
	free_bytes = -1
	st.check_space()
	st.on_save_result(OK)
	assert_false(st.visible)


func test_reads_the_real_filesystem() -> void:
	var left := StorageStatus.space_left_in(OS.get_user_data_dir())
	assert_gt(left, StorageStatus.LOW_SPACE_BYTES, "the test machine has normal free space")
