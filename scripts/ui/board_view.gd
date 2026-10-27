class_name BoardView
extends Control
## Draws a PuzzleSession's board and turns pointer/keyboard input into arrow
## taps. It never changes the model: it emits `arrow_tapped` and the owner
## calls session.tap() and then play_exit()/play_blocked().
##
## Input rules (spec §13): single-finger tap only; a press that moves more than
## DRAG_THRESHOLD, lasts longer than LONG_PRESS, is cancelled, or overlaps a
## second finger never taps. Hits resolve to the nearest arrow path within
## HIT_RADIUS cells, measured in board coordinates.

signal arrow_tapped(id: String)
signal exit_finished(id: String)

const DRAG_THRESHOLD := 24.0     # px in viewport space
const LONG_PRESS := 0.8          # seconds
const HIT_RADIUS := 0.6          # in cells
const MAX_CELL := 120.0
const LINE_WIDTH := 0.13         # in cells
const HEAD_LEN := 0.42
const HEAD_HALF_W := 0.27

var session: PuzzleSession
var reduce_motion := false
## Seconds clock used for long-press detection (tests inject a fake one).
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var input_enabled := true

var _cell := 64.0
var _origin := Vector2.ZERO
var _leaving := {}        # id -> {t: float, cells, dir}
var _pulse := {}          # id -> t (blocked feedback)
var _arrival := {}        # id -> t (undo fade-in)
var _hint_id := ""
var _hint_t := 0.0
var _focus_id := ""
var _touches := {}        # index -> {pos, time}
var _multi := false
var _press_index := -1


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func bind(p_session: PuzzleSession) -> void:
	session = p_session
	_leaving.clear()
	_pulse.clear()
	_arrival.clear()
	_hint_id = ""
	_focus_id = ""
	_layout()
	queue_redraw()


func is_animating() -> bool:
	return not _leaving.is_empty()


# --- geometry ---------------------------------------------------------------

func cell_size() -> float:
	return _cell


func _layout() -> void:
	if session == null:
		return
	var b := session.board
	# Leave one cell of room around the grid for arrowheads and exits.
	var cw := size.x / float(b.width + 1)
	var ch := size.y / float(b.height + 1)
	_cell = minf(minf(cw, ch), MAX_CELL)
	var grid := Vector2(b.width, b.height) * _cell
	_origin = (size - grid) / 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()


## Centre of a cell in local coordinates.
func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


## Local point -> continuous board coordinates (cells).
func to_board(local: Vector2) -> Vector2:
	return (local - _origin) / _cell - Vector2(0.5, 0.5)


## Nearest arrow path within HIT_RADIUS cells of a local point, or "".
func arrow_at(local: Vector2) -> String:
	if session == null:
		return ""
	var p := to_board(local)
	var best := ""
	var best_d := HIT_RADIUS
	for id in session.board.remaining_ids():
		if _leaving.has(id):
			continue
		var cells := session.board.arrow(id).cells
		var pts: Array[Vector2] = []
		for c in cells:
			pts.append(Vector2(c))
		pts.append(Vector2(cells[cells.size() - 1]) + Vector2(session.board.arrow(id).direction()) * HEAD_LEN)
		for i in pts.size() - 1:
			var d := _seg_dist(p, pts[i], pts[i + 1])
			if d < best_d:  # strict: equal distances keep the earlier arrow
				best_d = d
				best = id
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() == 0.0 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
		accept_event()
	elif event is InputEventScreenDrag:
		if _touches.has(event.index) and event.position.distance_to(_touches[event.index].pos) > DRAG_THRESHOLD:
			_touches[event.index].dragged = true
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if _focus_id != "":
			_request_tap(_focus_id)
		accept_event()
	else:
		for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			if event.is_action_pressed(action):
				move_focus(action)
				accept_event()
				return


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.canceled:
		_touches.clear()
		_multi = false
		return
	if e.pressed:
		if not _touches.is_empty():
			_multi = true
		_touches[e.index] = {"pos": e.position, "time": clock.call(), "dragged": false}
		return
	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	_touches.erase(e.index)
	var was_multi := _multi
	if _touches.is_empty():
		_multi = false
	if was_multi or t.dragged:
		return
	if e.position.distance_to(t.pos) > DRAG_THRESHOLD:
		return
	if clock.call() - t.time > LONG_PRESS:
		return
	var id := arrow_at(e.position)
	if id != "":
		_request_tap(id)


func _request_tap(id: String) -> void:
	if not input_enabled or is_animating() or session == null:
		return
	arrow_tapped.emit(id)


