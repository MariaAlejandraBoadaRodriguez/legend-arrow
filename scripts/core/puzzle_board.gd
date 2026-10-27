class_name PuzzleBoard
extends RefCounted
## Pure puzzle state: a finite grid holding disjoint arrows.
##
## Rule (spec §4): a tapped arrow translates rigidly in its head direction until
## every cell is off the board. It may leave only if that full swept motion never
## touches a cell of another arrow still on the board. Its own cells are ignored.
## Because the motion is rigid, the swept area is the union of the rays cast
## from every body cell in the exit direction, so a clear arrowhead with a
## blocked body is still blocked.

var width: int = 0
var height: int = 0

var _all: Dictionary = {}        # id -> ArrowPath, every arrow ever added
var _order: Array[String] = []   # definition order, stable
var _present: Dictionary = {}    # id -> true for arrows still on the board
var _occupancy: Dictionary = {}  # Vector2i -> id for arrows still on the board


func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


## Adds an arrow. Returns false (and changes nothing) if the id is taken, the
## path is shorter than two cells, or any cell is out of bounds or occupied.
func add_arrow(a: ArrowPath) -> bool:
	if a.id == "" or _all.has(a.id) or a.length() < 2:
		return false
	for c in a.cells:
		if not in_bounds(c) or _occupancy.has(c):
			return false
	_all[a.id] = a
	_order.append(a.id)
	_place(a.id)
	return true


## Forgets an arrow entirely (generator use: rejecting a candidate path).
func discard_arrow(id: String) -> void:
	if not _all.has(id):
		return
	if _present.has(id):
		_lift(id)
	_all.erase(id)
	_order.erase(id)


func arrow(id: String) -> ArrowPath:
	return _all.get(id)


func has_arrow(id: String) -> bool:
	return _present.has(id)


func all_ids() -> Array[String]:
	return _order.duplicate()


## Ids still on the board, in definition order.
func remaining_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if _present.has(id):
			out.append(id)
	return out


func remaining_count() -> int:
	return _present.size()


func total_count() -> int:
	return _order.size()


func is_empty() -> bool:
	return _present.is_empty()


func occupant(c: Vector2i) -> String:
	return _occupancy.get(c, "")


## Returns the id of the first arrow found in the swept path of `id`, or "" if
## the arrow can leave. Rays are scanned head first so feedback points at the
## blocker closest to what the player is looking at.
func find_blocker(id: String) -> String:
	if not _present.has(id):
		return ""
	var a: ArrowPath = _all[id]
	var dir := a.direction()
	for i in range(a.length() - 1, -1, -1):
		var p: Vector2i = a.cells[i] + dir
		while in_bounds(p):
			var occ: String = _occupancy.get(p, "")
			if occ != "" and occ != id:
				return occ
			p += dir
	return ""


## Every arrow intersecting the swept path of `id` (on the current board),
## sorted by definition order.
func blockers_of(id: String) -> Array[String]:
	var found := {}
	if _present.has(id):
		var a: ArrowPath = _all[id]
		var dir := a.direction()
		for c in a.cells:
			var p: Vector2i = c + dir
			while in_bounds(p):
				var occ: String = _occupancy.get(p, "")
				if occ != "" and occ != id:
					found[occ] = true
				p += dir
	var out: Array[String] = []
	for other in _order:
		if found.has(other):
			out.append(other)
	return out


func is_removable(id: String) -> bool:
	return _present.has(id) and find_blocker(id) == ""


func removable_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if _present.has(id) and find_blocker(id) == "":
			out.append(id)
	return out


func has_legal_move() -> bool:
	for id in _order:
		if _present.has(id) and find_blocker(id) == "":
			return true
	return false


## Removes the arrow if its swept path is clear. A blocked or unknown id
## returns false and leaves the board untouched.
func remove(id: String) -> bool:
	if not is_removable(id):
		return false
	_lift(id)
	return true


## Puts a previously removed arrow back (used by undo/restart). Cells are
## guaranteed free because arrows are disjoint and nothing else moves.
func restore(id: String) -> bool:
	if not _all.has(id) or _present.has(id):
		return false
	_place(id)
	return true


func restore_all() -> void:
	for id in _order:
		if not _present.has(id):
			_place(id)


## Number of one-cell translation steps until every cell of the arrow has left
## the board. The view uses it to scale the exit animation.
func exit_steps(id: String) -> int:
	var a: ArrowPath = _all[id]
	var dir := a.direction()
	var steps := 0
	for c in a.cells:
		var d := 0
		match dir:
			ArrowPath.RIGHT:
				d = width - c.x
			ArrowPath.LEFT:
				d = c.x + 1
			ArrowPath.DOWN:
				d = height - c.y
			ArrowPath.UP:
				d = c.y + 1
		steps = maxi(steps, d)
	return steps


## Deep copy, including which arrows are currently removed.
func duplicate_board() -> PuzzleBoard:
	var b := PuzzleBoard.new(width, height)
	for id in _order:
		var src: ArrowPath = _all[id]
		b.add_arrow(ArrowPath.new(id, src.cells))
	for id in _order:
		if not _present.has(id):
			b._lift(id)
	return b


## Canonical key of the current state (sorted remaining ids).
func state_key() -> String:
	var ids := remaining_ids()
	ids.sort()
	return ",".join(ids)


func _place(id: String) -> void:
	var a: ArrowPath = _all[id]
	_present[id] = true
	for c in a.cells:
		_occupancy[c] = id


func _lift(id: String) -> void:
	var a: ArrowPath = _all[id]
	_present.erase(id)
	for c in a.cells:
		_occupancy.erase(c)
