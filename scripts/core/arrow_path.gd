class_name ArrowPath
extends RefCounted
## One arrow: an ordered orthogonal path of grid cells. The final cell is the
## arrowhead and the final segment defines the exit direction.
## Coordinates are Vector2i(x, y) with y growing downwards.

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

var id: String = ""
var cells: Array[Vector2i] = []


func _init(p_id: String = "", p_cells: Array = []) -> void:
	id = p_id
	for c in p_cells:
		cells.append(c)


func head() -> Vector2i:
	return cells[cells.size() - 1]


## Unit vector of the final segment. Only meaningful for validated paths.
func direction() -> Vector2i:
	return head() - cells[cells.size() - 2]


func length() -> int:
	return cells.size()


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


func to_dict() -> Dictionary:
	var out: Array = []
	for c in cells:
		out.append([c.x, c.y])
	return {"id": id, "cells": out}


## Builds an arrow from a dictionary shaped like to_dict(). JSON numbers arrive
## as floats; they are converted to ints. Call LevelValidator first for
## untrusted input: this does not validate geometry.
static func from_dict(d: Dictionary) -> ArrowPath:
	var pts: Array = []
	for pair in d.get("cells", []):
		pts.append(Vector2i(int(pair[0]), int(pair[1])))
	return ArrowPath.new(str(d.get("id", "")), pts)


static func direction_name(dir: Vector2i) -> String:
	match dir:
		UP:
			return "up"
		DOWN:
			return "down"
		LEFT:
			return "left"
		RIGHT:
			return "right"
	return "invalid"
