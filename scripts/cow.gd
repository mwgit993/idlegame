extends Control

# The star of the show: a cute, round cartoon cow drawn every frame with Godot's vector API.
# She's built like a plush toy: a big soft head on a small round body, big shiny black eyes,
# rosy cheeks, a pink muzzle with a little smile, floppy ears, nubby horns and a fluffy tuft.
# main.gd calls squeeze() on every milking. Everything else animates here from the clock and
# a few little springs: eyes that glance toward the mouse, blinks, a happy squint and open
# smile on every squeeze, floppy ears, a swishing tail, squash and stretch, milk spraying from
# the udder and splashing on the grass, and during MOO RUSH a happy dance with heart eyes, a
# tongue, hearts and sparkles.
# Shapes are in cow-local coordinates: the origin is on the ground between her hooves.

const INK: Color = Color("#3a2621")
const HIDE: Color = Color("#fffdf7")
const HIDE_SHADE: Color = Color("#ede5d9")
const SPOT: Color = Color("#3b3440")
const PINK: Color = Color("#ffb3c8")
const PINK_DARK: Color = Color("#e77897")
const PINK_LIGHT: Color = Color("#ffdbe5")
const CHEEK: Color = Color(1.0, 0.45, 0.58)
const MOUTH: Color = Color("#8c2a3a")
const TONGUE: Color = Color("#ff7b98")
const EYE: Color = Color("#2a1f22")
const HOOF: Color = Color("#6b5348")
const HORN: Color = Color("#ffeec2")
const MILK_EDGE: Color = Color("#9fc0dc")
const HEART_COLS: Array[Color] = [Color("#ff3d6e"), Color("#ff7aa8"), Color("#e8348a")]
const SPARK_COLS: Array[Color] = [Color("#ffffff"), Color("#ffe066"), Color("#ffc2dc")]
const LW: float = 3.0
const MAX_PARTICLES: int = 260

const BODY_C: Vector2 = Vector2(-8, -56)
const HEAD_C: Vector2 = Vector2(50, -112)
const SNOUT_C: Vector2 = Vector2(50, -92)  # the pink muzzle
const NECK: Vector2 = Vector2(44, -80)     # the head wobbles around this point
const EYES: Array[Vector2] = [Vector2(34, -123), Vector2(66, -123)]
const EYE_RX: float = 6.6
const EYE_RY: float = 8.4
const LOOK: float = 2.0                    # how far (px) the eyes glance toward the mouse
const UDDER_C: Vector2 = Vector2(-10, -22)

var ground: Vector2 = Vector2(100.0, 304.0)  # between her hooves, in this Control's coordinates

var _t: float = 0.0
var _sq: float = 0.0        # squash (+) / stretch (-)
var _sq_v: float = 0.0
var _hop: float = 0.0       # px above the ground
var _hop_v: float = 0.0
var _udder: float = 0.0     # 1 right after a squeeze, eases back to 0
var _pop: float = 0.0       # 1 right after a squeeze: happy squint and open smile
var _ear: float = 0.0       # ear flap spring (also swings the bell)
var _ear_v: float = 0.0
var _blink_t: float = 2.0
var _look: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # where each eye is glancing
var _look_v: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _last_mouse: Vector2 = Vector2.ZERO
var _still_t: float = 0.0
var _wander: Vector2 = Vector2.ZERO
var _rush: float = 0.0      # eases 0..1 with MOO RUSH
var _heart_t: float = 0.0
var _spark_t: float = 0.0

var _drops: Array[Dictionary] = []    # milk in flight: pos, vel, r, floor
var _splats: Array[Dictionary] = []   # splash droplets: pos, vel, life
var _puddles: Array[Dictionary] = []  # pos, life
var _fx: Array[Dictionary] = []       # MOO RUSH hearts and sparkles: heart, pos, vel, life, max, size, col

