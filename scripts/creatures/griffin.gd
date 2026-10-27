extends QuadrupedRig
## Griffin: tawny-grey lion body, pale eagle head and great feathered wings.
## Signature: rears and spreads its wings wide, then folds them.

const HEAD_FEATHER := Color("#D6D4CE")
const BEAK := Color("#8C8678")
const WING := Color("#7A7266")
const FOLDED := 2.2
const SPREAD := 2.95


func _init() -> void:
	COAT = Color("#8B8275")
	COAT_DARK = Color("#6C6458")
	COAT_LIGHT = Color("#B8AFA1")
	leg_len = 120.0
	leg_width = 26.0
	body_len = 210.0
	body_h = 85.0
	neck_end = Vector2(36, -80)
	neck_width = 34.0
	hip_x = -100.0
	base_width = 250.0


func build_head(head: Node2D) -> void:
	shape(head, ellipse(Vector2(-10, 18), Vector2(40, 30), 24), HEAD_FEATHER, INK, 2.0)  # ruff
	shape(head, ellipse(Vector2(0, -10), Vector2(34, 30), 24), HEAD_FEATHER)
	shape(head, PackedVector2Array([Vector2(26, -16), Vector2(62, -4), Vector2(58, 14), Vector2(42, 6), Vector2(26, 6)]), BEAK)
	shape(head, ellipse(Vector2(14, -16), Vector2(6, 5), 12), Color("#E6D9B0"), INK, 1.5)
	stroke(head, PackedVector2Array([Vector2(4, -24), Vector2(22, -22)]), INK, 3.0)


func build_tail(tail: Node2D) -> void:
	shape(tail, ribbon(spline([Vector2.ZERO, Vector2(-50, 40), Vector2(-70, 100)]), 8, 5), COAT)
	shape(tail, ellipse(Vector2(-72, 106), Vector2(12, 16), 14), COAT_DARK)


func build_foot(leg: Node2D, at: Vector2, color: Color) -> void:
	if leg.name.begins_with("fore"):
		for k in 3:
			stroke(leg, PackedVector2Array([at + Vector2(-4, -4), at + Vector2(-10 + k * 10, 8)]), BEAK.darkened(0.3), 4.0)
	else:
		super(leg, at, color)


func extras(_root: Node2D, body: Node2D, _head: Node2D) -> void:
	var at := Vector2(body_len * 0.72, -body_h * 0.92)
	var back := add_part("wing_back", body, at + Vector2(-14, -4), -3)
	feather_wing(back, 250, 130, WING.darkened(0.15), INK)
	var front := add_part("wing", body, at, 4)
	feather_wing(front, 270, 140, WING, INK)


func standing() -> Dictionary:
	var s := super()
	s["wing"] = [FOLDED, Vector2.ONE]
	s["wing_back"] = [FOLDED + 0.15, Vector2.ONE]
	return s


func pose_dormant() -> void:
	super()
	apply_pose({"wing": [1.75, Vector2(0.9, 0.8)], "wing_back": [1.85, Vector2(0.9, 0.8)]})


func signature(t: Tween) -> void:
	rise(t)
	tween_pose(t, {"body": [-0.35, Vector2.ONE, Vector2(hip_x, -leg_len)], "fore": [0.8, Vector2(1, 0.8)], "fore_far": [0.6, Vector2(1, 0.8)],
		"wing": [SPREAD, Vector2(1.1, 1.1)], "wing_back": [SPREAD + 0.2, Vector2(1.1, 1.1)], "neck": [-0.2, Vector2.ONE]}, 0.8, Tween.TRANS_BACK, Tween.EASE_OUT)
	t.tween_interval(0.5)
	tween_pose(t, standing(), 0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
