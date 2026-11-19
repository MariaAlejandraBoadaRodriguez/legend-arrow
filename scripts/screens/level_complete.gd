extends Screen
## Results (v0.2 §3): time, personal best ("New record!"), 1–3 stars that
## appear one by one (a simple fade with reduced motion), Retry / Next.
## Shown after every completed puzzle. The run was already recorded and saved
## by the puzzle screen; this screen only reads it, so leaving, replaying or
## killing the app here cannot grant or lower anything.
##
## params: level_id, time_ms, stars, best_time_ms, best_stars, new_record,
##         first_record, previous_best_ms, par_ms, hints_used

var level_id := ""
var stars: StarRow


func build() -> void:
	level_id = str(params.get("level_id", ""))
	var cid := Game.campaign.creature_of_level(level_id)
	var p := Game.progression
	content.add_child(Ui.spacer(Palette.SPACE * 2))
	content.add_child(Ui.label("PUZZLE_COMPLETE", "TitleLabel"))
	if cid != "":
		content.add_child(Ui.label(Game.campaign.creature(cid).name_key, "CaptionLabel"))
	content.add_child(Ui.spacer(0, true))
	stars = StarRow.new(int(params.get("stars", p.best_stars(level_id))), 96.0)
	stars.name = "Stars"
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(stars)
	content.add_child(Ui.spacer(Palette.SPACE * 2))
	var t := Ui.label(SpeedTimer.format_ms(int(params.get("time_ms", 0))), "TitleLabel")
	t.name = "TimeLabel"
	content.add_child(t)
	var par := int(params.get("par_ms", 0))
	if par > 0:
		var pl := Ui.label(tr("PAR_TIME") % SpeedTimer.format_ms(par), "CaptionLabel")
		pl.name = "ParLabel"
		content.add_child(pl)
	var rec := Ui.label(_record_text(), "HeadingLabel")
	rec.name = "RecordLabel"
	content.add_child(rec)
	if int(params.get("hints_used", 0)) > 0 and int(params.get("stars", 0)) < 3 and int(params.get("time_ms", 0)) <= par:
		var hl := Ui.label("STARS_HINT_NOTE", "CaptionLabel")
		hl.name = "HintNote"
		content.add_child(hl)
	content.add_child(Ui.spacer(0, true))
	var row := Ui.hbox(Palette.SPACE * 2)
	row.add_child(Ui.button("RETRY", _on_retry, false, "RetryButton"))
	row.add_child(Ui.button("NEXT", _on_next, true, "NextButton"))
	for b in row.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	content.add_child(Ui.button("LEVEL_SELECTION", Game.leave, false, "LevelSelectButton"))
	stars.reveal(Game.reduce_motion())
	Game.audio.play_sfx("complete")


func _record_text() -> String:
	if bool(params.get("new_record", false)):
		return tr("NEW_RECORD")
	if bool(params.get("first_record", false)):
		return tr("FIRST_CLEAR")
	var best := int(params.get("best_time_ms", Game.progression.best_time_ms(level_id)))
	return tr("PERSONAL_BEST") % SpeedTimer.format_ms(best) if best >= 0 else ""


func _on_retry() -> void:
	Game.go("puzzle", {"level_id": level_id}, true)


## Next: an earned awakening first (it is the reward), then the following
## level in campaign order if it is open, else the level list. Between levels
## is the only place an interstitial may appear; nothing waits for it.
func _on_next() -> void:
	var pending := Game.progression.pending_awakening()
	if pending != "":
		Game.go("awakening", {"creature_id": pending, "replay": false}, true)
		return
	var nxt := next_level_after(level_id)
	if nxt != "":
		Game.ads.maybe_show_interstitial(InterstitialPolicy.CONTEXT_BETWEEN_LEVELS)
		Game.go("puzzle", {"level_id": nxt}, true)
	else:
		Game.leave()


## The next level in campaign order when it is unlocked, else "".
static func next_level_after(id: String) -> String:
	var ids := Game.campaign.level_ids()
	var i := ids.find(id)
	if i < 0 or i + 1 >= ids.size():
		return ""
	var n: String = ids[i + 1]
	return n if Game.progression.is_level_unlocked(n) else ""


func handle_back() -> bool:
	return Game.leave()
