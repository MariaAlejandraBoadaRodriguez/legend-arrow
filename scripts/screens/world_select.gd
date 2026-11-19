extends Screen
## The ten worlds in difficulty order (v0.2 §2). Open worlds show their
## atmosphere thumbnail, awakened count and stars; locked worlds show the
## silhouettes of their dragons and what opens them, with no pressure or timer.


func build() -> void:
	var p := Game.progression
	var c := Game.campaign
	content.add_child(Ui.top_bar("WORLDS_TITLE", tr("TOTAL_STARS") % [p.total_stars(), 3 * c.level_ids().size()], Game.back))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := Ui.vbox(Palette.SPACE * 2)
	col.name = "WorldList"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for w in c.worlds:
		col.add_child(_card(w))


func _card(w: Dictionary) -> Control:
	var p := Game.progression
	var open := p.is_world_unlocked(w.id)
	var btn := Button.new()
	btn.name = "World_%s" % w.id
	btn.custom_minimum_size = Vector2(0, 232)
	btn.disabled = not open
	btn.pressed.connect(func(): Game.go("level_select", {"world_id": w.id}))
	var row := Ui.hbox(Palette.SPACE * 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.full_rect(row)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = 16
	row.offset_bottom = -16
	btn.add_child(row)
	var thumb := WorldThumb.new(w.id, not open)
	thumb.name = "Thumb"
	thumb.custom_minimum_size = Vector2(200, 0)
	row.add_child(thumb)
	var info := Ui.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := Ui.label(tr("WORLD_N_NAME") % [int(w.number), tr(w.name_key)], "", HORIZONTAL_ALIGNMENT_LEFT)
	title.name = "Name"
	info.add_child(title)
	var levels := Game.campaign.levels_in_world(w.id)
	var status := Ui.label("", "CaptionLabel", HORIZONTAL_ALIGNMENT_LEFT)
	status.name = "Status"
	if open:
		status.text = tr("WORLD_PROGRESS") % [p.world_completed_count(w.id), levels.size(), p.stars_in(levels), 3 * levels.size()]
	else:
		var prev: Dictionary = Game.campaign.worlds[Game.campaign.world_index(w.id) - 1]
		status.text = tr("WORLD_LOCKED_HINT") % tr(prev.name_key)
	info.add_child(status)
	if not open:
		info.add_child(_silhouettes(w.id))
	return btn


## Locked world: its dragons as small faint silhouettes.
func _silhouettes(world_id: String) -> Control:
	var grid := GridContainer.new()
	grid.name = "Silhouettes"
	grid.columns = 5
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cr in Game.campaign.creatures_in_world(world_id):
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(52, 40)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(SilhouetteRig.path_for(cr.id)):
			t.texture = load(SilhouetteRig.path_for(cr.id))
		t.modulate = Palette.SECONDARY
		t.modulate.a = 0.55
		grid.add_child(t)
	return grid