# Shapes that never change, built once.
var _body: PackedVector2Array
var _body_spots: Array[PackedVector2Array] = []
var _belly: Array[PackedVector2Array] = []
var _chin_shadow: Array[PackedVector2Array] = []
var _head: PackedVector2Array
var _head_spots: Array[PackedVector2Array] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = Art.superellipse(BODY_C, 58.0, 36.0, 2.3, 56)
	var spot_defs: Array[Vector4] = [
		Vector4(-36, -74, 15, 0.3), Vector4(6, -88, 11, 1.9), Vector4(-12, -42, 9, 3.1), Vector4(-64, -48, 10, 5.0),
	]
	for d: Vector4 in spot_defs:
		_body_spots.append_array(Art.clip(Art.blob(Vector2(d.x, d.y), d.z, d.w, 0.12), _body))
	_belly = Art.clip(_body, Art.ellipse(BODY_C + Vector2(0, 31), 62.0, 14.0))
	_chin_shadow = Art.clip(_body, Art.ellipse(HEAD_C + Vector2(-2, 36), 34.0, 9.0))
	# A big soft head with a fluffy three-puff tuft on top, all one outline.
	_head = Art.superellipse(HEAD_C, 42.0, 35.0, 2.25, 56)
	for puff: Vector3 in [Vector3(-8, -32, 8.0), Vector3(1, -36, 9.0), Vector3(9, -31, 7.5)]:
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(_head, Art.ellipse(HEAD_C + Vector2(puff.x, puff.y), puff.z, puff.z, 0.0, 24))
		var best: float = 0.0
		for p: PackedVector2Array in merged:
			var area: float = _area(p)  # keep the outline (a hole would be smaller)
			if area > best:
				best = area
				_head = p
	_head_spots = Art.clip(Art.blob(HEAD_C + Vector2(-33, -24), 9.5, 0.8, 0.14), _head)


func _area(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i: int in range(p.size()):
		s += p[i].cross(p[(i + 1) % p.size()])
	return absf(s) * 0.5


# One squeeze of the udder: squash, hop, a happy squint, flap the ears, spray milk.
func squeeze() -> void:
	_sq = 0.13
	_sq_v = -1.2
	if _hop < 2.0:
		_hop_v = 110.0
	_udder = 1.0
	_pop = 1.0
	_ear_v += 5.0
	_spray()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 30.0)
	_t += dt
	var rush_on: bool = Farm.rush_left > 0.0
	_rush = move_toward(_rush, 1.0 if rush_on else 0.0, dt * 3.0)

	_sq_v += (-260.0 * _sq - 11.0 * _sq_v) * dt
	_sq += _sq_v * dt
	_ear_v += (-90.0 * _ear - 5.0 * _ear_v) * dt
	_ear += _ear_v * dt
	_hop_v -= 900.0 * dt
	_hop += _hop_v * dt
	if _hop <= 0.0:
		if _hop_v < -80.0:
			_sq = maxf(_sq, 0.07)  # a little squish on landing
		_hop = 0.0
		_hop_v = 0.0
		if rush_on and fmod(_t, 0.55) < dt * 1.5:
			_hop_v = 120.0  # happy MOO RUSH dance
	_udder *= exp(-dt * 7.0)
	_pop *= exp(-dt * 6.0)

	_blink_t -= dt
	if _blink_t < -0.16:
		_blink_t = randf_range(2.2, 5.0) if randf() > 0.15 else 0.12

	_update_eyes(dt)
	_update_milk(dt)
	_update_fx(dt, rush_on)
	queue_redraw()


func _xf() -> Transform2D:
	var breathe: float = sin(_t * 2.2) * 0.012
	var tilt: float = sin(_t * 7.0) * 0.06 * _rush
	return Transform2D(tilt, Vector2(1.0 + _sq * 0.9, 1.0 - _sq + breathe), 0.0, ground + Vector2(0.0, -_hop))


