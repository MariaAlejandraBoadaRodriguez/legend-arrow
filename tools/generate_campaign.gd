extends SceneTree
## Generates every level of build/campaign_plan.json (tools/build_campaign.py).
## Per level: seeds 1..SEEDS through LevelGenerator on the dragon's
## silhouette; each candidate is certified (exact solver: solvable, recorded
## solution replays to an empty board, a legal first move exists) and scored:
## reaching the dependency target first, then deeper chains, then fewer
## arrows free at the start (simultaneous exits), then silhouette coverage.
## Writes data/levels/<id>.json; prints one GEN line per level, FAIL lines for
## levels with no certified board; exit code 1 if any failed. Deterministic.

const SEEDS := 140
const GenerateLevel := preload("res://tools/generate_level.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var plan = JSON.parse_string(FileAccess.get_file_as_string(args[0] if args.size() > 0 else "res://build/campaign_plan.json"))
	var failed := 0
	for p in plan:
		var lvl := best_level(p)
		if lvl.is_empty():
			print("FAIL %s no certified board (%dx%d, %d arrows, %d mask cells)" % [p.id, p.width, p.height, p.arrows, GenerateLevel.mask_cells(p.mask).size()])
			failed += 1
			continue
		var f := FileAccess.open("res://data/levels/%s.json" % p.id, FileAccess.WRITE)
		f.store_string(GenerateLevel.format_level(lvl))
		f.close()
		var board := LevelData.to_board(lvl)
		print("GEN %s w%d k%d %dx%d arrows=%d depth=%d/%d free=%d seed=%d" % [p.id, p.world, p.index,
			lvl.width, lvl.height, board.total_count(), PuzzleSolver.dependency_depth(board), p.min_depth,
			board.removable_ids().size(), lvl.seed])
	print("generate_campaign: %d levels, %d failed" % [plan.size(), failed])
	quit(1 if failed > 0 else 0)


static func best_level(p: Dictionary) -> Dictionary:
	var mask := GenerateLevel.mask_cells(p.mask)
	var w := int(p.width)
	var h := int(p.height)
	var best := {}
	var best_score := -INF
	var seeds := SEEDS if int(p.arrows) <= 24 else (80 if int(p.arrows) <= 40 else 60)
	if int(p.get("seeds", 0)) > 0:
		seeds = int(p.seeds)
	for seed_value in range(1, seeds + 1):
		var g := LevelGenerator.generate(seed_value, w, h, int(p.arrows), {
			"mask": mask, "min_len": 2, "max_len": int(p.max_len)})
		if g.is_empty():
			continue
		var level := {
			"schema_version": LevelValidator.SCHEMA_VERSION, "id": p.id, "creature_id": p.id,
			"difficulty": p.difficulty, "width": w, "height": h, "seed": g.seed,
			"arrows": g.arrows, "solution": g.solution,
		}
		level = JSON.parse_string(JSON.stringify(level))
		if not certified(level):
			continue
		var board := LevelData.to_board(level)
		var depth := PuzzleSolver.dependency_depth(board)
		var used := 0
		for a in level.arrows:
			used += (a.cells as Array).size()
		var free := board.removable_ids().size()
		# Later worlds weigh deeper chains and fewer simultaneous exits more.
		var score := (1000.0 if depth >= int(p.min_depth) else 0.0) + depth * float(p.get("depth_weight", 10.0)) \
			- free * float(p.get("free_weight", 2.0)) + float(used) / mask.size()
		if score > best_score:
			best_score = score
			best = level
	return best


## Validator + exact solver + the recorded solution replays to an empty board.
static func certified(level: Dictionary) -> bool:
	if not LevelValidator.validate(level).is_empty():
		return false
	var board := LevelData.to_board(level)
	if not board.has_legal_move() or not PuzzleSolver.is_solvable(board):
		return false
	return PuzzleSolver.verify_solution(board, level.solution).ok
