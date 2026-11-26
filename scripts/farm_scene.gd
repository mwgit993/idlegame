extends Control

# The cheerful farm behind everything: sky, smiling sun, drifting clouds, rolling hills, the
# red barn and silo, a fence and swaying flowers. Every piece is its own Control that draws
# itself once (Godot keeps the draw commands), so nothing static is redrawn per frame. Per
# frame we only move or rotate a few Controls: clouds drift, the sun's rays turn, flowers
# sway, and a rainbow fades in during MOO RUSH.

const W: float = 640.0
const H: float = 360.0
const PANEL_W: float = 232.0  # the part of the farm that isn't covered by the right panel
const OUTLINE_FAR: Color = Color("#5fae4f")
const OUTLINE_NEAR: Color = Color("#3f8f2c")

var _t: float = 0.0
var _clouds: Array[Control] = []
var _cloud_speed: Array[float] = []
var _flowers: Array[Control] = []
var _flower_phase: Array[float] = []
var _rays: Control
var _rainbow: Control


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer(_draw_sky)
	_rainbow = _layer(_draw_rainbow)
	_rainbow.modulate.a = 0.0
	var sun: Control = _layer(func(_c: Control) -> void: pass)
	sun.position = Vector2(198.0, 76.0)
	_rays = _layer(_draw_sun_rays, sun)
	_layer(_draw_sun_face, sun)
	var cloud_defs: Array[Vector3] = [
		Vector3(30.0, 58.0, 0.9), Vector3(150.0, 110.0, 0.65), Vector3(330.0, 70.0, 1.0),
		Vector3(470.0, 120.0, 0.7), Vector3(-60.0, 132.0, 0.55),
	]
	for i: int in range(cloud_defs.size()):
		var cd: Vector3 = cloud_defs[i]
		var cl: Control = _layer(_draw_cloud.bind(i))
		cl.position = Vector2(cd.x, cd.y)
		cl.scale = Vector2(cd.z, cd.z)
		_clouds.append(cl)
		_cloud_speed.append(4.0 + cd.z * 6.0)
	_layer(_draw_land)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2024
	var spots: Array[Vector2] = [
		Vector2(8, 246), Vector2(30, 243), Vector2(110, 244), Vector2(176, 245), Vector2(214, 243),
		Vector2(10, 300), Vector2(22, 314), Vector2(206, 296), Vector2(222, 312), Vector2(196, 316),
	]
	var petal_cols: Array[Color] = [Color("#ffffff"), Color("#ffe066"), Color("#ff9cc0"), Color("#b39dff")]
	for i: int in range(spots.size()):
		var fl: Control = _layer(_draw_flower.bind(petal_cols[i % petal_cols.size()], 0.8 + rng.randf() * 0.4))
		fl.position = spots[i]
		_flowers.append(fl)
		_flower_phase.append(rng.randf() * TAU)


func _layer(cb: Callable, parent: Control = null) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: cb.call(c))
	if parent == null:
		add_child(c)
	else:
		parent.add_child(c)
	return c


func _process(delta: float) -> void:
	_t += delta
	for i: int in range(_clouds.size()):
		var cl: Control = _clouds[i]
		cl.position.x += _cloud_speed[i] * delta
		if cl.position.x > W + 70.0:
			cl.position.x = -90.0
	_rays.rotation = _t * 0.18
	for i: int in range(_flowers.size()):
		_flowers[i].rotation = sin(_t * 1.7 + _flower_phase[i]) * 0.16
	var want: float = 0.9 if Farm.rush_left > 0.0 else 0.0
	_rainbow.modulate.a = move_toward(_rainbow.modulate.a, want, delta * 1.5)


# =========================================================================================
# DRAWING (each runs once)
# =========================================================================================
func _draw_sky(c: Control) -> void:
	var top: Color = Color("#3fb0ec")
	var bot: Color = Color("#c8f0ff")
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 240), Vector2(0, 240)]),
		PackedColorArray([top, top, bot, bot]))


