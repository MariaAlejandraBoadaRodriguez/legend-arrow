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
	Ui.full_rect(pad)
	add_child(pad)
	content = Ui.vbox(Palette.SPACE * 2)
	pad.add_child(content)
	build()
	# Keyboard/controller users start on the first focusable control.
	var first := _first_focusable(self)
	if first != null:
		Ui.focus_later(first)


func build() -> void:
	pass


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
