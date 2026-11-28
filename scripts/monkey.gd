extends "res://scripts/critter.gd"

# The monkey (the third animal, in the banana grove): a round plush monkey with big round ears,
# a peach face and muzzle, a little tuft of hair and a curly tail. A bunch of bananas hangs on a
# vine beside him; each click he reaches up, picks one and it drops into the wooden crate at his
# feet. The shared parts (springs, eyes, the rush dance, goodies) are in critter.gd.

const FUR: Color = Color("#a8693d")
const FUR_DARK: Color = Color("#7f4b27")
const FACE: Color = Color("#f8d9ab")
const FACE_SHADE: Color = Color("#ecc28c")
const EAR_IN: Color = Color("#f2a99e")
const BANANA: Color = Color("#ffd94a")
const BANANA_DARK: Color = Color("#e0a91c")
const STEM: Color = Color("#7a5a2a")
const VINE: Color = Color("#4f9b3a")
const LEAF: Color = Color("#5fbf3f")
const CRATE: Color = Color("#d39553")
const CRATE_DARK: Color = Color("#a3683a")
const LW: float = 3.0

const BODY_C: Vector2 = Vector2(0, -42)
const HEAD_C: Vector2 = Vector2(2, -100)
const NECK: Vector2 = Vector2(2, -70)
const EYES: Array[Vector2] = [Vector2(-9, -105), Vector2(13, -105)]
const BUNCH: Vector2 = Vector2(82, -150)       # where the bananas hang
const SHOULDER_R: Vector2 = Vector2(26, -60)
const HAND_REST: Vector2 = Vector2(40, -26)
const HAND_UP: Vector2 = Vector2(66, -132)

var _reach: float = 0.0     # 1 = right hand up at the bunch
var _reach_v: float = 0.0
var _body: PackedVector2Array
var _face: PackedVector2Array


func _ready() -> void:
	super._ready()
	container_pos = Vector2(80.0, -12.0)
	_body = Art.superellipse(BODY_C, 36.0, 34.0, 2.2, 48)
	# One peach face shape: two eye patches and the muzzle, merged so it has a single outline.
	_face = Art.ellipse(HEAD_C + Vector2(0.0, 11.0), 21.0, 14.5, 0.0, 36)
	for e: Vector2 in EYES:
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(_face, Art.ellipse(e + Vector2(0.0, 1.0), 12.5, 13.5, 0.0, 28))
		if not merged.is_empty():
			var best: float = 0.0
			for p: PackedVector2Array in merged:
				var r: Rect2 = _bounds(p)
				if r.get_area() > best:
					best = r.get_area()
					_face = p


func _bounds(p: PackedVector2Array) -> Rect2:
	var r: Rect2 = Rect2(p[0], Vector2.ZERO)
	for v: Vector2 in p:
		r = r.expand(v)
	return r


func _on_click() -> void:
	_reach = maxf(_reach, 0.6)
	_reach_v += 9.0


func _goodie_start() -> Vector2:
	return BUNCH + Vector2(-4.0, 8.0)


func _animate(dt: float) -> void:
	_reach_v += (-110.0 * _reach - 10.0 * _reach_v) * dt
	_reach += _reach_v * dt
	_reach = clampf(_reach, -0.2, 1.2)


