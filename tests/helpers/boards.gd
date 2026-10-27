class_name TestBoards
extends RefCounted
## Builders shared by tests. Paths are listed tail first, head last.


## make(5, 5, {"a": [[0, 0], [1, 0]], ...}) -> PuzzleBoard (asserts nothing)
static func make(w: int, h: int, arrows: Dictionary) -> PuzzleBoard:
	var b := PuzzleBoard.new(w, h)
	for id in arrows:
		b.add_arrow(ArrowPath.from_dict({"id": id, "cells": arrows[id]}))
	return b


## Level dictionary in the packaged JSON shape.
static func level(id: String, w: int, h: int, arrows: Dictionary, solution: Array, difficulty := "tutorial") -> Dictionary:
	var list: Array = []
	for a in arrows:
		list.append({"id": a, "cells": arrows[a]})
	return {
		"schema_version": 1,
		"id": id,
		"creature_id": "forest_drake",
		"difficulty": difficulty,
		"width": w,
		"height": h,
		"arrows": list,
		"solution": solution,
	}


## Round-trips a level through JSON text, like a packaged file would.
static func via_json(level_dict: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(level_dict))
