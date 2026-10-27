extends Screen
## Home: hero creature, title, Play / Bestiary / Settings.


func build() -> void:
	var stage := CreatureStage.new()
	stage.name = "HeroStage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 520)
	content.add_child(stage)
	stage.show_creature(Game.campaign.creatures[0].id, Game.reduce_motion())
	stage.start_idle()
	var title := Ui.label("APP_NAME", "TitleLabel")
	title.name = "AppTitle"
	title.uppercase = true
	title.add_theme_constant_override("outline_size", 0)
	content.add_child(title)
	content.add_child(Ui.label("APP_TAGLINE", "CaptionLabel"))
	content.add_child(Ui.spacer(Palette.SPACE * 3))
	content.add_child(Ui.button("HOME_PLAY", _on_play, true, "PlayButton"))
	content.add_child(Ui.button("HOME_BESTIARY", func(): Game.go("bestiary"), false, "BestiaryButton"))
	var settings := Ui.link("HOME_SETTINGS", func(): Game.go("settings"), "SettingsButton")
	settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(settings)


func _on_play() -> void:
	if not Game.progression.data.tutorial_done:
		Game.go("tutorial")
	else:
		Game.go("level_select")
