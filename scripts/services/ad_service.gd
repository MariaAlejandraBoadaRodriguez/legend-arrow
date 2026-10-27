class_name AdService
extends RefCounted
## Rewarded-hint state machine, consent gating and interstitial pacing
## (spec §16). Lives in the Game autoload so callbacks never depend on a
## screen that may have been freed; screens only listen to its signals.
##
## Rewarded: IDLE -> LOADING -> READY -> SHOWING -> REWARDED | DISMISSED -> IDLE
##           LOADING/SHOWING -> FAILED (retry allowed after a short cooldown)
## A hint is granted only from the SDK's earned-reward callback, exactly once
## per presentation id (persisted receipt). Duplicate, late or unknown
## callbacks are harmless. Dismissal and failures never grant or consume hints.

signal reward_state_changed(state: int)
signal rewarded_result(result: String)    # rewarded, dismissed, no_fill, offline, failed
signal hint_granted(presentation_id: String)
signal fullscreen_started
signal fullscreen_ended

enum RewardState { IDLE, LOADING, READY, SHOWING, REWARDED, DISMISSED, FAILED }

var provider: AdProvider
var config: AdConfig
var limits := RemoteConfig.new()
var consent: ConsentService
var interstitials: InterstitialPolicy
var progression: Progression
## Optional hooks. Left empty by default: a lambda stored here would capture
## `self` and keep this RefCounted alive forever (reference cycle).
var persist := Callable()
var events: EventLog
var clock := Callable()
var debug_build := OS.is_debug_build()

var reward_state := RewardState.IDLE
var _show_when_ready := false
var _current_pid := ""
var _issued := {}            # presentation ids started this launch
var _counter := 0
var _nonce := ""
var _initialized := false
var _last_failure_at := -INF
var _interstitial_ready := false
var _interstitial_loading := false
var _fullscreen := false


func _init(p_provider: AdProvider, p_config: AdConfig, p_progression: Progression, p_events: EventLog) -> void:
	provider = p_provider
	config = p_config
	progression = p_progression
	events = p_events
	consent = ConsentService.new(provider)
	consent.changed.connect(_on_consent_changed)
	interstitials = InterstitialPolicy.new(limits, config.restricted())
	_nonce = "%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 100000]
	provider.initialized.connect(_on_initialized)
	provider.rewarded_loaded.connect(_on_loaded)
	provider.rewarded_load_failed.connect(_on_load_failed)
	provider.rewarded_earned.connect(_on_earned)
	provider.rewarded_closed.connect(_on_closed)
	provider.rewarded_show_failed.connect(_on_show_failed)
	provider.interstitial_loaded.connect(_on_interstitial_loaded)
	provider.interstitial_load_failed.connect(_on_interstitial_load_failed)
	provider.interstitial_closed.connect(_on_interstitial_done)
	provider.interstitial_show_failed.connect(_on_interstitial_show_failed)


## Called once at boot. Never blocks: consent answers arrive later.
func start() -> void:
	if not config_usable():
		return
	provider.configure(config.to_provider_dict())
	consent.request_update()


## Test IDs only in debug builds; release builds need a valid owner config.
func config_usable() -> bool:
	if config.is_test:
		return debug_build
	return config.release_errors().is_empty()


func ads_permitted() -> bool:
	return provider.is_available() and config_usable() and consent.can_request_ads


func rewarded_available() -> bool:
	return ads_permitted() and limits.rewarded_enabled


func is_busy() -> bool:
	return reward_state in [RewardState.LOADING, RewardState.SHOWING, RewardState.REWARDED]


func retry_wait() -> float:
	if reward_state != RewardState.FAILED:
		return 0.0
	return maxf(0.0, RemoteConfig.RETRY_COOLDOWN_SECONDS - (_now() - _last_failure_at))


## Player chose "Watch an ad for a hint". Returns started / busy / cooldown /
## unavailable. Repeat taps while loading or showing are ignored.
func watch_for_hint() -> String:
	if not rewarded_available():
		return "unavailable"
	if is_busy():
		return "busy"
	if reward_state == RewardState.READY:
		_show_rewarded()
		return "started"
	if retry_wait() > 0.0:
		return "cooldown"
	_show_when_ready = true
	_load_rewarded()
	return "started"


## The player backed out while the ad was loading: keep the load (it may be
## used later) but do not pop it up uninvited.
func cancel_pending_show() -> void:
	_show_when_ready = false


## Loads quietly so a later tap can show at once.
func preload_rewarded() -> void:
	if rewarded_available() and reward_state == RewardState.IDLE:
		_show_when_ready = false
		_load_rewarded()


