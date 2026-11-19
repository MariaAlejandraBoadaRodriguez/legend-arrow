extends Screen
## Collection grid. Locked creatures show only a faint still silhouette.


func build() -> void:
	var p := Game.progression
	var ids := Game.campaign.creature_ids()
	content.add_child(Ui.top_bar("BESTIARY_TITLE", tr("N_AWAKENED") % [p.unlocked_count(), ids.size()], Game.back))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := Ui.vbox(Palette.SPACE * 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for w in Game.campaign.worlds:
		var head := Ui.label(tr("WORLD_N_NAME") % [int(w.number), tr(w.name_key)], "HeadingLabel", HORIZONTAL_ALIGNMENT_LEFT)
		col.add_child(head)
		var grid := GridContainer.new()
		grid.name = "Grid_%s" % w.id
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", Palette.SPACE * 2)
		grid.add_theme_constant_override("v_separation", Palette.SPACE * 2)
		col.add_child(grid)
		for cr in Game.campaign.creatures_in_world(w.id):
			grid.add_child(_tile(cr.id))
	content.add_child(Ui.button("CONTINUE_ADVENTURE", _continue, true, "ContinueAdventure"))


## Grid thumbnails stay still (v0.2 §4): a light texture per tile, never a
## rendered rig, so 100 tiles stay cheap.
func _tile(cid: String) -> Control:
	var unlocked := Game.progression.is_creature_unlocked(cid)
	var btn := Button.new()
	btn.name = "Tile_%s" % cid
	btn.custom_minimum_size = Vector2(0, UiTheme.fs(230))  # grows with Larger text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not unlocked
	btn.pressed.connect(func(): Game.go("creature_detail", {"creature_id": cid}))
	var col := Ui.vbox(4)
	Ui.full_rect(col)
	col.offset_top = 8
	col.offset_bottom = -8
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var thumb := TextureRect.new()
	thumb.name = "Thumb"
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var world := Game.campaign.world_of(cid)
	var photo := SilhouetteRig.thumb_for(cid) if unlocked else null
	if photo != null:
		thumb.texture = photo          # still photoreal thumbnail (grid stays still)
	elif ResourceLoader.exists(SilhouetteRig.path_for(cid)):
		thumb.texture = load(SilhouetteRig.path_for(cid))
		thumb.modulate = SilhouetteRig.WORLD_TINT.get(world, Palette.INK) if unlocked else Color(Palette.GRID, 0.8)
	col.add_child(thumb)
	var name_label := Ui.label(Game.campaign.creature(cid).name_key if unlocked else "LOCKED", "CaptionLabel")
	name_label.name = "Locked" if not unlocked else "Name"
	name_label.add_theme_font_size_override("font_size", UiTheme.fs(UiTheme.SIZE_CAPTION - 2))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	return btn


func _continue() -> void:
	Game.reset_to("home")
	Game.go("level_select")  # the world of the next dragon to awaken
