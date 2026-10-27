class_name LevelValidator
extends RefCounted
## Validates level dictionaries (parsed JSON, see docs/LEVEL_FORMAT.md).
## validate() returns a list of human-readable errors; empty means valid.

const SCHEMA_VERSION := 1
const MAX_GRID := 40
const MAX_ARROWS := 60
## Arrow-count bands per difficulty (spec §5, provisional, inclusive).
const DIFFICULTY_BANDS := {
	"tutorial": [1, 8],
	"easy": [6, 12],
	"medium": [13, 24],
	"hard": [25, 40],
	"expert": [41, 60],
}
const ID_PATTERN := "^[a-z0-9_]+$"

static var _id_regex: RegEx


static func validate(level: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(level) != TYPE_DICTIONARY:
		errors.append("level must be a JSON object")
		return errors
	var d: Dictionary = level

	if not _is_int(d.get("schema_version")) or int(d.get("schema_version")) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	for key in ["id", "creature_id"]:
		if not _is_id(d.get(key)):
			errors.append("%s must be a non-empty lowercase id ([a-z0-9_])" % key)
	var difficulty = d.get("difficulty")
	if typeof(difficulty) != TYPE_STRING or not DIFFICULTY_BANDS.has(difficulty):
		errors.append("difficulty must be one of %s" % ", ".join(DIFFICULTY_BANDS.keys()))
		difficulty = ""

	var w = d.get("width")
	var h = d.get("height")
	var size_ok := _is_int(w) and _is_int(h) and int(w) >= 2 and int(h) >= 2 and int(w) <= MAX_GRID and int(h) <= MAX_GRID
	if not size_ok:
		errors.append("width and height must be integers in 2..%d" % MAX_GRID)
		return errors

	var arrows = d.get("arrows")
	if typeof(arrows) != TYPE_ARRAY or (arrows as Array).is_empty():
		errors.append("arrows must be a non-empty array")
		return errors
	if (arrows as Array).size() > MAX_ARROWS:
		errors.append("too many arrows (%d > %d)" % [(arrows as Array).size(), MAX_ARROWS])

	var board := PuzzleBoard.new(int(w), int(h))
	var ids := {}
	var owner := {}  # Vector2i -> arrow id
	var geometry_ok := true
	for i in (arrows as Array).size():
		var path_errors := _validate_arrow(arrows[i], i, int(w), int(h), ids, owner)
		if path_errors.is_empty():
			board.add_arrow(ArrowPath.from_dict(arrows[i]))
		else:
			geometry_ok = false
			errors.append_array(path_errors)

	if difficulty != "":
		var band: Array = DIFFICULTY_BANDS[difficulty]
		var n := (arrows as Array).size()
		if n < band[0] or n > band[1]:
			errors.append("%s levels need %d-%d arrows, found %d" % [difficulty, band[0], band[1], n])

	var solution = d.get("solution")
	if typeof(solution) != TYPE_ARRAY:
		errors.append("solution must be an array of arrow ids")
		return errors
	if not geometry_ok:
		return errors

	var listed := {}
	for s in solution:
		if typeof(s) != TYPE_STRING or not ids.has(s):
			errors.append("solution references unknown arrow '%s'" % str(s))
		elif listed.has(s):
			errors.append("solution lists arrow '%s' twice" % s)
		listed[str(s)] = true
	if (solution as Array).size() != ids.size():
		errors.append("solution must list every arrow exactly once (%d of %d)" % [(solution as Array).size(), ids.size()])
	if not errors.is_empty():
		return errors

	var result := PuzzleSolver.verify_solution(board, solution)
	if not result.ok:
		errors.append("recorded solution fails at step %d: %s" % [result.step, result.error])
	if not PuzzleSolver.is_solvable(board):
		errors.append("board is not solvable under swept-body rules")
	return errors


static func _validate_arrow(a: Variant, index: int, w: int, h: int, ids: Dictionary, owner: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var label := "arrow[%d]" % index
	if typeof(a) != TYPE_DICTIONARY:
		errors.append("%s must be an object" % label)
		return errors
	var id = a.get("id")
	if not _is_id(id):
		errors.append("%s has an invalid id" % label)
		return errors
	label = "arrow '%s'" % id
	if ids.has(id):
		errors.append("%s: duplicate id" % label)
		return errors
	ids[id] = true
	var cells = a.get("cells")
	if typeof(cells) != TYPE_ARRAY or (cells as Array).size() < 2:
		errors.append("%s: path needs at least 2 cells" % label)
		return errors
	var pts: Array[Vector2i] = []
	for c in cells:
		if typeof(c) != TYPE_ARRAY or (c as Array).size() != 2 or not _is_int(c[0]) or not _is_int(c[1]):
			errors.append("%s: each cell must be [x, y] integers" % label)
			return errors
		pts.append(Vector2i(int(c[0]), int(c[1])))
	var own := {}
	for i in pts.size():
		var p := pts[i]
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			errors.append("%s: cell (%d, %d) is out of bounds" % [label, p.x, p.y])
		if own.has(p):
			errors.append("%s: cell (%d, %d) repeats within the path" % [label, p.x, p.y])
		own[p] = true
		if owner.has(p) and owner[p] != id:
			errors.append("%s overlaps arrow '%s' at (%d, %d)" % [label, owner[p], p.x, p.y])
		if i > 0:
			var step := p - pts[i - 1]
			if absi(step.x) + absi(step.y) != 1:
				errors.append("%s: cells %d and %d are not orthogonally adjacent" % [label, i - 1, i])
	if errors.is_empty():
		for p in pts:
			owner[p] = id
	return errors


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v)


static func _is_id(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		return false
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	return _id_regex.search(v) != null
