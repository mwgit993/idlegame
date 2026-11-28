extends "res://scripts/critter.gd"

# The bee (the fourth animal, in the bee meadow): a round plush bumblebee hovering over the grass.
# Big yellow head with antennae, a fuzzy collar, a striped body, little see-through wings that
# flutter all the time (a blur on every click and in the rush), stubby arms and dangling legs.
# She holds a honey dipper; each click she flicks it and a drop of honey flies into the glass jar
# beside her, which fills up and empties with a sparkle. A straw beehive (a skep) sits on a stand
# to her left with two tiny bees buzzing around it. The shared parts (springs, eyes, the rush
# dance, goodies) are in critter.gd.

const YELLOW: Color = Color("#ffd23a")
const YELLOW_SHADE: Color = Color("#f2b41c")
const STRIPE: Color = Color("#4a3328")
const FUZZ: Color = Color("#fff3d2")
const WING: Color = Color(0.86, 0.95, 1.0, 0.78)
const WING_VEIN: Color = Color(0.62, 0.8, 0.95, 0.9)
const HONEY: Color = Color("#ffb21e")
const HONEY_DARK: Color = Color("#e5870f")
const HONEY_LIGHT: Color = Color("#ffd776")
const WOOD: Color = Color("#c98a4b")
const WOOD_DARK: Color = Color("#9a6232")
const STRAW: Color = Color("#e8b85c")
const STRAW_DARK: Color = Color("#b7803a")
const LW: float = 3.0

const BODY_C: Vector2 = Vector2(-6, -58)
const HEAD_C: Vector2 = Vector2(4, -110)
const NECK: Vector2 = Vector2(0, -84)
const EYES: Array[Vector2] = [Vector2(-7, -115), Vector2(15, -115)]
const SHOULDER_R: Vector2 = Vector2(22, -66)
const SKEP: Vector2 = Vector2(-70, 0)          # the beehive's stand, relative to ground
const DIPPER_LEN: float = 24.0
const DIP_REST: float = -0.85                   # the dipper held up and out
const DIP_FLICK: float = 0.55                   # swung down toward the jar

var _flick: float = 0.0     # 1 = the dipper swung toward the jar
var _flick_v: float = 0.0
var _buzz: float = 0.0      # wing blur after a click
var _body: PackedVector2Array
var _stripes: Array[PackedVector2Array] = []
var _collar: PackedVector2Array


func _ready() -> void:
	super._ready()
	container_pos = Vector2(84.0, -32.0)
	_body = Art.superellipse(BODY_C, 34.0, 29.0, 2.2, 48)
	for band: Vector2 in [Vector2(-71.0, -62.0), Vector2(-53.0, -44.0)]:
		_stripes.append_array(Art.clip(_body, _band(band.x, band.y)))
	_collar = PackedVector2Array()
	for i: int in range(48):
		var a: float = TAU * float(i) / 48.0
		var r: float = 1.0 + 0.1 * sin(a * 9.0)
		_collar.append(NECK + Vector2(cos(a) * 23.0 * r, sin(a) * 8.0 * r))


