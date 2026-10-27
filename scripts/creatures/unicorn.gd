extends QuadrupedRig
## Unicorn: a pale grey horse with a spiralled horn and long mane. Signature:
## rears on its hind legs, tosses its mane and lands.

const HORN := Color("#ECE7DA")
const MANE := Color("#8E959A")


func _init() -> void:
	COAT = Color("#C9CDD0")
	COAT_DARK = Color("#A2A8AD")
	COAT_LIGHT = Color("#E2E5E7")
	leg_len = 150.0
	leg_width = 20.0
	body_len = 210.0
	body_h = 88.0
	neck_end = Vector2(50, -110)
	neck_width = 30.0
	hip_x = -100.0
	base_width = 250.0


func build_head(head: Node2D) -> void:
	shape(head, PackedVector2Array([Vector2(-14, -24), Vector2(18, -34), Vector2(70, -4), Vector2(84, 16), Vector2(70, 30), Vector2(30, 22), Vector2(-10, 8)]), COAT)
	shape(head, PackedVector2Array([Vector2(0, -28), Vector2(6, -58), Vector2(16, -32)]), COAT)
	shape(head, PackedVector2Array([Vector2(10, -32), Vector2(44, -118), Vector2(22, -30)]), HORN, Color("#9C978A"), 1.5)
	for i in 5:
		var a := Vector2(14, -38).lerp(Vector2(40, -108), i / 5.0)
		stroke(head, PackedVector2Array([a + Vector2(-5, 2), a + Vector2(6, -6)]), Color("#9C978A"), 1.5)
	shape(head, ellipse(Vector2(28, -6), Vector2(6, 4), 12), INK, INK, 0.0)
	shape(head, ellipse(Vector2(78, 18), Vector2(4, 3), 8), Color("#7A8085"), Color("#7A8085"), 0.0)


func build_tail(tail: Node2D) -> void:
	for i in 5:
		var line := spline([Vector2(0, i * 3), Vector2(-30 - i * 4, 40), Vector2(-46 - i * 6, 110 + i * 6)])
		stroke(tail, line, MANE, 7.0)


func build_foot(leg: Node2D, at: Vector2, _color: Color) -> void:
	shape(leg, PackedVector2Array([at + Vector2(-10, -12), at + Vector2(10, -12), at + Vector2(13, 4), at + Vector2(-13, 4)]), Color("#5E6469"))


func extras(_root: Node2D, _body: Node2D, _head: Node2D) -> void:
	var neck: Node2D = parts.neck
	for i in 7:
		var p := Vector2.ZERO.lerp(neck_end, i / 7.0) + Vector2(-16, -6)
		stroke(neck, spline([p, p + Vector2(-24, 14), p + Vector2(-30, 34)]), MANE, 6.0)


func signature(t: Tween) -> void:
	rise(t)
	tween_pose(t, {"body": [-0.5, Vector2.ONE, Vector2(hip_x, -leg_len)], "fore": [1.0, Vector2(1, 0.75)],
		"fore_far": [0.9, Vector2(1, 0.75)], "neck": [-0.25, Vector2.ONE], "tail": [0.4, Vector2.ONE]}, 0.6, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween_pose(t, {"fore": [0.6, Vector2(1, 0.8)], "fore_far": [1.2, Vector2(1, 0.75)], "neck": [-0.1, Vector2.ONE]}, 0.35)
	t.tween_interval(0.3)
	tween_pose(t, standing(), 0.55, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_pose(t, {"neck": [0.18, Vector2.ONE], "head": [0.15, Vector2.ONE]}, 0.25)
	tween_pose(t, {"neck": [0.0, Vector2.ONE], "head": [0.0, Vector2.ONE]}, 0.35)
