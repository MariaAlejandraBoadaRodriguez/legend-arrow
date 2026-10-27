class_name CreatureRig
extends Node2D
## Layered 2D cut-out creature. Subclasses build parts (each a pivot Node2D
## holding filled shapes and ink outlines) and implement poses.
##
## Lifecycle: awaken() plays the signature sequence (emits awakening_finished),
## skip() jumps to the final pose, start_idle() loops subtle breathing/tail
## motion, stop() kills every tween. Reduced motion: a short dissolve to the
## final pose, no movement.

signal awakening_finished

const AWAKEN_SECONDS := 5.0

var parts := {}               # name -> Node2D pivot
## Parent of all parts.
var group: Node2D
## What the reveal fades. CreatureStage points this at the composited texture
## so overlapping layers never show through each other mid-fade.
var fade_target: CanvasItem
var reduce_motion := false
var awakening := false
var _tweens: Array[Tween] = []
var _idle: Array[Tween] = []


func _ready() -> void:
	# Parts use small relative z offsets (-3..4); lift the whole rig so those
	# never fall behind the screen background.
	z_index = 10
	group = Node2D.new()
	group.name = "Group"
	add_child(group)
	if fade_target == null:
		fade_target = self
	build()
	pose_final()


## Override: create parts with add_part().
func build() -> void:
	pass


## Override: folded/dormant pose before the reveal.
func pose_dormant() -> void:
	pass


## Override: settled final pose.
func pose_final() -> void:
	pass


## Override: queue the signature motion on `t` (a parallel-capable tween).
func signature(_t: Tween) -> void:
	pass


## Override: queue idle loops. Return the created looping tweens.
func idle_tweens() -> Array[Tween]:
	return []


func awaken() -> void:
	stop()
	awakening = true
	if reduce_motion:
		pose_final()
		fade_target.modulate = Color(1, 1, 1, 0)
		var t := _track(create_tween())
		t.tween_property(fade_target, "modulate:a", 1.0, 0.6)
		t.tween_callback(_finish)
		return
	pose_dormant()
	fade_target.modulate = Color(0.3, 0.33, 0.36, 0.0)
	var t := _track(create_tween())
	# 0.0-1.2 s: faint silhouette gathers.
	t.tween_property(fade_target, "modulate", Color(0.3, 0.33, 0.36, 0.45), 1.2).set_trans(Tween.TRANS_SINE)
	# 1.2-2.0 s: full form resolves.
	t.tween_property(fade_target, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
	# 2.0-~4.6 s: signature movement.
	signature(t)
	t.tween_callback(_finish)


func skip() -> void:
	if not awakening:
		return
	stop()
	pose_final()
	fade_target.modulate = Color.WHITE
	_finish()


func _finish() -> void:
	awakening = false
	awakening_finished.emit()


func start_idle() -> void:
	for t in _idle:
		t.kill()
	_idle.clear()
	if reduce_motion:
		return
	_idle = idle_tweens()


func stop() -> void:
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	for t in _idle:
		if t.is_valid():
			t.kill()
	_idle.clear()


func _track(t: Tween) -> Tween:
	_tweens.append(t)
	return t


func _exit_tree() -> void:
	stop()


# --- shape helpers ----------------------------------------------------------

## Adds a pivot node. `at` is its position in the parent's space.
func add_part(part_name: String, parent: Node2D, at: Vector2, z := 0) -> Node2D:
	var n := Node2D.new()
	n.name = part_name
	n.position = at
	n.z_index = z
	parent.add_child(n)
	parts[part_name] = n
	return n


## Filled polygon with an ink outline.
static func shape(parent: Node2D, pts: PackedVector2Array, fill: Color, ink := Color("#25282B"), ink_w := 3.0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = fill
	p.antialiased = true
	parent.add_child(p)
	if ink_w > 0.0:
		var l := Line2D.new()
		var closed := pts.duplicate()
		closed.append(pts[0])
		l.points = closed
		l.width = ink_w
		l.default_color = ink
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.antialiased = true
		parent.add_child(l)
	return p


static func stroke(parent: Node2D, pts: PackedVector2Array, color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	parent.add_child(l)
	return l


## Smooth Catmull-Rom samples through control points.
static func spline(ctrl: Array, samples_per_seg := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in samples_per_seg:
			var t := float(s) / samples_per_seg
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[ctrl.size() - 1])
	return out


## Closed outline of a tapering band along a polyline (widths are half-widths
## at the start and end, interpolated).
static func ribbon(line: PackedVector2Array, w_start: float, w_end: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := line.size()
	for i in n:
		var a := line[maxi(i - 1, 0)]
		var b := line[mini(i + 1, n - 1)]
		var tangent := (b - a).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var w := lerpf(w_start, w_end, float(i) / maxf(1.0, n - 1))
		left.append(line[i] + normal * w)
		right.append(line[i] - normal * w)
	right.reverse()
	left.append_array(right)
	return left


static func ellipse(center: Vector2, radii: Vector2, steps := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		out.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return out
