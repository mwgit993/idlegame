extends Control

# Shared base for the hen (chicken.gd) and the monkey (monkey.gd). Like the cow (cow.gd) they
# are plush toys drawn every frame with the vector API. This owns what they share:
#   - squash, stretch and hop springs, and a gentle breath
#   - blinking, and eyes that glance a couple of pixels toward the mouse
#   - a happy ^ ^ squint after each click
#   - the rush dance: hopping, heart eyes, floating hearts and sparkles
#   - goodies: each click sends one flying (an egg, a banana) in an arc into a container beside
#     the animal (the nest, the crate). When the container holds CAPACITY it empties with a
#     sparkle and a coin clink. Like the cow's pails, this is all for show: Farm pays on click.
# A subclass draws the animal (_draw_animal, in animal-local coordinates: the origin is on the
# ground between its feet, y goes up negative), the container (_draw_container_back/_front) and a
# goodie (_draw_goodie), anything fixed beside it (_draw_scenery), and says where goodies start
# (_goodie_start).

const INK: Color = Color("#3a2621")
const EYE: Color = Color("#2a1f22")
const CHEEK: Color = Color(1.0, 0.45, 0.58)
const MOUTH: Color = Color("#8c2a3a")
const TONGUE: Color = Color("#ff7b98")
const HEART_COLS: Array[Color] = [Color("#ff3d6e"), Color("#ff7aa8"), Color("#e8348a")]
const SPARK_COLS: Array[Color] = [Color("#ffffff"), Color("#ffe066"), Color("#ffc2dc")]
const MAX_PARTICLES: int = 200
const GRAVITY: float = 900.0
const FLIGHT: float = 0.42   # seconds a goodie is in the air
const CAPACITY: int = 6      # goodies the container holds before it empties
const LOOK: float = 2.0

var ground: Vector2 = Vector2(100.0, 304.0)  # between its feet, in this Control's coordinates
var container_pos: Vector2 = Vector2(78.0, -6.0)  # the container's centre, relative to ground
var stored: int = 0          # goodies in the container right now
var shipped: int = 0         # times the container has emptied (the smoke test reads it)

var _t: float = 0.0
var _sq: float = 0.0
var _sq_v: float = 0.0
var _hop: float = 0.0
var _hop_v: float = 0.0
var _pop: float = 0.0        # 1 right after a click: happy squint and open mouth
var _blink_t: float = 2.0
var _look: Vector2 = Vector2.ZERO
var _look_v: Vector2 = Vector2.ZERO
var _rush: float = 0.0
var _heart_t: float = 0.0
var _spark_t: float = 0.0
var _bump: float = 0.0       # the container's little bounce when something lands
var _fx: Array[Dictionary] = []      # hearts and sparkles: heart, pos, vel, life, max, size, col
var _flying: Array[Dictionary] = []  # goodies in the air: pos, vel, life, rot, spin


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# One click: squash, hop, a happy squint, and a goodie flies into the container.
func squeeze() -> void:
	_sq = 0.13
	_sq_v = -1.2
	if _hop < 2.0:
		_hop_v = 110.0
	_pop = 1.0
	_on_click()
	if _flying.size() < 30:
		var start: Vector2 = ground + _goodie_start() + Vector2(0.0, -_hop)
		var target: Vector2 = ground + container_pos + Vector2(randf_range(-9.0, 9.0), -3.0)
		var v: Vector2 = (target - start) / FLIGHT - Vector2(0.0, 0.5 * GRAVITY * FLIGHT)
		_flying.append({"pos": start, "vel": v, "life": FLIGHT, "rot": randf_range(-0.4, 0.4), "spin": randf_range(-7.0, 7.0)})


# Goodies in the air plus hearts and sparkles.
func particle_count() -> int:
	return _flying.size() + _fx.size()


# --- Hooks for the subclass ---

func _on_click() -> void:
	pass


