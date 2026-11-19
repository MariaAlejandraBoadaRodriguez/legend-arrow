class_name SilhouetteRig
extends CreatureRig
## Interim art for roster dragons that have no layered rig yet (D-47): the
## dragon's own silhouette, cut from its real image by tools/build_campaign.py
## (assets/creatures/silhouettes/<id>.png), tinted with its world's colour.
## Same lifecycle as every rig (awaken / skip / idle / reduced motion).
## Milestone D replaces it with the photoreal image.

const DIR := "res://assets/creatures/silhouettes"
## One restrained tint per world, following the roster's colour progression
## (muted -> vivid -> jewel -> legendary).
const WORLD_TINT := {
	"w01": Color("#5E6B5A"), "w02": Color("#6A6170"), "w03": Color("#2F7A78"), "w04": Color("#3E6E9E"),
	"w05": Color("#2F5FA8"), "w06": Color("#9A4A2E"), "w07": Color("#1F7F86"), "w08": Color("#5A4BA0"),
	"w09": Color("#3C2F5E"), "w10": Color("#9C7A2E"),
}
const BOX := Vector2(700, 620)   # fits the stage view above FEET

var dragon_id := ""
var world_id := ""
var _sprite: Sprite2D


static func path_for(id: String) -> String:
	return DIR.path_join(id + ".png")


## Still grid thumbnail: the photoreal thumbnail once imported (D-49), else
## null (callers then show the tinted silhouette).
static func thumb_for(id: String) -> Texture2D:
	var p := "res://assets/creatures/thumbs/%s.webp" % id
	return load(p) if ResourceLoader.exists(p) else null


func build() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Silhouette"
	_sprite.centered = false
	var tex: Texture2D = load(path_for(dragon_id)) if ResourceLoader.exists(path_for(dragon_id)) else null
	_sprite.texture = tex
	_sprite.modulate = WORLD_TINT.get(world_id, Palette.INK)
	if tex != null:
		var s := minf(BOX.x / tex.get_width(), BOX.y / tex.get_height())
		_sprite.scale = Vector2(s, s)
		_sprite.position = Vector2(-tex.get_width() * s * 0.5, -tex.get_height() * s)  # feet on the origin
	var pivot := add_part("body", group, Vector2.ZERO)
	pivot.add_child(_sprite)


func pose_dormant() -> void:
	parts.body.scale = Vector2(0.94, 0.94)


func pose_final() -> void:
	parts.body.scale = Vector2.ONE


func signature(t: Tween) -> void:
	t.tween_property(parts.body, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.body, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE)


func idle_tweens() -> Array[Tween]:
	var t := create_tween().set_loops()
	t.tween_property(parts.body, "scale", Vector2(1.012, 1.012), 2.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(parts.body, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE)
	return [t]