func _head_xf() -> Transform2D:
	var a: float = sin(_t * 1.6) * 0.035 + sin(_t * 5.0) * 0.08 * _rush
	return Transform2D(a, NECK) * Transform2D(0.0, -NECK)


# =========================================================================================
# EYES: a gentle glance toward the mouse (a couple of pixels, no wobble), wandering a little
# when the mouse is still.
# =========================================================================================
func _update_eyes(dt: float) -> void:
	var m: Vector2 = get_local_mouse_position()
	if m.distance_to(_last_mouse) > 0.5:
		_last_mouse = m
		_still_t = 0.0
	else:
		_still_t += dt
	if _still_t > 3.0 and fmod(_still_t, 2.2) < dt:
		_wander = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.6))
	for e: int in range(2):
		var target: Vector2 = _wander * LOOK
		if _still_t <= 3.0:
			var d: Vector2 = m - (ground + EYES[e] + Vector2(0.0, -_hop))
			target = d.limit_length(120.0) / 120.0 * LOOK
		# Critically damped: eases over without overshooting.
		var acc: Vector2 = (target - _look[e]) * 90.0 - _look_v[e] * 19.0
		_look_v[e] += acc * dt
		_look[e] += _look_v[e] * dt


func _lid() -> float:
	if _blink_t >= 0.0:
		return 0.0
	var ph: float = clampf(-_blink_t / 0.16, 0.0, 1.0)
	return 1.0 - absf(ph * 2.0 - 1.0)


# =========================================================================================
# MILK AND MOO RUSH PARTICLES (screen space)
# =========================================================================================
func _teat_tips() -> Array[Vector2]:
	var tips: Array[Vector2] = []
	var u: float = _udder
	var c: Vector2 = UDDER_C + Vector2(0.0, 2.0 * u)
	var ry: float = 11.0 * (1.0 - 0.2 * u)
	for i: int in range(4):
		var fi: float = float(i) - 1.5
		var top: Vector2 = Vector2(c.x + fi * 7.5 * (1.0 + 0.1 * u), c.y + ry * 0.5)
		var ang: float = sin(_t * 3.0 + float(i)) * 0.07 + fi * 0.12
		tips.append(top + Vector2(0.0, ry * 0.4 + 5.5 + 4.0 * u).rotated(ang))
	return tips


# Milk drops, splashes, puddles and MOO RUSH hearts/sparkles currently alive.
func particle_count() -> int:
	return _drops.size() + _splats.size() + _puddles.size() + _fx.size()


func _spray() -> void:
	if particle_count() > MAX_PARTICLES:
		return
	var xf: Transform2D = _xf()
	var tips: Array[Vector2] = _teat_tips()
	var first: int = randi() % 4
	for k: int in range(2):
		var i: int = (first + k * 2) % 4
		var tip: Vector2 = xf * tips[i]
		for n: int in range(5):
			_drops.append({
				"pos": tip + Vector2(randf_range(-1.5, 1.5), float(n) * 2.0),
				"vel": Vector2(randf_range(-95.0, 95.0) + (float(i) - 1.5) * 22.0, randf_range(-70.0, 110.0)),
				"r": randf_range(2.2, 3.8),
				"floor": ground.y + randf_range(1.0, 12.0),
			})


