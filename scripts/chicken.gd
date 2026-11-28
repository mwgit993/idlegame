extends "res://scripts/critter.gd"

# The hen (the second animal, in the hen house): a round plush chicken with a big soft head, a
# red comb and wattle, rosy cheeks, a little orange beak that opens to cluck, wings that flap on
# every click and a fluffy tail. Each click lays an egg that hops into the straw nest beside her.
# The shared parts (springs, eyes, the rush dance, goodies) are in critter.gd.

const FEATHER: Color = Color("#fffdf7")
const FEATHER_SHADE: Color = Color("#efe4d4")
const WING: Color = Color("#f5eadb")
const WING_LINE: Color = Color("#d9c7ae")
const COMB: Color = Color("#ff5247")
const COMB_LIGHT: Color = Color("#ff8f86")
const BEAK: Color = Color("#ffb52e")
const BEAK_DARK: Color = Color("#e5870f")
const LEG: Color = Color("#ff9f1c")
const STRAW: Color = Color("#e8b85c")
const STRAW_DARK: Color = Color("#b7803a")
const EGG: Color = Color("#fff3df")
const LW: float = 3.0

const BODY_C: Vector2 = Vector2(-4, -46)
const HEAD_C: Vector2 = Vector2(8, -102)
const NECK: Vector2 = Vector2(4, -74)
const EYES: Array[Vector2] = [Vector2(-4, -107), Vector2(20, -107)]

var _flap: float = 0.0     # wing spring: 1 = wings up
var _flap_v: float = 0.0
var _body: PackedVector2Array
var _belly: Array[PackedVector2Array] = []


func _ready() -> void:
	super._ready()
	container_pos = Vector2(80.0, -7.0)
	_body = Art.superellipse(BODY_C, 47.0, 39.0, 2.2, 56)
	_belly = Art.clip(_body, Art.ellipse(BODY_C + Vector2(0, 30), 52.0, 14.0))


func _on_click() -> void:
	_flap_v += 10.0


func _goodie_start() -> Vector2:
	return Vector2(-4.0, -12.0)


func _animate(dt: float) -> void:
	_flap_v += (-130.0 * _flap - 9.0 * _flap_v) * dt
	_flap += _flap_v * dt
	if _rush > 0.0:
		_flap = lerpf(_flap, 0.35 + 0.35 * sin(_t * 18.0), _rush * 0.5)


func _draw_animal() -> void:
	var xf: Transform2D = _xf()
	# Legs with three-toed feet.
	for x: float in [-15.0, 9.0]:
		var lift: float = maxf(0.0, sin(_t * 14.0 + x)) * 4.0 * _rush
		Art.inked_stroke(self, PackedVector2Array([Vector2(x, -14.0), Vector2(x - 1.0, -2.0 - lift)]), LEG, 3.6, 2.0)
		for d: float in [-1.0, 0.0, 1.0]:
			Art.inked_stroke(self, PackedVector2Array([Vector2(x - 1.0, -2.0 - lift), Vector2(x - 1.0 + d * 6.0, 0.5 - lift + absf(d) * -0.5)]), LEG, 2.4, 1.8)
	# Fluffy tail feathers, swishing.
	var sw: float = sin(_t * (2.4 + 4.0 * _rush)) * 0.12
	for f: Vector3 in [Vector3(-60.0, -96.0, 9.5), Vector3(-68.0, -82.0, 10.0), Vector3(-63.0, -66.0, 9.0)]:
		var root: Vector2 = Vector2(-40.0, -66.0)
		var tip: Vector2 = root + (Vector2(f.x, f.y) - root).rotated(sw)
		var c: Vector2 = root.lerp(tip, 0.45)
		Art.fill(self, Art.teardrop(tip, c, f.z), FEATHER, INK, LW)
	# Wings behind the body's edge, flapping up on a click.
	_draw_wing(-1.0)
	_draw_wing(1.0)
	# Body.
	draw_colored_polygon(_body, FEATHER)
	for b: PackedVector2Array in _belly:
		draw_colored_polygon(b, FEATHER_SHADE)
	Art.outline(self, _body, INK, LW)
	# Little feather scallops on the chest.
	for k: int in range(3):
		var cx: float = -14.0 + 12.0 * float(k)
		draw_arc(Vector2(cx, -44.0 + absf(float(k) - 1.0) * 3.0), 6.0, 0.15 * PI, 0.85 * PI, 10, WING_LINE, 1.6)
	# Head (bobs around the neck), comb behind it.
	var hxf: Transform2D = xf * _head_xf(NECK) * _peck_xf()
	draw_set_transform_matrix(hxf)
	var puff: float = 1.0 + 0.08 * _pop
	for cb: Vector3 in [Vector3(-11.0, -26.0, 7.5), Vector3(0.0, -31.0, 9.0), Vector3(11.0, -26.0, 7.5)]:
		Art.fill(self, Art.blob(HEAD_C + Vector2(cb.x, cb.y), cb.z * puff, cb.x, 0.06, 20), COMB, INK, LW)
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(cb.x - 2.0, cb.y - 2.5), cb.z * 0.35, cb.z * 0.25, -0.4, 12), COMB_LIGHT)
	Art.fill(self, Art.ellipse(HEAD_C, 31.0, 29.0, 0.0, 48), FEATHER, INK, LW)
	draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(-12.0, -14.0), 8.0, 4.0, -0.5, 16), Color(1, 1, 1, 0.8))
	_draw_cheeks()
	_draw_eyes(EYES, 5.6, 7.2)
	_draw_beak()
	draw_set_transform_matrix(xf)


