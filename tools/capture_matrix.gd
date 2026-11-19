extends SceneTree
## Captures the main screens of the real app at one device profile, for the
## v0.2 screen matrix (§9.4). Needs a renderer (xvfb on Linux):
##   xvfb-run -a -s "-screen 0 1700x2700x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy -s res://tools/capture_matrix.gd -- P1 720x1280 [1.3]
## Output: build/matrix/<profile>/<screen>.png. Progress is set up with the
## real progression rules (worlds 1-3 complete, a record on every level).

const SAVE := "user://matrix_save.json"

var out_dir := ""
var game: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var profile: String = args[0] if args.size() > 0 else "P2"
	var res: PackedStringArray = (args[1] if args.size() > 1 else "1080x1920").split("x")
	var text_scale := float(args[2]) if args.size() > 2 else 1.0
	# Typical density per profile, so 40 dp board cells are simulated (D-48).
	Ui.dpi_override = float(args[3]) if args.size() > 3 else {"P1": 320.0, "P5": 320.0, "P6": 320.0}.get(profile, 420.0)
	out_dir = "res://build/matrix/%s" % profile
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(int(res[0]), int(res[1])))
	await process_frame
	game = root.get_node("Game")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE + suffix)
	game.boot(SAVE)
	var p = game.progression
	p.data.tutorial_done = true
	for w in game.campaign.worlds.slice(0, 3):
		for l in game.campaign.levels_in_world(w.id):
			p.complete_level(l)
			p.record_result(l, 20000 + l.length() * 900, 1 + l.length() % 3)
			p.mark_awakening_seen(game.campaign.creature_of_level(l))
	game.set_setting("large_text", text_scale > 1.01)
	game.set_setting("reduce_motion", true)
	root.add_child(load("res://scenes/main.tscn").instantiate())
	await _settle()
	await shot("01_home")
	game.go("world_select")
	await _settle()
	await shot("02_world_select")
	game.go("level_select", {"world_id": "w04"})
	await _settle()
	await shot("03_level_select")
	game.go("level_select", {"world_id": "w01"})
	await _settle()
	await shot("04_level_select_done")
	game.go("puzzle", {"level_id": "ancient_dragon"})
	await _settle()
	await shot("05_puzzle_large_board")
	game.go("puzzle", {"level_id": "cloud_serpent"}, true)
	await _settle()
	var pz: Control = game.current_screen()
	var blocked := ""
	for id in pz.session.board.remaining_ids():
		if not pz.session.board.is_removable(id):
			blocked = id
			break
	pz._on_tap(blocked)
	await _settle(0.1)
	await shot("06_puzzle_blocked")
	pz._on_hint()
	await _settle(0.3)
	await shot("07_hint")
	pz.open_pause()
	await _settle()
	await shot("08_pause")
	game.go("level_complete", {"level_id": "cloud_serpent", "stars": 3, "time_ms": 42000, "par_ms": 45000,
		"new_record": true}, true)
	await _settle(1.4)
	await shot("09_results")
	game.go("bestiary")
	await _settle()
	await shot("10_bestiary")
	game.go("creature_detail", {"creature_id": "forest_drake"})
	await _settle()
	await shot("11_creature_detail")
	game.go("settings")
	await _settle()
	await shot("12_settings")
	print("capture_matrix: %s done" % profile)
	quit()


func _settle(t := 0.5) -> void:
	await create_timer(t).timeout
	await process_frame


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, label])
