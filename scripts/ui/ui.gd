class_name Ui
extends RefCounted
## Tiny widget factory so screens stay declarative. Text arguments may be
## translation keys: Controls auto-translate them and follow locale changes.


static func label(text: String, variation: String = "", align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_press: Callable, primary := false, name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "PrimaryButton" if primary else ""
	b.custom_minimum_size = Vector2(0, Palette.TOUCH_MIN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if name != "":
		b.name = name
	b.pressed.connect(on_press)
	return b


static func link(text: String, on_press: Callable, name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "FlatLinkButton"
	b.custom_minimum_size = Vector2(Palette.TOUCH_MIN, Palette.TOUCH_MIN)
	if name != "":
		b.name = name
	b.pressed.connect(on_press)
	return b


## Square icon-style button (text glyph) with a 48 dp touch target.
static func icon_button(glyph: String, on_press: Callable, tooltip := "", name := "") -> Button:
	var b := link(glyph, on_press, name)
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", Palette.INK)
	b.tooltip_text = tooltip
	return b


static func vbox(separation := Palette.SPACE * 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := Palette.SPACE * 2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	return m


static func spacer(height := 0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Header row: [back]  title/subtitle  [action]
static func top_bar(title: String, subtitle: String, on_back: Callable, action: Control = null) -> Control:
	var row := hbox(0)
	var back := icon_button("‹", on_back, "BACK", "BackButton") if on_back.is_valid() else spacer()
	back.custom_minimum_size = Vector2(Palette.TOUCH_MIN, Palette.TOUCH_MIN)
	row.add_child(back)
	var titles := vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := label(title, "HeadingLabel")
	t.name = "Title"
	titles.add_child(t)
	if subtitle != "":
		var st := label(subtitle, "CaptionLabel")
		st.name = "Subtitle"
		titles.add_child(st)
	row.add_child(titles)
	if action == null:
		action = spacer()
		action.custom_minimum_size = Vector2(Palette.TOUCH_MIN, Palette.TOUCH_MIN)
	row.add_child(action)
	return row


## Simple segmented progress dots: `done` of `total`.
static func progress_dots(done: int, total: int) -> HBoxContainer:
	var row := hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in total:
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(56, 8)
		bar.color = Palette.ACCENT if i < done else Palette.GRID
		row.add_child(bar)
	return row


## Focuses a control on the next frame if it is still on screen by then.
static func focus_later(c: Control) -> void:
	var grab := func():
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()
	grab.call_deferred()
