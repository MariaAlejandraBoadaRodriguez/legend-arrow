extends Screen
## Audio buses, accessibility, language and info links. Every change is
## applied and saved immediately.

const LANGS := ["", "en", "es"]
const LANG_KEYS := ["LANGUAGE_SYSTEM", "LANGUAGE_EN", "LANGUAGE_ES"]


func build() -> void:
	content.add_child(Ui.top_bar("SETTINGS_TITLE", "", Game.back))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := Ui.vbox(Palette.SPACE * 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var s := Game.settings()

	col.add_child(_section("SETTINGS_AUDIO"))
	col.add_child(_slider("SETTINGS_MUSIC", "music_volume", s.music_volume))
	col.add_child(_slider("SETTINGS_SFX", "sfx_volume", s.sfx_volume))
	col.add_child(_slider("SETTINGS_CREATURE", "creature_volume", s.creature_volume))

	col.add_child(_section("SETTINGS_ACCESSIBILITY"))
	col.add_child(_toggle("SETTINGS_REDUCE_MOTION", "SETTINGS_REDUCE_MOTION_DESC", "reduce_motion", s.reduce_motion))
	col.add_child(_toggle("SETTINGS_HAPTICS", "SETTINGS_HAPTICS_DESC", "haptics", s.haptics))

	col.add_child(_section("SETTINGS_LANGUAGE"))
	var lang := OptionButton.new()
	lang.name = "LanguageOption"
	lang.custom_minimum_size = Vector2(0, Palette.TOUCH_MIN)
	for i in LANGS.size():
		lang.add_item(LANG_KEYS[i], i)
	lang.selected = maxi(0, LANGS.find(s.language))
	lang.item_selected.connect(_on_language)
	col.add_child(lang)

	col.add_child(Ui.spacer(Palette.SPACE))
	col.add_child(_row_link("SETTINGS_REPLAY_TUTORIAL", func(): Game.go("tutorial"), "ReplayTutorial"))
	col.add_child(_row_link("SETTINGS_PRIVACY_OPTIONS", _privacy_options, "PrivacyOptions"))
	col.add_child(_row_link("SETTINGS_PRIVACY_POLICY", func(): Game.go("privacy"), "PrivacyPolicy"))
	col.add_child(_row_link("SETTINGS_CREDITS", func(): Dialog.open(self, "SETTINGS_CREDITS", "CREDITS_BODY", [["CONTINUE", func(): pass, true]], "CreditsDialog"), "Credits"))


func _section(key: String) -> Label:
	var l := Ui.label(key, "HeadingLabel", HORIZONTAL_ALIGNMENT_LEFT)
	l.add_theme_font_size_override("font_size", UiTheme.SIZE_BODY + 2)
	return l


func _slider(key: String, setting: String, value: float) -> Control:
	var col := Ui.vbox(4)
	var top := Ui.hbox()
	var l := Ui.label(key, "", HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	var pct := Ui.label("%d%%" % roundi(value * 100), "CaptionLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	pct.custom_minimum_size = Vector2(90, 0)
	top.add_child(pct)
	col.add_child(top)
	var slider := HSlider.new()
	slider.name = "Slider_%s" % setting
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 64)
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % roundi(v * 100)
		Game.set_setting(setting, v))
	col.add_child(slider)
	return col


func _toggle(key: String, desc: String, setting: String, value: bool) -> Control:
	var row := Ui.hbox()
	var texts := Ui.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(Ui.label(key, "", HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(Ui.label(desc, "CaptionLabel", HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(texts)
	var check := CheckButton.new()
	check.name = "Toggle_%s" % setting
	check.button_pressed = value
	check.custom_minimum_size = Vector2(Palette.TOUCH_MIN, Palette.TOUCH_MIN)
	check.toggled.connect(func(on): Game.set_setting(setting, on))
	row.add_child(check)
	return row


func _row_link(key: String, cb: Callable, node_name: String) -> Button:
	var b := Ui.button(key, cb, false, node_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return b


## Opens Google's consent form when the SDK says one is required in this
## region; otherwise our own privacy page.
func _privacy_options() -> void:
	if not Game.ads.consent.show_privacy_options():
		Game.go("privacy")


func _on_language(index: int) -> void:
	Game.set_setting("language", LANGS[index])
	# Formatted strings were built in the old language; rebuild the page.
	Game.go("settings", {}, true)


func handle_back() -> bool:
	var d := Dialog.top(self)
	if d != null:
		d.close()
		return true
	return false
