class_name Screen
extends Control
## Base for full-screen pages. Subclasses build their UI in build() and may
## override handle_back(), on_leave() and on_app_paused().

var params: Dictionary = {}
var content: VBoxContainer   # padded column most screens fill


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var pad := Ui.margin(Palette.SPACE * 5)
	pad.name = "Pad"
	Ui.full_rect(pad)
	add_child(pad)
	# Wide screens (4:3 tablets): keep a centred column instead of stretching
	# buttons edge to edge (v0.2 §8).
	resized.connect(_fit_width.bind(pad))
	_fit_width(pad)
	content = Ui.vbox(Palette.SPACE * 2)
	pad.add_child(content)
	build()
	# Keyboard/controller users start on the first focusable control.
	var first := _first_focusable(self)
	if first != null:
		Ui.focus_later(first)


func build() -> void:
	pass


const MAX_CONTENT_WIDTH := 900.0


func _fit_width(pad: MarginContainer) -> void:
	var side := maxf(Palette.SPACE * 5, (size.x - MAX_CONTENT_WIDTH) / 2.0)
	pad.add_theme_constant_override("margin_left", int(side))
	pad.add_theme_constant_override("margin_right", int(side))


## Return true when the Back press was consumed (e.g. an overlay closed).
func handle_back() -> bool:
	return false


func find(node_name: String) -> Node:
	return find_child(node_name, true, false)


func _first_focusable(n: Node) -> Control:
	for child in n.get_children():
		if child is BaseButton and (child as Control).visible and (child as Control).focus_mode != Control.FOCUS_NONE:
			return child
		var deeper := _first_focusable(child)
		if deeper != null:
			return deeper
	return null
