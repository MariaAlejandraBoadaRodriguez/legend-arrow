extends Node
## Autoload "Game": owns the campaign, progression, save repository, settings
## and navigation. Screens talk to it; it never reaches into screen nodes.
## boot() must be called before use (main scene does; tests pass a temp path).

signal screen_changed(screen_name: String)
signal settings_changed

const SCREENS := {
	"home": "res://scenes/screens/home.tscn",
	"tutorial": "res://scenes/screens/tutorial.tscn",
	"world_select": "res://scenes/screens/world_select.tscn",
	"level_select": "res://scenes/screens/level_select.tscn",
	"puzzle": "res://scenes/screens/puzzle.tscn",
	"level_complete": "res://scenes/screens/level_complete.tscn",
	"awakening": "res://scenes/screens/awakening.tscn",
	"creature_detail": "res://scenes/screens/creature_detail.tscn",
	"bestiary": "res://scenes/screens/bestiary.tscn",
	"settings": "res://scenes/screens/settings.tscn",
	"privacy": "res://scenes/screens/privacy.tscn",
}
const BUSES := ["Music", "SFX", "Creature"]
## English is the only language (owner decision D-41): the locale is fixed.
const LOCALE := "en"

var campaign: Campaign
var progression: Progression
var repository: SaveRepository
var events := EventLog.new()
var ads: AdService
var audio: AudioDirector
var tutorial_data: Dictionary = {}
var boot_result: Dictionary = {}
var booted := false
var ad_fullscreen := false    # a full-screen ad is showing (timers hold)
var force_mock_ads := false   # set by Main for on-device E2E runs (before boot)

var _host: Control            # where screens are mounted (set by main scene)
var _current: Control
var _current_name := ""
var _stack: Array = []        # [[name, params], ...] for Back


func _ready() -> void:
	_ensure_buses()
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)


## Loads content and the save. Returns the SaveRepository.load_save() result.
func boot(save_path: String = "user://save.json") -> Dictionary:
	var c := Campaign.load_file()
	assert(c.campaign != null, "campaign.json invalid: %s" % str(c.errors))
	campaign = c.campaign
	tutorial_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))
	repository = SaveRepository.new(save_path)
	save_pending = false
	storage.space_left = func() -> int: return StorageStatus.space_left_in(save_path.get_base_dir())
	storage.save_failed = false
	storage.check_space()
	boot_result = repository.load_save()
	progression = Progression.new(campaign, boot_result.data)
	if boot_result.recovered:
		events.log_event("save_recovery", {"source": int(boot_result.source)})
	apply_settings()
	set_ad_provider(_default_ad_provider())
	booted = true
	return boot_result


## Android uses the Kotlin plugin when present; an Android build without it
## gets no ads at all. Desktop/editor runs use the mock so the flow is testable.
func _default_ad_provider() -> AdProvider:
	if force_mock_ads:
		return MockAdProvider.new()
	if Engine.has_singleton(AndroidAdProvider.SINGLETON):
		return AndroidAdProvider.new()
	if OS.has_feature("android"):
		return AdProvider.new()
	return MockAdProvider.new()


## Rebuilds the ad layer around a provider (boot, tests). Consent is requested
## in the background; nothing waits for it.
func set_ad_provider(provider: AdProvider) -> void:
	ads = AdService.new(provider, AdConfig.load_for_build(OS.is_debug_build()), progression, events)
	ads.persist = persist
	ads.fullscreen_started.connect(_on_ad_fullscreen_started)
	ads.fullscreen_ended.connect(_on_ad_fullscreen_ended)
	ads.start()


## Full-screen ads: silence the game first, restore only if still allowed.
func _on_ad_fullscreen_started() -> void:
	ad_fullscreen = true
	audio.set_muted("ad", true)


func _on_ad_fullscreen_ended() -> void:
	ad_fullscreen = false
	audio.set_muted("ad", false)
	apply_settings()


## Result of the last save write (OK or an Error code), for diagnostics.
var last_persist_error := OK
## True while the newest progress is only in memory (a write failed); the
## save is retried once at once and then every SAVE_RETRY_S until it lands.
var save_pending := false
var _retry_left := 0.0
const SAVE_RETRY_S := 2.0
## Free-space watch and the "Storage full" message state (D-52).
var storage := StorageStatus.new()
var _recheck_left := 0.0