func _update_milk(dt: float) -> void:
	var live: Array[Dictionary] = []
	for d: Dictionary in _drops:
		var v: Vector2 = d["vel"]
		v.y += 620.0 * dt
		d["vel"] = v
		var p: Vector2 = (d["pos"] as Vector2) + v * dt
		d["pos"] = p
		if p.y >= float(d["floor"]):
			_puddles.append({"pos": p, "life": 0.7})
			for k: int in range(3):
				_splats.append({"pos": p, "vel": Vector2(randf_range(-70.0, 70.0), randf_range(-120.0, -40.0)), "life": 0.35})
		else:
			live.append(d)
	_drops = live
	var live_s: Array[Dictionary] = []
	for s: Dictionary in _splats:
		var sv: Vector2 = s["vel"]
		sv.y += 520.0 * dt
		s["vel"] = sv
		s["pos"] = (s["pos"] as Vector2) + sv * dt
		s["life"] = float(s["life"]) - dt
		if float(s["life"]) > 0.0:
			live_s.append(s)
	_splats = live_s
	var live_p: Array[Dictionary] = []
	for pd: Dictionary in _puddles:
		pd["life"] = float(pd["life"]) - dt
		if float(pd["life"]) > 0.0:
			live_p.append(pd)
	_puddles = live_p


func _update_fx(dt: float, rush_on: bool) -> void:
	if rush_on and particle_count() < MAX_PARTICLES:
		_heart_t -= dt
		_spark_t -= dt
		if _heart_t <= 0.0:
			_heart_t = 0.16
			var hp: Vector2 = _xf() * (HEAD_C + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 0.0)))
			_fx.append({"heart": true, "pos": hp, "vel": Vector2(randf_range(-18.0, 18.0), randf_range(-50.0, -32.0)),
				"life": 1.3, "max": 1.3, "size": randf_range(9.0, 14.0), "col": HEART_COLS[randi() % HEART_COLS.size()]})
		if _spark_t <= 0.0:
			_spark_t = 0.07
			var sp: Vector2 = ground + Vector2(randf_range(-95.0, 112.0), randf_range(-175.0, -8.0))
			_fx.append({"heart": false, "pos": sp, "vel": Vector2.ZERO, "life": 0.55, "max": 0.55,
				"size": randf_range(3.0, 7.0), "col": SPARK_COLS[randi() % SPARK_COLS.size()]})
	var live: Array[Dictionary] = []
	for f: Dictionary in _fx:
		f["life"] = float(f["life"]) - dt
		var v: Vector2 = f["vel"]
		f["pos"] = (f["pos"] as Vector2) + Vector2(v.x + sin(_t * 4.0 + float(f["size"])) * 12.0, v.y) * dt
		if float(f["life"]) > 0.0:
			live.append(f)
	_fx = live


# =========================================================================================
# DRAWING
# =========================================================================================
func _draw() -> void:
	var sh: float = clampf(1.0 - _hop / 30.0, 0.6, 1.0)
	draw_colored_polygon(Art.ellipse(ground + Vector2(-2.0, 2.0), 76.0 * sh * (1.0 + _sq * 0.5), 9.0 * sh), Color(0.12, 0.32, 0.05, 0.3))
	for pd: Dictionary in _puddles:
		var k: float = float(pd["life"]) / 0.7
		var pp: Vector2 = pd["pos"]
		draw_colored_polygon(Art.ellipse(pp, 3.0 + (1.0 - k) * 8.0, 1.2 + (1.0 - k) * 2.2, 0.0, 16), Color(1, 1, 1, 0.85 * k))

	var xf: Transform2D = _xf()
	draw_set_transform_matrix(xf)
	_draw_tail()
	var lift: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i: int in range(4):
		lift[i] = maxf(0.0, sin(_t * 14.0 + float(i) * 1.7)) * 5.0 * _rush
	_draw_leg(-30.0, HIDE_SHADE, lift[0])
	_draw_leg(38.0, HIDE_SHADE, lift[1])
	_draw_leg(-46.0, HIDE, lift[2])
	_draw_leg(22.0, HIDE, lift[3])
	_draw_udder()
	_draw_body()

	var hxf: Transform2D = xf * _head_xf()
	draw_set_transform_matrix(hxf)
	_draw_ears()
	_draw_horns()
	draw_colored_polygon(_head, HIDE)
	for s: PackedVector2Array in _head_spots:
		draw_colored_polygon(s, SPOT)
	Art.outline(self, _head, INK, LW)
	_draw_bell(hxf)
	draw_set_transform_matrix(hxf)
	_draw_cheeks()
	_draw_snout()
	_draw_eyes()
	draw_set_transform_matrix(Transform2D.IDENTITY)

	_draw_milk()
	_draw_fx()


