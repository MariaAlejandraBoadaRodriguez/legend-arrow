class_name SerpentRig
extends CreatureRig
## Legless creatures built as a chain of tapered segments (Cloud Serpent,
## Stone Wyrm). Each segment is a child of the previous one, so a pose is just
## a list of joint angles and motion bends the whole body smoothly.

var SKIN := Color("#9AA6AE")
var SKIN_DARK := Color("#7B8790")
var BELLY := Color("#C6CED3")
var INK := Color("#25282B")
var segments := 10
var seg_len := 46.0
var width_start := 30.0
var width_end := 12.0
var base_at := Vector2(-150, -40)


func build() -> void:
	var root := Node2D.new()
	root.name = "Root"
	group.add_child(root)
	parts["root"] = root
	build_base(root)
	var parent: Node2D = root
	var at := base_at
	for i in segments:
		var seg := add_part("seg%d" % i, parent, at, 0)
		var w0 := lerpf(width_start, width_end, float(i) / segments)
		var w1 := lerpf(width_start, width_end, float(i + 1) / segments)
		shape(seg, PackedVector2Array([Vector2(-2, -w0), Vector2(seg_len + 2, -w1), Vector2(seg_len + 2, w1), Vector2(-2, w0)]), SKIN, SKIN, 0.0)
		shape(seg, ellipse(Vector2(seg_len, 0), Vector2(w1, w1), 16), SKIN, SKIN, 0.0)
		stroke(seg, PackedVector2Array([Vector2(0, w0 * 0.55), Vector2(seg_len, w1 * 0.55)]), BELLY, maxf(3.0, w1 * 0.5))
		stroke(seg, PackedVector2Array([Vector2(0, -w0), Vector2(seg_len, -w1)]), INK, 2.0)
		stroke(seg, PackedVector2Array([Vector2(0, w0), Vector2(seg_len, w1)]), INK, 2.0)
		segment_detail(seg, i, w0, w1)
		parent = seg
		at = Vector2(seg_len, 0)
	var head := add_part("head", parent, Vector2(seg_len, 0), 2)
	build_head(head)


func build_base(_root: Node2D) -> void:
	pass


func segment_detail(_seg: Node2D, _i: int, _w0: float, _w1: float) -> void:
	pass


func build_head(_head: Node2D) -> void:
	pass


## Joint angles (radians) from the base outwards, plus the head angle.
func chain_pose(angles: Array, head_angle := 0.0) -> Dictionary:
	var p := {}
	for i in segments:
		p["seg%d" % i] = [angles[mini(i, angles.size() - 1)], Vector2.ONE]
	p["head"] = [head_angle, Vector2.ONE]
	return p


## Tight spiral, head tucked.
func coiled() -> Dictionary:
	var a: Array = [-0.3]
	for i in segments - 1:
		a.append(0.62)
	return chain_pose(a, 0.4)


func final_angles() -> Array:
	return [-1.15, 0.32, 0.3, 0.1, -0.3, -0.36, -0.3, 0.1, 0.3, 0.32]


func pose_dormant() -> void:
	apply_pose(coiled())


func pose_final() -> void:
	apply_pose(chain_pose(final_angles(), 0.15))


func idle_tweens() -> Array[Tween]:
	var out: Array[Tween] = []
	var base := final_angles()
	var wave := create_tween().set_loops()
	var a := {}
	var b := {}
	for i in segments:
		var phase := sin(i * 0.9)
		a["seg%d" % i] = base[mini(i, base.size() - 1)] + 0.05 * phase
		b["seg%d" % i] = base[mini(i, base.size() - 1)] - 0.05 * phase
	for k in a:
		wave.parallel().tween_property(parts[k], "rotation", a[k], 1.8).set_trans(Tween.TRANS_SINE)
	wave.chain()
	for k in b:
		wave.parallel().tween_property(parts[k], "rotation", b[k], 1.8).set_trans(Tween.TRANS_SINE)
	out.append(wave)
	return out