func _draw_animal() -> void:
	var xf: Transform2D = _xf()
	# Curly tail behind him.
	var sw: float = sin(_t * (2.0 + 3.0 * _rush)) * 0.15
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(26):
		var k: float = float(i) / 25.0
		var base: Vector2 = Vector2(-30.0, -28.0) + Vector2(-34.0 * k, -30.0 * k * k)
		var curl: float = smoothstep(0.55, 1.0, k)
		var a: float = curl * 5.0 + sw
		base += Vector2(cos(a + PI) * 8.0 * curl, sin(a + PI) * 8.0 * curl)
		pts.append(base)
	Art.inked_stroke(self, pts, FUR, 5.0, 2.4)
	# Left arm hanging at his side, behind the body.
	var hand_l: Vector2 = Vector2(-42.0, -24.0) + Vector2(0.0, sin(_t * 2.2) * 1.5)
	Art.inked_stroke(self, PackedVector2Array([Vector2(-26.0, -60.0), Vector2(-40.0, -44.0), hand_l]), FUR, 9.0, 2.4)
	Art.fill(self, Art.ellipse(hand_l, 7.5, 6.5, 0.0, 18), FACE, INK, 2.4)
	# Legs and feet.
	for x: float in [-15.0, 15.0]:
		var lift: float = maxf(0.0, sin(_t * 14.0 + x)) * 4.0 * _rush
		Art.fill(self, Art.ellipse(Vector2(x, -12.0 - lift), 10.0, 11.0, 0.0, 20), FUR, INK, LW)
		Art.fill(self, Art.ellipse(Vector2(x * 1.15, -4.0 - lift), 11.5, 5.5, 0.0, 20), FACE, INK, LW)
	# Body and belly.
	Art.fill(self, _body, FUR, INK, LW)
	Art.fill(self, Art.ellipse(BODY_C + Vector2(2.0, 4.0), 21.0, 22.0, 0.0, 32), FACE, INK, 2.2)
	draw_colored_polygon(Art.ellipse(BODY_C + Vector2(2.0, 18.0), 15.0, 6.0, 0.0, 20), FACE_SHADE)
	# Right arm reaching up toward the bananas.
	var k2: float = clampf(_reach, 0.0, 1.0)
	var hand_r: Vector2 = HAND_REST.lerp(HAND_UP, sin(k2 * PI * 0.5)) + Vector2(0.0, sin(_t * 2.2 + 1.0) * 1.5)
	var elbow: Vector2 = SHOULDER_R.lerp(hand_r, 0.5) + Vector2(12.0, 4.0) * (1.0 - k2 * 0.6)
	Art.inked_stroke(self, PackedVector2Array([SHOULDER_R, elbow, hand_r]), FUR, 9.0, 2.4)
	Art.fill(self, Art.ellipse(hand_r, 7.5, 6.5, 0.0, 18), FACE, INK, 2.4)
	# Head: ears, round head, tuft, face.
	var hxf: Transform2D = xf * _head_xf(NECK)
	draw_set_transform_matrix(hxf)
	for side: float in [-1.0, 1.0]:
		var ec: Vector2 = HEAD_C + Vector2(33.0 * side, -2.0)
		var flick: float = sin(_t * 3.0 + side) * 0.06 + _pop * 0.15 * side
		Art.fill(self, Art.ellipse(ec, 13.0, 12.0, flick, 24), FUR, INK, LW)
		draw_colored_polygon(Art.ellipse(ec + Vector2(1.5 * side, 0.5), 7.5, 7.0, flick, 18), EAR_IN)
	for tf: Vector3 in [Vector3(-7.0, -31.0, 6.0), Vector3(1.0, -35.0, 7.0), Vector3(8.0, -30.0, 5.5)]:
		Art.fill(self, Art.blob(HEAD_C + Vector2(tf.x, tf.y), tf.z, tf.x, 0.08, 18), FUR, INK, LW)
	Art.fill(self, Art.ellipse(HEAD_C, 32.0, 30.0, 0.0, 48), FUR, INK, LW)
	draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(-14.0, -16.0), 7.0, 3.5, -0.5, 16), Color(1, 1, 1, 0.22))
	Art.fill(self, _face, FACE, INK, 2.4)
	var a: float = 0.4 + 0.2 * _pop + 0.25 * _rush
	for side2: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(19.0 * side2, 9.0), 5.5, 3.5, 0.0, 16), Color(CHEEK.r, CHEEK.g, CHEEK.b, a))
	_draw_eyes(EYES, 5.4, 7.0)
	for side3: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(3.2 * side3, 7.0), 1.6, 2.2, side3 * 0.3, 10), FUR_DARK)
	var m: Vector2 = HEAD_C + Vector2(0.0, 14.0)
	if _rush > 0.4 or _pop > 0.3:
		var open: float = maxf(_pop, _rush)
		_draw_open_mouth(m, 5.0 + 3.0 * open, 3.0 + 4.0 * open)
	else:
		draw_arc(m + Vector2(0.0, -3.0), 7.0, 0.2 * PI, 0.8 * PI, 14, INK, 2.4)
	draw_set_transform_matrix(xf)


func _draw_open_mouth(top: Vector2, half_w: float, depth: float) -> void:
	var mouth: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI * float(i) / 16.0
		mouth.append(top + Vector2(cos(a) * half_w, sin(a) * depth))
	Art.fill(self, mouth, MOUTH, INK, 2.2)
	if depth > 4.0:
		for p: PackedVector2Array in Art.clip(mouth, Art.ellipse(top + Vector2(0.0, depth), half_w * 0.62, depth * 0.45, 0.0, 16)):
			draw_colored_polygon(p, TONGUE)


