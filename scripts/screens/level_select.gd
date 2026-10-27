extends Screen
## Realm tabs, creature cards with "n of 2" progress, and one Play button.

var realm := ""
var selected := ""
var _tabs: HBoxContainer
var _list: VBoxContainer
var _play: Button
var _title: Label


func build() -> void:
	var p := Game.progression
	var next := p.next_level()
	selected = str(params.get("creature_id", Game.campaign.creature_of_level(next) if next != "" else Game.campaign.creatures[0].id))
	realm = Game.campaign.creature(selected).realm
	var bar := Ui.top_bar("", "LEVEL_SELECT_SUBTITLE", Game.back)
	_title = bar.find_child("Title", true, false)
	content.add_child(bar)
	_tabs = Ui.hbox(Palette.SPACE)
	_tabs.name = "RealmTabs"
	content.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = Ui.vbox(Palette.SPACE * 2)
	_list.name = "CreatureList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_play = Ui.button("", _on_play, true, "PlayButton")
	content.add_child(_play)
	_refresh()


func _refresh() -> void:
	var c := Game.campaign
	_title.text = c.realms.filter(func(r): return r.id == realm)[0].name_key
	for child in _tabs.get_children():
		child.queue_free()
	for r in c.realms:
		var tab := Ui.link(r.name_key, _select_realm.bind(r.id), "Tab_%s" % r.id)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_color_override("font_color", Palette.ACCENT if r.id == realm else Palette.SECONDARY)
		_tabs.add_child(tab)
	for child in _list.get_children():
		child.queue_free()
	var in_realm := c.creatures_in_realm(realm)
	if in_realm.is_empty():
		_list.add_child(Ui.label("COMING_SOON", "CaptionLabel"))
	for cr in in_realm:
		_list.add_child(_card(cr))
	_update_play()


func _card(cr: Dictionary) -> Control:
	var p := Game.progression
	var unlocked_to_play := p.is_level_unlocked(cr.levels[0])
	var btn := Button.new()
	btn.name = "Card_%s" % cr.id
	btn.custom_minimum_size = Vector2(0, 200)
	btn.toggle_mode = true
	btn.button_pressed = cr.id == selected
	btn.disabled = not unlocked_to_play
	btn.pressed.connect(_select_creature.bind(cr.id))
	var row := Ui.hbox(Palette.SPACE * 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.full_rect(row)
	row.offset_left = 16
	row.offset_right = -16
	btn.add_child(row)
	var thumb := CreatureStage.new()
	thumb.custom_minimum_size = Vector2(220, 180)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thumb)
	thumb.show_creature(cr.id, true, true)
	if not p.is_creature_unlocked(cr.id):
		thumb.set_tint(Color(0.55, 0.58, 0.6, 0.35))
	var col := Ui.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(Ui.label(cr.name_key, "", HORIZONTAL_ALIGNMENT_LEFT))
	var status := Ui.label("", "CaptionLabel", HORIZONTAL_ALIGNMENT_LEFT)
	status.name = "Status"
	status.text = tr("N_OF_2_COMPLETE") % p.creature_progress(cr.id) if unlocked_to_play else tr("LOCKED")
	col.add_child(status)
	return btn


func _select_realm(id: String) -> void:
	realm = id
	_refresh()


func _select_creature(id: String) -> void:
	selected = id
	for child in _list.get_children():
		if child is Button:
			child.button_pressed = child.name == "Card_%s" % id
	_update_play()


## The level Play opens for the selected creature: its next unfinished
## puzzle, or puzzle 1 again when both are done (replay).
func target_level() -> String:
	var cr := Game.campaign.creature(selected)
	if cr.is_empty() or cr.realm != realm:
		return ""
	for l in cr.levels:
		if Game.progression.is_level_unlocked(l) and not Game.progression.is_level_completed(l):
			return l
	return cr.levels[0] if Game.progression.is_level_unlocked(cr.levels[0]) else ""


func _update_play() -> void:
	var l := target_level()
	_play.disabled = l == ""
	_play.text = tr("PLAY_PUZZLE") % (Game.campaign.level_slot(l) + 1) if l != "" else tr("LOCKED")


func _on_play() -> void:
	var l := target_level()
	if l != "":
		Game.go("puzzle", {"level_id": l})
