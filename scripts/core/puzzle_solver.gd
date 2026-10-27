class_name PuzzleSolver
extends RefCounted
## Exact solver for the removal-only swept-body rules.
##
## Key fact: an arrow's swept area depends only on its own cells, so the set of
## arrows blocking it in any state is (blockers on the full board) ∩ (arrows
## still present). Removing an arrow can therefore never create a new blocker
## (monotonicity), and a board is solvable iff its "A is blocked by B"
## dependency graph is acyclic. Any legal move keeps a solvable board solvable.


## id -> Array[String] of arrows that must leave before it, computed on the
## board's current state.
static func dependency_graph(board: PuzzleBoard) -> Dictionary:
	var g := {}
	for id in board.remaining_ids():
		g[id] = board.blockers_of(id)
	return g


## Deterministic solution (Kahn's algorithm, ties broken by definition order)
## from the board's current state. Returns an empty array when the board is
## unsolvable, and also when it is already empty: check board.is_empty().
static func solve(board: PuzzleBoard) -> Array[String]:
	var g := dependency_graph(board)
	var ids := board.remaining_ids()
	var pending := {}       # id -> number of blockers still present
	var unblocks := {}      # blocker -> ids it is blocking
	for id in ids:
		pending[id] = g[id].size()
		for b in g[id]:
			if not unblocks.has(b):
				unblocks[b] = []
			unblocks[b].append(id)
	var order: Array[String] = []
	var done := {}
	var progressed := true
	while progressed:
		progressed = false
		for id in ids:
			if done.has(id) or pending[id] > 0:
				continue
			done[id] = true
			order.append(id)
			progressed = true
			for dependent in unblocks.get(id, []):
				pending[dependent] -= 1
			break  # restart scan so ties always resolve to definition order
	if order.size() != ids.size():
		return []
	return order


static func is_solvable(board: PuzzleBoard) -> bool:
	return board.is_empty() or solve(board).size() == board.remaining_count()


## Plays `order` on a copy of the board. Result:
## {ok: bool, step: int (index of failing move or -1), error: String}
static func verify_solution(board: PuzzleBoard, order: Array) -> Dictionary:
	var b := board.duplicate_board()
	var seen := {}
	for i in order.size():
		var id := str(order[i])
		if seen.has(id):
			return {"ok": false, "step": i, "error": "arrow '%s' appears twice in solution" % id}
		seen[id] = true
		if not b.has_arrow(id):
			return {"ok": false, "step": i, "error": "unknown arrow '%s' in solution" % id}
		var blocker := b.find_blocker(id)
		if blocker != "":
			return {"ok": false, "step": i, "error": "arrow '%s' blocked by '%s'" % [id, blocker]}
		b.remove(id)
	if not b.is_empty():
		return {"ok": false, "step": order.size(), "error": "%d arrows remain after solution" % b.remaining_count()}
	return {"ok": true, "step": -1, "error": ""}


## Longest chain of "must clear first" dependencies (1 = every arrow is free
## at the start). 0 for an empty or unsolvable board.
static func dependency_depth(board: PuzzleBoard) -> int:
	var order := solve(board)
	if order.is_empty():
		return 0
	var g := dependency_graph(board)
	var depth := {}
	var best := 0
	for id in order:  # topological: blockers are processed before dependents
		var d := 1
		for b in g[id]:
			d = maxi(d, depth[b] + 1)
		depth[id] = d
		best = maxi(best, d)
	return best


## Exhaustively explores every state reachable by legal moves (breadth first).
## Result: {states: int, deadlocks: int, complete: bool, truncated: bool}
## `deadlocks` counts non-empty states with no legal move. Only use on small
## boards: the state space can be up to 2^n.
static func explore(board: PuzzleBoard, max_states: int = 20000) -> Dictionary:
	var start := board.duplicate_board()
	var seen := {start.state_key(): true}
	var queue: Array[PuzzleBoard] = [start]
	var deadlocks := 0
	var reached_empty := false
	var truncated := false
	while not queue.is_empty():
		var cur: PuzzleBoard = queue.pop_front()
		if cur.is_empty():
			reached_empty = true
			continue
		var moves := cur.removable_ids()
		if moves.is_empty():
			deadlocks += 1
			continue
		for id in moves:
			var nxt := cur.duplicate_board()
			nxt.remove(id)
			var key := nxt.state_key()
			if seen.has(key):
				continue
			if seen.size() >= max_states:
				truncated = true
				continue
			seen[key] = true
			queue.append(nxt)
	return {"states": seen.size(), "deadlocks": deadlocks, "complete": reached_empty, "truncated": truncated}
