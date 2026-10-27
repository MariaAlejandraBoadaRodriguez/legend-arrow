class_name AppDriver
extends RefCounted
## Drives the real screens inside the test tree: boots Game on a temp save,
## mounts screens in a phone-sized host and sends synthesized touch events to
## the board. This is in-engine scene integration, not Android instrumentation.

const SIZE := Vector2(720, 1280)

var test: GutTest
var save_path: String
var host: Control


func _init(p_test: GutTest, tag: String) -> void:
	test = p_test
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	save_path = "user://test_saves/app_%s_%d.json" % [tag, Time.get_ticks_usec()]


func start(fresh := true) -> void:
	if fresh:
		wipe()
	host = Control.new()
	host.size = SIZE
	test.add_child_autofree(host)
	Game.events.clear()
	Game.boot(save_path)
	Game.set_host(host)


## Simulates the process dying and the app launching again from disk.
func relaunch() -> Dictionary:
	Game.unmount()
	host.queue_free()
	host = Control.new()
	host.size = SIZE
	test.add_child_autofree(host)
	var res := Game.boot(save_path)
	Game.set_host(host)
	return res


func stop() -> void:
	Game.unmount()
	Game.booted = false
	wipe()


func wipe() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)


func screen() -> Control:
	return Game.current_screen()


func button(node_name: String) -> Button:
	return screen().find_child(node_name, true, false) as Button


## Presses a button the way a user would (it must be visible and enabled).
func press(node_name: String) -> bool:
	var b := button(node_name)
	if b == null:
		var d := Dialog.top(screen())
		if d != null:
			b = d.find_child(node_name, true, false) as Button
	if b == null or b.disabled or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


## Finger down + up at the middle cell of an arrow, in board-local coords.
func tap_arrow(board: BoardView, id: String) -> void:
	var cells := board.session.board.arrow(id).cells
	tap_at(board, board.cell_center(cells[cells.size() / 2]))


func tap_at(board: BoardView, pos: Vector2, index := 0) -> void:
	board._gui_input(touch(pos, true, index))
	board._gui_input(touch(pos, false, index))


static func touch(pos: Vector2, pressed: bool, index := 0, canceled := false) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = index
	e.canceled = canceled
	return e


static func drag(pos: Vector2, index := 0) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.index = index
	return e


## Waits for a board's animations. Holds only a weak reference so the wait
## never touches a board that navigation has already freed.
func board_idle(board: BoardView, max_time := 2.0) -> void:
	var w: WeakRef = weakref(board)
	await test.wait_until(func():
		var b = w.get_ref()
		return b == null or not b.is_animating(), max_time)


## Waits until the current screen is no longer the one with this instance id.
func screen_changed_from(instance_id: int, max_time := 3.0) -> void:
	await test.wait_until(func():
		var c: Control = Game.current_screen()
		return c != null and c.get_instance_id() != instance_id, max_time)


## Taps every arrow of the recorded solution, letting exit animations finish.
func solve_current_puzzle() -> void:
	var pz := screen()
	var pid := pz.get_instance_id()
	for id in pz.level.solution:
		await board_idle(pz.board)
		tap_arrow(pz.board, id)
	await screen_changed_from(pid)
