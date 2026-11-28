extends Control

# The cheerful farm behind everything: sky, smiling sun, drifting clouds, rolling hills, the
# red barn and silo, a fence and swaying flowers. Every piece is its own Control that draws
# itself once (Godot keeps the draw commands), so nothing static is redrawn per frame. Per
# frame we only move or rotate a few Controls: clouds drift, the sun's rays turn, flowers
# sway, and a rainbow fades in during MOO RUSH.
# Each animal has its own part of the farm: set_land("cow" / "chicken" / "monkey" / "bee") swaps
# the landmark (barn and silo, the hen house, palm trees and a hut, beehive boxes and sunflowers),
# the far hills and the fence.

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
var land: String = "cow"
var _themed: Array[Control] = []  # layers that redraw when the theme changes


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
	_themed.append(_layer(_draw_far_hill))
	_themed.append(_layer(_draw_landmarks))
	_layer(_draw_near_land)
	_themed.append(_layer(_draw_fence))
	_layer(_draw_tufts)
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


func set_land(id: String) -> void:
	if id == land:
		return
	land = id
	for c: Control in _themed:
		c.queue_redraw()


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
	c.draw_arc(center, 134.0, PI, TAU, 64, Color(1, 1, 1, 0.5), 3.0)
	for i: int in range(cols.size()):
		c.draw_arc(center, 130.0 - float(i) * 6.0, PI, TAU, 64, cols[i], 6.4)


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
	c.draw_circle(Vector2(-5, -5), 8.0, Color(1, 1, 1, 0.25))
	c.draw_arc(Vector2(-7, -2), 3.4, PI * 1.1, PI * 1.9, 10, Art.INK, 2.0)
	c.draw_arc(Vector2(7, -2), 3.4, PI * 1.1, PI * 1.9, 10, Art.INK, 2.0)
	c.draw_arc(Vector2(0, 2), 8.0, 0.2 * PI, 0.8 * PI, 16, Art.INK, 2.2)
	c.draw_circle(Vector2(-11, 5), 3.0, Color(1.0, 0.5, 0.4, 0.5))
	c.draw_circle(Vector2(11, 5), 3.0, Color(1.0, 0.5, 0.4, 0.5))


func _draw_cloud(c: Control, i: int) -> void:
	var puffs: Array[Vector3] = [Vector3(-24, 4, 12), Vector3(-9, -6, 16), Vector3(10, -9, 18), Vector3(27, 1, 13), Vector3(2, 6, 14)]
	if i % 2 == 1:
		puffs = [Vector3(-18, 3, 11), Vector3(-2, -8, 15), Vector3(16, -2, 13), Vector3(4, 6, 12)]
	for p: Vector3 in puffs:
		c.draw_circle(Vector2(p.x, p.y), p.z + 1.5, Color("#8fbfdd"))
	for p2: Vector3 in puffs:
		c.draw_circle(Vector2(p2.x, p2.y), p2.z - 0.5, Color("#e2f3fd"))
	for p3: Vector3 in puffs:
		c.draw_circle(Vector2(p3.x - 2.0, p3.y - 3.0), p3.z * 0.8, Color.WHITE)


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
	c.draw_polyline(top, line, 2.5)


func _draw_far_hill(c: Control) -> void:
	var col: Color = {"monkey": Color("#7fcf6a"), "bee": Color("#c4ea8a")}.get(land, Color("#b4e89a"))
	_draw_hill(c, _hill(186.0, 12.0, 0.017, 0.4, 7.0, 0.043, 2.0), col, OUTLINE_FAR)
	if land == "bee":
		# A wildflower meadow on the far hill.
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		var cols: Array[Color] = [Color("#ffffff"), Color("#ffe066"), Color("#ff9cc0"), Color("#b39dff")]
		for i: int in range(40):
			var x: float = rng.randf_range(0.0, PANEL_W + 10.0)
			var y: float = 196.0 + rng.randf_range(0.0, 14.0) + sin(x * 0.017 + 0.4) * 6.0
			c.draw_circle(Vector2(x, y), rng.randf_range(1.2, 2.0), cols[i % cols.size()])


