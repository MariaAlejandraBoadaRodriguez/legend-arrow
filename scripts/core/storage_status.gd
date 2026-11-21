class_name StorageStatus
extends RefCounted
## Decides when the player sees "Storage full. Free up some space to save
## your progress." (0.2.1, DECISIONS D-52).
##
## Shown when:
##   - the last save write failed and free space is below LOW_SPACE_BYTES
##     (a failure with plenty of space left is an I/O error, not "storage
##     full": the save is still retried, but this message is not shown); or
##   - free space is below LOW_SPACE_BYTES (checked at launch, before every
##     save and every RECHECK_S while the message is up), as a warning before
##     progress is at risk.
## Hidden again once a save succeeds and free space is back above the
## threshold. Never shown when free space is unknown (-1) and saves succeed.

## 10 MB. A full save is ~50 KB and a write keeps up to three copies
## (save, .tmp, .bak), so 10 MB is ~60x what a save needs: a device below it
## is one app update or photo away from failing writes. Android's own
## low-storage warning starts far higher, so the message never shows on a
## device with normal free space.
const LOW_SPACE_BYTES := 10 * 1024 * 1024
## While the message is up, free space is re-read this often so it clears
## soon after the player frees space.
const RECHECK_S := 5.0

signal changed(visible: bool)

## Returns the free bytes for the save directory, or -1 when unknown.
var space_left: Callable = func() -> int: return -1
var save_failed := false   # last write failed while storage was low
var low := false           # free space below LOW_SPACE_BYTES
var visible := false


func check_space() -> void:
	var left: int = space_left.call()
	low = left >= 0 and left < LOW_SPACE_BYTES
	_update()


## Call after every save write with its result (OK or an Error code).
func on_save_result(err: int) -> void:
	check_space()
	save_failed = err != OK and low
	_update()


func _update() -> void:
	var v := save_failed or low
	if v != visible:
		visible = v
		changed.emit(v)


## Free bytes on the filesystem holding `dir` (Godot DirAccess), -1 if unknown.
static func space_left_in(dir: String) -> int:
	var d := DirAccess.open(dir)
	if d == null:
		return -1
	return int(d.get_space_left())   # 0 on a full filesystem
