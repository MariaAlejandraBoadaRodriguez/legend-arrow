extends QuadrupedRig
## Basilisk: a low grey-green lizard-serpent with a crowned crest. Signature:
## rises on its forelegs, raises its crest and turns its gaze (spec §9).

var _eye: Polygon2D


func _init() -> void:
	COAT = Color("#5F665C")
	COAT_DARK = Color("#474D45")
	COAT_LIGHT = Color("#8C9488")
	leg_len = 55.0
	leg_width = 22.0
	body_len = 260.0
	body_h = 58.0
	neck_end = Vector2(40, -22)
	neck_width = 26.0
	hip_x = -120.0
	base_width = 280.0


func build_head(head: Node2D) -> void:
	var crest := add_part("crest", head, Vector2(4, -20), -1)
	for i in 5:
		var a := -0.9 + i * 0.32
		var tip := Vector2(cos(a - PI / 2), sin(a - PI / 2)) * 58
		shape(crest, PackedVector2Array([Vector2(-6, 0), tip, Vector2(6, 0)]), COAT_DARK, INK, 2.0)
	shape(head, PackedVector2Array([Vector2(-10, -24), Vector2(40, -30), Vector2(86, -10), Vector2(90, 6), Vector2(50, 20), Vector2(-10, 16)]), COAT)
	_eye = shape(head, ellipse(Vector2(40, -12), Vector2(8, 4), 12), Color("#BFC4B4"), INK, 1.5)
	stroke(head, PackedVector2Array([Vector2(40, -16), Vector2(40, -8)]), INK, 2.0)
	stroke(head, PackedVector2Array([Vector2(52, 8), Vector2(88, 4)]), COAT_DARK, 2.0)


func build_tail(tail: Node2D) -> void:
	var line := spline([Vector2.ZERO, Vector2(-80, 24), Vector2(-170, 50), Vector2(-250, 46)])
	shape(tail, ribbon(line, 26, 4), COAT)


func build_foot(leg: Node2D, at: Vector2, color: Color) -> void:
	for k in 3:
		stroke(leg, PackedVector2Array([at, at + Vector2(-8 + k * 10, 8)]), color.darkened(0.3), 4.0)


func extras(_root: Node2D, body: Node2D, _head: Node2D) -> void:
	for i in 8:
		var x := 20.0 + i * 28.0
		shape(body, PackedVector2Array([Vector2(x - 9, -body_h + 6), Vector2(x, -body_h - 18), Vector2(x + 9, -body_h + 6)]), COAT_DARK, INK, 1.5)


func pose_final() -> void:
	super()
	parts.crest.scale = Vector2.ONE


func signature(t: Tween) -> void:
	rise(t)
	tween_pose(t, {"body": [-0.18, Vector2.ONE, Vector2(hip_x, -leg_len)], "neck": [-0.35, Vector2.ONE], "crest": [0.0, Vector2(1.35, 1.35)]}, 0.6, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween_pose(t, {"head": [-0.25, Vector2(0.86, 1.0)]}, 0.5)
	t.tween_property(_eye, "color", Color("#EDE6C8"), 0.3)
	t.tween_interval(0.4)
	t.tween_property(_eye, "color", Color("#BFC4B4"), 0.4)
	tween_pose(t, {"body": [0.0, Vector2.ONE, Vector2(hip_x, -leg_len)], "neck": [0.0, Vector2.ONE], "head": [0.0, Vector2.ONE], "crest": [0.0, Vector2.ONE]}, 0.6)
