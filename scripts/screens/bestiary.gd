extends Screen
## Collection grid. Locked creatures show only a faint still silhouette.


func build() -> void:
	var p := Game.progression
	var ids := Game.campaign.creature_ids()
	content.add_child(Ui.top_bar("BESTIARY_TITLE", tr("N_AWAKENED") % [p.unlocked_count(), ids.size()], Game.back))
	var dots := Ui.progress_dots(p.unlocked_count(), ids.size())
	content.add_child(dots)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Palette.SPACE * 2)
	grid.add_theme_constant_override("v_separation", Palette.SPACE * 2)
	scroll.add_child(grid)
	for cid in ids:
		grid.add_child(_tile(cid))
	content.add_child(Ui.button("CONTINUE_ADVENTURE", _continue, true, "ContinueAdventure"))


func _tile(cid: String) -> Control:
	var unlocked := Game.progression.is_creature_unlocked(cid)
	var btn := Button.new()
	btn.name = "Tile_%s" % cid
	btn.custom_minimum_size = Vector2(300, 300)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not unlocked
	btn.pressed.connect(func(): Game.go("creature_detail", {"creature_id": cid}))
	var col := Ui.vbox(4)
	Ui.full_rect(col)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var stage := CreatureStage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stage)
	stage.show_creature(cid, true, true)
	if not unlocked:
		stage.set_tint(Color(0.55, 0.58, 0.6, 0.3))
	var name_label := Ui.label(Game.campaign.creature(cid).name_key, "CaptionLabel")
	col.add_child(name_label)
	if not unlocked:
		var lock := Ui.label("LOCKED", "CaptionLabel")
		lock.name = "Locked"
		col.add_child(lock)
	col.add_child(Ui.spacer(8))
	return btn


func _continue() -> void:
	Game.reset_to("home")
	Game.go("level_select")
