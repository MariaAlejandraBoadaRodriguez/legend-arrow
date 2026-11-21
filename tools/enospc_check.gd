extends SceneTree
## Real disk-full check (0.2.1; docs/qa/SAVE_INVESTIGATION.md).
## Writes a good save, fills the filesystem so only a few KB remain, then
## writes a larger save: the real write hits ENOSPC (no test hook).
##   godot --headless --path . -s res://tools/enospc_check.gd -- <dir on a small fs> <old|new>
## Prints what the write returned and what the next load gets.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var legacy: bool = args.size() > 1 and args[1] == "old"
	var path := dir.path_join("save.json")
	for f in ["save.json", "save.json.tmp", "save.json.bak", "save.json.corrupt", "filler"]:
		DirAccess.remove_absolute(dir.path_join(f))
	var repo := SaveRepository.new(path)
	repo.legacy_unverified = legacy
	var small := SaveSchema.defaults()
	small.tutorial_done = true
	small.levels["forest_drake"] = {"completed": true, "best_time_ms": 9000, "best_stars": 3}
	print("first write: ", repo.write(small))
	# Fill the filesystem, then free a single 4 KB block.
	var filler := FileAccess.open(dir.path_join("filler"), FileAccess.WRITE)
	var chunk := PackedByteArray(); chunk.resize(4096)
	while true:
		filler.store_buffer(chunk)
		filler.flush()
		if filler.get_error() != OK:
			break
	filler.close()
	var fl := FileAccess.open(dir.path_join("filler"), FileAccess.READ_WRITE)
	fl.resize(maxi(0, fl.get_length() - 4096))
	fl.close()
	var big := small.duplicate(true)
	for i in 300:   # ~20 KB payload: more than the space left
		big.levels["level_%03d" % i] = {"completed": true, "best_time_ms": 12345 + i, "best_stars": 2}
	# What the game does on a save: check free space, write, report the result.
	var storage := StorageStatus.new()
	storage.space_left = func() -> int: return StorageStatus.space_left_in(dir)
	storage.check_space()
	var err := repo.write(big)
	storage.on_save_result(err)
	var space_full := StorageStatus.space_left_in(dir)
	var main_ok: bool = SaveRepository.read_file(path).ok
	var res := SaveRepository.new(path).load_save()
	var d: Dictionary = res.data
	print("RESULT code=%s second_write_err=%d main_readable=%s load_source=%s recovered=%s has_forest_drake=%s has_big=%s storage_message=%s space_left=%d" % [
		"old" if legacy else "new", err, main_ok, res.source, res.recovered,
		d.levels.has("forest_drake"), d.levels.has("level_299"), storage.visible, space_full])
	# Space freed: the same save now lands and the message clears.
	DirAccess.remove_absolute(dir.path_join("filler"))
	storage.check_space()
	var err2 := repo.write(big)
	storage.on_save_result(err2)
	print("RECOVERY code=%s write_err=%d has_big=%s storage_message=%s" % [
		"old" if legacy else "new", err2, SaveRepository.new(path).load_save().data.levels.has("level_299"), storage.visible])
	quit()
