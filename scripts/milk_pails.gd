extends RefCounted

# The milk pails. Each squeeze squirts milk from two teats in little arcs that land in the pail
# under the udder, so none of it reaches the grass. After PAIL_SQUEEZES squeezes the pail is
# full. It scoots over to wait beside the cow (there are MAX_WAITING spots) and a fresh empty
# pail drops in. A little red wagon comes for the waiting pails COLLECT_WAIT seconds after the
# first one starts waiting, or straight away once both spots are taken. It rolls out from
# behind the dairy panel, the pails hop in, and it rolls off with them. This is only for show:
# a squeeze still pays the moment you click.
# cow.gd owns one of these. It calls squirt() on every squeeze, update() every frame and draw()
# right after drawing the cow, so the pails sit in front of her. Positions are in the cow
# Control's coordinates, relative to `ground` (the spot between her hooves).

const PAIL_SQUEEZES: int = 15     # squeezes to fill a pail
const DROPS_PER_TEAT: int = 3
const GRAVITY: float = 620.0
const MAX_WAITING: int = 2
const COLLECT_WAIT: float = 5.0   # seconds a full pail waits before the wagon comes
const WAGON_CAPACITY: int = 3
const MAX_PARTICLES: int = 220

# The pail, in px at scale 1. The origin is the middle of its bottom.
const RIM_Y: float = -13.0
const RIM_RX: float = 11.0
const RIM_RY: float = 3.2
const BASE_HW: float = 8.0
const BASE_RY: float = 2.2

# Where things stand, relative to `ground`.
const CATCH: Vector2 = Vector2(-10, 8)        # the pail under the udder
const SLOTS: Array[float] = [81.0, 58.0]       # the waiting spots (x), nearest the wagon first
const SLOT_Y: float = 7.0
const WAGON_Y: float = 11.0                    # the ground line under the wagon's wheels
const WAGON_STOP: float = 113.0
const WAGON_OFF: float = 178.0                 # out of sight behind the dairy panel
const BED_SPOTS: Array[float] = [10.0, 0.0, -10.0]
const BED_Y: float = -12.0                     # where a loaded pail's bottom sits
const LOADED_SCALE: float = 0.7
const DROP_IN: float = 26.0                    # a fresh pail falls from this high

enum Wagon { AWAY, ARRIVING, LOADING, LEAVING }

const INK: Color = Color("#3a2621")
const STEEL: Color = Color("#d6dfe7")
const STEEL_DARK: Color = Color("#9aabba")
const STEEL_IN: Color = Color("#7d8d9c")
const HANDLE: Color = Color("#8496a6")
const MILK: Color = Color("#fffdf7")
const MILK_EDGE: Color = Color("#9fc0dc")
const SHADOW: Color = Color(0.12, 0.32, 0.05, 0.25)
const WAGON_RED: Color = Color("#e2463a")
const WAGON_DARK: Color = Color("#a72a22")
const WHEEL: Color = Color("#ffcc2e")
const WHEEL_DARK: Color = Color("#d99100")

var ground: Vector2 = Vector2(100.0, 304.0)
var level: float = 0.0                 # milk in the pail under the udder, 0 to 1
var drop_in: float = 0.0               # how far (px) the fresh pail still is above its spot
var drop_in_v: float = 0.0
var waiting: Array[Dictionary] = []    # full pails beside the cow: x, hop
var hopping: Array[Dictionary] = []    # pails jumping into the wagon: from, spot, t
var wagon: Wagon = Wagon.AWAY
var wagon_x: float = 278.0             # starts out of sight (AWAY keeps it there)
var wagon_t: float = 0.0
var wait_t: float = 0.0
var hop_cd: float = 0.0
var loaded: int = 0                    # pails sitting in the wagon
var wheel_spin: float = 0.0
# Counters for the smoke test.
var spawned: int = 0                   # milk drops squirted
var caught: int = 0                    # milk drops that landed in a pail
var collected: int = 0                 # pails the wagon took away

var _extra: float = 0.0                # milk that landed in a full pail, for the fresh one
var _drops: Array[Dictionary] = []     # milk in flight: pos, vel, r, amt
var _splats: Array[Dictionary] = []    # droplets jumping up out of the milk: pos, vel
var _ripples: Array[Dictionary] = []   # rings on the milk: x (from the pail's middle), life
var _twinkles: Array[Dictionary] = []  # sparkles where a pail lands in the wagon: pos, life


