extends CreatureRig
## Moon Owl: a large silver-grey owl on a dead branch, pale facial disc and
## ear tufts. Signature: opens its wings to full span, swivels its head and
## settles with the wings half open.

const PLUMAGE := Color("#7F868B")
const PLUMAGE_DARK := Color("#5E656A")
const BELLY := Color("#B9BEC1")
const DISC := Color("#D5D9DB")
const EYE := Color("#EEF0EE")
const INK := Color("#25282B")
const BARK := Color("#6B6660")


func build() -> void:
	var root := Node2D.new()
	root.name = "Root"
	group.add_child(root)
	parts["root"] = root
	# Dead branch
	shape(root, ribbon(spline([Vector2(-260, 10), Vector2(-120, -6), Vector2(40, -2), Vector2(200, -14), Vector2(270, -30)]), 14, 8), BARK)
	shape(root, ribbon(spline([Vector2(150, -8), Vector2(200, -60), Vector2(230, -90)]), 7, 2), BARK)

	var body := add_part("body", root, Vector2(0, -30), 0)
	var tail := add_part("tail", body, Vector2(0, -10), -2)
	shape(tail, PackedVector2Array([Vector2(-34, 0), Vector2(34, 0), Vector2(46, 70), Vector2(0, 84), Vector2(-46, 70)]), PLUMAGE_DARK)

	var wing_l := add_part("wing_l", body, Vector2(-62, -190), 2)
	feather_wing(wing_l, 230, 120, PLUMAGE_DARK, INK)
	wing_l.scale = Vector2(-1, 1)
	var wing_r := add_part("wing_r", body, Vector2(62, -190), 2)
	feather_wing(wing_r, 230, 120, PLUMAGE_DARK, INK)

	# Torso (egg) with belly chevrons
	shape(body, ellipse(Vector2(0, -120), Vector2(86, 122), 32), PLUMAGE)
	shape(body, ellipse(Vector2(0, -100), Vector2(56, 88), 28), BELLY, BELLY, 0.0)
	for row in 5:
		for col in 3:
			var c := Vector2(-28 + col * 28, -150 + row * 26)
			stroke(body, PackedVector2Array([c + Vector2(-8, -3), c, c + Vector2(8, -3)]), PLUMAGE_DARK, 2.5)
	# Talons
	for x in [-22, 22]:
		for k in 3:
			stroke(body, PackedVector2Array([Vector2(x - 8 + k * 8, 22), Vector2(x - 10 + k * 10, 34)]), INK, 4.0)

	var head := add_part("head", body, Vector2(0, -255), 3)
	shape(head, PackedVector2Array([Vector2(-70, -40), Vector2(-62, -78), Vector2(-40, -56)]), PLUMAGE_DARK)  # ear tufts
	shape(head, PackedVector2Array([Vector2(70, -40), Vector2(62, -78), Vector2(40, -56)]), PLUMAGE_DARK)
	shape(head, ellipse(Vector2(0, 0), Vector2(78, 64), 32), PLUMAGE)
	shape(head, ellipse(Vector2(-28, 2), Vector2(32, 34), 24), DISC, PLUMAGE_DARK, 1.5)
	shape(head, ellipse(Vector2(28, 2), Vector2(32, 34), 24), DISC, PLUMAGE_DARK, 1.5)
	var eyes := add_part("eyes", head, Vector2.ZERO, 1)
	for x in [-28, 28]:
		shape(eyes, ellipse(Vector2(x, 0), Vector2(15, 15), 20), EYE, INK, 2.0)
		shape(eyes, ellipse(Vector2(x, 0), Vector2(7, 7), 14), INK, INK, 0.0)
	shape(head, PackedVector2Array([Vector2(-7, 18), Vector2(7, 18), Vector2(0, 36)]), Color("#3B3F43"))


func pose_dormant() -> void:
	apply_pose({
		"wing_l": [0.05, Vector2(-0.95, 0.95)], "wing_r": [-0.05, Vector2(0.95, 0.95)],
		"head": [0.0, Vector2.ONE, Vector2(0, -228)], "body": [0.0, Vector2(1.0, 0.94)],
		"eyes": [0.0, Vector2(1, 0.15)], "tail": [0.0, Vector2.ONE],
	})


func pose_final() -> void:
	apply_pose({
		"wing_l": [0.42, Vector2(-1, 1)], "wing_r": [-0.42, Vector2(1, 1)],
		"head": [0.0, Vector2.ONE, Vector2(0, -255)], "body": [0.0, Vector2.ONE],
		"eyes": [0.0, Vector2.ONE], "tail": [0.0, Vector2.ONE],
	})


func signature(t: Tween) -> void:
	# Eyes open and the head rises (2.0-2.6 s).
	tween_pose(t, {"eyes": [0.0, Vector2.ONE], "head": [0.0, Vector2.ONE, Vector2(0, -255)], "body": [0.0, Vector2.ONE]}, 0.6)
	# Full wingspan (2.6-3.6 s).
	tween_pose(t, {"wing_l": [1.75, Vector2(-1, 1)], "wing_r": [-1.75, Vector2(1, 1)]}, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
	# Head swivel (3.6-4.4 s).
	tween_pose(t, {"head": [-0.28, Vector2.ONE, Vector2(0, -255)]}, 0.3)
	tween_pose(t, {"head": [0.22, Vector2.ONE, Vector2(0, -255)]}, 0.3)
	tween_pose(t, {"head": [0.0, Vector2.ONE, Vector2(0, -255)]}, 0.2)
	# Settle with the wings half open (4.4-5.0 s).
	tween_pose(t, {"wing_l": [0.42, Vector2(-1, 1)], "wing_r": [-0.42, Vector2(1, 1)]}, 0.6)


func idle_tweens() -> Array[Tween]:
	var out: Array[Tween] = []
	var breathe := create_tween().set_loops()
	breathe.tween_property(parts.body, "scale", Vector2(1.01, 1.012), 1.6).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(parts.body, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	out.append(breathe)
	var blink := create_tween().set_loops()
	blink.tween_interval(3.2)
	blink.tween_property(parts.eyes, "scale", Vector2(1, 0.1), 0.08)
	blink.tween_property(parts.eyes, "scale", Vector2.ONE, 0.1)
	out.append(blink)
	var look := create_tween().set_loops()
	look.tween_interval(2.0)
	look.tween_property(parts.head, "rotation", 0.12, 0.6).set_trans(Tween.TRANS_SINE)
	look.tween_interval(1.8)
	look.tween_property(parts.head, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	out.append(look)
	return out
