extends DrakeRig
## Wyvern: two-legged, slate-blue, the wings are its arms. Signature: unfolds
## its wings, beats twice and lifts off the rock, then lands (spec §9).

const HEAD := Vector2(1.25, 1.25)


func _init() -> void:
	SKIN = Color("#4A5661")
	SKIN_DARK = Color("#37414B")
	SKIN_LIGHT = Color("#66737E")
	MEMBRANE = Color("#76838E")
	MEMBRANE_DARK = Color("#59656F")
	fore_legs = false
	wing_scale = 1.15


func signature(t: Tween) -> void:
	tween_pose(t, {"wing": [0.0, Vector2.ONE], "wing_back": [0.12, Vector2.ONE], "neck": [-0.1, Vector2.ONE],
		"head": [-0.15, HEAD], "body": [0.0, Vector2.ONE, Vector2(0, -128)]}, 0.8, Tween.TRANS_BACK, Tween.EASE_OUT)
	for i in 2:
		tween_pose(t, {"wing": [-0.35, Vector2(1, 0.9)], "wing_back": [-0.2, Vector2(1, 0.9)],
			"body": [-0.05, Vector2.ONE, Vector2(0, -150 - i * 50)]}, 0.28)
		tween_pose(t, {"wing": [0.25, Vector2.ONE], "wing_back": [0.3, Vector2.ONE],
			"body": [-0.08, Vector2.ONE, Vector2(0, -170 - i * 60)]}, 0.32)
	tween_pose(t, {"wing": [0.0, Vector2.ONE], "wing_back": [0.12, Vector2.ONE], "neck": [0.0, Vector2.ONE],
		"head": [0.0, HEAD], "body": [0.0, Vector2.ONE, Vector2(0, -128)]}, 0.8)