func particle_count() -> int:
	return _drops.size() + _splats.size() + _ripples.size() + _twinkles.size()


# The middle of the bottom of the pail under the udder (it may still be dropping in).
func catch_pos() -> Vector2:
	return ground + CATCH + Vector2(0.0, -drop_in)


# The height of the milk in a pail: near the rim when full, near the bottom when nearly empty.
func _surface_y(base: Vector2, lv: float, s: float) -> float:
	return base.y + (RIM_Y + 1.6 + (1.0 - lv) * 9.0) * s


# The half-width of the milk's surface (the pail narrows toward the bottom).
func _surface_rx(base: Vector2, lv: float, s: float) -> float:
	var depth: float = clampf((_surface_y(base, lv, s) - (base.y + RIM_Y * s)) / (-RIM_Y * s), 0.0, 1.0)
	return (lerpf(RIM_RX, BASE_HW, depth) - 1.2) * s


# One squeeze. `tips` are the two squeezed teat tips. Each drop is aimed so that its arc ends
# inside the rim.
func squirt(tips: Array[Vector2]) -> void:
	var n: int = tips.size() * DROPS_PER_TEAT
	if n == 0:
		return
	if particle_count() + n > MAX_PARTICLES:
		_add_milk(1.0 / float(PAIL_SQUEEZES))  # too busy to draw it: pour it straight in
		return
	var base: Vector2 = ground + CATCH
	var rim_y: float = base.y + RIM_Y
	var edge: float = RIM_RX - 3.5
	for tip: Vector2 in tips:
		for k: int in range(DROPS_PER_TEAT):
			var p: Vector2 = Vector2(clampf(tip.x + randf_range(-1.0, 1.0), base.x - edge, base.x + edge), tip.y - float(k) * 0.8)
			var vy: float = randf_range(-85.0, -25.0)
			var t: float = (-vy + sqrt(maxf(vy * vy + 2.0 * GRAVITY * (rim_y - p.y), 0.0))) / GRAVITY
			var tx: float = base.x + randf_range(-edge, edge)
			_drops.append({"pos": p, "vel": Vector2((tx - p.x) / maxf(t, 0.05), vy),
				"r": randf_range(1.2, 1.8), "amt": 1.0 / float(PAIL_SQUEEZES * n)})
			spawned += 1


# Milk that lands in a full pail goes into the fresh one, unless both waiting spots are taken
# (then the full pail can't move and the extra splashes away).
func _add_milk(amt: float) -> void:
	var total: float = level + amt
	if total < 0.999:  # the drops' shares add up to 1 only up to rounding
		level = total
		return
	level = 1.0
	if waiting.size() < MAX_WAITING:
		_extra = minf(_extra + maxf(total - 1.0, 0.0), 0.5)


func update(dt: float, ground_pos: Vector2) -> void:
	ground = ground_pos
	_update_drops(dt)
	_update_catch(dt)
	_update_waiting(dt)
	_update_wagon(dt)


func _update_drops(dt: float) -> void:
	var base: Vector2 = ground + CATCH
	var surf: float = _surface_y(base, level, 1.0)
	var live: Array[Dictionary] = []
	for d: Dictionary in _drops:
		var v: Vector2 = d["vel"]
		v.y += GRAVITY * dt
		var p: Vector2 = (d["pos"] as Vector2) + v * dt
		if p.y > base.y + RIM_Y:  # below the rim: stay between the walls
			p.x = clampf(p.x, base.x - RIM_RX + 2.5, base.x + RIM_RX - 2.5)
		d["vel"] = v
		d["pos"] = p
		if v.y > 0.0 and p.y >= surf:
			caught += 1
			var spilling: bool = level >= 1.0
			_add_milk(float(d["amt"]))
			if _ripples.size() < 24:
				_ripples.append({"x": p.x - base.x, "life": 0.45})
			if randf() < 0.45 or spilling:
				_splats.append({"pos": Vector2(p.x, surf), "vel": Vector2(randf_range(-18.0, 18.0), randf_range(-125.0, -55.0))})
		else:
			live.append(d)
	_drops = live

	var live_s: Array[Dictionary] = []
	for s: Dictionary in _splats:
		var sv: Vector2 = s["vel"]
		sv.y += GRAVITY * dt
		s["vel"] = sv
		var sp: Vector2 = (s["pos"] as Vector2) + sv * dt
		s["pos"] = sp
		if sv.y < 0.0 or sp.y < surf:  # gone again once it falls back into the milk
			live_s.append(s)
	_splats = live_s

	var live_r: Array[Dictionary] = []
	for r: Dictionary in _ripples:
		r["life"] = float(r["life"]) - dt
		if float(r["life"]) > 0.0:
			live_r.append(r)
	_ripples = live_r

	var live_t: Array[Dictionary] = []
	for tw: Dictionary in _twinkles:
		tw["life"] = float(tw["life"]) - dt
		if float(tw["life"]) > 0.0:
			live_t.append(tw)
	_twinkles = live_t


