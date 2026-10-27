extends Screen
## Three interactive steps (spec §4): a legal move, a harmless blocked move,
## and clearing a board. One short sentence per step.

var step := 0
var session: PuzzleSession
var board: BoardView
var _step_label: Label
var _text: Label
var _feedback: Label
var _next: Button
var _dots_holder: Control
var _step_done := false


func build() -> void:
	content.add_child(Ui.label("TUTORIAL_TITLE", "HeadingLabel"))
	_step_label = Ui.label("", "CaptionLabel")
	content.add_child(_step_label)
	_dots_holder = Ui.hbox(0)
	_dots_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_dots_holder)
	board = BoardView.new()
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.reduce_motion = Game.reduce_motion()
	board.arrow_tapped.connect(_on_tap)
	content.add_child(board)
	_text = Ui.label("")
	_text.name = "StepText"
	content.add_child(_text)
	_feedback = Ui.label("", "CaptionLabel")
	_feedback.name = "Feedback"
	content.add_child(_feedback)
	_next = Ui.button("TUTORIAL_NEXT", _on_next, true, "NextButton")
	content.add_child(_next)
	var skip := Ui.link("TUTORIAL_SKIP", finish, "SkipButton")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(skip)
	_load_step(0)


func steps() -> Array:
	return Game.tutorial_data.steps


func _load_step(i: int) -> void:
	step = i
	var spec: Dictionary = steps()[i]
	session = PuzzleSession.new(spec.level)
	board.bind(session)
	if spec.highlight != "":
		board.show_hint(spec.highlight)
	_step_label.text = tr("TUTORIAL_STEP_OF") % (i + 1)
	_text.text = spec.text_key
	_feedback.text = ""
	_step_done = false
	_next.disabled = true
	_next.text = "TUTORIAL_START" if i == steps().size() - 1 else "TUTORIAL_NEXT"
	for c in _dots_holder.get_children():
		c.queue_free()
	_dots_holder.add_child(Ui.progress_dots(i + 1, steps().size()))


func _on_tap(id: String) -> void:
	var r := session.tap(id)
	match r.result:
		PuzzleSession.TapResult.REMOVED:
			board.play_exit(id)
			_feedback.text = ""
			var spec: Dictionary = steps()[step]
			if spec.complete_when == "first_removal" or session.is_complete():
				_mark_done()
		PuzzleSession.TapResult.BLOCKED:
			board.play_blocked(id)
			_feedback.text = "BLOCKED_MESSAGE"


func _mark_done() -> void:
	_step_done = true
	_next.disabled = false
	_feedback.text = "TUTORIAL_WELL_DONE"
	Ui.focus_later(_next)


func is_step_done() -> bool:
	return _step_done


func _on_next() -> void:
	if not _step_done:
		return
	if step + 1 < steps().size():
		_load_step(step + 1)
	else:
		finish()


func finish() -> void:
	var first_time: bool = not Game.progression.data.tutorial_done
	Game.progression.data.tutorial_done = true
	Game.persist()
	if first_time:
		Game.events.log_event("tutorial_complete")
	Game.reset_to("home")
	Game.go("level_select")
