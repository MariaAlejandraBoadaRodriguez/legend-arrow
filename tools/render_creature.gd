extends SceneTree
## Renders a creature's final pose and awakening frames to build/shots/ for
## visual review (needs a real renderer, e.g. under xvfb):
## xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##   -s res://tools/render_creature.gd -- forest_drake


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "forest_drake"
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	Ui.full_rect(bg)
	root.add_child(bg)
	var stage := CreatureStage.new()
	Ui.full_rect(stage)
	root.add_child(stage)
	if not stage.show_creature(id):
		printerr("render_creature: no art for %s" % id)
		quit(1)
		return
	for i in 3:
		await process_frame
	await _shot("%s_final" % id)
	stage.rig.awaken()
	var prev := 0.0
	for m in [0.6, 1.6, 2.5, 3.3, 4.2, 5.2]:
		await create_timer(m - prev).timeout
		prev = m
		await _shot("%s_t%.1f" % [id, m])
	quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/shots/%s.png" % shot_name)
