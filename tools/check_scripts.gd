extends SceneTree
## Loads every project GDScript (excluding vendored addons) and fails if any
## does not compile. Run: godot --headless --path . -s res://tools/check_scripts.gd

const ROOTS := ["res://scripts", "res://scenes", "res://tests", "res://tools"]


func _init() -> void:
	var files: Array[String] = []
	for root in ROOTS:
		_collect(root, files)
	var failed: Array[String] = []
	for path in files:
		var script: Script = ResourceLoader.load(path)
		if script == null or not script.can_instantiate():
			failed.append(path)
	print("check_scripts: %d scripts checked, %d failed" % [files.size(), failed.size()])
	for path in failed:
		printerr("check_scripts: FAILED to compile %s" % path)
	if files.is_empty():
		printerr("check_scripts: no scripts found")
		quit(2)
		return
	quit(1 if not failed.is_empty() else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
