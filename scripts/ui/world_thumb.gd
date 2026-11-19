class_name WorldThumb
extends Control
## Restrained atmosphere thumbnail for a world (v0.2 §2): a soft sky gradient
## in the world's tint and two layers of distant ridges. Drawn, no assets.
## Locked worlds are drawn desaturated.

var world_id := ""
var locked := false


func _init(p_world := "", p_locked := false) -> void:
	world_id = p_world
	locked = p_locked
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 120)


func _draw() -> void:
	var tint: Color = SilhouetteRig.WORLD_TINT.get(world_id, Palette.ACCENT)
	if locked:
		var g := tint.get_luminance()
		tint = Color(g, g, g).lerp(Palette.GRID, 0.4)
	var top := tint.lerp(Palette.BACKGROUND, 0.82)
	var bottom := tint.lerp(Palette.BACKGROUND, 0.45)
	var n := 24
	for i in n:
		var y0 := size.y * i / n
		draw_rect(Rect2(0, y0, size.x, size.y / n + 1), top.lerp(bottom, float(i) / (n - 1)))
	var seed_v := world_id.hash()
	for layer in 2:
		var col := tint.lerp(Palette.INK, 0.15 + 0.25 * layer)
		col.a = 0.35 + 0.3 * layer
		var pts := PackedVector2Array([Vector2(0, size.y)])
		var base := size.y * (0.55 + 0.18 * layer)
		for k in 9:
			var x := size.x * k / 8.0
			var h := sin(k * 1.7 + (seed_v % 97) * 0.13 + layer * 2.1) * 0.5 + 0.5
			pts.append(Vector2(x, base - h * size.y * (0.18 - 0.06 * layer)))
		pts.append(Vector2(size.x, size.y))
		draw_colored_polygon(pts, col)
