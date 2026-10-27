class_name DrakeRig
extends CreatureRig
## Shared anatomy for winged drakes (Forest Drake, Arctic Drake, Wyvern,
## Ancient Dragon). Subclasses set colours and flags in _init() and may
## override extras() and signature(). Local space: origin at the feet, facing
## right, roughly 640 x 600 units.

var SKIN := Color("#4F575D")
var SKIN_DARK := Color("#3C4348")
var SKIN_LIGHT := Color("#69737A")
var MEMBRANE := Color("#7E878D")
var MEMBRANE_DARK := Color("#5F686E")
var BONE := Color("#2B3034")
var ROCK := Color("#C9CDCF")
var ROCK_SHADE := Color("#AEB4B8")
var EYE := Color("#E9ECEA")
## Anatomy switches.
var fore_legs := true        # false: wyvern (wings are the arms)
var extra_horns := 0         # crown of extra horns (ancient dragon)
var wing_scale := 1.0
var tail_spade := true


func build() -> void:
	var root := Node2D.new()
	root.name = "Root"
	group.add_child(root)
	parts["root"] = root

	# Rock base
	shape(root, PackedVector2Array([Vector2(-230, 10), Vector2(-170, -22), Vector2(-60, -30), Vector2(40, -24), Vector2(150, -30), Vector2(240, 4), Vector2(260, 40), Vector2(-250, 40)]), ROCK, ROCK_SHADE, 2.0)
	stroke(root, PackedVector2Array([Vector2(-120, 0), Vector2(-60, 12), Vector2(10, 4)]), ROCK_SHADE, 2.0)

	var body := add_part("body", root, Vector2(0, -128), 0)

	# Back wing (behind everything on the body).
	var wing_back := add_part("wing_back", body, Vector2(30, -50), -3)
	_wing(wing_back, MEMBRANE_DARK, SKIN_DARK, 0.86 * wing_scale)

	# Tail
	var tail := add_part("tail", body, Vector2(-70, 10), -1)
	var tail_line := spline([Vector2(0, 0), Vector2(-70, 30), Vector2(-150, 95), Vector2(-215, 130), Vector2(-270, 120), Vector2(-300, 90)])
	shape(tail, ribbon(tail_line, 26, 4), SKIN)
	if tail_spade:
		shape(tail, PackedVector2Array([Vector2(-300, 90), Vector2(-332, 70), Vector2(-312, 108), Vector2(-292, 98)]), SKIN_DARK)
	for i in range(2, tail_line.size() - 6, 4):
		var p := tail_line[i]
		stroke(tail, PackedVector2Array([p + Vector2(-4, -12), p + Vector2(2, -26)]), SKIN_DARK, 3.0)

	# Hind and fore legs on the far side (darker).
	var hind_far := add_part("hind_far", body, Vector2(-40, 20), -2)
	_leg(hind_far, SKIN_DARK, [Vector2(0, 0), Vector2(-30, 50), Vector2(2, 86), Vector2(-12, 124)], 34)
	if fore_legs:
		var fore_far := add_part("fore_far", body, Vector2(60, 10), -2)
		_leg(fore_far, SKIN_DARK, [Vector2(0, 0), Vector2(14, 52), Vector2(-2, 92), Vector2(12, 128)], 26)

	# Torso
	var torso_line := spline([Vector2(-90, 10), Vector2(-20, -8), Vector2(50, -24), Vector2(95, -48)])
	shape(body, ribbon(torso_line, 54, 40), SKIN)
	shape(body, ribbon(spline([Vector2(-70, 40), Vector2(0, 32), Vector2(74, 4)]), 12, 9), SKIN_LIGHT, SKIN_LIGHT, 0.0)
	for i in range(2, torso_line.size() - 2, 3):
		var p := torso_line[i]
		stroke(body, PackedVector2Array([p + Vector2(-6, -50), p + Vector2(0, -66)]), SKIN_DARK, 4.0)

	# Near legs
	var hind := add_part("hind", body, Vector2(-60, 14), 1)
	_leg(hind, SKIN, [Vector2(0, 0), Vector2(-38, 48), Vector2(-4, 86), Vector2(-20, 126)], 42)
	if fore_legs:
		var fore := add_part("fore", body, Vector2(78, 0), 1)
		_leg(fore, SKIN, [Vector2(0, 0), Vector2(22, 54), Vector2(4, 94), Vector2(18, 130)], 30)

	# Neck and head
	var neck := add_part("neck", body, Vector2(92, -46), 2)
	var neck_line := spline([Vector2(0, 0), Vector2(30, -50), Vector2(38, -110), Vector2(64, -160)])
	shape(neck, ribbon(neck_line, 32, 20), SKIN)
	for i in range(2, neck_line.size() - 2, 3):
		var p := neck_line[i]
		stroke(neck, PackedVector2Array([p + Vector2(-22, 0), p + Vector2(-34, -6)]), SKIN_DARK, 3.0)
	var head := add_part("head", neck, Vector2(64, -160), 3)
	head.scale = Vector2(1.25, 1.25)
	shape(head, PackedVector2Array([Vector2(-4, -26), Vector2(-62, -58), Vector2(-40, -30), Vector2(-10, -12)]), BONE, BONE, 2.0)  # horn
	shape(head, PackedVector2Array([Vector2(8, -28), Vector2(-34, -66), Vector2(-18, -32)]), SKIN_DARK, BONE, 2.0)  # far horn
	shape(head, PackedVector2Array([Vector2(-14, -18), Vector2(14, -30), Vector2(48, -28), Vector2(92, -12), Vector2(98, -2), Vector2(70, 4)]), SKIN)
	var jaw := add_part("jaw", head, Vector2(0, 0), -1)
	shape(jaw, PackedVector2Array([Vector2(-14, -2), Vector2(66, 4), Vector2(86, 8), Vector2(60, 20), Vector2(20, 22), Vector2(-16, 12)]), SKIN_DARK)
	for i in extra_horns:
		var bx := -20.0 + i * 14.0
		shape(head, PackedVector2Array([Vector2(bx, -24), Vector2(bx - 30 - i * 6, -70 - i * 4), Vector2(bx + 8, -28)]), BONE, BONE, 1.5)
	shape(head, ellipse(Vector2(36, -16), Vector2(6, 4), 12), EYE, BONE, 1.5)
	stroke(head, PackedVector2Array([Vector2(26, -26), Vector2(50, -24)]), BONE, 3.0)

	# Near wing (in front of the body).
	var wing := add_part("wing", body, Vector2(10, -40), 4)
	_wing(wing, MEMBRANE, SKIN, wing_scale)
	extras(root, body, head)


