extends SceneTree
## Real disk-full check (v0.2 save investigation, docs/qa/SAVE_INVESTIGATION.md).
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
	var err := repo.write(big)
	var main_ok: bool = SaveRepository.read_file(path).ok
	var res := SaveRepository.new(path).load_save()
	var d: Dictionary = res.data
	print("RESULT code=%s second_write_err=%d main_readable=%s load_source=%s recovered=%s has_forest_drake=%s has_big=%s" % [
		"old" if legacy else "new", err, main_ok, res.source, res.recovered,
		d.levels.has("forest_drake"), d.levels.has("level_299")])
	DirAccess.remove_absolute(dir.path_join("filler"))
	quit()