# A stripe across the body, curving down a little in the middle like it wraps around her.
func _band(y0: float, y1: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var x: float = lerpf(-48.0, 36.0, float(i) / 12.0)
		var k: float = (x - BODY_C.x) / 42.0
		pts.append(Vector2(x, y0 + 4.0 * (1.0 - k * k)))
	for i2: int in range(12, -1, -1):
		var x2: float = lerpf(-48.0, 36.0, float(i2) / 12.0)
		var k2: float = (x2 - BODY_C.x) / 42.0
		pts.append(Vector2(x2, y1 + 4.0 * (1.0 - k2 * k2)))
	return pts


func _on_click() -> void:
	_flick_v += 11.0
	_buzz = 1.0


# The drop leaves the dipper's tip (she bobs, so it's worked out now, not fixed).
func _goodie_start() -> Vector2:
	return _dipper_tip() + Vector2(0.0, _bob())


func _animate(dt: float) -> void:
	_flick_v += (-120.0 * _flick - 11.0 * _flick_v) * dt
	_flick += _flick_v * dt
	_flick = clampf(_flick, -0.3, 1.2)
	_buzz = move_toward(_buzz, 0.0, dt * 2.5)


# She hovers: a slow bob up and down.
func _bob() -> float:
	return sin(_t * 2.6) * 4.0 - 2.0


func _hand_r() -> Vector2:
	var k: float = clampf(_flick, 0.0, 1.0)
	return Vector2(34.0, -58.0).lerp(Vector2(38.0, -50.0), k) + Vector2(0.0, sin(_t * 2.2 + 1.0) * 1.0)


func _dipper_angle() -> float:
	return lerpf(DIP_REST, DIP_FLICK, clampf(_flick, -0.2, 1.1))


func _dipper_tip() -> Vector2:
	return _hand_r() + Vector2.from_angle(_dipper_angle()) * (DIPPER_LEN + 4.0)


func _draw_animal() -> void:
	var lift: Transform2D = Transform2D(0.0, Vector2(0.0, _bob()))
	var xf: Transform2D = _xf() * lift
	draw_set_transform_matrix(xf)
	# Wings on her back, behind everything: a big and a small one each side.
	var speed: float = 34.0 + 30.0 * maxf(_buzz, _rush)
	var amp: float = 0.22 + 0.25 * maxf(_buzz, _rush)
	for side: float in [-1.0, 1.0]:
		var root: Vector2 = Vector2(-6.0 + 12.0 * side, -82.0)
		var flap: float = sin(_t * speed + (0.0 if side < 0.0 else 0.6)) * amp
		_draw_wing(root, -PI * 0.5 + side * (0.8 + flap), 21.0, 12.0)
		_draw_wing(root + Vector2(4.0 * side, 6.0), -PI * 0.5 + side * (1.45 + flap * 0.8), 14.0, 8.0)
	# Dangling legs.
	for lx: float in [-18.0, 4.0]:
		var swing: float = sin(_t * 3.0 + lx * 0.2) * 2.5 + maxf(0.0, sin(_t * 14.0 + lx)) * 3.0 * _rush
		var foot: Vector2 = Vector2(lx - 1.0 + swing, -20.0)
		Art.inked_stroke(self, PackedVector2Array([Vector2(lx, -34.0), Vector2(lx + swing * 0.5, -27.0), foot]), STRIPE, 4.0, 2.0)
		Art.fill(self, Art.ellipse(foot + Vector2(1.5, 1.0), 4.0, 2.8, 0.0, 14), STRIPE, INK, 1.8)
	# A tiny rounded stinger at her back.
	var sting: PackedVector2Array = Art.round_poly(PackedVector2Array([
		BODY_C + Vector2(-31.0, 6.0), BODY_C + Vector2(-44.0, 12.0), BODY_C + Vector2(-30.0, 14.0)]), 1.5, 3)
	Art.fill(self, sting, STRIPE, INK, 2.0)
	# Left arm, waving a little at her side.
	var hand_l: Vector2 = Vector2(-44.0, -52.0) + Vector2(0.0, sin(_t * 2.2) * 2.0 - 3.0 * _pop)
	Art.inked_stroke(self, PackedVector2Array([Vector2(-34.0, -66.0), Vector2(-42.0, -60.0), hand_l]), STRIPE, 6.0, 2.2)
	Art.fill(self, Art.ellipse(hand_l, 5.0, 4.5, 0.0, 14), STRIPE, INK, 2.0)
	# Body with its stripes and a soft shine.
	draw_colored_polygon(_body, YELLOW)
	draw_colored_polygon(Art.ellipse(BODY_C + Vector2(4.0, 18.0), 24.0, 8.0, 0.0, 20), YELLOW_SHADE)
	for s: PackedVector2Array in _stripes:
		draw_colored_polygon(s, STRIPE)
	Art.outline(self, _body, INK, LW)
	draw_colored_polygon(Art.ellipse(BODY_C + Vector2(-14.0, -14.0), 7.0, 3.5, -0.5, 14), Color(1, 1, 1, 0.3))
	# Right arm holding the honey dipper.
	var hand: Vector2 = _hand_r()
	var ang: float = _dipper_angle()
	var tip: Vector2 = hand + Vector2.from_angle(ang) * DIPPER_LEN
	var d: Vector2 = Vector2.from_angle(ang)
	Art.inked_stroke(self, PackedVector2Array([hand - d * 6.0, tip]), WOOD, 3.6, 2.0)
	var head: PackedVector2Array = Art.rrect(Rect2(-5.0, -5.5, 12.0, 11.0), 3.5)
	var hx: Transform2D = Transform2D(ang, tip + d * 4.0)
	Art.fill(self, hx * head, HONEY, INK, 2.0)
	for gx: float in [-1.5, 2.5]:
		draw_line(hx * Vector2(gx, -5.0), hx * Vector2(gx, 5.0), HONEY_DARK, 1.4)
	draw_colored_polygon(hx * Art.ellipse(Vector2(-1.0, -2.5), 2.5, 1.2, 0.0, 10), Color(1, 1, 1, 0.6))
	var elbow: Vector2 = SHOULDER_R.lerp(hand, 0.5) + Vector2(4.0, 3.0)
	Art.inked_stroke(self, PackedVector2Array([SHOULDER_R, elbow, hand]), STRIPE, 6.0, 2.2)
	Art.fill(self, Art.ellipse(hand, 5.0, 4.5, 0.0, 14), STRIPE, INK, 2.0)
	# Fuzzy collar between body and head.
	Art.fill(self, _collar, FUZZ, INK, 2.4)
	# Head: antennae behind it, then the head and the face.
	var hxf: Transform2D = xf * _head_xf(NECK)
	draw_set_transform_matrix(hxf)
	for side2: float in [-1.0, 1.0]:
		var wob: float = sin(_t * 3.0 + side2) * 2.0 + _pop * 5.0 * side2
		var base: Vector2 = HEAD_C + Vector2(10.0 * side2 + 2.0, -24.0)
		var knob: Vector2 = HEAD_C + Vector2(22.0 * side2 + 2.0 + wob, -48.0 - _pop * 3.0)
		var mid: Vector2 = base.lerp(knob, 0.5) + Vector2(-5.0 * side2, 0.0)
		Art.inked_stroke(self, PackedVector2Array([base, mid, knob]), STRIPE, 3.2, 1.8)
		Art.circle(self, knob, 5.0, STRIPE, INK, 2.0)
		draw_circle(knob + Vector2(-1.5, -1.5), 1.4, Color(1, 1, 1, 0.6))
	Art.fill(self, Art.ellipse(HEAD_C, 31.0, 29.0, 0.0, 48), YELLOW, INK, LW)
	draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(-13.0, -15.0), 8.0, 4.0, -0.5, 16), Color(1, 1, 1, 0.4))
	var a: float = 0.42 + 0.2 * _pop + 0.25 * _rush
	for side3: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(4.0 + 19.0 * side3, 5.0), 6.0, 3.8, 0.0, 18), Color(CHEEK.r, CHEEK.g, CHEEK.b, a))
	_draw_eyes(EYES, 5.6, 7.2)
	var m: Vector2 = HEAD_C + Vector2(4.0, 8.0)
	if _rush > 0.4 or _pop > 0.3:
		var open: float = maxf(_pop, _rush)
		_draw_open_mouth(m, 5.0 + 3.0 * open, 3.0 + 4.0 * open)
	else:
		draw_arc(m + Vector2(0.0, -4.0), 6.5, 0.2 * PI, 0.8 * PI, 14, INK, 2.4)
	draw_set_transform_matrix(xf)