## Hook for creature-specific details (frost, spines, crest...).
func extras(_root: Node2D, _body: Node2D, _head: Node2D) -> void:
	pass


func _leg(part: Node2D, color: Color, joints: Array, width: float) -> void:
	shape(part, ribbon(spline(joints, 6), width * 0.5, width * 0.32), color)
	var foot: Vector2 = joints[joints.size() - 1]
	shape(part, PackedVector2Array([foot + Vector2(-10, -8), foot + Vector2(28, -6), foot + Vector2(34, 4), foot + Vector2(-12, 4)]), color)


func _wing(part: Node2D, membrane: Color, arm: Color, scale_k: float) -> void:
	var wrist := Vector2(-20, -230) * scale_k
	var tips := [Vector2(-200, -250), Vector2(-270, -160), Vector2(-260, -70), Vector2(-180, 0)]
	var notches := [Vector2(-160, -196), Vector2(-206, -116), Vector2(-196, -40)]
	var edge: Array = [wrist]
	for i in tips.size():
		edge.append(tips[i] * scale_k)
		if i < notches.size():
			edge.append(notches[i] * scale_k)
	edge.append(Vector2(-60, 20) * scale_k)
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(-30, -110) * scale_k])
	pts.append_array(spline(edge, 5))
	shape(part, pts, Color(membrane, 0.95), Color("#25282B"), 2.5)
	stroke(part, PackedVector2Array([Vector2.ZERO, Vector2(-30, -110) * scale_k, wrist]), arm, 12.0 * scale_k)
	for tip in tips:
		stroke(part, PackedVector2Array([wrist, tip * scale_k]), BONE, 4.0 * scale_k)