# A quick nod down on each click, like a peck.
func _peck_xf() -> Transform2D:
	var a: float = 0.14 * _pop
	return Transform2D(a, NECK) * Transform2D(0.0, -NECK)


func _draw_wing(side: float) -> void:
	var root: Vector2 = BODY_C + Vector2(37.0 * side, -8.0)
	var ang: float = (PI * 0.5 - 0.2) if side > 0.0 else (PI * 0.5 + 0.2)
	ang -= side * _flap * 1.0
	var c: Vector2 = root + Vector2.from_angle(ang) * 12.0
	var wing: PackedVector2Array = Art.ellipse(c, 19.0, 11.0, ang, 28)
	Art.fill(self, wing, WING, INK, LW)
	for k: int in range(2):
		var p: Vector2 = c + Vector2.from_angle(ang) * (4.0 + 6.0 * float(k))
		draw_arc(p, 5.0, ang - 1.2, ang + 1.2, 8, WING_LINE, 1.5)


func _draw_cheeks() -> void:
	var a: float = 0.42 + 0.2 * _pop + 0.25 * _rush
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(20.0 * side, 6.0), 6.5, 4.0, 0.0, 20), Color(CHEEK.r, CHEEK.g, CHEEK.b, a))


# A small rounded beak that opens on a cluck (and stays open, singing, in the rush), with the
# wattle hanging under it.
func _draw_beak() -> void:
	var b: Vector2 = HEAD_C + Vector2(0.0, 2.0)
	var open: float = maxf(_pop, 0.7 * _rush) * 5.0
	Art.fill(self, Art.blob(b + Vector2(0.0, 18.0 + open), 4.6, 1.0, 0.05, 16), COMB, INK, 2.4)
	var lower: PackedVector2Array = Art.round_poly(PackedVector2Array([
		b + Vector2(-5.5, 6.0), b + Vector2(5.5, 6.0), b + Vector2(0.0, 11.5 + open)]), 2.0, 3)
	Art.fill(self, lower, BEAK_DARK, INK, 2.2)
	var upper: PackedVector2Array = Art.round_poly(PackedVector2Array([
		b + Vector2(-7.0, 1.5), b + Vector2(7.0, 1.5), b + Vector2(0.0, 10.0)]), 2.2, 3)
	Art.fill(self, upper, BEAK, INK, 2.2)
	draw_colored_polygon(Art.ellipse(b + Vector2(-2.5, 3.6), 2.2, 1.0, 0.0, 10), Color(1, 1, 1, 0.7))


# The straw nest: back rim, then the eggs inside, then the front rim with straws sticking out.
func _draw_container_back(c: Vector2) -> void:
	Art.fill(self, Art.ellipse(c + Vector2(0.0, -3.0), 27.0, 9.0, 0.0, 32), STRAW_DARK, INK, 2.4)
	var spots: Array[Vector2] = [Vector2(-10, -5), Vector2(9, -5), Vector2(0, -7), Vector2(-4, -11), Vector2(6, -11), Vector2(1, -15)]
	for i: int in range(mini(stored, spots.size())):
		_draw_egg(c + spots[i], (float(i) - 2.5) * 0.12, 0.9)


func _draw_container_front(c: Vector2) -> void:
	var front: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI * float(i) / 16.0
		front.append(c + Vector2(cos(a) * 29.0, -2.0 + sin(a) * 9.0))
	for i2: int in range(16, -1, -1):
		var a2: float = PI * float(i2) / 16.0
		front.append(c + Vector2(cos(a2) * 25.0, -4.0 + sin(a2) * 4.0))
	Art.fill(self, front, STRAW, INK, 2.4)
	for k: int in range(7):
		var x: float = -22.0 + 7.3 * float(k)
		var y: float = -1.0 + sin(float(k) * 1.3) * 1.5 + absf(x) * -0.05
		draw_line(c + Vector2(x, y), c + Vector2(x + 4.0, y + 4.5), STRAW_DARK, 1.4)
	for s: Vector3 in [Vector3(-27.0, -3.0, -0.6), Vector3(27.0, -3.0, 0.6), Vector3(-18.0, 5.0, -0.3)]:
		var p: Vector2 = c + Vector2(s.x, s.y)
		Art.stroke(self, PackedVector2Array([p, p + Vector2.from_angle(PI * 0.5 + s.z + PI) * 7.0]), STRAW_DARK, 1.6)


func _draw_goodie(pos: Vector2, rot: float, s: float) -> void:
	_draw_egg(pos, rot, s)


func _draw_egg(pos: Vector2, rot: float, s: float) -> void:
	Art.fill(self, Art.ellipse(pos, 6.0 * s, 7.8 * s, rot, 20), EGG, INK, 1.8)
	draw_colored_polygon(Art.ellipse(pos + Vector2(-2.0, -2.8).rotated(rot) * s, 1.6 * s, 2.4 * s, rot - 0.4, 10), Color(1, 1, 1, 0.9))