func _draw_wing(root: Vector2, ang: float, rx: float, ry: float) -> void:
	var c: Vector2 = root + Vector2.from_angle(ang) * rx * 0.9
	Art.fill(self, Art.ellipse(c, rx, ry, ang, 28), WING, INK, 2.2)
	draw_line(root + Vector2.from_angle(ang) * 4.0, c + Vector2.from_angle(ang) * rx * 0.6, WING_VEIN, 1.5)
	draw_colored_polygon(Art.ellipse(c + Vector2.from_angle(ang - 0.6) * ry * 0.4, rx * 0.35, ry * 0.25, ang, 12), Color(1, 1, 1, 0.55))


func _draw_open_mouth(top: Vector2, half_w: float, depth: float) -> void:
	var mouth: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI * float(i) / 16.0
		mouth.append(top + Vector2(cos(a) * half_w, sin(a) * depth))
	Art.fill(self, mouth, MOUTH, INK, 2.2)
	if depth > 4.0:
		for p: PackedVector2Array in Art.clip(mouth, Art.ellipse(top + Vector2(0.0, depth), half_w * 0.62, depth * 0.45, 0.0, 16)):
			draw_colored_polygon(p, TONGUE)


# The straw beehive on its wooden stand, with two tiny bees buzzing around it.
func _draw_scenery() -> void:
	var b: Vector2 = ground + SKEP
	for lx: float in [-15.0, 15.0]:
		Art.fill(self, Art.rrect(Rect2(b.x + lx - 2.5, b.y - 10.0, 5.0, 11.0), 1.5), WOOD_DARK, INK, 1.8)
	Art.fill(self, Art.rrect(Rect2(b.x - 22.0, b.y - 14.0, 44.0, 6.0), 2.0), WOOD, INK, 2.0)
	# Coils of straw, narrower toward the top.
	var widths: Array[float] = [38.0, 37.0, 34.0, 30.0, 24.0, 15.0]
	for k: int in range(widths.size() - 1, -1, -1):
		var w: float = widths[k]
		var y: float = b.y - 22.0 - float(k) * 8.0
		Art.fill(self, Art.rrect(Rect2(b.x - w * 0.5, y - 4.5, w, 10.0), 5.0), STRAW, INK, 2.0)
		for s: int in range(3):
			var sx: float = b.x - w * 0.3 + w * 0.3 * float(s)
			draw_line(Vector2(sx - 2.0, y - 1.0), Vector2(sx + 2.0, y + 2.0), STRAW_DARK, 1.2)
	# The doorway, with a little honey drip on the sill.
	var door: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var a: float = PI + PI * float(i) / 12.0
		door.append(b + Vector2(cos(a) * 6.0, -17.0 + sin(a) * 6.0))
	Art.fill(self, door, Color("#4a2620"), INK, 1.8)
	Art.fill(self, Art.teardrop(b + Vector2(9.0, -10.0), b + Vector2(9.0, -6.5), 2.2), HONEY, INK, 1.4)
	# Two tiny bees on loops around it.
	for n: int in range(2):
		var ph: float = _t * (1.3 + 0.4 * float(n)) + float(n) * 2.6
		var p: Vector2 = b + Vector2(-2.0, -46.0) + Vector2(cos(ph) * 30.0, sin(ph * 2.0) * 9.0 - 8.0 * float(n))
		_draw_tiny_bee(p, cos(ph) < 0.0)