func _draw_tail() -> void:
	var root: Vector2 = Vector2(-63, -74)
	var sw: float = sin(_t * (2.4 + 4.0 * _rush)) * (0.42 + 0.25 * _rush)
	var tip: Vector2 = root + Vector2(-15.0, 38.0).rotated(sw * 0.7)
	var ctrl: Vector2 = root + Vector2(-20.0, 4.0).rotated(sw * 0.3)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var t: float = float(i) / 12.0
		pts.append(root.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t))
	Art.inked_stroke(self, pts, HIDE, 4.2, 2.4)
	var dir: Vector2 = (tip - pts[10]).normalized()
	Art.fill(self, Art.blob(tip + dir * 1.5, 5.5, 0.4, 0.12, 18), SPOT, INK, 2.4)


# A short, stubby plush leg with a rounded hoof.
func _draw_leg(x: float, col: Color, lift: float) -> void:
	Art.fill(self, Art.rrect(Rect2(x - 8.5, -42.0, 17.0, 42.0 - lift), 8.0), col, INK, LW)
	var hoof: PackedVector2Array = Art.rrect(Rect2(x - 9.0, -9.0 - lift, 18.0, 9.0), 4.5)
	Art.fill(self, hoof, HOOF, INK, LW)
	draw_line(Vector2(x - 5.5, -6.5 - lift), Vector2(x - 1.5, -6.5 - lift), Color(1, 1, 1, 0.28), 1.6, true)


func _draw_udder() -> void:
	var u: float = _udder
	var c: Vector2 = UDDER_C + Vector2(0.0, 2.0 * u)
	var rx: float = 18.0 * (1.0 + 0.14 * u)
	var ry: float = 11.0 * (1.0 - 0.2 * u)
	var tips: Array[Vector2] = _teat_tips()
	for i: int in range(4):
		var top: Vector2 = Vector2(c.x + (float(i) - 1.5) * 7.5 * (1.0 + 0.1 * u), c.y + ry * 0.5)
		Art.inked_stroke(self, PackedVector2Array([top, top.lerp(tips[i], 0.55), tips[i]]), PINK, 5.0, 2.2)
	Art.fill(self, Art.ellipse(c, rx, ry, 0.0, 32), PINK, INK, LW)
	draw_colored_polygon(Art.ellipse(c + Vector2(-6.0, -2.0), rx * 0.3, ry * 0.26, -0.2, 14), PINK_LIGHT)


func _draw_body() -> void:
	draw_colored_polygon(_body, HIDE)
	for b: PackedVector2Array in _belly:
		draw_colored_polygon(b, HIDE_SHADE)
	for s: PackedVector2Array in _body_spots:
		draw_colored_polygon(s, SPOT)
	for s: PackedVector2Array in _chin_shadow:
		draw_colored_polygon(s, Color(0.25, 0.15, 0.1, 0.1))
	Art.outline(self, _body, INK, LW)


# Soft floppy ears that stick out sideways and droop a little; they flap up on a squeeze.
func _draw_ears() -> void:
	for side: float in [-1.0, 1.0]:
		var root: Vector2 = HEAD_C + Vector2(36.0 * side, -14.0)
		var ang: float = 0.32 if side > 0.0 else PI - 0.32
		ang += side * sin(_t * 2.2 + side) * 0.07 - side * _ear * 0.45
		var dir: Vector2 = Vector2.from_angle(ang)
		var c: Vector2 = root + dir * 11.0
		Art.fill(self, Art.ellipse(c, 14.5, 8.0, ang, 28), SPOT if side < 0.0 else HIDE, INK, LW)
		draw_colored_polygon(Art.ellipse(c + dir * 2.5, 8.5, 4.2, ang, 20), PINK)


