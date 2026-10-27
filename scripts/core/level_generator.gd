class_name LevelGenerator
extends RefCounted
## Deterministic offline level generator using reverse construction.
##
## Arrows are inserted one at a time; a candidate is accepted only if it can
## leave the board given the arrows already placed. Removing arrows in reverse
## insertion order is therefore always legal, so every output is solvable by
## construction (and is re-checked by the exact solver and validator anyway).

## Options:
##   min_len / max_len : path length range (cells), default 2..5
##   straight_bias     : 0..100, chance to keep walking straight, default 55
##   mask              : optional Array of [x, y] cells arrows may use (silhouettes)
##   max_attempts      : candidate paths per round, default 40 * arrow_count
##   max_restarts      : fresh rounds after a stalled one, default 20
##   stall_limit       : failed candidates in a row that end a round, default 60
static func generate(seed_value: int, width: int, height: int, arrow_count: int, options: Dictionary = {}) -> Dictionary:
	var rng := DeterministicRng.new(seed_value)
	var min_len: int = options.get("min_len", 2)
	var max_len: int = maxi(min_len, options.get("max_len", 5))
	var straight_bias: int = options.get("straight_bias", 55)
	var max_attempts: int = options.get("max_attempts", 40 * arrow_count)
	var max_restarts: int = options.get("max_restarts", 20)
	var stall_limit: int = options.get("stall_limit", 60)
	var allowed := {}
	if options.has("mask"):
		for c in options["mask"]:
			allowed[Vector2i(int(c[0]), int(c[1]))] = true
	else:
		for y in height:
			for x in width:
				allowed[Vector2i(x, y)] = true

	# A board can saturate (no space left that can still escape). When a round
	# stalls, start over; the RNG keeps advancing so every round differs and the
	# result stays a pure function of the seed.
	for round in max_restarts + 1:
		var board := PuzzleBoard.new(width, height)
		var inserted: Array[String] = []
		var attempts := 0
		var stall := 0
		while inserted.size() < arrow_count and attempts < max_attempts and stall < stall_limit:
			attempts += 1
			stall += 1
			# Prefer shorter paths as placements start failing.
			var hi := maxi(min_len, max_len - stall / 8)
			var path := _random_walk(rng, board, allowed, rng.range_int(min_len, hi), min_len, straight_bias)
			if path.is_empty():
				continue
			var id := "g%d" % attempts
			var candidates := [path, _reversed(path)]
			if rng.range_int(0, 1) == 1:
				candidates.reverse()
			for cand in candidates:
				if board.add_arrow(ArrowPath.new(id, cand)) and board.is_removable(id):
					inserted.append(id)
					stall = 0
					break
				if board.has_arrow(id):
					board.discard_arrow(id)
		if inserted.size() == arrow_count:
			return _to_level(board, inserted, seed_value)
	return {}


## Difficulty label for an arrow count (LevelValidator.DIFFICULTY_BANDS).
static func difficulty_for(arrow_count: int) -> String:
	if arrow_count <= 5:
		return "tutorial"
	if arrow_count <= 12:
		return "easy"
	if arrow_count <= 24:
		return "medium"
	if arrow_count <= 40:
		return "hard"
	return "expert"


## Places random disjoint paths WITHOUT any solvability guarantee. Used by
## tests to cross-check the solver against brute force on arbitrary boards.
static func random_board(seed_value: int, width: int, height: int, arrow_count: int, max_len: int = 4) -> PuzzleBoard:
	var rng := DeterministicRng.new(seed_value)
	var allowed := {}
	for y in height:
		for x in width:
			allowed[Vector2i(x, y)] = true
	var board := PuzzleBoard.new(width, height)
	var attempts := 0
	while board.total_count() < arrow_count and attempts < arrow_count * 20:
		attempts += 1
		var path := _random_walk(rng, board, allowed, rng.range_int(2, max_len), 2, 40)
		if not path.is_empty():
			board.add_arrow(ArrowPath.new("r%d" % attempts, path))
	return board


static func _random_walk(rng: DeterministicRng, board: PuzzleBoard, allowed: Dictionary, target_len: int, min_len: int, straight_bias: int) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for c in allowed:
		if board.in_bounds(c) and board.occupant(c) == "":
			free.append(c)
	if free.size() < min_len:
		return []
	free.sort()  # dictionary order is insertion-based; sort for determinism
	var path: Array[Vector2i] = [free[rng.range_int(0, free.size() - 1)]]
	var used := {path[0]: true}
	var dirs: Array[Vector2i] = [ArrowPath.UP, ArrowPath.RIGHT, ArrowPath.DOWN, ArrowPath.LEFT]
	while path.size() < target_len:
		var options: Array[Vector2i] = []
		for d in dirs:
			var n: Vector2i = path[path.size() - 1] + d
			if allowed.has(n) and board.in_bounds(n) and board.occupant(n) == "" and not used.has(n):
				options.append(n)
		if options.is_empty():
			break
		var next: Vector2i = options[rng.range_int(0, options.size() - 1)]
		if path.size() >= 2 and rng.range_int(0, 99) < straight_bias:
			var straight: Vector2i = path[path.size() - 1] * 2 - path[path.size() - 2]
			if options.has(straight):
				next = straight
		path.append(next)
		used[next] = true
	if path.size() < min_len:
		return []
	return path


static func _reversed(path: Array[Vector2i]) -> Array[Vector2i]:
	var out := path.duplicate()
	out.reverse()
	return out


## Renames arrows a01.. in reading order of their heads and records the
## certified solution (reverse insertion order).
static func _to_level(board: PuzzleBoard, inserted: Array[String], seed_value: int) -> Dictionary:
	var ids := inserted.duplicate()
	ids.sort_custom(func(p, q):
		var hp: Vector2i = board.arrow(p).head()
		var hq: Vector2i = board.arrow(q).head()
		return hp.y < hq.y or (hp.y == hq.y and hp.x < hq.x))
	var rename := {}
	var arrows: Array = []
	for i in ids.size():
		var new_id := "a%02d" % (i + 1)
		rename[ids[i]] = new_id
		var d := board.arrow(ids[i]).to_dict()
		d["id"] = new_id
		arrows.append(d)
	var solution: Array = []
	for i in range(inserted.size() - 1, -1, -1):
		solution.append(rename[inserted[i]])
	return {
		"schema_version": LevelValidator.SCHEMA_VERSION,
		"width": board.width,
		"height": board.height,
		"seed": seed_value,
		"arrows": arrows,
		"solution": solution,
	}
