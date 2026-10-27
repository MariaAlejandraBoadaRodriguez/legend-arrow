extends DrakeRig
## Arctic Drake: pale ice-grey with frosted spines. Signature: rises, unfolds
## its wings and exhales a thin stream of frost (spec §9).

const HEAD := Vector2(1.25, 1.25)

var _frost: Node2D


func _init() -> void:
	SKIN = Color("#8D99A2")
	SKIN_DARK = Color("#6F7B84")
	SKIN_LIGHT = Color("#C2CBD1")
	MEMBRANE = Color("#AEB9C1")
	MEMBRANE_DARK = Color("#8F9BA4")
	BONE = Color("#4A535A")


func extras(_root: Node2D, body: Node2D, head: Node2D) -> void:
	for i in 6:
		var x := -70.0 + i * 28.0
		shape(body, PackedVector2Array([Vector2(x - 8, -40 + i * -3), Vector2(x + 2, -78 - i * 2), Vector2(x + 10, -42 + i * -3)]),
			Color("#E3E8EB"), Color("#6F7B84"), 1.5)
	_frost = specks(head, Vector2(120, 6), 14, Vector2(90, 26), Color("#E8EEF1", 0.85), 4.0, 11)
	_frost.modulate.a = 0.0
	parts["frost"] = _frost


func pose_final() -> void:
	super()
	if _frost != null:
		_frost.modulate.a = 0.0
		_frost.position = Vector2(120, 6)


func signature(t: Tween) -> void:
	tween_pose(t, {"wing": [0.0, Vector2.ONE], "wing_back": [0.12, Vector2.ONE], "neck": [-0.08, Vector2.ONE],
		"head": [-0.1, HEAD], "tail": [0.0, Vector2.ONE], "body": [0.0, Vector2.ONE, Vector2(0, -128)]}, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
	# Exhale: jaw opens, frost drifts forward and fades.
	t.tween_property(parts.jaw, "rotation", 0.28, 0.25)
	t.parallel().tween_property(_frost, "modulate:a", 1.0, 0.3)
	t.tween_property(_frost, "position", Vector2(230, 0), 1.1).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_frost, "scale", Vector2(1.6, 1.3), 1.1)
	t.tween_property(_frost, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(parts.jaw, "rotation", 0.0, 0.3)
	tween_pose(t, {"neck": [0.0, Vector2.ONE], "head": [0.0, HEAD]}, 0.5)