func _draw_rainbow(c: Control) -> void:
	var cols: Array[Color] = [Color("#ff5a5a"), Color("#ffa53a"), Color("#ffe14a"), Color("#6fdc5a"), Color("#4ab8ff"), Color("#a07cff")]
	var center: Vector2 = Vector2(118.0, 236.0)
	c.draw_arc(center, 134.0, PI, TAU, 64, Color(1, 1, 1, 0.5), 3.0, true)
	for i: int in range(cols.size()):
		c.draw_arc(center, 130.0 - float(i) * 6.0, PI, TAU, 64, cols[i], 6.4, true)


func _draw_sun_rays(c: Control) -> void:
	for i: int in range(12):
		var a: float = TAU * float(i) / 12.0
		var long: float = 31.0 if i % 2 == 0 else 26.0
		var d: Vector2 = Vector2(cos(a), sin(a))
		var n: Vector2 = Vector2(-d.y, d.x)
		var ray: PackedVector2Array = Art.round_poly(PackedVector2Array([
			d * 19.0 + n * 5.0, d * long, d * 19.0 - n * 5.0]), 2.0, 3)
		Art.fill(c, ray, Color("#ffd23f"), Color("#ef9b0f"), 2.0)


func _draw_sun_face(c: Control) -> void:
	Art.circle(c, Vector2.ZERO, 20.0, Color("#ffe45c"), Color("#ef9b0f"), 2.5)
	c.draw_circle(Vector2(-5, -5), 8.0, Color(1, 1, 1, 0.25), true, -1.0, true)
	c.draw_arc(Vector2(-7, -2), 3.4, PI * 1.1, PI * 1.9, 10, Art.INK, 2.0, true)
	c.draw_arc(Vector2(7, -2), 3.4, PI * 1.1, PI * 1.9, 10, Art.INK, 2.0, true)
	c.draw_arc(Vector2(0, 2), 8.0, 0.2 * PI, 0.8 * PI, 16, Art.INK, 2.2, true)
	c.draw_circle(Vector2(-11, 5), 3.0, Color(1.0, 0.5, 0.4, 0.5), true, -1.0, true)
	c.draw_circle(Vector2(11, 5), 3.0, Color(1.0, 0.5, 0.4, 0.5), true, -1.0, true)


func _draw_cloud(c: Control, i: int) -> void:
	var puffs: Array[Vector3] = [Vector3(-24, 4, 12), Vector3(-9, -6, 16), Vector3(10, -9, 18), Vector3(27, 1, 13), Vector3(2, 6, 14)]
	if i % 2 == 1:
		puffs = [Vector3(-18, 3, 11), Vector3(-2, -8, 15), Vector3(16, -2, 13), Vector3(4, 6, 12)]
	for p: Vector3 in puffs:
		c.draw_circle(Vector2(p.x, p.y), p.z + 1.5, Color("#8fbfdd"), true, -1.0, true)
	for p2: Vector3 in puffs:
		c.draw_circle(Vector2(p2.x, p2.y), p2.z - 0.5, Color("#e2f3fd"), true, -1.0, true)
	for p3: Vector3 in puffs:
		c.draw_circle(Vector2(p3.x - 2.0, p3.y - 3.0), p3.z * 0.8, Color.WHITE, true, -1.0, true)


func _hill(y0: float, a1: float, f1: float, p1: float, a2: float, f2: float, p2: float) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array()
	var x: float = -10.0
	while x <= W + 10.0:
		top.append(Vector2(x, y0 - a1 * sin(x * f1 + p1) - a2 * sin(x * f2 + p2)))
		x += 8.0
	return top