func _draw_landmarks(c: Control) -> void:
	match land:
		"chicken":
			_draw_hay(c, Vector2(112, 196))
			_draw_coop(c)
		"monkey":
			_draw_hut(c)
			_draw_palm(c, Vector2(110, 210), 0.18, 1.0)
			_draw_palm(c, Vector2(14, 212), -0.12, 0.85)
		"bee":
			_draw_bee_boxes(c)
			_draw_sunflower(c, Vector2(198, 214), 62.0, 1.0)
			_draw_sunflower(c, Vector2(176, 214), 44.0, 0.8)
			_draw_sunflower(c, Vector2(218, 214), 50.0, 0.85)
		_:
			_draw_silo(c)
			_draw_barn(c)
	# Bushes at its feet.
	var bush: Color = Color("#46a93a") if land == "monkey" else Color("#5fbf3f")
	for b: Vector3 in [Vector3(10, 207, 10), Vector3(104, 206, 9), Vector3(120, 209, 7)]:
		Art.fill(c, Art.blob(Vector2(b.x, b.y), b.z, b.x, 0.1, 24), bush, Art.INK, 2.0)


func _draw_near_land(c: Control) -> void:
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
	c.draw_polyline(field_top, OUTLINE_NEAR, 2.5)
	# Mown stripes on the field, very faint.
	for k: int in range(5):
		var y: float = 252.0 + float(k) * 22.0
		c.draw_line(Vector2(0, y), Vector2(W, y + 6.0), Color(1, 1, 1, 0.06), 9.0)


func _draw_tufts(c: Control) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in range(34):
		var g: Vector2 = Vector2(rng.randf_range(4.0, PANEL_W + 160.0), rng.randf_range(244.0, 352.0))
		var s: float = rng.randf_range(0.8, 1.3)
		var tuft: PackedVector2Array = PackedVector2Array([
			g + Vector2(-4, 0) * s, g + Vector2(-2.5, -5) * s, g + Vector2(0, -1) * s,
			g + Vector2(1.5, -7) * s, g + Vector2(2.5, -1) * s, g + Vector2(5, -4.5) * s, g + Vector2(4.5, 0) * s])
		c.draw_polyline(tuft, OUTLINE_NEAR, 1.6)


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
		Vector2(15, 159), Vector2(23, 141), Vector2(47, 130), Vector2(71, 141), Vector2(79, 159)]), 3.0), trim, 2.0)
	# Hayloft window.
	Art.fill(c, Art.rrect(Rect2(40, 141, 14, 13), 2.0), Color("#5a2e24"), trim, 2.2)
	c.draw_line(Vector2(47, 142), Vector2(47, 153), trim, 1.6)
	# Big X door.
	var door: Rect2 = Rect2(33, 176, 28, 32)
	c.draw_colored_polygon(Art.rrect(door, 1.5), Color("#b8322a"))
	Art.outline(c, Art.rrect(door, 1.5), trim, 2.4)
	c.draw_line(door.position + Vector2(2, 2), door.end - Vector2(2, 2), trim, 2.4)
	c.draw_line(Vector2(door.end.x - 2, door.position.y + 2), Vector2(door.position.x + 2, door.end.y - 2), trim, 2.4)
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


