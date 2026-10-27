extends CreatureRig
## Phoenix: an ash-grey long-necked bird with trailing tail plumes and a small,
## desaturated warm highlight (spec §8). Signature: opens its wings high and
## sheds a few pale embers that drift up and fade (spec §9).

const ASH := Color("#8E8A86")
const ASH_DARK := Color("#6C6865")
const ASH_LIGHT := Color("#BDB8B2")
const WARM := Color("#C7A588")       # muted ember tone, used sparingly
const INK := Color("#25282B")
const OPEN := 2.6
const REST := 0.5

var _embers: Node2D


func build() -> void:
	var root := Node2D.new()
	root.name = "Root"
	group.add_child(root)
	parts["root"] = root
	rock_base(root, 200)
	var body := add_part("body", root, Vector2(0, -150), 0)
	var tail := add_part("tail", body, Vector2(-60, 20), -2)
	for i in 4:
		var line := spline([Vector2.ZERO, Vector2(-70 - i * 10, 40 + i * 12), Vector2(-160 - i * 18, 70 + i * 22), Vector2(-220 - i * 22, 60 + i * 34)])
		shape(tail, ribbon(line, 10, 3), ASH if i % 2 == 0 else ASH_DARK)
		shape(tail, ellipse(line[line.size() - 1], Vector2(10, 7), 12), WARM, INK, 1.5)
	var wing_back := add_part("wing_back", body, Vector2(10, -40), -1)
	feather_wing(wing_back, 220, 120, ASH_DARK, INK)
	# Legs
	for x in [-6, 14]:
		stroke(body, PackedVector2Array([Vector2(x, 30), Vector2(x - 4, 110), Vector2(x + 10, 118)]), INK, 5.0)
	shape(body, ellipse(Vector2(0, 0), Vector2(78, 50), 32), ASH)
	shape(body, ellipse(Vector2(10, 14), Vector2(50, 28), 24), ASH_LIGHT, ASH_LIGHT, 0.0)
	var neck := add_part("neck", body, Vector2(50, -26), 2)
	shape(neck, ribbon(spline([Vector2.ZERO, Vector2(18, -50), Vector2(10, -100), Vector2(30, -130)]), 18, 12), ASH)
	var head := add_part("head", neck, Vector2(30, -130), 3)
	for i in 4:
		var a := -2.2 + i * 0.22
		var tip := Vector2(cos(a), sin(a)) * (46 + i * 6)
		shape(head, PackedVector2Array([Vector2(-4, -8), tip, Vector2(4, -10)]), WARM if i == 3 else ASH_DARK, INK, 1.5)
	shape(head, ellipse(Vector2(4, 0), Vector2(22, 17), 20), ASH)
	shape(head, PackedVector2Array([Vector2(20, -6), Vector2(50, 4), Vector2(20, 8)]), Color("#5B5652"))
	shape(head, ellipse(Vector2(8, -4), Vector2(4, 3), 10), Color("#EEE8DE"), INK, 1.5)
	var wing := add_part("wing", body, Vector2(0, -34), 4)
	feather_wing(wing, 240, 130, ASH, INK)
	_embers = specks(root, Vector2(0, -260), 12, Vector2(300, 120), Color("#E8D2BC", 0.9), 4.0, 31)
	_embers.modulate.a = 0.0


func _rest() -> Dictionary:
	return {"wing": [REST, Vector2.ONE], "wing_back": [REST + 0.2, Vector2.ONE], "neck": [0.0, Vector2.ONE],
		"head": [0.0, Vector2.ONE], "tail": [0.0, Vector2.ONE], "body": [0.0, Vector2.ONE, Vector2(0, -150)]}


func pose_dormant() -> void:
	apply_pose({"wing": [0.2, Vector2(0.9, 0.85)], "wing_back": [0.3, Vector2(0.9, 0.85)], "neck": [0.7, Vector2.ONE],
		"head": [0.5, Vector2.ONE], "tail": [0.15, Vector2.ONE], "body": [0.0, Vector2.ONE, Vector2(0, -120)]})


func pose_final() -> void:
	apply_pose(_rest())
	if _embers != null:
		_embers.modulate.a = 0.0
		_embers.position = Vector2(0, -260)


func signature(t: Tween) -> void:
	tween_pose(t, _rest(), 0.7)
	tween_pose(t, {"wing": [OPEN, Vector2(1.1, 1.1)], "wing_back": [OPEN + 0.25, Vector2(1.05, 1.05)], "neck": [-0.15, Vector2.ONE],
		"head": [-0.2, Vector2.ONE]}, 0.9, Tween.TRANS_BACK, Tween.EASE_OUT)
	t.parallel().tween_property(_embers, "modulate:a", 1.0, 0.5)
	t.tween_property(_embers, "position", Vector2(0, -360), 1.2).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_embers, "modulate:a", 0.0, 1.2)
	tween_pose(t, _rest(), 0.7)


func idle_tweens() -> Array[Tween]:
	var out: Array[Tween] = []
	var breathe := create_tween().set_loops()
	breathe.tween_property(parts.body, "scale", Vector2(1.0, 1.02), 1.6).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(parts.body, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	out.append(breathe)
	var sway := create_tween().set_loops()
	sway.tween_property(parts.tail, "rotation", 0.05, 2.4).set_trans(Tween.TRANS_SINE)
	sway.tween_property(parts.tail, "rotation", -0.03, 2.4).set_trans(Tween.TRANS_SINE)
	out.append(sway)
	return out
