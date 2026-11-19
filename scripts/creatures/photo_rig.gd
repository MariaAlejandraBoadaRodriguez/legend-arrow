class_name PhotoRig
extends CreatureRig
## Photoreal dragon (v0.2 §4, D-49): the owner's image, cut out by
## scripts/import_art.sh (assets/creatures/art/<id>.webp).
##
## Awakening (~5 s, skippable after 1 s by the screen): short arrows gather
## from around the stage into the dragon's silhouette (points sampled from
## assets/creatures/masks/<id>.png) -> the real image fades in through soft
## mist -> a white rim light passes -> a gentle breath; a slow camera push and
## two mist layers drifting at different speeds give parallax. Reduced
## motion: the base class's short dissolve to the final pose. Idle: a slow
## breath and drifting mist. One full image per rig; freeing the rig (the
## stage does on leave) releases the texture.

const ART_DIR := "res://assets/creatures/art"
const MASK_DIR := "res://assets/creatures/masks"
const BOX := Vector2(700, 620)   # fits the stage view above its feet point
const ARROWS := 28
const AWAKEN_TOTAL := 5.0

var dragon_id := ""
var _sprite: Sprite2D
var _rim: Sprite2D
var _arrows: Array[Line2D] = []
var _targets: Array[Vector2] = []
var _starts: Array[Vector2] = []
var _mist_back: Sprite2D
var _mist_front: Sprite2D
var _fit := 1.0
var _size := Vector2.ZERO


static func art_path(id: String) -> String:
	return ART_DIR.path_join(id + ".webp")


static func has_art(id: String) -> bool:
	return ResourceLoader.exists(art_path(id))


func build() -> void:
	var tex: Texture2D = load(art_path(dragon_id))
	_size = Vector2(tex.get_width(), tex.get_height())
	_fit = minf(BOX.x / _size.x, BOX.y / _size.y)
	var cam := add_part("camera", group, Vector2(0, -_size.y * _fit * 0.5))
	_mist_back = _mist(Color(1, 1, 1, 0.0), 1.35)
	cam.add_child(_mist_back)
	var body := add_part("body", cam, Vector2.ZERO)
	_sprite = Sprite2D.new()
	_sprite.name = "Art"
	_sprite.texture = tex
	_sprite.scale = Vector2(_fit, _fit)   # centred on the camera pivot
	body.add_child(_sprite)
	_rim = Sprite2D.new()
	_rim.name = "Rim"
	_rim.texture = tex
	_rim.scale = Vector2(_fit, _fit) * 1.012
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rim.material = add
	_rim.modulate = Color(1, 1, 1, 0)
	body.add_child(_rim)
	_mist_front = _mist(Color(1, 1, 1, 0.0), 1.1)
	_mist_front.position = Vector2(0, _size.y * _fit * 0.32)
	cam.add_child(_mist_front)
	var arrows := add_part("arrows", cam, Vector2.ZERO)
	_build_arrows(arrows)


## Soft white radial blob used as mist.
func _mist(c: Color, scale_k: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 128
	var s := Sprite2D.new()
	s.texture = t
	s.modulate = c
	s.scale = Vector2(BOX.x / 256.0, BOX.y * 0.5 / 128.0) * scale_k
	return s


func _build_arrows(parent: Node2D) -> void:
	var pts := _mask_points(ARROWS)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dragon_id)
	for i in pts.size():
		var l := Line2D.new()
		l.width = 6.0
		l.default_color = Palette.ACCENT
		l.points = PackedVector2Array([Vector2(-14, 0), Vector2(10, 0), Vector2(2, -7), Vector2(10, 0), Vector2(2, 7)])
		var ang := rng.randf() * TAU
		var start := Vector2.from_angle(ang) * rng.randf_range(420.0, 560.0)
		_starts.append(start)
		_targets.append(pts[i])
		l.position = start
		l.rotation = (pts[i] - start).angle()
		l.modulate.a = 0.0
		parent.add_child(l)
		_arrows.append(l)


