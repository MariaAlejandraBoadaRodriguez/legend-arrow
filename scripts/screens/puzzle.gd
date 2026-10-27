extends Screen
## The puzzle: board, Undo / Hint / Restart, pause overlay. Every committed
## move is saved immediately; completion is persisted before any reward screen.

var level: Dictionary
var level_id := ""
var creature_id := ""
var session: PuzzleSession
var board: BoardView
var _message: Label
var _hint_btn: Button
var _undo_btn: Button
var _completing := false


func build() -> void:
	level_id = str(params.get("level_id", ""))
	var res := LevelData.load_file(Game.campaign.level_path(level_id))
	if not res.errors.is_empty():
		push_error("puzzle: cannot load %s: %s" % [level_id, str(res.errors)])
		content.add_child(Ui.label("LOCKED"))
		return
	level = res.level
	creature_id = level.creature_id
	session = PuzzleSession.new(level)
	var saved: Dictionary = Game.progression.data.in_progress
	if saved.get("level_id", "") == level_id:
		session.apply_saved(saved)
	var subtitle := "%s · %s" % [tr("PUZZLE_N_OF_2") % (Game.campaign.level_slot(level_id) + 1), tr("DIFFICULTY_%s" % str(level.difficulty).to_upper())]
	var pause := Ui.icon_button("II", open_pause, "PAUSE", "PauseButton")
	pause.add_theme_font_size_override("font_size", 30)
	content.add_child(Ui.top_bar(Game.campaign.creature(creature_id).name_key, subtitle, open_pause, pause))
	board = BoardView.new()
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.reduce_motion = Game.reduce_motion()
	board.arrow_tapped.connect(_on_tap)
	board.exit_finished.connect(_on_exit_finished)
	content.add_child(board)
	board.bind(session)
	_message = Ui.label("", "CaptionLabel")
	_message.name = "Message"
	_message.custom_minimum_size = Vector2(0, 40)
	content.add_child(_message)
	var row := Ui.hbox(Palette.SPACE * 2)
	_undo_btn = Ui.button("UNDO", _on_undo, false, "UndoButton")
	_hint_btn = Ui.button("", _on_hint, false, "HintButton")
	row.add_child(_undo_btn)
	row.add_child(_hint_btn)
	row.add_child(Ui.button("RESTART", _on_restart, false, "RestartButton"))
	content.add_child(row)
	Game.events.log_event("level_start", {"level": level_id})
	_refresh_controls()


func _on_tap(id: String) -> void:
	if _completing or Dialog.top(self) != null:
		return
	var r := session.tap(id)
	match r.result:
		PuzzleSession.TapResult.REMOVED:
			board.play_exit(id)
			_message.text = ""
			if session.is_complete():
				_commit_completion()
			else:
				Game.progression.save_in_progress(session)
				Game.persist()
		PuzzleSession.TapResult.BLOCKED:
			board.play_blocked(id)
			_message.text = "BLOCKED_MESSAGE"
			Game.events.log_event("blocked_tap", {"level": level_id})
			if bool(Game.settings().haptics) and OS.has_feature("mobile"):
				Input.vibrate_handheld(30)
	_refresh_controls()


## Persist first, then let the last exit animation finish before moving on.
func _commit_completion() -> void:
	_completing = true
	board.input_enabled = false
	var result := Game.progression.complete_level(level_id)
	Game.persist()
	Game.events.log_event("level_complete", {"level": level_id, "first": result.first_completion})
	if result.unlocked_creature != "":
		Game.events.log_event("creature_unlock", {"creature": result.unlocked_creature})
	set_meta("completion", result)
	if not board.is_animating():
		_go_next()


func _on_exit_finished(_id: String) -> void:
	if _completing and not board.is_animating():
		_go_next()


func _go_next() -> void:
	if not is_inside_tree() or has_meta("navigated"):
		return
	set_meta("navigated", true)
	var result: Dictionary = get_meta("completion")
	if result.unlocked_creature != "":
		Game.go("awakening", {"creature_id": result.unlocked_creature, "replay": false}, true)
	else:
		Game.go("level_complete", {"level_id": level_id}, true)


func _on_undo() -> void:
	var id := session.undo()
	if id != "":
		board.play_restored(id)
		_message.text = ""
		Game.progression.save_in_progress(session)
		Game.persist()
	_refresh_controls()


func _on_restart() -> void:
	if _completing:
		return
	session.restart()
	board.bind(session)
	_message.text = ""
	Game.progression.save_in_progress(session)
	Game.persist()
	_refresh_controls()


func _on_hint() -> void:
	if _completing:
		return
	var target := session.hint()
	if target == "":
		return
	if board.hint_id() == target:
		return  # the current hint is still showing; don't spend another
	var spent := Game.progression.spend_hint(level_id)
	if spent == "":
		open_hint_sheet()
		return
	Game.events.log_event("hint_requested", {"kind": spent})
	Game.persist()
	board.show_hint(target)
	_refresh_controls()


func open_hint_sheet() -> Dialog:
	return Dialog.open(self, "HINT_SHEET_TITLE", "%s\n%s" % [tr("HINT_SHEET_USED"), tr("HINT_SHEET_FREE_PATH")],
		[["KEEP_PLAYING", func(): pass, true, "KeepPlaying"]], "HintSheet")


func open_pause() -> Dialog:
	if Dialog.top(self) != null:
		return Dialog.top(self)
	board.finish_animations()
	return Dialog.open(self, "PAUSED", "PAUSED_SAVED", [
		["RESUME", func(): pass, true, "ResumeButton"],
		["RESTART_PUZZLE", _on_restart, false, "PauseRestart"],
		["LEVEL_SELECTION", Game.leave, false, "PauseLevelSelect"],
		["HOME_SETTINGS", func(): Game.go("settings"), false, "PauseSettings"],
	], "PauseDialog")


func _refresh_controls() -> void:
	if session == null:
		return
	_undo_btn.disabled = not session.can_undo()
	var free := Game.progression.free_hints_left(level_id)
	var earned := Game.progression.ad_hints_available()
	_hint_btn.text = tr("HINT_FREE") % free if free > 0 or earned == 0 else tr("HINT_AD_READY") % earned


## Back: close an overlay first, otherwise pause (spec §7).
func handle_back() -> bool:
	var d := Dialog.top(self)
	if d != null:
		d.close()
		return true
	if _completing:
		return true
	open_pause()
	return true


func on_app_paused() -> void:
	if board != null:
		board.finish_animations()
	if session != null and not session.is_complete():
		Game.progression.save_in_progress(session)
