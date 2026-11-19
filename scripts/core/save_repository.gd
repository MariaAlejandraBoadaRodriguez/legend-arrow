class_name SaveRepository
extends RefCounted
## Atomic local save with last-known-good backup.
##
## File envelope: {"format": "legend_arrow_save", "sha256": <hex of payload
## text>, "payload": <JSON text of the save dictionary>}. The checksum detects
## truncated or edited files.
##
## write():  1) write <save>.tmp completely and read it back: it must parse
##              and hold exactly this payload, else stop (main untouched)
##           2) rotate <save> -> <save>.bak   3) rename <save>.tmp -> <save>
## A process kill at any point leaves either the previous or the new complete
## save readable: load() tries main, then tmp, then backup.
## Step 1's check matters because Godot reports neither short writes (disk
## full, I/O error) nor a failed rename inside FileAccess.close(); without it
## a broken tmp would replace a good main, and the next load would restore the
## older backup (v0.2 API 26 investigation, docs/qa/SAVE_INVESTIGATION.md).

const FILE_FORMAT := "legend_arrow_save"

enum Source { MAIN, TEMP, BACKUP, NEW }

var path: String
## Test hook: stop write() after this step (1..2) to simulate a process kill.
var simulate_crash_after_step := -1
## Test hook: damage the tmp file right after it is written ("truncate":
## short write; "stale": an older complete save; "missing": failed rename).
var simulate_bad_tmp := ""
## Writes made through this repository (diagnostics).
var write_seq := 0


func _init(p_path: String = "user://save.json") -> void:
	path = p_path


## Result: {data: Dictionary, source: Source, recovered: bool, problems: Array}
## `recovered` is true when the main file was unreadable and an older copy was
## restored; the UI shows "Progress restored" only in that case.
func load_save() -> Dictionary:
	var problems: Array = []
	var main_missing := not FileAccess.file_exists(path)
	if main_missing:
		problems.append("main save missing")
	else:
		var res := read_file(path)
		if res.ok:
			return {"data": res.data, "source": Source.MAIN, "recovered": false, "problems": problems}
		problems.append("%s: %s" % [path.get_file(), res.error])
		_quarantine(path)  # keep the evidence, never delete it
	for candidate in [[path + ".tmp", Source.TEMP], [path + ".bak", Source.BACKUP]]:
		var file_path: String = candidate[0]
		if not FileAccess.file_exists(file_path):
			continue
		var res := read_file(file_path)
		if not res.ok:
			problems.append("%s: %s" % [file_path.get_file(), res.error])
			continue
		# A missing main file with a complete tmp is an interrupted rename: the
		# newest save is intact, so there is nothing to tell the player.
		var recovered: bool = not (main_missing and candidate[1] == Source.TEMP)
		write(res.data)  # repair the main file
		return {"data": res.data, "source": candidate[1], "recovered": recovered, "problems": problems}
	return {"data": SaveSchema.defaults(), "source": Source.NEW, "recovered": false, "problems": problems}


## Writes atomically. Returns OK or an error code.
func write(data: Dictionary) -> int:
	var payload := JSON.stringify(data, "", true)
	write_seq += 1
	# pid / seq / time are diagnostics only (which process wrote which save);
	# read_file() ignores them.
	var envelope := JSON.stringify({"format": FILE_FORMAT, "sha256": payload.sha256_text(), "payload": payload,
		"pid": OS.get_process_id(), "seq": write_seq, "unix_ms": int(Time.get_unix_time_from_system() * 1000.0)})
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(envelope)
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	_apply_bad_tmp_hook(tmp)
	# Never promote a tmp that is not exactly what we meant to write.
	var check := read_file(tmp)
	if not check.ok or FileAccess.get_file_as_string(tmp) != envelope:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	if simulate_crash_after_step == 1:
		return OK
	if FileAccess.file_exists(path) and read_file(path).ok:
		var err := DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	if simulate_crash_after_step == 2:
		return OK
	return DirAccess.rename_absolute(tmp, path)


func _apply_bad_tmp_hook(tmp: String) -> void:
	match simulate_bad_tmp:
		"truncate":
			var text := FileAccess.get_file_as_string(tmp)
			var t := FileAccess.open(tmp, FileAccess.WRITE)
			t.store_string(text.left(text.length() / 2))
			t.close()
		"stale":
			var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
			var t2 := FileAccess.open(tmp, FileAccess.WRITE)
			t2.store_string(old)
			t2.close()
		"missing":
			DirAccess.remove_absolute(tmp)


## Read-only view of what load_save() would return, without quarantining or
## repairing anything (diagnostics and tests must not change the files).
func peek() -> Dictionary:
	var problems: Array = []
	for candidate in [[path, Source.MAIN], [path + ".tmp", Source.TEMP], [path + ".bak", Source.BACKUP]]:
		if not FileAccess.file_exists(candidate[0]):
			if candidate[1] == Source.MAIN:
				problems.append("main save missing")
			continue
		var res := read_file(candidate[0])
		if res.ok:
			return {"data": res.data, "source": candidate[1], "problems": problems}
		problems.append("%s: %s" % [str(candidate[0]).get_file(), res.error])
	return {"data": SaveSchema.defaults(), "source": Source.NEW, "problems": problems}


## The diagnostic fields of a save file's envelope ({} if unreadable).
static func envelope_info(file_path: String) -> Dictionary:
	var env = _parse_quietly(FileAccess.get_file_as_string(file_path))
	if typeof(env) != TYPE_DICTIONARY:
		return {}
	return {"pid": env.get("pid", -1), "seq": env.get("seq", -1), "unix_ms": env.get("unix_ms", -1)}


## Result: {ok: bool, data: Dictionary, error: String}. Migrates and sanitizes.
static func read_file(file_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return {"ok": false, "data": {}, "error": "empty or unreadable"}
	var envelope = _parse_quietly(text)
	if typeof(envelope) != TYPE_DICTIONARY or envelope.get("format") != FILE_FORMAT:
		return {"ok": false, "data": {}, "error": "not a save file"}
	var payload = envelope.get("payload")
	if typeof(payload) != TYPE_STRING or payload.sha256_text() != envelope.get("sha256"):
		return {"ok": false, "data": {}, "error": "checksum mismatch"}
	var data = SaveSchema.ints_from_json(_parse_quietly(payload))
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "payload is not an object"}
	var migrated := SaveSchema.migrate(data)
	if migrated.is_empty():
		return {"ok": false, "data": {}, "error": "unsupported schema_version %s" % str(data.get("schema_version"))}
	var problems := SaveSchema.sanitize(migrated)
	if not problems.is_empty():
		return {"ok": false, "data": {}, "error": "; ".join(problems)}
	return {"ok": true, "data": migrated, "error": ""}


## JSON.parse_string() logs an engine error on bad input; a corrupt save is an
## expected condition here, so parse through an instance and just return null.
static func _parse_quietly(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


func _quarantine(file_path: String) -> void:
	var dest := file_path + ".corrupt"
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	DirAccess.rename_absolute(file_path, dest)
