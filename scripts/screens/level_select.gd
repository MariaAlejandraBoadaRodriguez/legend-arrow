extends Screen
## One world's ten dragons (v0.2 §2/§3): a tile per dragon with its
## silhouette, name, best stars and best time; locked dragons show only a
## faint silhouette. Play opens the selected (default: next) level. The
## Worlds button opens the world list. params: world_id (default: the world
## of the next level to play).

var world_id := ""
var selected := ""
var _grid: GridContainer
var _play: Button


func build() -> void:
	var p := Game.progression
	var c := Game.campaign
	var next := p.next_level()
	world_id = str(params.get("world_id", c.world_of(c.creature_of_level(next)) if next != "" else c.worlds[0].id))
	if not p.is_world_unlocked(world_id):
		world_id = c.worlds[0].id
	var levels := c.levels_in_world(world_id)
	selected = _default_selection()
	var w := c.world(world_id)
	var worlds_btn := Ui.link("WORLDS_TITLE", func(): Game.go("world_select"), "WorldsButton")
	content.add_child(Ui.top_bar(tr("WORLD_N_NAME") % [int(w.number), tr(w.name_key)],
		tr("WORLD_PROGRESS") % [p.world_completed_count(world_id), levels.size(), p.stars_in(levels), 3 * levels.size()],
		Game.back, worlds_btn))
	var total := Ui.label(tr("TOTAL_STARS") % [p.total_stars(), 3 * c.level_ids().size()], "CaptionLabel")
	total.name = "TotalStars"
	content.add_child(total)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "DragonGrid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", Palette.SPACE * 2)
	_grid.add_theme_constant_override("v_separation", Palette.SPACE * 2)
	scroll.add_child(_grid)
	for cr in c.creatures_in_world(world_id):
		_grid.add_child(_tile(cr))
	_play = Ui.button("", _on_play, true, "PlayButton")
	content.add_child(_play)
	_update_play()


func _default_selection() -> String:
	var p := Game.progression
	for l in Game.campaign.levels_in_world(world_id):
		if p.is_level_unlocked(l) and not p.is_level_completed(l):
			return Game.campaign.creature_of_level(l)
	return Game.campaign.creatures_in_world(world_id)[0].id


func _tile(cr: Dictionary) -> Control:
	var p := Game.progression
	var level_id: String = cr.levels[0]
	var open := p.is_level_unlocked(level_id)
	var done := p.is_level_completed(level_id)
	var btn := Button.new()
	btn.name = "Card_%s" % cr.id
	btn.custom_minimum_size = Vector2(0, 300)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.toggle_mode = true
	btn.button_pressed = cr.id == selected
	btn.disabled = not open
	btn.pressed.connect(_select.bind(cr.id))
	var col := Ui.vbox(4)
	Ui.full_rect(col)
	col.offset_top = 12
	col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var thumb := TextureRect.new()
	thumb.name = "Silhouette"
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var photo := SilhouetteRig.thumb_for(cr.id) if done else null
	if photo != null:
		thumb.texture = photo          # awakened: its real image
	elif ResourceLoader.exists(SilhouetteRig.path_for(cr.id)):
		thumb.texture = load(SilhouetteRig.path_for(cr.id))
		thumb.modulate = SilhouetteRig.WORLD_TINT.get(world_id, Palette.INK) if done else (Palette.SECONDARY if open else Palette.GRID)
	col.add_child(thumb)
	var name_label := Ui.label(cr.name_key, "CaptionLabel")
	name_label.name = "Name"
	col.add_child(name_label)
	var line := Ui.hbox(Palette.SPACE)
	line.name = "Best_%s" % level_id
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StarRow.new(p.best_stars(level_id), 26.0)
	st.name = "Stars"
	line.add_child(st)
	var bt := p.best_time_ms(level_id)
	var tl := Ui.label(SpeedTimer.format_ms(bt) if bt >= 0 else ("" if open else tr("LOCKED")), "CaptionLabel")
	tl.name = "BestTime"
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(tl)
	col.add_child(line)
	return btn


func _select(id: String) -> void:
	selected = id
	for child in _grid.get_children():
		if child is Button:
			child.button_pressed = child.name == "Card_%s" % id
	_update_play()


## The level Play opens: the selected dragon's level when it is open.
func target_level() -> String:
	var cr := Game.campaign.creature(selected)
	if cr.is_empty() or cr.world != world_id:
		return ""
	var l: String = cr.levels[0]
	return l if Game.progression.is_level_unlocked(l) else ""


func _update_play() -> void:
	var l := target_level()
	_play.disabled = l == ""
	if l == "":
		_play.text = tr("LOCKED")
	else:
		var verb := "REPLAY_DRAGON" if Game.progression.is_level_completed(l) else "PLAY_DRAGON"
		_play.text = tr(verb) % tr(Game.campaign.creature(selected).name_key)


func _on_play() -> void:
	var l := target_level()
	if l != "":
		Game.go("puzzle", {"level_id": l})