func _load_rewarded() -> void:
	_set_state(RewardState.LOADING)
	provider.load_rewarded()


func _show_rewarded() -> void:
	_counter += 1
	_current_pid = "rw-%s-%d" % [_nonce, _counter]
	_issued[_current_pid] = true
	_show_when_ready = false
	_set_state(RewardState.SHOWING)
	_begin_fullscreen()
	provider.show_rewarded(_current_pid)


func _on_consent_changed() -> void:
	if consent.can_request_ads and not _initialized and config_usable():
		_initialized = true
		provider.initialize()


func _on_initialized() -> void:
	preload_rewarded()


func _on_loaded() -> void:
	if reward_state != RewardState.LOADING:
		return  # duplicate or stale callback
	_set_state(RewardState.READY)
	if _show_when_ready:
		_show_rewarded()


func _on_load_failed(code: String, _message: String) -> void:
	if reward_state != RewardState.LOADING:
		return
	var was_requested := _show_when_ready
	_show_when_ready = false
	_last_failure_at = _now()
	_set_state(RewardState.FAILED)
	var result := "offline" if code == "network" else ("no_fill" if code == "no_fill" else "failed")
	_log(result)
	if was_requested:
		rewarded_result.emit(result)


func _on_earned(pid: String) -> void:
	if not _issued.has(pid):
		return  # not a presentation we started
	if progression.grant_ad_hint(pid):
		if persist.is_valid():
			persist.call()
		_log("rewarded")
		hint_granted.emit(pid)
	if pid == _current_pid and reward_state == RewardState.SHOWING:
		_set_state(RewardState.REWARDED)


func _on_closed(pid: String) -> void:
	if pid != _current_pid or not reward_state in [RewardState.SHOWING, RewardState.REWARDED]:
		return
	var earned := reward_state == RewardState.REWARDED
	if not earned:
		_set_state(RewardState.DISMISSED)
		_log("dismissed")
	_finish_fullscreen_ad(false)
	_current_pid = ""
	_set_state(RewardState.IDLE)
	rewarded_result.emit("rewarded" if earned else "dismissed")


func _on_show_failed(pid: String, _message: String) -> void:
	if pid != _current_pid or reward_state != RewardState.SHOWING:
		return
	_last_failure_at = _now()
	_current_pid = ""
	_end_fullscreen()
	_set_state(RewardState.FAILED)
	_log("failed")
	rewarded_result.emit("failed")


# --- interstitials -------------------------------------------------------------

## Call after a level's completion has been saved.
func on_level_completed(is_tutorial: bool) -> void:
	interstitials.on_level_completed(is_tutorial)
	if ads_permitted() and not _interstitial_ready and not _interstitial_loading \
			and interstitials.blocked_reason(INF, InterstitialPolicy.CONTEXT_BETWEEN_LEVELS) in ["", "cooldown"]:
		_interstitial_loading = true
		provider.load_interstitial()


## Shows an already-loaded interstitial if every rule allows it right now.
## Never waits for a load: returns false and the game continues at once.
func maybe_show_interstitial(context: String) -> bool:
	if not ads_permitted() or not _interstitial_ready or is_busy():
		return false
	if not interstitials.allowed(_now(), context):
		return false
	_interstitial_ready = false
	_begin_fullscreen()
	interstitials.on_fullscreen_ad_shown(_now(), true)
	provider.show_interstitial()
	return true


func _on_interstitial_loaded() -> void:
	_interstitial_loading = false
	_interstitial_ready = true


func _on_interstitial_load_failed(_code: String, _message: String) -> void:
	_interstitial_loading = false


func _on_interstitial_done() -> void:
	_end_fullscreen()


func _on_interstitial_show_failed(_message: String) -> void:
	_end_fullscreen()


# --- helpers --------------------------------------------------------------------

func _now() -> float:
	return clock.call() if clock.is_valid() else Time.get_ticks_msec() / 1000.0


func _finish_fullscreen_ad(was_interstitial: bool) -> void:
	interstitials.on_fullscreen_ad_shown(_now(), was_interstitial)
	_end_fullscreen()


func _begin_fullscreen() -> void:
	if not _fullscreen:
		_fullscreen = true
		fullscreen_started.emit()


func _end_fullscreen() -> void:
	if _fullscreen:
		_fullscreen = false
		fullscreen_ended.emit()


func _set_state(s: RewardState) -> void:
	if reward_state != s:
		reward_state = s
		reward_state_changed.emit(s)


func _log(result: String) -> void:
	if events != null:
		events.log_event("ad_result", {"format": "rewarded", "result": result})
