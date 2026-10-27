extends Screen
## Shown after a puzzle that does not unlock a creature (e.g. puzzle 1 of 2).


func build() -> void:
	var level_id := str(params.get("level_id", ""))
	var cid := Game.campaign.creature_of_level(level_id)
	var p := Game.progression
	content.add_child(Ui.label("PUZZLE_COMPLETE", "TitleLabel"))
	var stage := CreatureStage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)
	stage.show_creature(cid, true, true)
	if not p.is_creature_unlocked(cid):
		stage.set_tint(Color(0.55, 0.58, 0.6, 0.4))
	content.add_child(Ui.label("TWO_PUZZLES", "CaptionLabel"))
	content.add_child(Ui.progress_dots(p.creature_progress(cid), 2))
	var status := Ui.label(tr("N_OF_2_COMPLETE") % p.creature_progress(cid), "CaptionLabel")
	status.name = "Status"
	content.add_child(status)
	var next := _next_level_of(cid)
	if next != "":
		content.add_child(Ui.button("CONTINUE_TO_PUZZLE_2", func(): Game.go("puzzle", {"level_id": next}, true), true, "ContinueButton"))
	content.add_child(Ui.button("LEVEL_SELECTION", Game.leave, next == "", "LevelSelectButton"))


func _next_level_of(cid: String) -> String:
	for l in Game.campaign.creature(cid).levels:
		if Game.progression.is_level_unlocked(l) and not Game.progression.is_level_completed(l):
			return l
	return ""
