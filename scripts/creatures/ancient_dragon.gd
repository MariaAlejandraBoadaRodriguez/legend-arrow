extends DrakeRig
## Ancient Dragon: the largest creature, dark graphite with a crown of horns
## and heavy dorsal plates. Signature: lowers its head, then rises to full
## height with a slow, wide wing spread and a long held stare.

const HEAD := Vector2(1.25, 1.25)


func _init() -> void:
	SKIN = Color("#3D4245")
	SKIN_DARK = Color("#2E3235")
	SKIN_LIGHT = Color("#585E62")
	MEMBRANE = Color("#5C6266")
	MEMBRANE_DARK = Color("#474C50")
	BONE = Color("#1F2224")
	EYE = Color("#D9D2BF")
	extra_horns = 3
	wing_scale = 1.2


func extras(root: Node2D, body: Node2D, _head: Node2D) -> void:
	root.scale = Vector2(1.1, 1.1)  # the largest creature in the roster
	for i in 5:
		var x := -80.0 + i * 36.0
		shape(body, PackedVector2Array([Vector2(x - 14, -46 - i * 4), Vector2(x, -96 - i * 5), Vector2(x + 14, -48 - i * 4)]),
			SKIN_DARK, BONE, 2.0)


func signature(t: Tween) -> void:
	tween_pose(t, {"neck": [0.45, Vector2.ONE], "head": [0.35, HEAD], "body": [0.0, Vector2.ONE, Vector2(0, -116)]}, 0.5)
	tween_pose(t, {"wing": [0.15, Vector2(1.08, 1.08)], "wing_back": [0.28, Vector2(1.08, 1.08)], "neck": [-0.15, Vector2.ONE],
		"head": [-0.2, HEAD], "tail": [-0.1, Vector2.ONE], "body": [0.0, Vector2(1.03, 1.03), Vector2(0, -136)]}, 1.4, Tween.TRANS_SINE, Tween.EASE_OUT)
	t.tween_interval(0.5)
	tween_pose(t, {"wing": [0.0, Vector2.ONE], "wing_back": [0.12, Vector2.ONE], "neck": [0.0, Vector2.ONE],
		"head": [0.0, HEAD], "tail": [0.0, Vector2.ONE], "body": [0.0, Vector2.ONE, Vector2(0, -128)]}, 0.7)
