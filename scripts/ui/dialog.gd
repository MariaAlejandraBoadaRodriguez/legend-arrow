class_name Dialog
extends Control
## Modal sheet over a scrim. Blocks input to everything behind it (spec §13:
## never select through modal overlays). Closed by its buttons or Back.

signal closed

var _panel: PanelContainer


## buttons: [[text, callable, primary(bool), node_name], ...]. Each button
## closes the dialog before running its callable.
static func open(parent: Control, title: String, body: String, buttons: Array, dialog_name := "Dialog") -> Dialog:
	var d := Dialog.new()
	d.name = dialog_name
	d._build(title, body, buttons)
	parent.add_child(d)
	return d


func _build(title: String, body: String, buttons: Array) -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.full_rect(scrim)
	add_child(scrim)
	var center := CenterContainer.new()
	Ui.full_rect(center)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "SheetPanel"
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var col := Ui.vbox(Palette.SPACE * 2)
	_panel.add_child(col)
	var t := Ui.label(title, "HeadingLabel")
	t.name = "DialogTitle"
	col.add_child(t)
	if body != "":
		var b := Ui.label(body, "CaptionLabel")
		b.name = "DialogBody"
		col.add_child(b)
	col.add_child(Ui.spacer(Palette.SPACE))
	var first: Button
	for spec in buttons:
		var cb: Callable = spec[1]
		var btn := Ui.button(spec[0], func(): close(); cb.call(), spec.size() > 2 and spec[2], spec[3] if spec.size() > 3 else "")
		col.add_child(btn)
		if first == null:
			first = btn
	if first != null:
		Ui.focus_later(first)


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


## Finds an open dialog under `parent` (screens use this for Back handling).
static func top(parent: Node) -> Dialog:
	for i in range(parent.get_child_count() - 1, -1, -1):
		var c := parent.get_child(i)
		if c is Dialog and not c.is_queued_for_deletion():
			return c
	return null