func _update_catch(dt: float) -> void:
	if drop_in > 0.0 or drop_in_v != 0.0:
		drop_in_v -= 1500.0 * dt
		drop_in += drop_in_v * dt
		if drop_in <= 0.0:
			drop_in = 0.0
			drop_in_v = -drop_in_v * 0.3 if drop_in_v < -90.0 else 0.0  # one little bounce
	# A full pail goes to wait beside the cow as soon as a spot is free, and a fresh one drops in.
	if level >= 1.0 and drop_in <= 0.0 and drop_in_v == 0.0 and waiting.size() < MAX_WAITING:
		waiting.append({"x": ground.x + CATCH.x, "hop": 0.0})
		level = _extra
		_extra = 0.0
		drop_in = DROP_IN
		drop_in_v = 0.0
		_ripples.clear()


func _update_waiting(dt: float) -> void:
	for i: int in range(waiting.size()):
		var w: Dictionary = waiting[i]
		var x: float = float(w["x"])
		var nx: float = move_toward(x, ground.x + SLOTS[i], 150.0 * dt)
		w["x"] = nx
		w["hop"] = float(w["hop"]) + absf(nx - x)


func _slot_ready(i: int) -> bool:
	return i < waiting.size() and absf(float(waiting[i]["x"]) - (ground.x + SLOTS[i])) < 0.5


func _update_wagon(dt: float) -> void:
	var old_x: float = wagon_x
	match wagon:
		Wagon.AWAY:
			wagon_x = ground.x + WAGON_OFF
			if waiting.is_empty():
				wait_t = 0.0
			else:
				wait_t += dt
				if wait_t >= COLLECT_WAIT or waiting.size() >= MAX_WAITING:
					wagon = Wagon.ARRIVING
					wagon_t = 0.0
		Wagon.ARRIVING:
			wagon_t = minf(wagon_t + dt / 0.8, 1.0)
			wagon_x = lerpf(ground.x + WAGON_OFF, ground.x + WAGON_STOP, 1.0 - pow(1.0 - wagon_t, 3.0))
			if wagon_t >= 1.0:
				wagon = Wagon.LOADING
				hop_cd = 0.15
		Wagon.LOADING:
			hop_cd -= dt
			if hop_cd <= 0.0 and _slot_ready(0) and loaded + hopping.size() < WAGON_CAPACITY:
				var w: Dictionary = waiting.pop_front()
				hopping.append({"from": Vector2(float(w["x"]), ground.y + SLOT_Y), "spot": loaded + hopping.size(), "t": 0.0})
				hop_cd = 0.3
			var done: bool = waiting.is_empty() or loaded + hopping.size() >= WAGON_CAPACITY
			if hopping.is_empty() and done and hop_cd <= -0.35:
				wagon = Wagon.LEAVING
				wagon_t = 0.0
		Wagon.LEAVING:
			wagon_t = minf(wagon_t + dt / 0.8, 1.0)
			wagon_x = lerpf(ground.x + WAGON_STOP, ground.x + WAGON_OFF, wagon_t * wagon_t * wagon_t)
			if wagon_t >= 1.0:
				collected += loaded
				loaded = 0
				wagon = Wagon.AWAY
				wait_t = 0.0
	wheel_spin += (wagon_x - old_x) / 4.5

	var live: Array[Dictionary] = []
	for h: Dictionary in hopping:
		h["t"] = float(h["t"]) + dt / 0.38
		if float(h["t"]) >= 1.0:
			loaded += 1
			_twinkles.append({"pos": _hop_target(int(h["spot"])) + Vector2(0.0, -16.0), "life": 0.45})
			Sfx.play("coin", -16.0, 0.1)
		else:
			live.append(h)
	hopping = live


func _hop_target(spot: int) -> Vector2:
	return Vector2(wagon_x + BED_SPOTS[mini(spot, BED_SPOTS.size() - 1)], ground.y + WAGON_Y + BED_Y)


