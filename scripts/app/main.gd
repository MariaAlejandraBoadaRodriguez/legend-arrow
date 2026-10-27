extends Control
## Root scene: background, safe-area host for screens, boot routing and the
## Android Back button.


func _ready() -> void:
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	Ui.full_rect(bg)
	add_child(bg)
	var host := Control.new()
	host.name = "ScreenHost"
	Ui.full_rect(host)
	add_child(host)
	_apply_safe_area(host)
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	Game.set_host(host)
	# Decide E2E mode before boot so the real ads SDK is never started in a
	# test run (brief §5: CI never contacts ad services).
	var e2e_journey := DeviceE2E.requested_journey()
	var e2e: DeviceE2E = null
	if e2e_journey != "":
		e2e = DeviceE2E.new(e2e_journey)
		Game.force_mock_ads = true
	var result := Game.boot() if not Game.booted else Game.boot_result
	if e2e != null:
		e2e.mock = Game.ads.provider as MockAdProvider
	route_after_boot(result)
	if e2e != null:
		add_child(e2e)
	Game.audio.play_music()


## Pending awakening (app killed mid-reveal) replays first; a restored backup
## shows the short recovery message over Home.
static func route_after_boot(result: Dictionary) -> void:
	var home := Game.reset_to("home")
	var pending := Game.progression.pending_awakening()
	if pending != "":
		Game.go("awakening", {"creature_id": pending, "replay": false})
	elif result.get("recovered", false):
		Dialog.open(home, "SAVE_RESTORED_TITLE", "SAVE_RESTORED_BODY", [["CONTINUE", func(): pass, true, "RestoredContinue"]], "SaveRestoredDialog")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if what == NOTIFICATION_WM_CLOSE_REQUEST or not Game.back():
			Game.persist()
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Game.back()


## Keeps screens clear of notches and gesture bars on phones.
func _apply_safe_area(host: Control) -> void:
	if not OS.has_feature("mobile"):
		return
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0 or screen.y <= 0:
		return
	var vp := get_viewport_rect().size
	var k := vp / screen
	host.offset_left = safe.position.x * k.x
	host.offset_top = safe.position.y * k.y
	host.offset_right = -(screen.x - safe.end.x) * k.x
	host.offset_bottom = -(screen.y - safe.end.y) * k.y
