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


## Applies {part: [rotation, scale(, position)]} to named parts.
func apply_pose(p: Dictionary) -> void:
	for k in p:
		var v: Array = p[k]
		parts[k].rotation = v[0]
		parts[k].scale = v[1]
		if v.size() > 2:
			parts[k].position = v[2]


## Queues the same pose as parallel tweens on `t` (all parts move together).
func tween_pose(t: Tween, p: Dictionary, seconds: float, trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> void:
	var first := true
	for k in p:
		var v: Array = p[k]
		var step := t.tween_property(parts[k], "rotation", v[0], seconds) if first else t.parallel().tween_property(parts[k], "rotation", v[0], seconds)
		step.set_trans(trans).set_ease(ease_type)
		first = false
		t.parallel().tween_property(parts[k], "scale", v[1], seconds).set_trans(trans).set_ease(ease_type)
		if v.size() > 2:
			t.parallel().tween_property(parts[k], "position", v[2], seconds).set_trans(trans).set_ease(ease_type)


## Low pale rock the creature stands on.
static func rock_base(parent: Node2D, half_width: float, fill := Color("#C9CDCF"), shade := Color("#AEB4B8")) -> void:
	var w := half_width
	shape(parent, PackedVector2Array([Vector2(-w * 0.92, 10), Vector2(-w * 0.68, -22), Vector2(-w * 0.24, -30), Vector2(w * 0.16, -24),
		Vector2(w * 0.6, -30), Vector2(w * 0.96, 4), Vector2(w * 1.04, 40), Vector2(-w, 40)]), fill, shade, 2.0)
	stroke(parent, PackedVector2Array([Vector2(-w * 0.48, 0), Vector2(-w * 0.24, 12), Vector2(w * 0.04, 4)]), shade, 2.0)


## Feathered wing hanging from its pivot (pointing down/back when rotation is
## 0). `length` is shoulder-to-tip; feathers fan along the trailing edge.
static func feather_wing(parent: Node2D, length: float, width: float, fill: Color, quill: Color, feathers := 7) -> void:
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(width * 0.55, length * 0.25), Vector2(width * 0.45, length * 0.7), Vector2(width * 0.12, length)])
	var edge := PackedVector2Array()
	for i in feathers + 1:
		var k := float(i) / feathers
		var base := Vector2(lerpf(width * 0.12, -width * 0.5, k), lerpf(length, length * 0.18, k))
		edge.append(base)
		if i < feathers:
			var nk := float(i + 1) / feathers
			var nxt := Vector2(lerpf(width * 0.12, -width * 0.5, nk), lerpf(length, length * 0.18, nk))
			edge.append((base + nxt) * 0.5 + Vector2(-width * 0.12, length * 0.04))
	outline.append_array(edge)
	shape(parent, outline, fill, Color("#25282B"), 2.5)
	for i in range(1, feathers):
		var k := float(i) / feathers
		var tip := Vector2(lerpf(width * 0.12, -width * 0.5, k), lerpf(length, length * 0.18, k))
		stroke(parent, PackedVector2Array([Vector2(width * 0.15, length * 0.2), tip]), quill, 2.0)


## A few drifting specks (frost, embers, dust): bounded and cheap. Returns the
## node so the caller can tween its modulate.
static func specks(parent: Node2D, origin: Vector2, count: int, spread: Vector2, color: Color, radius := 4.0, seed_value := 1) -> Node2D:
	var holder := Node2D.new()
	holder.position = origin
	parent.add_child(holder)
	var rng := DeterministicRng.new(seed_value)
	for i in count:
		var p := Polygon2D.new()
		p.polygon = ellipse(Vector2.ZERO, Vector2(radius, radius), 8)
		p.color = color
		p.position = Vector2(rng.range_int(0, int(spread.x)) - spread.x / 2.0, -rng.range_int(0, int(spread.y)))
		holder.add_child(p)
	return holder


static func ellipse(center: Vector2, radii: Vector2, steps := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		out.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return out
