extends GutTest
## WCAG AA: 4.5:1 for normal text, 3:1 for large text and UI components.


func _check(fg: Color, bg: Color, minimum: float, label: String) -> void:
	var ratio := Palette.contrast(fg, bg)
	assert_gte(ratio, minimum, "%s contrast %.2f >= %.1f" % [label, ratio, minimum])


func test_known_reference_ratio() -> void:
	assert_almost_eq(Palette.contrast(Color.BLACK, Color.WHITE), 21.0, 0.01)


func test_text_pairs_meet_aa() -> void:
	_check(Palette.INK, Palette.BACKGROUND, 4.5, "ink on background")
	_check(Palette.INK, Palette.CARD, 4.5, "ink on card")
	_check(Palette.SECONDARY, Palette.BACKGROUND, 4.5, "secondary on background")
	_check(Palette.SECONDARY, Palette.CARD, 4.5, "secondary on card")
	_check(Palette.ON_ACCENT, Palette.ACCENT, 4.5, "white on accent button")
	_check(Palette.ACCENT, Palette.BACKGROUND, 4.5, "accent text on background")
	_check(Palette.ERROR, Palette.BACKGROUND, 4.5, "error text on background")


func test_ui_components_meet_3_to_1() -> void:
	_check(Palette.FOCUS, Palette.BACKGROUND, 3.0, "focus outline")
	_check(Palette.ACCENT, Palette.CARD, 3.0, "active arrow on card")
	_check(Palette.INK, Palette.BACKGROUND, 3.0, "arrows on board")


func test_grid_is_decorative_only() -> void:
	# The dot grid is intentionally low contrast; it must never be the only cue.
	assert_lt(Palette.contrast(Palette.GRID, Palette.BACKGROUND), 3.0)
