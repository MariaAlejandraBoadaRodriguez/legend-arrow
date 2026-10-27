extends SerpentRig
## Stone Wyrm: a massive limbless wyrm with rock-plate armour, curled among
## boulders. Signature: emerges from the stone, rears up to its full height
## and opens its jaws, shaking off dust.

const STONE := Color("#6B6862")
const PLATE := Color("#55524D")

var _dust: Node2D


func _init() -> void:
	SKIN = STONE
	SKIN_DARK = PLATE
	BELLY = Color("#99958C")
	segments = 9
	seg_len = 48.0
	width_start = 40.0
	width_end = 20.0
	base_at = Vector2(-120, -30)


func final_angles() -> Array:
	return [-0.15, -0.35, -0.45, -0.4, -0.2, 0.15, 0.35, 0.4, 0.3]


func coiled() -> Dictionary:
	var a: Array = [0.0]
	for i in segments - 1:
		a.append(0.7)
	var p := chain_pose(a, 0.6)
	p["seg0"] = [0.0, Vector2(1, 0.7)]
	return p


func build_base(root: Node2D) -> void:
	rock_base(root, 250, Color("#BFC0BC"), Color("#9FA19C"))
	for b in [[Vector2(-210, -40), Vector2(48, 40)], [Vector2(150, -36), Vector2(56, 38)], [Vector2(40, -20), Vector2(40, 26)]]:
		shape(root, ellipse(b[0], b[1], 18), Color("#A7A9A4"), Color("#83857F"), 2.0)
	_dust = specks(root, Vector2(-60, -40), 14, Vector2(260, 60), Color("#B9B6AE", 0.8), 5.0, 23)
	_dust.modulate.a = 0.0


func segment_detail(seg: Node2D, _i: int, w0: float, w1: float) -> void:
	shape(seg, PackedVector2Array([Vector2(6, -w0 + 4), Vector2(seg_len * 0.5, -w0 - 10), Vector2(seg_len - 4, -w1 + 4)]), PLATE, INK, 1.5)


func build_head(head: Node2D) -> void:
	shape(head, PackedVector2Array([Vector2(-10, -26), Vector2(30, -30), Vector2(70, -14), Vector2(74, 0), Vector2(30, 2), Vector2(-10, 0)]), STONE)
	var jaw := add_part("jaw", head, Vector2(0, 0), -1)
	shape(jaw, PackedVector2Array([Vector2(-10, 0), Vector2(30, 2), Vector2(68, 6), Vector2(40, 22), Vector2(-6, 20)]), PLATE)
	shape(head, PackedVector2Array([Vector2(0, -26), Vector2(-30, -52), Vector2(14, -30)]), PLATE, INK, 1.5)
	shape(head, ellipse(Vector2(34, -16), Vector2(6, 4), 10), Color("#D9D2BF"), INK, 1.5)


func pose_final() -> void:
	super()
	parts.jaw.rotation = 0.0
	if _dust != null:
		_dust.modulate.a = 0.0


func signature(t: Tween) -> void:
	t.tween_property(_dust, "modulate:a", 1.0, 0.3)
	tween_pose(t, chain_pose(final_angles(), 0.0), 1.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	t.parallel().tween_property(_dust, "position", Vector2(-60, -110), 1.3)
	t.parallel().tween_property(_dust, "modulate:a", 0.0, 1.3)
	t.tween_property(parts.jaw, "rotation", 0.4, 0.3)
	t.parallel().tween_property(parts.head, "rotation", -0.2, 0.3)
	t.tween_interval(0.4)
	t.tween_property(parts.jaw, "rotation", 0.0, 0.4)
	t.parallel().tween_property(parts.head, "rotation", 0.0, 0.4)