## Keyboard/controller: moves focus to the nearest arrow head in a direction.
func move_focus(action: String) -> void:
	if session == null or session.board.is_empty():
		return
	var ids := session.board.remaining_ids()
	if _focus_id == "" or not session.board.has_arrow(_focus_id):
		_focus_id = ids[0]
		queue_redraw()
		return
	var dir: Vector2 = {"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT, "ui_up": Vector2.UP, "ui_down": Vector2.DOWN}[action]
	var from := _arrow_mid(_focus_id)
	var best := ""
	var best_score := INF
	for id in ids:
		if id == _focus_id:
			continue
		var delta := _arrow_mid(id) - from
		var along := delta.dot(dir)
		if along <= 0.01:
			continue
		var score := along + 2.0 * absf(delta.cross(dir))
		if score < best_score:
			best_score = score
			best = id
	if best != "":
		_focus_id = best
		queue_redraw()


func focused_id() -> String:
	return _focus_id


func _arrow_mid(id: String) -> Vector2:
	var sum := Vector2.ZERO
	var cells := session.board.arrow(id).cells
	for c in cells:
		sum += Vector2(c)
	return sum / cells.size()


# --- feedback animations ----------------------------------------------------

## Call after session.tap() removed `id`.
func play_exit(id: String) -> void:
	var a := session.board.arrow(id)
	var dur := clampf(0.2 + 0.02 * _exit_distance(a), 0.2, 0.4) if not reduce_motion else 0.12
	_leaving[id] = {"t": 0.0, "dur": dur, "cells": a.cells.duplicate(), "dir": Vector2(a.direction()), "dist": float(_exit_distance(a))}
	if _hint_id == id:
		_hint_id = ""
	if _focus_id == id:
		_focus_id = ""
	set_process(true)


func _exit_distance(a: ArrowPath) -> int:
	var dir := a.direction()
	var far := 0
	for c in a.cells:
		match dir:
			ArrowPath.RIGHT:
				far = maxi(far, session.board.width - c.x)
			ArrowPath.LEFT:
				far = maxi(far, c.x + 1)
			ArrowPath.DOWN:
				far = maxi(far, session.board.height - c.y)
			ArrowPath.UP:
				far = maxi(far, c.y + 1)
	return far + 1


func play_blocked(id: String) -> void:
	_pulse[id] = 0.0
	set_process(true)


func play_restored(id: String) -> void:
	_arrival[id] = 0.0
	set_process(true)


func show_hint(id: String) -> void:
	_hint_id = id
	_hint_t = 0.0
	set_process(true)


func hint_id() -> String:
	return _hint_id


## Finishes every running animation immediately (background, skip, tests).
func finish_animations() -> void:
	var done := _leaving.keys()
	_leaving.clear()
	_pulse.clear()
	_arrival.clear()
	queue_redraw()
	for id in done:
		exit_finished.emit(id)


func _process(delta: float) -> void:
	var finished: Array = []
	for id in _leaving:
		_leaving[id].t += delta
		if _leaving[id].t >= _leaving[id].dur:
			finished.append(id)
	for id in finished:
		_leaving.erase(id)
	for id in _pulse.keys():
		_pulse[id] += delta
		if _pulse[id] > 0.15:
			_pulse.erase(id)
	for id in _arrival.keys():
		_arrival[id] += delta
		if _arrival[id] > 0.2:
			_arrival.erase(id)
	if _hint_id != "":
		_hint_t += delta
	queue_redraw()
	if _leaving.is_empty() and _pulse.is_empty() and _arrival.is_empty() and _hint_id == "":
		set_process(false)
	for id in finished:
		exit_finished.emit(id)


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if session == null:
		return
	var b := session.board
	var dot_r := maxf(1.5, _cell * 0.035)
	for y in b.height:
		for x in b.width:
			draw_circle(cell_center(Vector2i(x, y)), dot_r, Palette.GRID)
	for id in b.remaining_ids():
		var color := Palette.INK
		var offset := Vector2.ZERO
		var alpha := 1.0
		var width := _cell * LINE_WIDTH
		var a := b.arrow(id)
		if _pulse.has(id):
			color = Palette.ERROR
			if not reduce_motion:
				var k := sin(_pulse[id] / 0.15 * PI)
				offset = Vector2(a.direction()) * _cell * 0.12 * k
		elif id == _hint_id:
			color = Palette.ACCENT
			if not reduce_motion:
				width *= 1.0 + 0.25 * (0.5 + 0.5 * sin(_hint_t * TAU / 1.2))
		if _arrival.has(id):
			alpha = clampf(_arrival[id] / 0.2, 0.0, 1.0)
		_draw_arrow(a.cells, Vector2(a.direction()), offset, Color(color, alpha), width)
		if id == _focus_id:
			_draw_focus(a.cells)
	for id in _leaving:
		var l: Dictionary = _leaving[id]
		var k: float = clampf(l.t / l.dur, 0.0, 1.0)
		var eased := k * k * (3.0 - 2.0 * k)
		var alpha := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
		var off: Vector2 = Vector2.ZERO if reduce_motion else l.dir * l.dist * _cell * eased
		if reduce_motion:
			alpha = 1.0 - k
		_draw_arrow(l.cells, l.dir, off, Color(Palette.ACCENT, alpha), _cell * LINE_WIDTH)


func _draw_arrow(cells: Array, dir: Vector2, offset: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(cell_center(c) + offset)
	var head := pts[pts.size() - 1]
	var tip := head + dir * _cell * HEAD_LEN
	var base := head + dir * _cell * (HEAD_LEN - 0.38)
	pts[pts.size() - 1] = base
	draw_polyline(pts, color, width, true)
	for i in range(0, pts.size() - 1):
		draw_circle(pts[i], width * 0.5, color)
	var n := Vector2(-dir.y, dir.x) * _cell * HEAD_HALF_W
	draw_colored_polygon(PackedVector2Array([tip, base + n, base - n]), color)


func _draw_focus(cells: Array) -> void:
	var r := Rect2(cell_center(cells[0]), Vector2.ZERO)
	for c in cells:
		r = r.expand(cell_center(c))
	r = r.grow(_cell * 0.45)
	draw_rect(r, Palette.FOCUS, false, maxf(3.0, _cell * 0.05))