func _goodie_start() -> Vector2:
	return Vector2.ZERO


func _animate(_dt: float) -> void:
	pass


func _draw_animal() -> void:
	pass


# Anything fixed beside the animal (the monkey's banana vine), in this Control's coordinates.
func _draw_scenery() -> void:
	pass


func _draw_container_back(_c: Vector2) -> void:
	pass


func _draw_container_front(_c: Vector2) -> void:
	pass


func _draw_goodie(_pos: Vector2, _rot: float, _s: float) -> void:
	pass


# --- Update ---

func _process(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 30.0)
	_t += dt
	var rush_on: bool = Farm.rush_left > 0.0
	_rush = move_toward(_rush, 1.0 if rush_on else 0.0, dt * 3.0)
	_sq_v += (-260.0 * _sq - 11.0 * _sq_v) * dt
	_sq += _sq_v * dt
	_hop_v -= 900.0 * dt
	_hop += _hop_v * dt
	if _hop <= 0.0:
		if _hop_v < -80.0:
			_sq = maxf(_sq, 0.07)
		_hop = 0.0
		_hop_v = 0.0
		if rush_on and fmod(_t, 0.55) < dt * 1.5:
			_hop_v = 120.0
	_pop *= exp(-dt * 6.0)
	_bump *= exp(-dt * 10.0)
	_blink_t -= dt
	if _blink_t < -0.16:
		_blink_t = randf_range(2.2, 5.0) if randf() > 0.15 else 0.12
	_update_look(dt)
	_update_flying(dt)
	_update_fx(dt, rush_on)
	_animate(dt)
	queue_redraw()


func _update_look(dt: float) -> void:
	var m: Vector2 = get_local_mouse_position()
	var target: Vector2 = (m - (ground + Vector2(0.0, -110.0))).limit_length(120.0) / 120.0 * LOOK
	var acc: Vector2 = (target - _look) * 90.0 - _look_v * 19.0
	_look_v += acc * dt
	_look += _look_v * dt


