class_name AwakeningBackdrop
extends Control
## The only landscape in the game (spec §8): pale layered ridges and mist.
## During the first 1.2 s faint arrow trails converge on the creature.

const TRAILS := 12
const GATHER := 1.2

var reduce_motion := false
var _t := 99.0
var _trails: Array = []   # [start, end]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play() -> void:
	_t = 0.0 if not reduce_motion else 99.0
	_trails.clear()
	var rng := DeterministicRng.new(7)
	for i in TRAILS:
		var a := TAU * i / TRAILS + rng.range_int(0, 40) / 100.0
		_trails.append(Vector2(cos(a), sin(a)))
	set_process(true)


func finish() -> void:
	_t = 99.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t > GATHER + 0.5:
		set_process(false)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BACKGROUND)
	# Sky wash
	for i in 6:
		var y := h * (0.1 + 0.08 * i)
		draw_rect(Rect2(0, y, w, h * 0.08), Color("#EEF0F0").lerp(Palette.BACKGROUND, i / 6.0))
	_ridge(h * 0.46, 0.20, Color("#DCE1E3"), 3)
	_ridge(h * 0.55, 0.14, Color("#CED5D9"), 11)
	_ridge(h * 0.66, 0.10, Color("#C0C8CD"), 23)
	# Mist rises from the valley and fades back to ivory behind the text.
	var bands := 40
	for i in bands:
		var k := float(i) / bands
		draw_rect(Rect2(0, h * (0.58 + 0.42 * k), w, h * 0.42 / bands + 1.0), Color(Palette.BACKGROUND, clampf(k * 1.6, 0.0, 1.0)))
	if _t < GATHER + 0.5:
		var center := Vector2(w * 0.5, h * 0.42)
		var k := clampf(_t / GATHER, 0.0, 1.0)
		var fade := 1.0 - clampf((_t - GATHER) / 0.5, 0.0, 1.0)
		for d in _trails:
			var far: Vector2 = center + d * w * 0.9
			var head := far.lerp(center, k * k)
			var tail := far.lerp(center, maxf(0.0, k * k - 0.18))
			draw_line(tail, head, Color(Palette.ACCENT, 0.55 * fade), 4.0, true)
			var n: Vector2 = (head - tail).normalized()
			if n != Vector2.ZERO:
				var side := Vector2(-n.y, n.x) * 9.0
				draw_colored_polygon(PackedVector2Array([head + n * 14.0, head + side, head - side]), Color(Palette.ACCENT, 0.55 * fade))


func _ridge(base_y: float, amp: float, color: Color, seed_value: int) -> void:
	var rng := DeterministicRng.new(seed_value)
	var pts := PackedVector2Array([Vector2(0, size.y)])
	var steps := 9
	for i in steps + 1:
		var x := size.x * i / steps
		var peak := rng.range_int(20, 100) / 100.0
		pts.append(Vector2(x, base_y - size.y * amp * peak))
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, color)
