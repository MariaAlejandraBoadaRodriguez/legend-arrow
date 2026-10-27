class_name CreatureStage
extends Control
## Shows one creature rig rendered into its own transparent SubViewport, so
## fades and tints apply to the finished image. Only one full rig is resident
## per stage; freeing the stage releases it (spec §14).

const VIEW := Vector2i(760, 700)
const FEET := Vector2(430, 650)

var rig: CreatureRig
var creature_id := ""
var _viewport: SubViewport
var _texture: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Loads the creature's art scene. Returns false if the metadata or art is missing.
## `still` renders a single frame (collection thumbnails stay still, spec §9).
func show_creature(cid: String, reduce_motion := false, still := false) -> bool:
	clear()
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % cid))
	if typeof(meta) != TYPE_DICTIONARY or not ResourceLoader.exists(str(meta.get("art", ""))):
		return false
	creature_id = cid
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if still else SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_texture = TextureRect.new()
	_texture.texture = _viewport.get_texture()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.full_rect(_texture)
	add_child(_texture)
	rig = load(meta.art).instantiate()
	rig.reduce_motion = reduce_motion
	rig.fade_target = _texture
	rig.position = FEET
	_viewport.add_child(rig)
	return true


## Starts the idle loop once the rig is in the tree.
func start_idle() -> void:
	if rig == null:
		return
	if rig.is_node_ready():
		rig.start_idle()
	else:
		rig.ready.connect(rig.start_idle, CONNECT_ONE_SHOT)


## Tint/alpha of the composited creature (e.g. a faint locked silhouette).
func set_tint(c: Color) -> void:
	if _texture != null:
		_texture.modulate = c


func clear() -> void:
	if rig != null:
		rig.stop()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	rig = null
	_viewport = null
	_texture = null
	creature_id = ""
