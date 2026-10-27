extends SceneTree
## Drives the real app through the main flow and saves screenshots to
## build/shots/<profile>/. Needs a renderer (xvfb on Linux):
## xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##   -s res://tools/capture_screens.gd -- phone|tablet [es]
## Screenshots are visual evidence only; behaviour is asserted by tests/.

const PROFILES := {"phone": Vector2i(540, 1170), "tablet": Vector2i(900, 1200)}
const SAVE := "user://capture_save.json"

var out_dir := ""
var game: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var profile: String = args[0] if args.size() > 0 else "phone"
	var lang: String = args[1] if args.size() > 1 else "en"
	out_dir = "res://build/shots/%s_%s" % [profile, lang]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(PROFILES[profile])
	await process_frame
	game = root.get_node("Game")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE + suffix)
	game.boot(SAVE)
	game.set_setting("language", lang)
	root.add_child(load("res://scenes/main.tscn").instantiate())
	await _settle()
	await shot("01_home")

	game.go("tutorial")
	await _settle()
	await shot("02_tutorial_step1")
	var tut: Control = game.current_screen()
	tut._on_tap(tut.steps()[0].highlight)
	await _settle(0.6)
	await shot("02_tutorial_step1_done")
	tut._on_next()
	await _settle()
	tut._on_tap("a01")  # blocked on purpose
	await _settle(0.05)
	await shot("02_tutorial_step2_blocked")
	tut.finish()
	await _settle()
	await shot("03_level_select")

	game.go("puzzle", {"level_id": "forest_drake_2"})
	await _settle()
	await shot("04_puzzle")
	var pz: Control = game.current_screen()
	var blocked := ""
	for id in pz.session.board.remaining_ids():
		if not pz.session.board.is_removable(id):
			blocked = id
			break
	pz._on_tap(blocked)
	await _settle(0.05)
	await shot("04_puzzle_blocked")
	pz._on_hint()
	await _settle(0.3)
	await shot("04_puzzle_hint")
	pz.open_pause()
	await _settle()
	await shot("10_pause")
	game.leave()
	await _settle()

	game.go("puzzle", {"level_id": "forest_drake_1"})
	await _settle()
	pz = game.current_screen()
	for id in pz.level.solution:
		pz._on_tap(id)
		await _settle(0.45)
	await _settle(0.5)
	await shot("05_level_complete")
	game.go("puzzle", {"level_id": "forest_drake_2"}, true)
	await _settle()
	pz = game.current_screen()
	for id in pz.level.solution:
		pz._on_tap(id)
		await _settle(0.45)
	await _settle(0.2)
	await shot("06_awakening_early")
	await _settle(1.6)
	await shot("06_awakening_mid")
	await _settle(4.0)
	await shot("06_awakening_end")
	game.current_screen()._on_continue()
	await _settle(1.0)
	await shot("07_creature_detail")
	game.go("bestiary")
	await _settle()
	await shot("08_bestiary")
	game.go("settings")
	await _settle()
	await shot("09_settings")
	game.go("privacy")
	await _settle()
	await shot("12_privacy")
	game.reset_to("home")
	pz = game.go("puzzle", {"level_id": "forest_drake_1"})
	await _settle()
	for i in 4:
		game.progression.spend_hint("forest_drake_1")
	pz.open_hint_sheet()
	await _settle()
	await shot("11_hint_sheet")
	var home: Control = game.reset_to("home")
	Dialog.open(home, "SAVE_RESTORED_TITLE", "SAVE_RESTORED_BODY", [["CONTINUE", func(): pass, true]])
	await _settle()
	await shot("14_save_restored")
	game.reset_to("home")
	# Late-game board and a finished collection: reached through the real
	# progression rules (every level completed in campaign order).
	game.go("puzzle", {"level_id": "phoenix_2"})
	await _settle()
	await shot("15_puzzle_late_game")
	for level_id in game.campaign.level_ids():
		game.progression.complete_level(level_id)
	for cid in game.campaign.creature_ids():
		game.progression.mark_awakening_seen(cid)
	game.reset_to("home")
	game.go("bestiary")
	await _settle()
	await shot("16_bestiary_complete")
	print("capture_screens: wrote %s" % out_dir)
	quit()


func _settle(seconds := 0.25) -> void:
	await create_timer(seconds).timeout
	await process_frame


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