func _hop_pos(h: Dictionary) -> Vector2:
	var t: float = float(h["t"])
	return (h["from"] as Vector2).lerp(_hop_target(int(h["spot"])), t) + Vector2(0.0, -sin(t * PI) * 20.0)


# =========================================================================================
# DRAWING
# =========================================================================================
func draw(ci: CanvasItem) -> void:
	if wagon != Wagon.AWAY:
		_draw_wagon(ci)
	for h: Dictionary in hopping:
		if float(h["t"]) < 0.6:
			_draw_pail(ci, _hop_pos(h), 1.0, lerpf(1.0, LOADED_SCALE, float(h["t"])), true)
	for i: int in range(waiting.size() - 1, -1, -1):
		var w: Dictionary = waiting[i]
		var x: float = float(w["x"])
		var moving: bool = absf(x - (ground.x + SLOTS[i])) > 0.01
		var base: Vector2 = Vector2(x, ground.y + SLOT_Y)
		ci.draw_colored_polygon(Art.ellipse(base + Vector2(0.0, 1.0), 11.0, 2.4, 0.0, 20), SHADOW)
		var hop: float = absf(sin(float(w["hop"]) * 0.2)) * 3.0 if moving else 0.0
		_draw_pail(ci, base + Vector2(0.0, -hop), 1.0, 1.0, true)

	# The pail under the udder, with the milk landing in it between its back and front.
	var cb: Vector2 = catch_pos()
	var sh: float = clampf(1.0 - drop_in / DROP_IN, 0.3, 1.0)
	ci.draw_colored_polygon(Art.ellipse(ground + CATCH + Vector2(0.0, 1.0), 11.0 * sh, 2.4 * sh, 0.0, 20), SHADOW)
	_pail_back(ci, cb, level, 1.0)
	var surf: float = _surface_y(cb, level, 1.0)
	var srx: float = _surface_rx(cb, level, 1.0)
	for r: Dictionary in _ripples:  # kept inside the milk, so none shows outside the pail
		var k: float = float(r["life"]) / 0.45
		var rx: float = clampf(float(r["x"]), -srx + 2.0, srx - 2.0)
		var rr: float = minf(1.5 + (1.0 - k) * 4.5, srx - absf(rx) - 0.5)
		if rr > 0.8:
			Art.outline(ci, Art.ellipse(Vector2(cb.x + rx, surf), rr, 0.4 + rr * 0.25, 0.0, 14), Color(MILK_EDGE.r, MILK_EDGE.g, MILK_EDGE.b, k * 0.8), 0.9)
	for s: Dictionary in _splats:
		ci.draw_circle(s["pos"] as Vector2, 1.1, MILK)
	for d: Dictionary in _drops:
		var v: Vector2 = d["vel"]
		var dr: float = float(d["r"])
		Art.fill(ci, Art.ellipse(d["pos"] as Vector2, dr + v.length() * 0.012, dr, v.angle(), 12), MILK, MILK_EDGE, 0.9)
	_pail_front(ci, cb, 1.0, false)

	for tw: Dictionary in _twinkles:
		var tk: float = float(tw["life"]) / 0.45
		Art.sparkle(ci, tw["pos"] as Vector2, 6.0 * sin(tk * PI), Color("#fff3a0"))


func _draw_pail(ci: CanvasItem, base: Vector2, lv: float, s: float, handle_up: bool) -> void:
	_pail_back(ci, base, lv, s)
	_pail_front(ci, base, s, handle_up)


# The inside of the pail and its milk.
func _pail_back(ci: CanvasItem, base: Vector2, lv: float, s: float) -> void:
	var rim: Vector2 = base + Vector2(0.0, RIM_Y * s)
	ci.draw_colored_polygon(Art.ellipse(rim, RIM_RX * s, RIM_RY * s, 0.0, 28), STEEL_IN)
	if lv <= 0.01:
		return
	var sy: float = _surface_y(base, lv, s)
	var rx: float = _surface_rx(base, lv, s)
	var milk: PackedVector2Array = Art.ellipse(Vector2(base.x, sy), rx, RIM_RY * 0.82 * s, 0.0, 24)
	ci.draw_colored_polygon(milk, MILK)
	ci.draw_colored_polygon(Art.ellipse(Vector2(base.x - rx * 0.35, sy - 0.6 * s), rx * 0.3, RIM_RY * 0.22 * s, 0.0, 12), Color(1, 1, 1, 0.9))


