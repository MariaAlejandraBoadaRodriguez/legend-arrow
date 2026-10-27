extends Screen
## A collected creature with its ambient idle loop.

var creature_id := ""
var stage: CreatureStage


func build() -> void:
	creature_id = str(params.get("creature_id", ""))
	var cr := Game.campaign.creature(creature_id)
	content.add_child(Ui.top_bar("", "", Game.back))
	stage = CreatureStage.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)
	stage.show_creature(creature_id, Game.reduce_motion())
	stage.start_idle()
	var title := Ui.label(cr.name_key, "TitleLabel")
	title.name = "CreatureName"
	content.add_child(title)
	var realm_key: String = Game.campaign.realms.filter(func(r): return r.id == cr.realm)[0].name_key
	content.add_child(Ui.label(realm_key, "CaptionLabel"))
	content.add_child(Ui.label(cr.name_key + "_LORE"))
	content.add_child(Ui.spacer(Palette.SPACE * 2))
	content.add_child(Ui.button("OPEN_BESTIARY", func(): Game.go("bestiary"), true, "OpenBestiary"))
	var replay := Ui.link("REPLAY_AWAKENING", func(): Game.go("awakening", {"creature_id": creature_id, "replay": true}), "ReplayAwakening")
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(replay)


func on_leave() -> void:
	if stage != null:
		stage.clear()
