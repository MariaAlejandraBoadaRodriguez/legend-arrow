extends Node
## Autoload "Game": owns the campaign, progression, save repository, settings
## and navigation. Screens talk to it; it never reaches into screen nodes.
## boot() must be called before use (main scene does; tests pass a temp path).

signal screen_changed(screen_name: String)
signal settings_changed

const SCREENS := {
	"home": "res://scenes/screens/home.tscn",
	"tutorial": "res://scenes/screens/tutorial.tscn",
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
const SUPPORTED_LOCALES := ["en", "es"]

var campaign: Campaign
var progression: Progression
var repository: SaveRepository
var events := EventLog.new()
var tutorial_data: Dictionary = {}
var boot_result: Dictionary = {}
var booted := false

var _host: Control            # where screens are mounted (set by main scene)
var _current: Control
var _current_name := ""
var _stack: Array = []        # [[name, params], ...] for Back


func _ready() -> void:
	_ensure_buses()


## Loads content and the save. Returns the SaveRepository.load_save() result.
func boot(save_path: String = "user://save.json") -> Dictionary:
	var c := Campaign.load_file()
	assert(c.campaign != null, "campaign.json invalid: %s" % str(c.errors))
	campaign = c.campaign
	tutorial_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))
	repository = SaveRepository.new(save_path)
	boot_result = repository.load_save()
	progression = Progression.new(campaign, boot_result.data)
	if boot_result.recovered:
		events.log_event("save_recovery", {"source": int(boot_result.source)})
	apply_settings()
	booted = true
	return boot_result


func persist() -> void:
	if booted:
		var err := repository.write(progression.data)
		if err != OK:
			push_error("Game: save failed (%d)" % err)


func settings() -> Dictionary:
	return progression.data.settings


func set_setting(key: String, value: Variant) -> void:
	progression.data.settings[key] = value
	apply_settings()
	persist()
	settings_changed.emit()


func apply_settings() -> void:
	var s := settings()
	var lang: String = s.language
	if lang == "" or not SUPPORTED_LOCALES.has(lang):
		lang = OS.get_locale_language()
		if not SUPPORTED_LOCALES.has(lang):
			lang = "en"
	TranslationServer.set_locale(lang)
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
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
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