# The front of the pail: walls, two ribs, a shine, the rim and the handle.
func _pail_front(ci: CanvasItem, base: Vector2, s: float, handle_up: bool) -> void:
	var rim: Vector2 = base + Vector2(0.0, RIM_Y * s)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):  # the front half of the rim, right to left
		var a: float = PI * float(i) / 16.0
		pts.append(rim + Vector2(cos(a) * RIM_RX, sin(a) * RIM_RY) * s)
	for i: int in range(13):  # the rounded bottom, left to right
		var a: float = PI - PI * float(i) / 12.0
		pts.append(base + Vector2(cos(a) * BASE_HW, sin(a) * BASE_RY) * s)
	ci.draw_colored_polygon(pts, STEEL)
	for hb: float in [0.3, 0.72]:
		var hw: float = lerpf(RIM_RX, BASE_HW, hb) - 0.7
		var ry: float = lerpf(RIM_RY, BASE_RY, hb)
		var y: float = RIM_Y * (1.0 - hb)
		var band: PackedVector2Array = PackedVector2Array()
		for i: int in range(13):
			var a: float = PI * float(i) / 12.0
			band.append(base + Vector2(cos(a) * hw, y + sin(a) * ry) * s)
		ci.draw_polyline(band, STEEL_DARK, 1.3 * s)
	ci.draw_line(base + Vector2(-6.6, -10.2) * s, base + Vector2(-5.4, -3.0) * s, Color(1, 1, 1, 0.75), 1.8 * s)
	Art.outline(ci, pts, INK, 2.0 * s)
	Art.outline(ci, Art.ellipse(rim, RIM_RX * s, RIM_RY * s, 0.0, 28), INK, 2.0 * s)
	# The handle: arched up over the top, or (under the udder) flopped down on the front.
	var dip: float = -11.0 if handle_up else 7.5
	var hp: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var t: float = float(i) / 12.0
		hp.append(rim + Vector2(lerpf(-RIM_RX + 0.6, RIM_RX - 0.6, t), 0.6 + dip * 4.0 * t * (1.0 - t)) * s)
	ci.draw_polyline(hp, INK, 2.6 * s)
	ci.draw_polyline(hp, HANDLE, 1.1 * s)
	for side: float in [-1.0, 1.0]:
		ci.draw_circle(rim + Vector2(side * (RIM_RX - 0.6), 0.6) * s, 1.4 * s, INK)


func _draw_wagon(ci: CanvasItem) -> void:
	var b: Vector2 = Vector2(wagon_x, ground.y + WAGON_Y)
	ci.draw_colored_polygon(Art.ellipse(b + Vector2(0.0, 0.5), 21.0, 2.6, 0.0, 20), SHADOW)
	# The pails already in it (and any about to land) sit behind the front of the bed.
	for i: int in range(loaded):
		_draw_pail(ci, _hop_target(i), 1.0, LOADED_SCALE, true)
	for h: Dictionary in hopping:
		if float(h["t"]) >= 0.6:
			_draw_pail(ci, _hop_pos(h), 1.0, lerpf(1.0, LOADED_SCALE, float(h["t"])), true)
	Art.inked_stroke(ci, PackedVector2Array([b + Vector2(18.0, -11.0), b + Vector2(29.0, -20.0)]), WAGON_DARK, 2.0, 1.4)
	Art.fill(ci, Art.rrect(Rect2(b + Vector2(-19.0, -17.0), Vector2(38.0, 11.0)), 2.5), WAGON_RED, INK, 2.0)
	ci.draw_line(b + Vector2(-16.0, -14.6), b + Vector2(16.0, -14.6), Color(1, 1, 1, 0.35), 1.4)
	for x: float in [-6.5, 6.5]:
		ci.draw_line(b + Vector2(x, -12.8), b + Vector2(x, -7.6), WAGON_DARK, 1.2)
	for wx: float in [-11.0, 11.0]:
		var c: Vector2 = b + Vector2(wx, -4.5)
		Art.circle(ci, c, 4.5, WHEEL, INK, 1.8)
		for k: int in range(3):
			var dir: Vector2 = Vector2.from_angle(wheel_spin + TAU * float(k) / 3.0)
			ci.draw_line(c - dir * 3.0, c + dir * 3.0, WHEEL_DARK, 1.1)
		ci.draw_circle(c, 1.3, INK)
