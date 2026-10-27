extends QuadrupedRig
## Antler Fox: a slender grey fox with pale branching antlers and a heavy
## plume of a tail. Signature: rises, looks back over its shoulder with a tail
## sweep, then turns and bows its antlers.

const ANTLER := Color("#CFC6B4")


func _init() -> void:
	COAT = Color("#7D756C")
	COAT_DARK = Color("#5D564F")
	COAT_LIGHT = Color("#B9B1A6")
	leg_len = 105.0
	leg_width = 18.0
	body_len = 170.0
	body_h = 62.0
	neck_end = Vector2(34, -70)
	neck_width = 20.0
	hip_x = -80.0
	base_width = 210.0


func build_head(head: Node2D) -> void:
	shape(head, PackedVector2Array([Vector2(-8, -26), Vector2(-14, -64), Vector2(8, -30)]), COAT_DARK)  # far ear
	# Antlers: main beams with tines.
	for side in [-1, 1]:
		var o := Vector2(side * 6, -24)
		var beam := PackedVector2Array([o, o + Vector2(-16, -40), o + Vector2(-34, -80), o + Vector2(-26, -120)])
		stroke(head, beam, ANTLER, 6.0)
		stroke(head, PackedVector2Array([beam[1], beam[1] + Vector2(18, -26)]), ANTLER, 4.0)
		stroke(head, PackedVector2Array([beam[2], beam[2] + Vector2(16, -22)]), ANTLER, 4.0)
		stroke(head, PackedVector2Array([beam[2], beam[2] + Vector2(-24, -10)]), ANTLER, 4.0)
	shape(head, ellipse(Vector2(8, -6), Vector2(30, 22), 24), COAT)
	shape(head, PackedVector2Array([Vector2(22, -16), Vector2(68, 4), Vector2(62, 10), Vector2(24, 12)]), COAT)
	shape(head, PackedVector2Array([Vector2(26, 4), Vector2(62, 9), Vector2(24, 14)]), COAT_LIGHT, COAT_LIGHT, 0.0)
	shape(head, PackedVector2Array([Vector2(2, -24), Vector2(10, -64), Vector2(22, -26)]), COAT)  # near ear
	shape(head, ellipse(Vector2(66, 5), Vector2(5, 4), 10), INK, INK, 0.0)
	shape(head, ellipse(Vector2(24, -8), Vector2(5, 3), 10), EYE, INK, 1.5)


func build_tail(tail: Node2D) -> void:
	# A drooping brush: thickest in the middle, pale tip.
	var line := spline([Vector2.ZERO, Vector2(-40, 34), Vector2(-100, 58), Vector2(-150, 44)])
	shape(tail, ribbon(line, 10, 30), COAT)
	shape(tail, ellipse(Vector2(-150, 44), Vector2(32, 20), 20), COAT_LIGHT)


func signature(t: Tween) -> void:
	rise(t)
	tween_pose(t, {"neck": [-1.1, Vector2.ONE], "head": [-0.5, Vector2.ONE], "tail": [-0.5, Vector2.ONE]}, 0.6)
	tween_pose(t, {"tail": [0.35, Vector2.ONE]}, 0.4)
	tween_pose(t, {"neck": [0.0, Vector2.ONE], "head": [0.0, Vector2.ONE], "tail": [0.0, Vector2.ONE]}, 0.5)
	tween_pose(t, {"neck": [0.45, Vector2.ONE], "head": [0.25, Vector2.ONE]}, 0.4)
	tween_pose(t, {"neck": [0.0, Vector2.ONE], "head": [0.0, Vector2.ONE]}, 0.5)