## Writes progress. Returns the write result. On failure it retries once at
## once and then keeps retrying in the background, so the save never stays
## behind what the screen shows while the game runs (0.2.0 known limitation).
func persist() -> int:
	if not booted:
		return OK
	storage.check_space()
	var err := repository.write(progression.data)
	if err != OK:
		push_error("Game: save failed (%d), retrying" % err)
		err = repository.write(progression.data)
	last_persist_error = err
	save_pending = err != OK
	_retry_left = SAVE_RETRY_S
	if err != OK:
		push_error("Game: save failed again (%d); kept in memory, retrying every %.0f s" % [err, SAVE_RETRY_S])
	storage.on_save_result(err)
	return err


func _process(delta: float) -> void:
	if not booted:
		return
	if save_pending:
		_retry_left -= delta
		if _retry_left <= 0.0:
			persist()
	elif storage.visible:
		_recheck_left -= delta
		if _recheck_left <= 0.0:
			_recheck_left = StorageStatus.RECHECK_S
			storage.check_space()


## True when the "Storage full" message should be on screen: never during an
## awakening, which plays without interruptions.
func storage_message_shown() -> bool:
	return booted and storage.visible and _current_name != "awakening"


func settings() -> Dictionary:
	return progression.data.settings


func set_setting(key: String, value: Variant) -> void:
	progression.data.settings[key] = value
	apply_settings()
	persist()
	settings_changed.emit()


func apply_settings() -> void:
	var s := settings()
	TranslationServer.set_locale(LOCALE)
	if UiTheme.set_text_scale(UiTheme.LARGE_TEXT if bool(s.get("large_text", false)) else 1.0):
		if _host != null and _host.get_parent() is Control:
			(_host.get_parent() as Control).theme = UiTheme.get_theme()
	for bus_name in BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		var vol: float = s.get({"Music": "music_volume", "SFX": "sfx_volume", "Creature": "creature_volume"}[bus_name], 1.0)
		AudioServer.set_bus_mute(idx, vol <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)))


func reduce_motion() -> bool:
	return booted and bool(settings().reduce_motion)


# --- navigation -------------------------------------------------------------

func set_host(host: Control) -> void:
	_host = host
	if host != null:
		# Drawn over every screen, never takes input (StorageBanner).
		host.add_child(StorageBanner.new())


func current_screen() -> Control:
	return _current


func current_screen_name() -> String:
	return _current_name


## Opens a screen. `replace` drops the current one from the Back stack.
func go(screen_name: String, params: Dictionary = {}, replace := false) -> Control:
	assert(SCREENS.has(screen_name), "unknown screen %s" % screen_name)
	if _current != null and not replace:
		_stack.append([_current_name, _current.get_meta("params", {})])
	return _mount(screen_name, params)


## Clears history and opens a root screen.
func reset_to(screen_name: String, params: Dictionary = {}) -> Control:
	_stack.clear()
	return _mount(screen_name, params)


## Android Back / Escape. The screen may consume it (close an overlay, pause).
## Returns false when there is nowhere to go back to (the app may close).
func back() -> bool:
	if _current != null and _current.has_method("handle_back") and _current.handle_back():
		return true
	return leave()


## Returns to the previous screen without asking the current one first.
func leave() -> bool:
	if _stack.is_empty():
		return false
	var prev: Array = _stack.pop_back()
	_mount(prev[0], prev[1])
	return true


func _mount(screen_name: String, params: Dictionary) -> Control:
	if _current != null:
		if _current.has_method("on_leave"):
			_current.on_leave()
		if _current.get_parent() != null:
			_current.get_parent().remove_child(_current)
		_current.queue_free()
	var scene: PackedScene = load(SCREENS[screen_name])
	var screen: Control = scene.instantiate()
	screen.set_meta("params", params)
	if screen.has_method("setup"):
		screen.setup(params)
	_current = screen
	_current_name = screen_name
	if _host != null:
		_host.add_child(screen)
	screen_changed.emit(screen_name)
	return screen


## Removes the current screen and forgets history (tests, shutdown).
func unmount() -> void:
	if _current != null:
		if _current.get_parent() != null:
			_current.get_parent().remove_child(_current)
		_current.queue_free()
	_current = null
	_current_name = ""
	_stack.clear()
	_host = null


# --- lifecycle --------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if audio != null:
				audio.set_muted("background", false)
			if _current != null and _current.has_method("on_app_resumed"):
				_current.on_app_resumed()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if audio != null and what != NOTIFICATION_WM_CLOSE_REQUEST:
				audio.set_muted("background", true)
			if _current != null and _current.has_method("on_app_paused"):
				_current.on_app_paused()
			persist()


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
