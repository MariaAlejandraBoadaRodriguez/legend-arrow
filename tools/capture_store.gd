extends SceneTree
## Renders Google Play store graphics from the real game to build/store/.
## Run through tools/make_store_graphics.sh, which also builds the icon and
## checks every size. Needs a renderer (Xvfb with a screen large enough):
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     -s res://tools/capture_store.gd -- screens|feature
## screens: the running app at 1080x1920 (720x1280 UI at 1.5x).
## feature: the awakening backdrop and a creature rig at 1024x500, 1:1 pixels.

const SAVE := "user://store_capture_save.json"
const OUT := "res://build/store"

var game: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "screens"
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	game = root.get_node("Game")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE + suffix)
	game.boot(SAVE)
	game.set_setting("language", "en")
	if mode == "feature":
		await _feature()
	else:
		await _screens()
	print("capture_store: wrote %s (%s)" % [OUT, mode])
	quit()


func _screens() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await _settle()
	root.add_child(load("res://scenes/main.tscn").instantiate())
	# A first creature already awakened, reached through the real rules.
	game.progression.complete_level("forest_drake_1")
	game.reset_to("home")
	await _settle(0.5)
	await shot("home")

	game.go("puzzle", {"level_id": "griffin_1"})
	await _settle()
	var pz: Control = game.current_screen()
	pz._on_tap(pz.level.solution[0])
	await _settle(0.6)
	pz._on_hint()
	await _settle(0.4)
	await shot("puzzle")
	game.reset_to("home")

	game.go("puzzle", {"level_id": "forest_drake_2"})
	await _settle()
	pz = game.current_screen()
	for id in pz.level.solution:
		pz._on_tap(id)
		await _settle(0.45)
	await _settle(3.0)
	await shot("awakening")
	await _settle(4.0)
	game.current_screen()._on_continue()
	await _settle(0.5)

	for level_id in game.campaign.level_ids():
		game.progression.complete_level(level_id)
	for cid in game.campaign.creature_ids():
		game.progression.mark_awakening_seen(cid)
	game.reset_to("home")
	game.go("bestiary")
	await _settle(0.8)
	await shot("bestiary")


func _feature() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1024, 500))
	await _settle()
	var ui := Control.new()
	ui.theme = UiTheme.get_theme()
	Ui.full_rect(ui)
	root.add_child(ui)
	var backdrop := AwakeningBackdrop.new()
	Ui.full_rect(backdrop)
	ui.add_child(backdrop)
	var stage := CreatureStage.new()
	stage.position = Vector2(500, 10)
	stage.size = Vector2(500, 470)
	ui.add_child(stage)
	stage.show_creature("forest_drake")
	var title := Ui.label("Legend Arrow", "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_theme_font_override("font", load(UiTheme.FONT_SEMIBOLD))
	title.add_theme_font_size_override("font_size", 76)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.position = Vector2(64, 150)
	ui.add_child(title)
	var tag := Ui.label("Clear the arrows. Awaken legends.", "CaptionLabel", HORIZONTAL_ALIGNMENT_LEFT)
	tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tag.add_theme_font_size_override("font_size", 30)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.position = Vector2(68, 262)
	ui.add_child(tag)
	var rule := ColorRect.new()
	rule.color = Palette.ACCENT
	rule.position = Vector2(68, 248)
	rule.size = Vector2(96, 5)
	ui.add_child(rule)
	await _settle(0.3)
	stage.rig.awaken()
	await _settle(5.5)
	await shot("feature")


func _settle(seconds := 0.25) -> void:
	await create_timer(seconds).timeout
	await process_frame


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