# Two little rounded horn nubs.
func _draw_horns() -> void:
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = HEAD_C + Vector2(25.0 * side, -36.0)
		Art.fill(self, Art.ellipse(c, 4.8, 7.2, side * 0.42, 20), HORN, INK, 2.6)
		draw_colored_polygon(Art.ellipse(c + Vector2(-1.2 * side - 0.6, -2.0), 1.4, 2.6, side * 0.42, 10), Color(1, 1, 1, 0.75))


func _draw_bell(hxf: Transform2D) -> void:
	var hang: Vector2 = SNOUT_C + Vector2(0.0, 16.0)
	var swing: float = sin(_t * 2.8) * 0.12 + _ear * 0.6
	var bxf: Transform2D = hxf * Transform2D(swing, hang)
	draw_set_transform_matrix(bxf)
	Art.fill(self, Art.rrect(Rect2(-3.0, -4.0, 6.0, 10.0), 2.0), Art.BARN, INK, 2.0)
	Art.draw_icon(self, "bell", Vector2(0.0, 15.0), 21.0, bxf)


func _draw_cheeks() -> void:
	var a: float = 0.42 + 0.2 * _pop + 0.25 * _rush
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(HEAD_C + Vector2(28.0 * side, -2.0), 7.5, 4.6, 0.0, 20), Color(CHEEK.r, CHEEK.g, CHEEK.b, a))


func _draw_snout() -> void:
	var sc: Vector2 = SNOUT_C
	Art.fill(self, Art.ellipse(sc, 31.0, 18.0, 0.0, 40), PINK, INK, LW)
	draw_colored_polygon(Art.ellipse(sc + Vector2(-13, -8), 8.0, 3.2, -0.25, 16), PINK_LIGHT)
	var flare: float = 1.0 + 0.15 * _udder
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(Art.ellipse(sc + Vector2(11.0 * side, -5.0), 3.0 * flare, 4.0 * flare, side * 0.3, 16), PINK_DARK)
	if _rush > 0.4:
		# Big open grin with the tongue out.
		_draw_open_mouth(sc + Vector2(0.0, 3.0), 10.0, 9.0)
		var wag: float = sin(_t * 11.0) * 0.25
		var tc: Vector2 = sc + Vector2(3.0, 14.0) + Vector2(sin(_t * 11.0) * 1.5, 0.0)
		Art.fill(self, Art.ellipse(tc, 5.5, 6.5, wag, 20), TONGUE, INK, 2.2)
		draw_line(tc + Vector2(0, -4).rotated(wag), tc + Vector2(0, 2.5).rotated(wag), PINK_DARK, 1.6, true)
	elif _pop > 0.3:
		# A happy little open smile.
		_draw_open_mouth(sc + Vector2(0.0, 3.0), 4.5 + 3.5 * _pop, 3.0 + 4.5 * _pop)
	else:
		# A gentle smile that sways as she chews her cud.
		var chew: float = sin(_t * 3.0) * 1.0
		draw_arc(sc + Vector2(chew, -1.0), 8.0, 0.2 * PI, 0.8 * PI, 16, INK, 2.4, true)


# A "D"-shaped open mouth (flat top, round bottom) with a bit of tongue showing.
func _draw_open_mouth(top: Vector2, half_w: float, depth: float) -> void:
	var mouth: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI * float(i) / 16.0
		mouth.append(top + Vector2(cos(a) * half_w, sin(a) * depth))
	Art.fill(self, mouth, MOUTH, INK, 2.2)
	if depth > 4.0:
		for p: PackedVector2Array in Art.clip(mouth, Art.ellipse(top + Vector2(0.0, depth), half_w * 0.62, depth * 0.45, 0.0, 16)):
			draw_colored_polygon(p, TONGUE)


