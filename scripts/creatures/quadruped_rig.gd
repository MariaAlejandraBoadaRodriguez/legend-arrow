class_name QuadrupedRig
extends CreatureRig
## Shared anatomy for four-legged creatures (Antler Fox, Unicorn, Basilisk,
## Griffin). The body pivots at the hip so rearing and rising look natural.
## Subclasses set proportions/colours in _init() and draw head, tail, feet and
## extras. Origin at the feet, facing right.

var COAT := Color("#7D7770")
var COAT_DARK := Color("#5F5A54")
var COAT_LIGHT := Color("#B5AEA5")
var INK := Color("#25282B")
var EYE := Color("#E9ECEA")
var leg_len := 120.0
var leg_width := 26.0
var body_len := 200.0
var body_h := 80.0
var neck_end := Vector2(40, -90)
var neck_width := 26.0
var head_scale := 1.0
var base_width := 240.0
var hip_x := -90.0


func build() -> void:
	var root := Node2D.new()
	root.name = "Root"
	group.add_child(root)
	parts["root"] = root
	rock_base(root, base_width)
	var body := add_part("body", root, Vector2(hip_x, -leg_len), 0)
	var tail := add_part("tail", body, Vector2(-6, -body_h * 0.62), -1)
	build_tail(tail)
	_limb("hind_far", body, Vector2(16, -8), -2, COAT_DARK, -1.0)
	_limb("fore_far", body, Vector2(body_len - 26, -6), -2, COAT_DARK, 1.0)
	shape(body, ellipse(Vector2(body_len * 0.5, -body_h * 0.5), Vector2(body_len * 0.55, body_h * 0.5), 36), COAT)
	shape(body, ellipse(Vector2(body_len * 0.52, -body_h * 0.26), Vector2(body_len * 0.4, body_h * 0.2), 28), COAT_LIGHT, COAT_LIGHT, 0.0)
	_limb("hind", body, Vector2(0, -4), 1, COAT, -1.0)
	_limb("fore", body, Vector2(body_len - 12, -2), 1, COAT, 1.0)
	var neck := add_part("neck", body, Vector2(body_len * 0.92, -body_h * 0.72), 2)
	shape(neck, ribbon(spline([Vector2.ZERO, neck_end * 0.5 + Vector2(-6, 0), neck_end]), neck_width, neck_width * 0.7), COAT)
	var head := add_part("head", neck, neck_end, 3)
	head.scale = Vector2(head_scale, head_scale)
	build_head(head)
	extras(root, body, head)


## A leg hanging from `at`; `facing` bends knees forward (1) or back (-1).
func _limb(part_name: String, body: Node2D, at: Vector2, z: int, color: Color, facing: float) -> void:
	var leg := add_part(part_name, body, at, z)
	var l := leg_len
	var joints := [Vector2.ZERO, Vector2(6 * facing, l * 0.42), Vector2(-8 * facing, l * 0.74), Vector2(2 * facing, l)]
	shape(leg, ribbon(spline(joints, 6), leg_width * 0.5, leg_width * 0.32), color)
	build_foot(leg, Vector2(2 * facing, l), color)


func build_head(_head: Node2D) -> void:
	pass


func build_tail(_tail: Node2D) -> void:
	pass


func build_foot(leg: Node2D, at: Vector2, color: Color) -> void:
	shape(leg, PackedVector2Array([at + Vector2(-10, -8), at + Vector2(14, -8), at + Vector2(16, 4), at + Vector2(-12, 4)]), color.darkened(0.25))


func extras(_root: Node2D, _body: Node2D, _head: Node2D) -> void:
	pass


## Lying down: hips low, legs folded, head down.
func pose_dormant() -> void:
	apply_pose({
		"body": [0.0, Vector2.ONE, Vector2(hip_x, -leg_len * 0.45)],
		"hind": [-1.2, Vector2(1, 0.55)], "hind_far": [-1.1, Vector2(1, 0.55)],
		"fore": [1.2, Vector2(1, 0.55)], "fore_far": [1.1, Vector2(1, 0.55)],
		"neck": [0.6, Vector2.ONE], "head": [0.2, Vector2(head_scale, head_scale)], "tail": [0.3, Vector2.ONE],
	})


func pose_final() -> void:
	apply_pose(standing())


func standing() -> Dictionary:
	return {
		"body": [0.0, Vector2.ONE, Vector2(hip_x, -leg_len)],
		"hind": [0.0, Vector2.ONE], "hind_far": [0.0, Vector2.ONE],
		"fore": [0.0, Vector2.ONE], "fore_far": [0.0, Vector2.ONE],
		"neck": [0.0, Vector2.ONE], "head": [0.0, Vector2(head_scale, head_scale)], "tail": [0.0, Vector2.ONE],
	}


## Gets up from the dormant pose (shared first beat of most signatures).
func rise(t: Tween, seconds := 0.8) -> void:
	tween_pose(t, standing(), seconds, Tween.TRANS_BACK, Tween.EASE_OUT)


func idle_tweens() -> Array[Tween]:
	var out: Array[Tween] = []
	var breathe := create_tween().set_loops()
	breathe.tween_property(parts.body, "scale", Vector2(1.0, 1.02), 1.5).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(parts.body, "scale", Vector2.ONE, 1.5).set_trans(Tween.TRANS_SINE)
	out.append(breathe)
	var sway := create_tween().set_loops()
	sway.tween_property(parts.tail, "rotation", 0.08, 2.0).set_trans(Tween.TRANS_SINE)
	sway.tween_property(parts.tail, "rotation", -0.04, 2.0).set_trans(Tween.TRANS_SINE)
	out.append(sway)
	var look := create_tween().set_loops()
	look.tween_interval(2.6)
	look.tween_property(parts.head, "rotation", -0.08, 0.7).set_trans(Tween.TRANS_SINE)
	look.tween_interval(1.4)
	look.tween_property(parts.head, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	out.append(look)
	return out
