class_name StarRow
extends Control
## Three drawn stars (no font glyph needed): `earned` filled in the accent
## colour, the rest outlined. reveal() makes them appear one by one; with
## reduced motion they simply fade in together (v0.2 §3).

const COUNT := 3

var earned := 0
var star_size := 48.0
var _alpha: Array[float] = [1.0, 1.0, 1.0]
var _scale: Array[float] = [1.0, 1.0, 1.0]
var revealed := true


func _init(p_earned: int = 0, p_size: float = 48.0) -> void:
	earned = clampi(p_earned, 0, COUNT)
	star_size = p_size
	custom_minimum_size = Vector2(star_size * COUNT + star_size * 0.35 * (COUNT - 1), star_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Plays the reveal. Returns the tween (null when nothing animates).
func reveal(reduce_motion: bool) -> Tween:
	revealed = false
	for i in COUNT:
		_alpha[i] = 0.0
		_scale[i] = 1.0 if reduce_motion else 0.4
	queue_redraw()
	var t := create_tween()
	if reduce_motion:
		t.tween_method(_set_all_alpha, 0.0, 1.0, 0.35)
	else:
		for i in COUNT:
			t.tween_method(_set_star.bind(i), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.12)
	t.finished.connect(func(): revealed = true)
	return t


func finish_reveal() -> void:
	for i in COUNT:
		_alpha[i] = 1.0
		_scale[i] = 1.0
	revealed = true
	queue_redraw()


func _set_all_alpha(a: float) -> void:
	for i in COUNT:
		_alpha[i] = a
	queue_redraw()


func _set_star(v: float, i: int) -> void:
	_alpha[i] = clampf(v, 0.0, 1.0)
	_scale[i] = lerpf(0.4, 1.0, v)
	queue_redraw()


func _draw() -> void:
	var gap := star_size * 0.35
	var total := star_size * COUNT + gap * (COUNT - 1)
	var x0 := (size.x - total) * 0.5
	for i in COUNT:
		var c := Vector2(x0 + star_size * 0.5 + i * (star_size + gap), size.y * 0.5)
		var pts := _star_points(c, star_size * 0.5 * _scale[i])
		if i < earned:
			var col := Palette.ACCENT
			col.a = _alpha[i]
			draw_colored_polygon(pts, col)
		else:
			var col2 := Palette.GRID
			col2.a = _alpha[i]
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, col2, maxf(2.0, star_size * 0.07), true)


static func _star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