func _update_flying(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for g: Dictionary in _flying:
		var v: Vector2 = g["vel"]
		g["pos"] = (g["pos"] as Vector2) + v * dt
		g["vel"] = v + Vector2(0.0, GRAVITY * dt)
		g["rot"] = float(g["rot"]) + float(g["spin"]) * dt
		g["life"] = float(g["life"]) - dt
		if float(g["life"]) > 0.0:
			keep.append(g)
			continue
		stored += 1
		_bump = 1.0
		if stored >= CAPACITY:
			stored = 0
			shipped += 1
			Sfx.play("coin", -12.0)
			for k: int in range(10):
				if particle_count() < MAX_PARTICLES:
					var a: float = TAU * float(k) / 10.0
					_fx.append({"heart": false, "pos": ground + container_pos + Vector2(cos(a), sin(a) * 0.5) * 14.0,
						"vel": Vector2(cos(a), sin(a) - 1.0) * 40.0, "life": 0.6, "max": 0.6, "size": randf_range(4.0, 7.0),
						"col": SPARK_COLS[k % SPARK_COLS.size()]})
	_flying = keep


func _update_fx(dt: float, rush_on: bool) -> void:
	if rush_on and particle_count() < MAX_PARTICLES:
		_heart_t -= dt
		_spark_t -= dt
		if _heart_t <= 0.0:
			_heart_t = 0.16
			var hp: Vector2 = ground + Vector2(randf_range(-40.0, 50.0), randf_range(-150.0, -110.0))
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


# The animal's transform: breathing, squash and stretch, the hop and the rush wiggle.
func _xf() -> Transform2D:
	var breathe: float = sin(_t * 2.2) * 0.012
	var tilt: float = sin(_t * 7.0) * 0.06 * _rush
	return Transform2D(tilt, Vector2(1.0 + _sq * 0.9, 1.0 - _sq + breathe), 0.0, ground + Vector2(0.0, -_hop))


# A gentle head bob around `neck` (animal-local), livelier during the rush.
func _head_xf(neck: Vector2) -> Transform2D:
	var a: float = sin(_t * 1.6) * 0.035 + sin(_t * 5.0) * 0.08 * _rush
	return Transform2D(a, neck) * Transform2D(0.0, -neck)


func _lid() -> float:
	if _blink_t >= 0.0:
		return 0.0
	var ph: float = clampf(-_blink_t / 0.16, 0.0, 1.0)
	return 1.0 - absf(ph * 2.0 - 1.0)


# --- Drawing ---

func _draw() -> void:
	var sh: float = clampf(1.0 - _hop / 30.0, 0.6, 1.0)
	draw_colored_polygon(Art.ellipse(ground + Vector2(-2.0, 2.0), 58.0 * sh * (1.0 + _sq * 0.5), 8.0 * sh), Color(0.12, 0.32, 0.05, 0.3))
	_draw_scenery()
	var c: Vector2 = ground + container_pos
	var bump: Transform2D = Transform2D(0.0, Vector2(1.0 + 0.06 * _bump, 1.0 - 0.08 * _bump), 0.0, c)
	draw_set_transform_matrix(bump)
	_draw_container_back(Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_set_transform_matrix(_xf())
	_draw_animal()
	draw_set_transform_matrix(bump)
	_draw_container_front(Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for g: Dictionary in _flying:
		_draw_goodie(g["pos"] as Vector2, float(g["rot"]), 1.0)
	_draw_fx()


# Big shiny black eyes at `centers` (current transform). A blink squashes them shut, a click
# turns them into happy ^ ^ squints, the rush makes them hearts.
func _draw_eyes(centers: Array[Vector2], rx: float, ry0: float) -> void:
	var lid: float = _lid()
	for e: int in range(centers.size()):
		var side: float = -1.0 if e == 0 else 1.0
		var c: Vector2 = centers[e] + _look
		if _rush > 0.5:
			var beat: float = 1.0 + 0.1 * sin(_t * 9.0)
			Art.fill(self, Art.heart(c + Vector2(0.0, 1.0), rx * 3.4 * beat, 28), HEART_COLS[0], INK, 2.0)
			draw_colored_polygon(Art.ellipse(c + Vector2(-3.5, -3.0), 2.2, 1.5, -0.5, 12), Color(1, 1, 1, 0.85))
		elif _pop > 0.45:
			var sq: PackedVector2Array = PackedVector2Array([c + Vector2(-rx, 2.5), c + Vector2(0.0, -4.0), c + Vector2(rx, 2.5)])
			Art.stroke(self, Art.round_poly(sq, 3.0, 4), EYE, 3.0)
		elif lid > 0.6:
			draw_arc(c + Vector2(0.0, -2.5), rx, 0.15 * PI, 0.85 * PI, 14, EYE, 3.0)
		else:
			var ry: float = ry0 * (1.0 - lid)
			draw_colored_polygon(Art.ellipse(c, rx, ry, 0.0, 28), EYE)
			draw_colored_polygon(Art.ellipse(c + Vector2(0.0, ry * 0.45), rx * 0.62, ry * 0.32, 0.0, 16), Color("#4a3a44"))
			if ry > 3.0:
				draw_circle(c + Vector2(-1.8, -ry * 0.38), 2.4, Color.WHITE)
				draw_circle(c + Vector2(2.1, ry * 0.3), 1.1, Color.WHITE)
			for k: int in range(2):
				var a: float = (PI + 0.35 + 0.42 * float(k)) if side < 0.0 else (TAU - 0.35 - 0.42 * float(k))
				var p0: Vector2 = c + Vector2(cos(a) * rx, sin(a) * ry)
				var dir: Vector2 = Vector2(cos(a), sin(a) * 0.9).normalized()
				Art.stroke(self, PackedVector2Array([p0, p0 + dir * 3.2]), EYE, 1.7)


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