# The vine with the banana bunch, hanging beside him. One banana is missing while he reaches.
func _draw_scenery() -> void:
	var bunch: Vector2 = ground + BUNCH
	var sway: float = sin(_t * 1.3) * 2.0
	var top: Vector2 = Vector2(bunch.x + 6.0, bunch.y - 120.0)
	Art.inked_stroke(self, PackedVector2Array([top, top.lerp(bunch, 0.5) + Vector2(sway * 2.0, 0.0), bunch + Vector2(sway, -14.0)]), VINE, 3.0, 1.8)
	for lf: Vector3 in [Vector3(-9.0, -70.0, -0.6), Vector3(10.0, -46.0, 0.7)]:
		var lc: Vector2 = bunch + Vector2(lf.x + sway, lf.y)
		Art.fill(self, Art.ellipse(lc, 9.0, 4.0, lf.z, 16), LEAF, INK, 1.8)
	var shown: int = 5 - int(clampf(_reach, 0.0, 1.0) > 0.5)
	for i: int in range(shown):
		var ang: float = -0.9 + 0.45 * float(i)
		_draw_banana(bunch + Vector2(sway, -12.0) + Vector2.from_angle(ang + PI * 0.5) * 13.0, ang, 1.15)
	Art.fill(self, Art.rrect(Rect2(bunch.x + sway - 3.0, bunch.y - 20.0, 6.0, 9.0), 2.0), STEM, INK, 1.8)


# The crate: bananas sitting in it, then its front.
func _draw_container_back(c: Vector2) -> void:
	var spots: Array[Vector2] = [Vector2(-12, -10), Vector2(0, -12), Vector2(12, -10), Vector2(-6, -15), Vector2(6, -15), Vector2(0, -18)]
	for k: int in range(mini(stored, spots.size())):
		_draw_banana(c + spots[k], -0.3 + 0.25 * float(k % 3), 0.9)


func _draw_container_front(c: Vector2) -> void:
	var box: Rect2 = Rect2(c.x - 24.0, c.y - 9.0, 48.0, 22.0)
	Art.fill(self, Art.rrect(box, 2.5), CRATE, INK, 2.4)
	for k: int in range(1, 3):
		var y: float = box.position.y + box.size.y * float(k) / 3.0
		draw_line(Vector2(box.position.x + 2.0, y), Vector2(box.end.x - 2.0, y), CRATE_DARK, 1.6)
	for x: float in [box.position.x + 5.0, box.end.x - 5.0]:
		draw_line(Vector2(x, box.position.y + 2.0), Vector2(x, box.end.y - 2.0), CRATE_DARK, 2.0)
	draw_line(box.position + Vector2(3.0, 2.0), box.position + Vector2(box.size.x - 3.0, 2.0), Color(1, 1, 1, 0.35), 1.4)


func _draw_goodie(pos: Vector2, rot: float, s: float) -> void:
	_draw_banana(pos, rot, s)


# A curved banana centred at pos, tilted by rot.
func _draw_banana(pos: Vector2, rot: float, s: float) -> void:
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var a: float = lerpf(-1.05, 1.05, float(i) / 12.0)
		outer.append(Vector2(sin(a) * 11.0, -cos(a) * 11.0 + 9.0) * s)
		inner.append(Vector2(sin(a) * 8.5, -cos(a) * 6.5 + 9.0) * s)
	var shape: PackedVector2Array = outer.duplicate()
	for i2: int in range(inner.size() - 1, -1, -1):
		shape.append(inner[i2])
	var xf: Transform2D = Transform2D(rot, pos)
	var pts: PackedVector2Array = xf * Art.round_poly(shape, 1.5, 2)
	Art.fill(self, pts, BANANA, INK, 1.8)
	draw_circle(xf * (outer[0] + Vector2(-0.5, 0.5)), 1.6 * s, STEM)
	draw_circle(xf * outer[outer.size() - 1], 1.4 * s, STEM)
	draw_line(xf * (Vector2(-4.0, -0.5) * s), xf * (Vector2(3.0, -0.8) * s), Color(1, 1, 1, 0.55), 1.3)