# The hen house: a little red coop on stilts with a round door, a ramp and nesting-box windows.
func _draw_coop(c: Control) -> void:
	for x: float in [24.0, 70.0]:
		Art.fill(c, Art.rrect(Rect2(x - 2.5, 186, 5, 22), 1.5), Color("#a8683a"), Art.INK, 2.0)
	var body: PackedVector2Array = Art.rrect(Rect2(16, 156, 62, 34), 2.0)
	Art.fill(c, body, Art.BARN, Art.INK, 2.5)
	for k: int in range(1, 6):
		c.draw_line(Vector2(16.0 + float(k) * 10.3, 159), Vector2(16.0 + float(k) * 10.3, 188), Color(0, 0, 0, 0.12), 1.2)
	var roof: PackedVector2Array = Art.round_poly(PackedVector2Array([Vector2(8, 160), Vector2(47, 128), Vector2(86, 160)]), 3.0)
	Art.fill(c, roof, Color("#ffcc2e"), Art.INK, 2.5)
	c.draw_polyline(PackedVector2Array([Vector2(16, 156), Vector2(47, 132), Vector2(78, 156)]), Color("#e8a400"), 2.0)
	Art.fill(c, Art.ellipse(Vector2(47, 176), 8.0, 10.0, 0.0, 24), Color("#4a2620"), Art.WHITE, 2.2)
	for wx: float in [26.0, 68.0]:
		Art.fill(c, Art.rrect(Rect2(wx - 6.0, 163, 12, 10), 2.0), Color("#5a2e24"), Art.WHITE, 2.0)
		c.draw_line(Vector2(wx - 4.0, 171), Vector2(wx + 4.0, 171), Color("#e8b85c"), 2.0)
	var ramp: PackedVector2Array = PackedVector2Array([Vector2(40, 186), Vector2(54, 186), Vector2(64, 208), Vector2(52, 208)])
	Art.fill(c, ramp, Color("#e0a66b"), Art.INK, 2.0)
	for k2: int in range(1, 4):
		var t: float = float(k2) / 4.0
		c.draw_line(Vector2(40, 186).lerp(Vector2(52, 208), t), Vector2(54, 186).lerp(Vector2(64, 208), t), Color("#b47a43"), 1.6)


func _draw_hay(c: Control, at: Vector2) -> void:
	var bale: PackedVector2Array = Art.rrect(Rect2(at.x - 13.0, at.y - 8.0, 26, 16), 4.0)
	Art.fill(c, bale, Color("#f0c85a"), Art.INK, 2.2)
	for k: int in range(3):
		c.draw_line(Vector2(at.x - 10.0, at.y - 4.0 + float(k) * 4.0), Vector2(at.x + 10.0, at.y - 5.0 + float(k) * 4.0), Color("#c99a30"), 1.4)
	for x: float in [-6.0, 6.0]:
		c.draw_line(Vector2(at.x + x, at.y - 8.0), Vector2(at.x + x, at.y + 8.0), Color("#a8683a"), 1.8)


# A palm tree: a curved trunk with ring marks and a crown of fronds. lean tilts it.
func _draw_palm(c: Control, base: Vector2, lean: float, s: float) -> void:
	var top: Vector2 = base + Vector2(sin(lean) * 70.0, -80.0) * s
	var ctrl: Vector2 = base + Vector2(sin(lean) * 10.0, -45.0) * s
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var t: float = float(i) / 12.0
		pts.append(base.lerp(ctrl, t).lerp(ctrl.lerp(top, t), t))
	Art.inked_stroke(c, pts, Color("#b98552"), 7.0 * s, 2.2)
	for i2: int in range(2, 12, 2):
		var p: Vector2 = pts[i2]
		c.draw_line(p + Vector2(-3.5, 0) * s, p + Vector2(3.5, -1) * s, Color("#8a5a32"), 1.6)
	for k: int in range(6):
		var a: float = -PI * 0.5 + (float(k) - 2.5) * 0.62
		var tip: Vector2 = top + Vector2.from_angle(a) * 30.0 * s + Vector2(0, 10.0 * s * absf(float(k) - 2.5) / 2.5)
		var mid: Vector2 = top.lerp(tip, 0.5) + Vector2(0, -6.0 * s)
		var leaf: PackedVector2Array = PackedVector2Array()
		for j: int in range(9):
			var t2: float = float(j) / 8.0
			leaf.append(top.lerp(mid, t2).lerp(mid.lerp(tip, t2), t2))
		var back: PackedVector2Array = leaf.duplicate()
		back.reverse()
		var n: Vector2 = (tip - top).normalized().orthogonal() * 5.0 * s
		var poly: PackedVector2Array = PackedVector2Array()
		for j2: int in range(leaf.size()):
			poly.append(leaf[j2] + n * sin(float(j2) / 8.0 * PI))
		for j3: int in range(back.size()):
			poly.append(back[j3] - n * sin(float(back.size() - 1 - j3) / 8.0 * PI))
		Art.fill(c, poly, Color("#4fbf3a"), Art.INK, 2.0)
	for nut: Vector2 in [Vector2(-3, 4), Vector2(3, 5)]:
		Art.circle(c, top + nut * s, 3.2 * s, Color("#7a4a26"), Art.INK, 1.6)