# Big shiny black eyes with two highlights and little lashes. A blink squashes them shut
# into a soft curve; a squeeze turns them into happy ^ ^ squints; MOO RUSH makes them hearts.
func _draw_eyes() -> void:
	var lid: float = _lid()
	for e: int in range(2):
		var side: float = -1.0 if e == 0 else 1.0
		var c: Vector2 = EYES[e] + _look[e]
		if _rush > 0.5:
			var beat: float = 1.0 + 0.1 * sin(_t * 9.0)
			Art.fill(self, Art.heart(c + Vector2(0.0, 1.0), 23.0 * beat, 28), HEART_COLS[0], INK, 2.0)
			draw_colored_polygon(Art.ellipse(c + Vector2(-4.0, -3.0), 2.4, 1.6, -0.5, 12), Color(1, 1, 1, 0.85))
		elif _pop > 0.45:
			# ^ happy squint
			var sq: PackedVector2Array = PackedVector2Array([c + Vector2(-6.5, 2.5), c + Vector2(0.0, -4.0), c + Vector2(6.5, 2.5)])
			Art.stroke(self, Art.round_poly(sq, 3.0, 4), EYE, 3.0)
		elif lid > 0.6:
			# closed: a soft downward curve
			draw_arc(c + Vector2(0.0, -2.5), 6.5, 0.15 * PI, 0.85 * PI, 14, EYE, 3.0, true)
		else:
			var ry: float = EYE_RY * (1.0 - lid)
			draw_colored_polygon(Art.ellipse(c, EYE_RX, ry, 0.0, 28), EYE)
			draw_colored_polygon(Art.ellipse(c + Vector2(0.0, ry * 0.45), EYE_RX * 0.62, ry * 0.32, 0.0, 16), Color("#4a3a44"))
			if ry > 3.0:
				draw_circle(c + Vector2(-2.0, -ry * 0.38), 2.6, Color.WHITE, true, -1.0, true)
				draw_circle(c + Vector2(2.3, ry * 0.3), 1.2, Color.WHITE, true, -1.0, true)
			# Two little lashes on the outer corner.
			for k: int in range(2):
				var a: float = (PI + 0.35 + 0.42 * float(k)) if side < 0.0 else (TAU - 0.35 - 0.42 * float(k))
				var p0: Vector2 = c + Vector2(cos(a) * EYE_RX, sin(a) * ry)
				var dir: Vector2 = Vector2(cos(a), sin(a) * 0.9).normalized()
				Art.stroke(self, PackedVector2Array([p0, p0 + dir * 3.6]), EYE, 1.8)


func _draw_milk() -> void:
	for d: Dictionary in _drops:
		var v: Vector2 = d["vel"]
		var r: float = float(d["r"])
		var pts: PackedVector2Array = Art.ellipse(d["pos"] as Vector2, r + v.length() * 0.018, r, v.angle(), 12)
		Art.fill(self, pts, Color.WHITE, MILK_EDGE, 1.2)
	for s: Dictionary in _splats:
		draw_circle(s["pos"] as Vector2, 1.6, Color(1, 1, 1, clampf(float(s["life"]) * 4.0, 0.0, 1.0)), true, -1.0, true)


func _draw_fx() -> void:
	for f: Dictionary in _fx:
		var k: float = float(f["life"]) / float(f["max"])
		var col: Color = f["col"]
		var pos: Vector2 = f["pos"]
		if bool(f["heart"]):
			var hs: float = float(f["size"]) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
			var a: float = clampf(k * 2.5, 0.0, 1.0)
			if hs >= 1.5:
				Art.fill(self, Art.heart(pos, hs, 24), Color(col.r, col.g, col.b, a), Color(INK.r, INK.g, INK.b, a), 1.6)
		else:
			var ss: float = float(f["size"]) * sin(k * PI)
			if ss >= 1.0:
				Art.sparkle(self, pos, ss, col)
