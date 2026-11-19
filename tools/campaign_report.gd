extends SceneTree
## Difficulty and par table per world (v0.2 §9.8), from the shipped levels:
##   godot --headless --path . -s res://tools/campaign_report.gd
## Prints a Markdown table: arrows (min-max), average dependency depth,
## average arrows blocked at the start, par range, and level seeds.


func _init() -> void:
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/roster.json"))
	print("| World | Arrows | Avg depth | Avg blocked at start | Par (s) | Seeds |")
	print("|---|---|---|---|---|---|")
	for w in roster.worlds:
		var arrows: Array[int] = []
		var depth := 0.0
		var blocked := 0.0
		var pars: Array[int] = []
		var seeds: Array[String] = []
		for did in w.dragons:
			var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % did))
			var board := LevelData.to_board(level)
			arrows.append(board.total_count())
			depth += PuzzleSolver.dependency_depth(board)
			for id in board.remaining_ids():
				if not board.is_removable(id):
					blocked += 1
			pars.append(StarRating.par_for_level(level) / 1000)
			seeds.append(str(int(level.seed)))
		var n := float(w.dragons.size())
		print("| %d %s | %d–%d | %.1f | %.1f | %d–%d | %s |" % [int(w.number), w.name, arrows.min(), arrows.max(),
			depth / n, blocked / n, pars.min(), pars.max(), ", ".join(seeds)])
	quit()
