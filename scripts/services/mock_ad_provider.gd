class_name MockAdProvider
extends AdProvider
## Scriptable fake SDK for desktop runs, tests and CI. Never contacts a network.
##
## With `manual = true` nothing is emitted on its own: tests drive callbacks
## through the emit_* helpers. Otherwise each request answers on the next idle
## frame according to the scripted outcomes below.

## Consent: "obtained", "not_required", "required_refused", "error"
var consent_outcome := "not_required"
## Rewarded load: "fill", "no_fill", "offline"
var load_outcome := "fill"
## Rewarded show: "earn", "dismiss_early", "fail_to_show", "earn_twice",
## "earn_after_close"
var show_outcome := "earn"
var interstitial_outcome := "fill"
var manual := false
var calls: Array[String] = []   # every SDK call, for "no duplicate request" tests
var config: Dictionary = {}


func is_available() -> bool:
	return true


func configure(c: Dictionary) -> void:
	config = c
	calls.append("configure")


func request_consent_update() -> void:
	calls.append("request_consent_update")
	if not manual:
		_later(_answer_consent)


func _answer_consent() -> void:
	if consent_outcome == "error":
		consent_error.emit("mock consent error")
	else:
		consent_info_updated.emit(consent_info())


func consent_info() -> Dictionary:
	return {
		"status": consent_outcome,
		"can_request_ads": consent_outcome in ["obtained", "not_required"],
		"privacy_options_required": consent_outcome != "not_required",
	}


func show_privacy_options() -> void:
	calls.append("show_privacy_options")
	if not manual:
		_later(privacy_options_closed.emit)


func initialize() -> void:
	calls.append("initialize")
	if not manual:
		_later(initialized.emit)


func load_rewarded() -> void:
	calls.append("load_rewarded")
	if not manual:
		_later(_answer_load)


func _answer_load() -> void:
	match load_outcome:
		"fill":
			rewarded_loaded.emit()
		"no_fill":
			rewarded_load_failed.emit("no_fill", "No fill")
		_:
			rewarded_load_failed.emit("network", "Offline")


func show_rewarded(presentation_id: String) -> void:
	calls.append("show_rewarded:%s" % presentation_id)
	if not manual:
		_later(_answer_show.bind(presentation_id))


func _answer_show(pid: String) -> void:
	if show_outcome == "fail_to_show":
		rewarded_show_failed.emit(pid, "Mock failure")
		return
	rewarded_shown.emit(pid)
	match show_outcome:
		"dismiss_early":
			rewarded_closed.emit(pid)
		"earn_twice":
			rewarded_earned.emit(pid)
			rewarded_earned.emit(pid)
			rewarded_closed.emit(pid)
		"earn_after_close":
			rewarded_closed.emit(pid)
			rewarded_earned.emit(pid)
		_:
			rewarded_earned.emit(pid)
			rewarded_closed.emit(pid)


func load_interstitial() -> void:
	calls.append("load_interstitial")
	if not manual:
		_later(_answer_interstitial_load)


func _answer_interstitial_load() -> void:
	if interstitial_outcome == "fill":
		interstitial_loaded.emit()
	else:
		interstitial_load_failed.emit("no_fill", "No fill")


func show_interstitial() -> void:
	calls.append("show_interstitial")
	if not manual:
		_later(interstitial_closed.emit)


func count(call_name: String) -> int:
	return calls.filter(func(c): return c == call_name or c.begins_with(call_name + ":")).size()


func _later(f: Callable) -> void:
	f.call_deferred()
