class_name StorageBanner
extends Control
## Non-blocking "Storage full" message (0.2.1, D-52). Game mounts one over
## the screen host; it follows Game.storage_message_shown(): visible while a
## save failed on full storage or free space is critically low, never during
## an awakening, gone on its own once saving works again. It never takes
## input, so play continues underneath.

const TEXT_KEY := "STORAGE_FULL"


func _init() -> void:
	name = "StorageBanner"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	visible = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	# Just below the screen header (screen padding + one touch-size row), so
	# the back button and title stay visible.
	var pad := Ui.margin(Palette.SPACE * 2)
	pad.add_theme_constant_override("margin_top", Palette.SPACE * 5 + Palette.TOUCH_MIN + Palette.SPACE)
	pad.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	var panel := PanelContainer.new()
	panel.name = "StoragePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.INK
	box.set_corner_radius_all(Palette.SPACE * 2)
	box.content_margin_left = Palette.SPACE * 3
	box.content_margin_right = Palette.SPACE * 3
	box.content_margin_top = Palette.SPACE * 2
	box.content_margin_bottom = Palette.SPACE * 2
	panel.add_theme_stylebox_override("panel", box)
	pad.add_child(panel)
	var text := Ui.label(TEXT_KEY)
	text.name = "StorageMessage"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Palette.ON_ACCENT)
	panel.add_child(text)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var show := Game.storage_message_shown()
	if show != visible:
		visible = show
