extends SceneTree
## Screen matrix (v0.2 §9.4): captures every screen of the real app at one
## device profile. Needs a renderer (xvfb on Linux):
##   xvfb-run -a -s "-screen 0 1700x2700x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy -s res://tools/capture_matrix.gd -- P3
## Output: docs/qa/screens/<profile>/<NN_screen>.png (scripts/screen_matrix.sh
## runs every profile and builds docs/qa/screen_matrix.png).
## Each profile sets the window size, the density used for dp (board cells),
## the text scale, and simulated system UI: status bar / cutout / navigation
## or gesture bar insets, drawn dark on the capture so overlaps are visible.

const SAVE := "user://matrix_save.json"
# size, dpi, text scale, insets (left, top, right, bottom) in px, cutout: punch-hole x (0 = none)
const PROFILES := {
	"P1": [Vector2i(720, 1280), 320.0, 1.0, Vector4(0, 48, 0, 96), 0],          # small phone, 3-button nav
	"P2": [Vector2i(1080, 1920), 420.0, 1.0, Vector4(0, 63, 0, 63), 0],         # standard phone, gesture bar
	"P3": [Vector2i(1080, 2400), 420.0, 1.0, Vector4(0, 128, 0, 63), 540],      # tall, punch-hole camera
	"P4": [Vector2i(1080, 2640), 440.0, 1.0, Vector4(0, 145, 0, 66), -1],       # very tall, notch + gesture bar
	"P5": [Vector2i(1200, 1920), 320.0, 1.0, Vector4(0, 48, 0, 96), 0],         # 7" tablet
	"P6": [Vector2i(1600, 2560), 320.0, 1.0, Vector4(0, 48, 0, 96), 0],         # 10-11" tablet
	"P7": [Vector2i(1080, 1920), 420.0, 1.3, Vector4(0, 63, 0, 63), 0],         # P2 + text x1.3
}

var out_dir := ""
var game: Node
var insets := Vector4.ZERO
var cutout := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var profile: String = args[0] if args.size() > 0 else "P2"
	var spec: Array = PROFILES[profile]
	out_dir = "res://docs/qa/screens/%s" % profile
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(spec[0])
	Ui.dpi_override = spec[1]
	insets = spec[3]
	cutout = spec[4]
	await process_frame   # autoloads (Game) exist from the first frame
	load("res://scripts/app/main.gd").safe_insets_override = insets
	game = root.get_node("Game")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE + suffix)
	game.boot(SAVE)
	game.set_setting("large_text", spec[2] > 1.01)
	game.set_setting("reduce_motion", false)
	root.add_child(load("res://scenes/main.tscn").instantiate())
	await _settle()
	await shot("01_home")

	game.go("tutorial")
	await _settle()
	var tut: Control = game.current_screen()
	await shot("02_tutorial_step1")
	tut._on_tap(tut.steps()[0].highlight)
	await _settle(0.6)
	tut._on_next()
	await _settle()
	await shot("03_tutorial_step2")
	for id in tut.steps()[1].level.solution:
		tut._on_tap(id)
		await _settle(0.3)
	tut._on_next()
	await _settle()
	await shot("04_tutorial_step3")

	# Progress: worlds 1-3 complete with records, so lists show stars/times.
	var p = game.progression
	p.data.tutorial_done = true
	for w in game.campaign.worlds.slice(0, 3):
		for l in game.campaign.levels_in_world(w.id):
			p.complete_level(l)
			p.record_result(l, 20000 + l.length() * 900, 1 + l.length() % 3)
			p.mark_awakening_seen(game.campaign.creature_of_level(l))
	game.persist()
	game.reset_to("home")
	game.go("world_select")
	await _settle()
	await shot("05_world_select")
	game.go("level_select", {"world_id": "w03"})
	await _settle(0.8)
	await shot("06_level_select")
	game.go("puzzle", {"level_id": "ancient_dragon"})
	await _settle()
	await shot("07_puzzle_large_board")
	game.go("puzzle", {"level_id": "cloud_serpent"}, true)
	await _settle()
	var pz: Control = game.current_screen()
	var blocked := ""
	for id in pz.session.board.remaining_ids():
		if not pz.session.board.is_removable(id):
			blocked = id
			break
	pz._on_tap(blocked)
	await _settle(0.12)
	await shot("08_blocked_move")
	pz._on_hint()
	await _settle(0.4)
	await shot("09_hint_highlight")
	pz.open_pause()
	await _settle()
	await shot("10_pause")
	pz.open_hint_sheet()
	await _settle()
	await shot("11_hint_ad_sheet")
	pz.open_no_ad_sheet()
	await _settle()
	await shot("12_ad_unavailable")
	game.go("level_complete", {"level_id": "cloud_serpent", "stars": 3, "time_ms": 42000, "par_ms": 45000,
		"new_record": true}, true)
	await _settle(1.6)
	await shot("13_results")
	game.go("awakening", {"creature_id": "cloud_peaks_monarch", "replay": true})
	await _settle(1.0)
	await shot("14_awakening_start")
	await _settle(5.0)
	await shot("15_awakening_end")
	game.reset_to("bestiary")
	await _settle(0.8)
	await shot("16_bestiary")
	game.go("creature_detail", {"creature_id": "river_drake"})
	await _settle(0.8)
	await shot("17_creature_detail")
	game.go("settings")
	await _settle()
	await shot("18_settings")
	load("res://scripts/app/main.gd").route_after_boot({"recovered": true})
	await _settle()
	await shot("19_save_recovery")
	print("capture_matrix: %s done" % out_dir)
	quit()


func _settle(t := 0.5) -> void:
	await create_timer(t).timeout
	await process_frame


## Saves the frame with the simulated system UI drawn over it, so anything
## under the status bar, cutout or gesture bar is visible in review.
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var bar := Color(0.05, 0.05, 0.06, 0.82)
	img.fill_rect(Rect2i(0, 0, w, int(insets.y)), bar)
	img.fill_rect(Rect2i(0, h - int(insets.w), w, int(insets.w)), bar)
	if cutout > 0:
		_disc(img, Vector2i(cutout, int(insets.y) / 2), int(insets.y) / 3, Color.BLACK)
	elif cutout < 0:   # notch
		img.fill_rect(Rect2i(w / 2 - 180, 0, 360, int(insets.y)), Color.BLACK)
	img.save_png("%s/%s.png" % [out_dir, label])


func _disc(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if Vector2(x - c.x, y - c.y).length() <= r and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)