# --- poses and motion -------------------------------------------------------

func pose_dormant() -> void:
	_set_pose({
		"wing": [-0.95, Vector2(0.55, 0.45)], "wing_back": [-0.85, Vector2(0.5, 0.4)],
		"neck": [0.35, Vector2.ONE], "head": [0.25, Vector2(1.25, 1.25)], "jaw": [0.0, Vector2.ONE],
		"tail": [0.12, Vector2.ONE],
	})
	parts.body.position = Vector2(0, -108)


func pose_final() -> void:
	_set_pose({
		"wing": [0.0, Vector2.ONE], "wing_back": [0.12, Vector2.ONE],
		"neck": [0.0, Vector2.ONE], "head": [0.0, Vector2(1.25, 1.25)], "jaw": [0.0, Vector2.ONE],
		"tail": [0.0, Vector2.ONE],
	})
	parts.body.position = Vector2(0, -128)


func _set_pose(p: Dictionary) -> void:
	for k in p:
		parts[k].rotation = p[k][0]
		parts[k].scale = p[k][1]


func signature(t: Tween) -> void:
	# Rise from the crouch while the wings unfold (2.0-3.0 s).
	t.set_parallel(true)
	t.tween_property(parts.body, "position", Vector2(0, -128), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.wing, "rotation", 0.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(parts.wing, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(parts.wing_back, "rotation", 0.12, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(parts.wing_back, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(parts.neck, "rotation", -0.12, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.head, "rotation", -0.18, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.tail, "rotation", -0.08, 1.0).set_trans(Tween.TRANS_SINE)
	t.set_parallel(false)
	# Silent roar (3.0-3.8 s).
	t.tween_property(parts.jaw, "rotation", 0.32, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(parts.head, "rotation", -0.32, 0.25)
	t.tween_interval(0.3)
	t.tween_property(parts.jaw, "rotation", 0.0, 0.25)
	# One slow wing beat with a slight lift, then settle (3.8-4.9 s).
	t.tween_property(parts.wing, "rotation", -0.22, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.wing_back, "rotation", -0.1, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.body, "position", Vector2(0, -142), 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.wing, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.wing_back, "rotation", 0.12, 0.4).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.body, "position", Vector2(0, -128), 0.4).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.neck, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.head, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(parts.tail, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


func idle_tweens() -> Array[Tween]:
	var out: Array[Tween] = []
	var breathe := create_tween().set_loops()
	breathe.tween_property(parts.body, "scale", Vector2(1.0, 1.015), 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(parts.body, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)
	out.append(breathe)
	var sway := create_tween().set_loops()
	sway.tween_property(parts.tail, "rotation", 0.05, 2.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(parts.tail, "rotation", -0.03, 2.2).set_trans(Tween.TRANS_SINE)
	out.append(sway)
	var look := create_tween().set_loops()
	look.tween_interval(3.0)
	look.tween_property(parts.head, "rotation", -0.06, 0.8).set_trans(Tween.TRANS_SINE)
	look.tween_interval(1.5)
	look.tween_property(parts.head, "rotation", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	out.append(look)
	var wing := create_tween().set_loops()
	wing.tween_property(parts.wing, "rotation", -0.03, 2.6).set_trans(Tween.TRANS_SINE)
	wing.tween_property(parts.wing, "rotation", 0.0, 2.6).set_trans(Tween.TRANS_SINE)
	out.append(wing)
	return out
