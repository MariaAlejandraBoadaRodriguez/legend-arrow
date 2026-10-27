extends Screen
## Creature awakening: arrow trails gather into a faint silhouette, the
## creature forms and performs its signature move (~5 s). Skip appears after
## the first second while it plays; Continue appears at the end. The unlock was
## already committed by the puzzle screen, so skipping, interrupting or
## replaying can never grant it twice.

const SKIP_AFTER := 1.0

var creature_id := ""
var replay := false
var stage: CreatureStage
var landscape: AwakeningBackdrop
var _skip: Button
var _continue: Button
var _elapsed := 0.0
var finished := false


func build() -> void:
	creature_id = str(params.get("creature_id", ""))
	replay = bool(params.get("replay", false))
	landscape = AwakeningBackdrop.new()
	landscape.reduce_motion = Game.reduce_motion()
	Ui.full_rect(landscape)
	add_child(landscape)
	move_child(landscape, 0)
	stage = CreatureStage.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)
	stage.show_creature(creature_id, Game.reduce_motion())
	var name_label := Ui.label(Game.campaign.creature(creature_id).name_key, "TitleLabel")
	name_label.name = "CreatureName"
	content.add_child(name_label)
	content.add_child(Ui.label("CREATURE_AWAKENED", "CaptionLabel"))
	_continue = Ui.button("CONTINUE", _on_continue, true, "ContinueButton")
	_continue.visible = false
	content.add_child(_continue)
	_skip = Ui.link("SKIP", skip, "SkipButton")
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip.visible = false
	content.add_child(_skip)
	if stage.rig == null:
		_on_finished()
		return
	stage.rig.awakening_finished.connect(_on_finished)
	if stage.rig.is_node_ready():
		_begin()
	else:
		stage.rig.ready.connect(_begin, CONNECT_ONE_SHOT)


func _begin() -> void:
	stage.rig.awaken()
	landscape.play()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_skip.visible = not finished and _elapsed >= SKIP_AFTER


func can_skip() -> bool:
	return not finished and _elapsed >= SKIP_AFTER


func skip() -> void:
	if not can_skip():
		return
	landscape.finish()
	stage.rig.skip()


func _on_finished() -> void:
	if finished:
		return
	finished = true
	_skip.visible = false
	_continue.visible = true
	Ui.focus_later(_continue)
	set_process(false)
	if not replay:
		Game.progression.mark_awakening_seen(creature_id)
		Game.persist()
	if stage.rig != null:
		stage.rig.start_idle()


func _on_continue() -> void:
	if replay:
		Game.leave()
	else:
		Game.go("creature_detail", {"creature_id": creature_id}, true)


## Back skips while playing (after the first second) and continues at the end.
func handle_back() -> bool:
	if not finished:
		skip()
		return true
	_on_continue()
	return true


func on_leave() -> void:
	if stage != null and stage.rig != null:
		stage.rig.stop()
