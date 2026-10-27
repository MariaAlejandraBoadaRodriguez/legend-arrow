extends SerpentRig
## Cloud Serpent: a long pale-blue serpent with fin-like crests and whiskers,
## drifting over a bank of cloud. Signature: uncoils, rises in an S-curve and
## sends a slow wave down its body.


func _init() -> void:
	SKIN = Color("#9AA6AE")
	SKIN_DARK = Color("#7B8790")
	BELLY = Color("#D2D9DD")
	segments = 11
	seg_len = 44.0
	width_start = 22.0
	width_end = 10.0
	base_at = Vector2(-170, -70)


func final_angles() -> Array:
	return [-0.55, -0.35, -0.3, 0.25, 0.4, 0.4, 0.2, -0.3, -0.42, -0.35, 0.25]


func build_base(root: Node2D) -> void:
	for c in [[Vector2(-160, -20), Vector2(110, 34)], [Vector2(-40, -10), Vector2(140, 40)], [Vector2(90, -24), Vector2(110, 30)]]:
		shape(root, ellipse(c[0], c[1], 28), Color("#E4E8EA"), Color("#C3CACE"), 2.0)


func segment_detail(seg: Node2D, i: int, w0: float, _w1: float) -> void:
	if i % 3 == 1:
		shape(seg, PackedVector2Array([Vector2(6, -w0), Vector2(22, -w0 - 26), Vector2(34, -w0 + 2)]), SKIN_DARK, INK, 1.5)


func build_head(head: Node2D) -> void:
	shape(head, PackedVector2Array([Vector2(-6, -16), Vector2(30, -18), Vector2(58, -6), Vector2(60, 6), Vector2(30, 14), Vector2(-6, 12)]), SKIN)
	shape(head, PackedVector2Array([Vector2(4, -14), Vector2(-14, -40), Vector2(18, -18)]), SKIN_DARK, INK, 1.5)
	shape(head, ellipse(Vector2(30, -6), Vector2(5, 3), 10), Color("#EEF0EE"), INK, 1.5)
	stroke(head, spline([Vector2(56, 4), Vector2(80, 18), Vector2(98, 10)]), INK, 2.0)
	stroke(head, spline([Vector2(54, 8), Vector2(74, 34), Vector2(94, 36)]), INK, 2.0)


func signature(t: Tween) -> void:
	# Uncoil and rise (2.0-3.2 s).
	tween_pose(t, chain_pose(final_angles(), 0.15), 1.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	# A slow wave travels from tail to head (3.2-4.6 s).
	var base := final_angles()
	for i in segments:
		var k := "seg%d" % i
		var bent: float = base[i] + (0.22 if i % 2 == 0 else -0.22)
		t.tween_property(parts[k], "rotation", bent, 0.12).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(parts[k], "rotation", base[i], 0.12).set_delay(0.12).set_trans(Tween.TRANS_SINE)
	tween_pose(t, chain_pose(final_angles(), 0.15), 0.3)