# A little bamboo hut with a straw roof.
func _draw_hut(c: Control) -> void:
	var body: PackedVector2Array = Art.rrect(Rect2(28, 168, 48, 40), 2.0)
	Art.fill(c, body, Color("#d8b25a"), Art.INK, 2.5)
	for k: int in range(1, 6):
		var x: float = 28.0 + float(k) * 8.0
		c.draw_line(Vector2(x, 170), Vector2(x, 206), Color("#a8843a"), 1.4)
	Art.fill(c, Art.rrect(Rect2(44, 182, 16, 26), 6.0), Color("#5a3a20"), Art.INK, 2.0)
	var roof: PackedVector2Array = Art.round_poly(PackedVector2Array([Vector2(18, 172), Vector2(52, 140), Vector2(86, 172)]), 4.0)
	Art.fill(c, roof, Color("#e8c46a"), Art.INK, 2.5)
	for k2: int in range(6):
		var x2: float = 26.0 + float(k2) * 10.0
		c.draw_line(Vector2(x2, 171), Vector2(lerpf(x2, 52.0, 0.35), 158), Color("#c9a040"), 1.4)


# Beehive boxes on stands: a tall stack of three and a short one, in pastel colours.
func _draw_bee_boxes(c: Control) -> void:
	var cols: Array[Color] = [Color("#fffdf6"), Color("#ffe58a"), Color("#bfe8c8"), Color("#ffc9dc"), Color("#fffdf6")]
	var stacks: Array[Vector3] = [Vector3(10, 3, 0), Vector3(46, 2, 3)]   # x, boxes, colour offset
	for st: Vector3 in stacks:
		var x: float = st.x
		for lx: float in [x + 3.0, x + 27.0]:
			Art.fill(c, Art.rrect(Rect2(lx - 2.0, 200, 4, 9), 1.0), Color("#a8683a"), Art.INK, 1.8)
		var y: float = 200.0
		for k: int in range(int(st.y)):
			y -= 15.0
			var box: PackedVector2Array = Art.rrect(Rect2(x, y, 30, 15), 1.5)
			Art.fill(c, box, cols[(k + int(st.z)) % cols.size()], Art.INK, 2.2)
			c.draw_line(Vector2(x + 4, y + 4), Vector2(x + 26, y + 4), Color(0, 0, 0, 0.1), 1.2)
		# Entrance slot at the bottom, and the roof.
		Art.fill(c, Art.rrect(Rect2(x + 9, 196, 12, 3), 1.0), Color("#4a2620"), Art.INK, 1.2)
		var roof: PackedVector2Array = Art.round_poly(PackedVector2Array([
			Vector2(x - 4, y), Vector2(x + 2, y - 7), Vector2(x + 28, y - 7), Vector2(x + 34, y)]), 1.5, 2)
		Art.fill(c, roof, Art.BARN, Art.INK, 2.2)
	# A couple of tiny bees in the air (the scene draws once, so they hold still).
	for p: Vector2 in [Vector2(42, 136), Vector2(158, 132)]:
		Art.fill(c, Art.ellipse(p + Vector2(-1, -3.5), 3.0, 2.0, -0.4, 10), Color(0.86, 0.95, 1.0, 0.85), Art.INK, 1.1)
		Art.fill(c, Art.ellipse(p, 4.2, 3.2, 0.0, 12), Color("#ffd23a"), Art.INK, 1.3)
		c.draw_line(p + Vector2(-0.5, -2.8), p + Vector2(-0.5, 2.8), Color("#4a3328"), 1.4)