func _draw_tiny_bee(p: Vector2, left: bool) -> void:
	var dir: float = -1.0 if left else 1.0
	var flap: float = sin(_t * 50.0) * 2.0
	Art.fill(self, Art.ellipse(p + Vector2(-1.0 * dir, -4.0 - flap * 0.5), 3.6, 2.4, -0.4 * dir, 10), WING, INK, 1.2)
	Art.fill(self, Art.ellipse(p, 5.0, 3.8, 0.0, 14), YELLOW, INK, 1.5)
	draw_line(p + Vector2(-0.5, -3.4), p + Vector2(-0.5, 3.4), STRIPE, 1.6)
	draw_circle(p + Vector2(2.6 * dir, -0.8), 0.9, INK)


# The glass honey jar: the honey inside (it rises with every drop), then the glass and its label.
func _draw_container_back(c: Vector2) -> void:
	var jar: PackedVector2Array = _jar(c)
	var level: float = 0.15 + 0.8 * float(stored) / float(CAPACITY)
	var top: float = c.y + 30.0 - 30.0 * level
	var fill_rect: PackedVector2Array = PackedVector2Array([Vector2(c.x - 30.0, top), Vector2(c.x + 30.0, top), Vector2(c.x + 30.0, c.y + 40.0), Vector2(c.x - 30.0, c.y + 40.0)])
	for p: PackedVector2Array in Art.clip(jar, fill_rect):
		draw_colored_polygon(p, HONEY)
	draw_line(Vector2(c.x - 18.0, top), Vector2(c.x + 18.0, top), HONEY_LIGHT, 2.0)


func _draw_container_front(c: Vector2) -> void:
	var jar: PackedVector2Array = _jar(c)
	draw_colored_polygon(jar, Color(1, 1, 1, 0.16))
	Art.outline(self, jar, INK, 2.4)
	# The rim around the neck.
	Art.fill(self, Art.rrect(Rect2(c.x - 16.0, c.y - 6.0, 32.0, 6.0), 2.5), Color("#f4ead6"), INK, 2.0)
	# A honey drip down the outside once it's getting full.
	if stored >= 3:
		var dx: float = c.x + 9.0
		var dl: float = 4.0 + 2.5 * float(stored)
		Art.fill(self, Art.teardrop(Vector2(dx, c.y - 3.0), Vector2(dx, c.y + dl), 3.0, 16), HONEY, INK, 1.6)
	# A honeycomb-cell label.
	var lab: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		lab.append(c + Vector2(0.0, 16.0) + Vector2.from_angle(TAU * float(i) / 6.0) * 9.0)
	Art.fill(self, Art.round_poly(lab, 1.5, 2), Color("#fff6dc"), INK, 1.8)
	Art.fill(self, Art.teardrop(c + Vector2(0.0, 10.5), c + Vector2(0.0, 17.5), 3.8), HONEY, INK, 1.4)
	# Glass shine.
	draw_line(c + Vector2(-14.0, 6.0), c + Vector2(-14.0, 22.0), Color(1, 1, 1, 0.7), 2.4)
	draw_circle(c + Vector2(-14.0, 26.5), 1.3, Color(1, 1, 1, 0.7))


func _jar(c: Vector2) -> PackedVector2Array:
	return Art.round_poly(PackedVector2Array([
		c + Vector2(-13.0, -2.0), c + Vector2(13.0, -2.0), c + Vector2(20.0, 6.0), c + Vector2(20.0, 30.0),
		c + Vector2(-20.0, 30.0), c + Vector2(-20.0, 6.0)]), 5.0, 4)


func _draw_goodie(pos: Vector2, rot: float, s: float) -> void:
	# A drop of honey, falling tip first.
	var tip: Vector2 = pos + Vector2(0.0, -7.0 * s).rotated(rot * 0.3)
	Art.fill(self, Art.teardrop(tip, pos, 4.6 * s, 16), HONEY, INK, 1.8)
	draw_circle(pos + Vector2(-1.6, -1.2) * s, 1.3 * s, Color(1, 1, 1, 0.75))