func _draw_hill(c: Control, top: PackedVector2Array, col: Color, line: Color) -> void:
	var poly: PackedVector2Array = top.duplicate()
	poly.append(Vector2(W + 10.0, H + 10.0))
	poly.append(Vector2(-10.0, H + 10.0))
	c.draw_colored_polygon(poly, col)
	c.draw_polyline(top, line, 2.5, true)


func _draw_land(c: Control) -> void:
	# Far hills.
	_draw_hill(c, _hill(186.0, 12.0, 0.017, 0.4, 7.0, 0.043, 2.0), Color("#b4e89a"), OUTLINE_FAR)
	_draw_silo(c)
	_draw_barn(c)
	# Bushes at the barn's feet.
	for b: Vector3 in [Vector3(10, 207, 10), Vector3(104, 206, 9), Vector3(120, 209, 7)]:
		Art.fill(c, Art.blob(Vector2(b.x, b.y), b.z, b.x, 0.1, 24), Color("#5fbf3f"), Art.INK, 2.0)
	# Middle hill and the near field.
	_draw_hill(c, _hill(212.0, 4.0, 0.03, 1.0, 3.0, 0.08, 0.3), Color("#97dc6c"), OUTLINE_FAR)
	var field_top: PackedVector2Array = _hill(226.0, 2.5, 0.02, 2.0, 1.5, 0.06, 1.0)
	var field: PackedVector2Array = field_top.duplicate()
	field.append(Vector2(W + 10.0, H + 10.0))
	field.append(Vector2(-10.0, H + 10.0))
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in field:
		cols.append(Color("#8ede5c").lerp(Color("#5aae3a"), clampf((p.y - 226.0) / 134.0, 0.0, 1.0)))
	c.draw_polygon(field, cols)
	c.draw_polyline(field_top, OUTLINE_NEAR, 2.5, true)
	# Mown stripes on the field, very faint.
	for k: int in range(5):
		var y: float = 252.0 + float(k) * 22.0
		c.draw_line(Vector2(0, y), Vector2(W, y + 6.0), Color(1, 1, 1, 0.06), 9.0)
	_draw_fence(c)
	# Grass tufts.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in range(34):
		var g: Vector2 = Vector2(rng.randf_range(4.0, PANEL_W + 160.0), rng.randf_range(244.0, 352.0))
		var s: float = rng.randf_range(0.8, 1.3)
		var tuft: PackedVector2Array = PackedVector2Array([
			g + Vector2(-4, 0) * s, g + Vector2(-2.5, -5) * s, g + Vector2(0, -1) * s,
			g + Vector2(1.5, -7) * s, g + Vector2(2.5, -1) * s, g + Vector2(5, -4.5) * s, g + Vector2(4.5, 0) * s])
		c.draw_polyline(tuft, OUTLINE_NEAR, 1.6, true)


func _draw_barn(c: Control) -> void:
	var trim: Color = Art.WHITE
	var body: PackedVector2Array = Art.rrect(Rect2(16, 158, 62, 50), 2.0)
	Art.fill(c, body, Art.BARN, Art.INK, 2.5)
	# Planks.
	for k: int in range(1, 6):
		var x: float = 16.0 + float(k) * 10.3
		c.draw_line(Vector2(x, 162), Vector2(x, 206), Color(0, 0, 0, 0.12), 1.2)
	# Gambrel roof with white trim.
	var roof: PackedVector2Array = Art.round_poly(PackedVector2Array([
		Vector2(10, 162), Vector2(20, 139), Vector2(47, 126), Vector2(74, 139), Vector2(84, 162)]), 3.0)
	Art.fill(c, roof, Art.BARN_DARK, Art.INK, 2.5)
	c.draw_polyline(Art.round_poly(PackedVector2Array([
		Vector2(15, 159), Vector2(23, 141), Vector2(47, 130), Vector2(71, 141), Vector2(79, 159)]), 3.0), trim, 2.0, true)
	# Hayloft window.
	Art.fill(c, Art.rrect(Rect2(40, 141, 14, 13), 2.0), Color("#5a2e24"), trim, 2.2)
	c.draw_line(Vector2(47, 142), Vector2(47, 153), trim, 1.6)
	# Big X door.
	var door: Rect2 = Rect2(33, 176, 28, 32)
	c.draw_colored_polygon(Art.rrect(door, 1.5), Color("#b8322a"))
	Art.outline(c, Art.rrect(door, 1.5), trim, 2.4)
	c.draw_line(door.position + Vector2(2, 2), door.end - Vector2(2, 2), trim, 2.4, true)
	c.draw_line(Vector2(door.end.x - 2, door.position.y + 2), Vector2(door.position.x + 2, door.end.y - 2), trim, 2.4, true)
	c.draw_line(Vector2(door.position.x + door.size.x * 0.5, door.position.y + 1), Vector2(door.position.x + door.size.x * 0.5, door.end.y - 1), trim, 1.6)
	Art.outline(c, Art.rrect(Rect2(31, 174, 32, 34), 2.0), Art.INK, 1.6)