## Points inside the dragon's mask, in body coordinates.
func _mask_points(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var path := MASK_DIR.path_join(dragon_id + ".png")
	var img: Image = null
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dragon_id) + 7
	var tries := 0
	while out.size() < n and tries < n * 200:
		tries += 1
		var u := Vector2(rng.randf(), rng.randf())
		if img != null:
			var px := Vector2i(int(u.x * (img.get_width() - 1)), int(u.y * (img.get_height() - 1)))
			if img.get_pixelv(px).r < 0.5:
				continue
			# the mask frame is the 256x384 fit of the trimmed image: map back
			var frame := Vector2(img.get_width(), img.get_height())
			var s := minf(frame.x / _size.x, frame.y / _size.y)
			var p := (u * frame - frame * 0.5) / s     # image pixels from centre
			out.append(p * _fit)
		else:
			out.append((u - Vector2(0.5, 0.5)) * _size * _fit * 0.6)
	return out


func pose_dormant() -> void:
	parts.camera.scale = Vector2(0.94, 0.94)
	parts.body.modulate.a = 0.0
	_rim.modulate.a = 0.0
	_mist_back.modulate.a = 0.0
	_mist_front.modulate.a = 0.0
	_mist_back.position = Vector2.ZERO
	for i in _arrows.size():
		_arrows[i].position = _starts[i]
		_arrows[i].modulate.a = 0.0


func pose_final() -> void:
	parts.camera.scale = Vector2.ONE
	parts.body.modulate.a = 1.0
	parts.body.scale = Vector2.ONE
	_rim.modulate.a = 0.0
	_mist_back.modulate.a = 0.35
	_mist_front.modulate.a = 0.22
	for a in _arrows:
		a.modulate.a = 0.0


## Full sequence; reduced motion uses the base dissolve.
func awaken() -> void:
	if reduce_motion:
		super.awaken()
		return
	stop()
	awakening = true
	pose_dormant()
	fade_target.modulate = Color.WHITE
	var t := _track(create_tween().set_parallel(true))
	# 0.0-1.6 s: arrows gather into the silhouette
	for i in _arrows.size():
		var d := 0.02 * i
		t.tween_property(_arrows[i], "modulate:a", 1.0, 0.25).set_delay(d)
		t.tween_property(_arrows[i], "position", _targets[i], 1.3).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_arrows[i], "modulate:a", 0.0, 0.6).set_delay(1.5 + d * 0.5)
	# 1.4-2.9 s: the real image appears through the mist
	t.tween_property(_mist_back, "modulate:a", 0.6, 1.0).set_delay(0.9)
	t.tween_property(_mist_front, "modulate:a", 0.45, 1.0).set_delay(1.1)
	t.tween_property(parts.body, "modulate:a", 1.0, 1.5).set_delay(1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_mist_back, "modulate:a", 0.35, 1.4).set_delay(2.4)
	t.tween_property(_mist_front, "modulate:a", 0.22, 1.4).set_delay(2.6)
	# 2.3-3.5 s: white rim light passes
	t.tween_property(_rim, "modulate:a", 0.55, 0.5).set_delay(2.3)
	t.tween_property(_rim, "modulate:a", 0.0, 0.8).set_delay(2.8)
	# whole time: slow camera push + parallax
	t.tween_property(parts.camera, "scale", Vector2.ONE, AWAKEN_TOTAL - 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(_mist_back, "position", Vector2(-24, 0), AWAKEN_TOTAL)
	t.tween_property(_mist_front, "position:x", 36.0, AWAKEN_TOTAL)
	# 3.4-4.8 s: one breath
	t.tween_property(parts.body, "scale", Vector2(1.015, 1.015), 0.7).set_delay(3.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.body, "scale", Vector2.ONE, 0.7).set_delay(4.1).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_finish).set_delay(AWAKEN_TOTAL)


func idle_tweens() -> Array[Tween]:
	var b := create_tween().set_loops()
	b.tween_property(parts.body, "scale", Vector2(1.01, 1.01), 2.6).set_trans(Tween.TRANS_SINE)
	b.tween_property(parts.body, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE)
	var m := create_tween().set_loops()
	m.tween_property(_mist_front, "position:x", _mist_front.position.x + 30.0, 6.0).set_trans(Tween.TRANS_SINE)
	m.tween_property(_mist_front, "position:x", _mist_front.position.x - 30.0, 6.0).set_trans(Tween.TRANS_SINE)
	return [b, m]