# A tall sunflower: a stem with two leaves and a big yellow head with a brown middle.
func _draw_sunflower(c: Control, base: Vector2, h: float, s: float) -> void:
	var head: Vector2 = base + Vector2(3.0 * s, -h)
	Art.inked_stroke(c, PackedVector2Array([base, base + Vector2(-2.0, -h * 0.5), head]), Color("#4fae3a"), 3.0 * s, 1.6)
	for lf: Vector3 in [Vector3(-7.0, -0.35, -0.6), Vector3(7.0, -0.55, 0.6)]:
		var lc: Vector2 = base + Vector2(lf.x * s, h * lf.y)
		Art.fill(c, Art.ellipse(lc, 7.0 * s, 3.2 * s, lf.z, 14), Color("#5fbf3f"), Art.INK, 1.6)
	for k: int in range(12):
		var a: float = TAU * float(k) / 12.0
		Art.fill(c, Art.ellipse(head + Vector2.from_angle(a) * 9.0 * s, 4.6 * s, 2.6 * s, a, 12), Color("#ffcc2e"), Art.INK, 1.4)
	Art.circle(c, head, 6.5 * s, Color("#7a4a26"), Art.INK, 1.8)
	for d: Vector2 in [Vector2(-2, -2), Vector2(2, -1), Vector2(-1, 2), Vector2(2.5, 2.5)]:
		c.draw_circle(head + d * s, 0.9 * s, Color("#4a2a14"))


func _draw_fence(c: Control) -> void:
	if land == "monkey":
		_draw_bamboo_fence(c)
		return
	var wood: Color = Color("#e0a66b") if land != "chicken" else Color("#fffdf6")
	var wood_dark: Color = Color("#b47a43") if land != "chicken" else Color("#d6cfc0")
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


func _draw_bamboo_fence(c: Control) -> void:
	var cane: Color = Color("#b9d65a")
	var joint: Color = Color("#7fa83a")
	Art.fill(c, Art.rrect(Rect2(-4, 226, PANEL_W + 12.0, 5.0), 2.0), cane, Art.INK, 2.0)
	var x: float = 4.0
	while x < PANEL_W + 6.0:
		Art.fill(c, Art.rrect(Rect2(x - 3.0, 212, 6, 32), 2.5), cane, Art.INK, 2.0)
		for jy: float in [222.0, 234.0]:
			c.draw_line(Vector2(x - 3.0, jy), Vector2(x + 3.0, jy), joint, 1.8)
		x += 14.0


func _draw_flower(c: Control, petal: Color, s: float) -> void:
	var head: Vector2 = Vector2(0, -12.0 * s)
	Art.inked_stroke(c, PackedVector2Array([Vector2.ZERO, Vector2(1.0, -6.0 * s), head]), Color("#4fae3a"), 1.6, 1.0)
	Art.fill(c, Art.ellipse(Vector2(3.0, -5.0 * s), 3.2 * s, 1.5 * s, -0.6, 12), Color("#5fbf3f"), Art.INK, 1.0)
	for k: int in range(5):
		var a: float = TAU * float(k) / 5.0 - PI / 2.0
		Art.circle(c, head + Vector2(cos(a), sin(a)) * 3.3 * s, 2.5 * s, petal, Art.INK, 1.0)
	Art.circle(c, head, 2.2 * s, Color("#ffb627"), Art.INK, 1.0)