func _draw_silo(c: Control) -> void:
	var body: PackedVector2Array = Art.rrect(Rect2(80, 146, 20, 62), 2.0)
	Art.fill(c, body, Color("#dfe7ec"), Art.INK, 2.5)
	for k: int in range(1, 6):
		var y: float = 146.0 + float(k) * 10.0
		c.draw_line(Vector2(82, y), Vector2(98, y), Color("#a9b8c3"), 1.4)
	c.draw_line(Vector2(84, 150), Vector2(84, 204), Color(1, 1, 1, 0.7), 2.0)
	var dome: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI + PI * float(i) / 16.0
		dome.append(Vector2(90, 147) + Vector2(cos(a) * 11.5, sin(a) * 10.0))
	Art.fill(c, dome, Color("#8fa4b3"), Art.INK, 2.5)


func _draw_fence(c: Control) -> void:
	var wood: Color = Color("#e0a66b")
	var wood_dark: Color = Color("#b47a43")
	for rail_y: float in [221.0, 233.0]:
		var rail: PackedVector2Array = Art.rrect(Rect2(-4, rail_y, PANEL_W + 12.0, 5.0), 2.0)
		Art.fill(c, rail, wood, Art.INK, 2.0)
		c.draw_line(Vector2(0, rail_y + 1.6), Vector2(PANEL_W + 6.0, rail_y + 1.6), Color(1, 1, 1, 0.35), 1.2)
	var x: float = 6.0
	while x < PANEL_W + 6.0:
		var post: PackedVector2Array = Art.round_poly(PackedVector2Array([
			Vector2(x - 3.5, 244), Vector2(x - 3.5, 216), Vector2(x, 211), Vector2(x + 3.5, 216), Vector2(x + 3.5, 244)]), 1.5, 2)
		Art.fill(c, post, wood, Art.INK, 2.0)
		c.draw_line(Vector2(x + 1.5, 217), Vector2(x + 1.5, 242), wood_dark, 1.2)
		x += 28.0


func _draw_flower(c: Control, petal: Color, s: float) -> void:
	var head: Vector2 = Vector2(0, -12.0 * s)
	Art.inked_stroke(c, PackedVector2Array([Vector2.ZERO, Vector2(1.0, -6.0 * s), head]), Color("#4fae3a"), 1.6, 1.0)
	Art.fill(c, Art.ellipse(Vector2(3.0, -5.0 * s), 3.2 * s, 1.5 * s, -0.6, 12), Color("#5fbf3f"), Art.INK, 1.0)
	for k: int in range(5):
		var a: float = TAU * float(k) / 5.0 - PI / 2.0
		Art.circle(c, head + Vector2(cos(a), sin(a)) * 3.3 * s, 2.5 * s, petal, Art.INK, 1.0)
	Art.circle(c, head, 2.2 * s, Color("#ffb627"), Art.INK, 1.0)
