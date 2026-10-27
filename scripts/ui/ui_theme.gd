class_name UiTheme
extends RefCounted
## Builds the single shared Theme from Palette tokens. Variations:
## PrimaryButton, FlatLinkButton, TitleLabel, HeadingLabel, CaptionLabel,
## CardPanel, SheetPanel.

const FONT_REGULAR := "res://assets/fonts/Inter-Regular.ttf"
const FONT_SEMIBOLD := "res://assets/fonts/Inter-SemiBold.ttf"

const SIZE_BODY := 30
const SIZE_CAPTION := 24
const SIZE_HEADING := 40
const SIZE_TITLE := 60

static var _cached: Theme


static func get_theme() -> Theme:
	if _cached == null:
		_cached = build()
	return _cached


static func build() -> Theme:
	var t := Theme.new()
	var regular: Font = load(FONT_REGULAR)
	var semibold: Font = load(FONT_SEMIBOLD)
	t.default_font = regular
	t.default_font_size = SIZE_BODY

	# Labels
	t.set_color("font_color", "Label", Palette.INK)
	for v in ["TitleLabel", "HeadingLabel", "CaptionLabel"]:
		t.set_type_variation(v, "Label")
	t.set_font("font", "TitleLabel", regular)
	t.set_font_size("font_size", "TitleLabel", SIZE_TITLE)
	t.set_font("font", "HeadingLabel", semibold)
	t.set_font_size("font_size", "HeadingLabel", SIZE_HEADING)
	t.set_font_size("font_size", "CaptionLabel", SIZE_CAPTION)
	t.set_color("font_color", "CaptionLabel", Palette.SECONDARY)

	# Buttons: secondary (outlined) by default.
	var focus := _box(Color(0, 0, 0, 0), Palette.FOCUS, 4, 16)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox("normal", "Button", _box(Palette.BACKGROUND, Palette.ACCENT, 2, 14))
	t.set_stylebox("hover", "Button", _box(Palette.CARD, Palette.ACCENT, 2, 14))
	t.set_stylebox("pressed", "Button", _box(Palette.GRID, Palette.ACCENT, 2, 14))
	t.set_stylebox("disabled", "Button", _box(Palette.BACKGROUND, Palette.GRID, 2, 14))
	t.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", Palette.INK)
	t.set_color("font_disabled_color", "Button", Palette.SECONDARY)
	t.set_font("font", "Button", semibold)
	t.set_constant("h_separation", "Button", 12)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(Palette.ACCENT, Palette.ACCENT, 0, 14))
	t.set_stylebox("hover", "PrimaryButton", _box(Palette.ACCENT.darkened(0.08), Palette.ACCENT, 0, 14))
	t.set_stylebox("pressed", "PrimaryButton", _box(Palette.FOCUS, Palette.FOCUS, 0, 14))
	t.set_stylebox("disabled", "PrimaryButton", _box(Palette.GRID, Palette.GRID, 0, 14))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "PrimaryButton", Palette.ON_ACCENT)

	t.set_type_variation("FlatLinkButton", "Button")
	var flat := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "FlatLinkButton", flat)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "FlatLinkButton", Palette.SECONDARY)
	t.set_font("font", "FlatLinkButton", regular)
	t.set_font_size("font_size", "FlatLinkButton", SIZE_CAPTION)

	# Panels
	t.set_stylebox("panel", "PanelContainer", _box(Palette.CARD, Palette.CARD, 0, 18, 24))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _box(Palette.CARD, Palette.GRID, 1, 18, 20))
	t.set_type_variation("SheetPanel", "PanelContainer")
	t.set_stylebox("panel", "SheetPanel", _box(Palette.BACKGROUND, Palette.GRID, 1, 24, 40))

	# Sliders and toggles
	var track := _box(Palette.GRID, Palette.GRID, 0, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(Palette.ACCENT, Palette.ACCENT, 0, 4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(36, Palette.ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _dot(40, Palette.FOCUS))
	t.set_stylebox("focus", "HSlider", focus)
	t.set_color("font_color", "CheckButton", Palette.INK)
	t.set_stylebox("focus", "CheckButton", focus)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_icon("checked_disabled", "CheckButton", _switch(true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false))
	t.set_color("font_color", "OptionButton", Palette.INK)
	return t


static func _box(bg: Color, border: Color, border_w: int, radius: int, margin: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 6
	s.content_margin_right = margin + 6
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.anti_aliasing = true
	return s


## Pill switch: accent track with the knob right when on, light track when off.
static func _switch(on: bool) -> ImageTexture:
	var w := 88
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Palette.ACCENT if on else Palette.GRID
	var r := h / 2.0
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, r, w - r)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var c := Color(track, a)
			var dk := Vector2(x + 0.5 - knob_x, y + 0.5 - r).length()
			var ka := clampf(r - 5.0 - dk, 0.0, 1.0)
			c = c.blend(Color(Palette.BACKGROUND, ka))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _dot(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)
