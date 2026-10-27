extends SceneTree
## Rasterises a creature's final-pose silhouette (base/props hidden) onto a
## puzzle grid and stores it as the creature's level mask for one slot.
## Needs a renderer (xvfb on Linux):
## xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##   -s res://tools/make_mask.gd -- <creature_id> <slot 1|2> <width> <height> [coverage=0.35] [dilate=0]
## `dilate` thickens thin silhouettes (serpents) by N 4-neighbour passes so a
## one-cell-wide body still leaves room for arrows.

const VIEW := Vector2i(1200, 1000)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var cid: String = a[0]
	var slot := int(a[1])
	var gw := int(a[2])
	var gh := int(a[3])
	var cover := float(a[4]) if a.size() > 4 else 0.35
	var dilate := int(a[5]) if a.size() > 5 else 0
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var meta_path := "res://data/creatures/%s.json" % cid
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var rig: CreatureRig = load(meta.art).instantiate()
	rig.position = Vector2(VIEW.x * 0.5, VIEW.y * 0.85)
	vp.add_child(rig)
	await process_frame
	# Hide everything that is not part of the creature's body (base, mist, specks).
	var body_parts := rig.parts.values()
	for child in rig.parts.root.get_children():
		if not body_parts.has(child):
			child.visible = false
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var used := img.get_used_rect()
	if used.size.x == 0:
		printerr("make_mask: empty render")
		quit(1)
		return
	# Fit the silhouette into the grid keeping its aspect ratio, centred.
	var scale := minf(gw / float(used.size.x), gh / float(used.size.y))
	var off := (Vector2(gw, gh) - Vector2(used.size) * scale) * 0.5
	var rows: Array = []
	var cells := 0
	for y in gh:
		var row := ""
		for x in gw:
			var x0 := used.position.x + (x - off.x) / scale
			var y0 := used.position.y + (y - off.y) / scale
			var x1 := x0 + 1.0 / scale
			var y1 := y0 + 1.0 / scale
			var hit := 0
			var total := 0
			for sy in range(int(y0), int(ceil(y1)), maxi(1, int((y1 - y0) / 6))):
				for sx in range(int(x0), int(ceil(x1)), maxi(1, int((x1 - x0) / 6))):
					total += 1
					if sx >= 0 and sy >= 0 and sx < img.get_width() and sy < img.get_height() and img.get_pixel(sx, sy).a > 0.5:
						hit += 1
			var on := total > 0 and float(hit) / total >= cover
			row += "#" if on else "."
			cells += 1 if on else 0
		rows.append(row)
	for _pass in dilate:
		var grown: Array = []
		for y in gh:
			var row := ""
			for x in gw:
				var on: bool = rows[y][x] == "#"
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < gw and ny < gh and rows[ny][nx] == "#":
						on = true
				row += "#" if on else "."
			grown.append(row)
		rows = grown
	cells = 0
	for r in rows:
		cells += r.count("#")
	var masks: Array = meta.get("level_masks", [[], []])
	while masks.size() < 2:
		masks.append([])
	masks[slot - 1] = rows
	meta["level_masks"] = masks
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  ", false) + "\n")
	f.close()
	print("\n".join(rows))
	print("make_mask: %s slot %d %dx%d -> %d cells" % [cid, slot, gw, gh, cells])
	quit(0)
