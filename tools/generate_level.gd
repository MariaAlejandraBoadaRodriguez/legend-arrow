extends SceneTree
## Offline level authoring tool. Searches a fixed seed range for the board that
## best covers the creature's silhouette mask, validates it and writes
## data/levels/<creature>_<slot>.json. Deterministic: same args, same file.
##
## godot --headless --path . -s res://tools/generate_level.gd -- \
##   --creature forest_drake --slot 1 --arrows 6 --difficulty tutorial \
##   [--seeds 1:400] [--min-len 2] [--max-len 4] [--min-depth 2] [--dry-run]


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var creature_path := "res://data/creatures/%s.json" % args.creature
	var creature = JSON.parse_string(FileAccess.get_file_as_string(creature_path))
	if typeof(creature) != TYPE_DICTIONARY or not creature.has("level_masks"):
		printerr("generate_level: %s has no level_masks" % creature_path)
		quit(1)
		return
	var rows: Array = creature.level_masks[int(args.slot) - 1]
	var mask := mask_cells(rows)
	var w: int = (rows[0] as String).length()
	var h: int = rows.size()
	var best := {}
	var best_score := -1.0
	var seeds: PackedStringArray = str(args.get("seeds", "1:400")).split(":")
	for seed_value in range(int(seeds[0]), int(seeds[1]) + 1):
		var lvl := LevelGenerator.generate(seed_value, w, h, int(args.arrows), {
			"mask": mask, "min_len": int(args.get("min-len", 2)), "max_len": int(args.get("max-len", 4)),
		})
		if lvl.is_empty():
			continue
		var board := LevelData.to_board(lvl)
		var depth := PuzzleSolver.dependency_depth(board)
		if depth < int(args.get("min-depth", 1)):
			continue
		var used := 0
		for a in lvl.arrows:
			used += (a.cells as Array).size()
		# Prefer silhouette coverage, then a few distinct exits at the start.
		var score := float(used) / mask.size() + 0.01 * mini(board.removable_ids().size(), 3)
		if score > best_score:
			best_score = score
			best = lvl
	if best.is_empty():
		printerr("generate_level: no board found")
		quit(1)
		return
	var level := {
		"schema_version": LevelValidator.SCHEMA_VERSION,
		"id": "%s_%s" % [args.creature, args.slot],
		"creature_id": args.creature,
		"difficulty": args.difficulty,
		"width": w,
		"height": h,
		"seed": best.seed,
		"arrows": best.arrows,
		"solution": best.solution,
	}
	var errors := LevelValidator.validate(JSON.parse_string(JSON.stringify(level)))
	if not errors.is_empty():
		printerr("generate_level: invalid: %s" % str(errors))
		quit(1)
		return
	var text := format_level(level)
	print(text)
	print("coverage=%.2f depth=%d seed=%d" % [best_score, PuzzleSolver.dependency_depth(LevelData.to_board(level)), best.seed])
	if not args.has("dry-run"):
		var f := FileAccess.open("res://data/levels/%s.json" % level.id, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit(0)


## Mask rows use '#' for usable cells.
static func mask_cells(rows: Array) -> Array:
	var out: Array = []
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				out.append([x, y])
	return out


## Stable, diff-friendly JSON: one arrow per line.
static func format_level(level: Dictionary) -> String:
	var lines: Array[String] = ["{"]
	for key in ["schema_version", "id", "creature_id", "difficulty", "width", "height", "seed"]:
		lines.append("  %s: %s," % [JSON.stringify(key), JSON.stringify(level[key])])
	lines.append("  \"arrows\": [")
	for i in level.arrows.size():
		var a: Dictionary = level.arrows[i]
		var cells := ", ".join((a.cells as Array).map(func(c): return "[%d, %d]" % [c[0], c[1]]))
		lines.append("    {\"id\": %s, \"cells\": [%s]}%s" % [JSON.stringify(a.id), cells, "," if i < level.arrows.size() - 1 else ""])
	lines.append("  ],")
	lines.append("  \"solution\": %s" % JSON.stringify(level.solution))
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _parse(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < argv.size():
		var key := argv[i].trim_prefix("--")
		if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
			out[key] = argv[i + 1]
			i += 2
		else:
			out[key] = true
			i += 1
	return out
