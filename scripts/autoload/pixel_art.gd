extends Node

# The cartoon art kit: the palette, vector shape helpers and every icon in the game, drawn
# with Godot's vector API (polygons, circles and thick lines; MSAA smooths the edges). Nothing is baked
# into image files or textures. Draw an icon from any draw callback with
#   Art.draw_icon(canvas_item, "name", center, size)
# Icon names: the business ids (pail, churn, cheese, icecream, yogurt, diner, cosmic, moon)
# plus coin, bell (the golden cowbell), farmhand, drop and star. Unknown names warn and draw
# the coin. The cow is in scripts/cow.gd and the farm background in scripts/farm_scene.gd.
#
# (The file kept its old name, pixel_art.gd, so the autoload line in project.godot didn't
# have to change.)

const INK: Color = Color("#2b1e1a")          # thick cartoon outlines
const WHITE: Color = Color("#fffdf6")
const BARN: Color = Color("#e2463a")
const BARN_DARK: Color = Color("#a72a22")
const GOLD: Color = Color("#ffcc2e")
const GOLD_DARK: Color = Color("#d99100")
const PINK: Color = Color("#ff9cc0")
const PINK_DARK: Color = Color("#e0628c")

const ICONS: Array[String] = [
	"pail", "churn", "cheese", "icecream", "yogurt", "diner", "cosmic", "moon",
	"eggbasket", "friedegg", "omelette", "custard", "cake", "eggnog", "hatchery", "fancyegg",
	"bunch", "smoothie", "bread", "split", "chips", "pie", "boat", "planet",
	"coin", "bell", "goldegg", "goldbanana", "egg", "banana", "farmhand", "drop", "star", "gear",
	"cowface", "henface", "monkeyface", "lock",
]
const LW: float = 2.2  # icon outline width, in the 32-unit icon box
const WGHT_TAG: int = 0x77676874  # OpenType 'wght' axis

var font_bold: FontVariation


func _ready() -> void:
	var ttf: FontFile = load("res://assets/fonts/Fredoka-Variable.ttf") as FontFile
	font_bold = FontVariation.new()
	font_bold.base_font = ttf
	font_bold.variation_opentype = {WGHT_TAG: 700}


func has_icon(id: String) -> bool:
	return id in ICONS


# =========================================================================================
# SHAPE HELPERS. Points are PackedVector2Arrays in the caller's coordinates.
# =========================================================================================
func ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 32) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		var x: float = cos(a) * rx
		var y: float = sin(a) * ry
		pts[i] = c + Vector2(x * cr - y * sr, x * sr + y * cr)
	return pts


# A squarish ellipse (e > 2 gets boxier): good for marshmallow-round bodies.
func superellipse(c: Vector2, rx: float, ry: float, e: float, n: int = 48) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	var k: float = 2.0 / e
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		var ca: float = cos(a)
		var sa: float = sin(a)
		pts[i] = c + Vector2(rx * signf(ca) * pow(absf(ca), k), ry * signf(sa) * pow(absf(sa), k))
	return pts


# A lumpy circle, for cow spots, bushes and splats.
func blob(c: Vector2, r: float, phase: float, wobble: float = 0.18, n: int = 28) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		var rr: float = r * (1.0 + wobble * sin(3.0 * a + phase) + wobble * 0.6 * sin(5.0 * a + phase * 1.7))
		pts[i] = c + Vector2(cos(a), sin(a)) * rr
	return pts


# Rounds every corner of a polygon (no sharp corners anywhere: cartoon-soft, and thick
# outlines don't spike).
func round_poly(pts: PackedVector2Array, radius: float, seg: int = 4) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = pts.size()
	for i: int in range(n):
		var p: Vector2 = pts[i]
		var da: Vector2 = pts[(i - 1 + n) % n] - p
		var db: Vector2 = pts[(i + 1) % n] - p
		var r: float = minf(radius, minf(da.length(), db.length()) * 0.49)
		if r < 0.05:
			out.append(p)
			continue
		var p1: Vector2 = p + da.normalized() * r
		var p2: Vector2 = p + db.normalized() * r
		for s: int in range(seg + 1):
			var t: float = float(s) / float(seg)
			out.append(p1.lerp(p, t).lerp(p.lerp(p2, t), t))
	return out


func rrect(r: Rect2, radius: float, seg: int = 4) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	return round_poly(pts, radius, seg)


func heart(c: Vector2, size: float, n: int = 36) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	var s: float = size / 34.0
	for i: int in range(n):
		var t: float = TAU * float(i) / float(n)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts[i] = c + Vector2(x, y + 2.0) * s
	return pts


func star(c: Vector2, r_out: float, r_in: float, points: int = 5, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(points * 2):
		var a: float = rot + PI * float(i) / float(points)
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func teardrop(tip: Vector2, c: Vector2, r: float, n: int = 20) -> PackedVector2Array:
	var d: Vector2 = tip - c
	var dist: float = maxf(d.length(), r + 0.5)
	var th: float = acos(r / dist)
	var base: float = d.angle()
	var pts: PackedVector2Array = PackedVector2Array([tip])
	for i: int in range(n + 1):
		var a: float = base + th + (TAU - 2.0 * th) * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


# Fill a polygon and give it a thick outline.
func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, line: Color = INK, w: float = LW) -> void:
	ci.draw_colored_polygon(pts, col)
	if w > 0.0:
		outline(ci, pts, line, w)


func outline(ci: CanvasItem, pts: PackedVector2Array, line: Color = INK, w: float = LW) -> void:
	if pts.size() < 3:
		return
	var c: PackedVector2Array = pts.duplicate()
	c.append(pts[0])
	c.append(pts[1])
	ci.draw_polyline(c, line, w)


func circle(ci: CanvasItem, c: Vector2, r: float, col: Color, line: Color = INK, w: float = LW) -> void:
	ci.draw_circle(c, r, col)
	if w > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, maxi(16, int(r * 2.5)), line, w)


# A thick line with round caps.
func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, col, w)
	ci.draw_circle(pts[0], w * 0.5, col)
	ci.draw_circle(pts[pts.size() - 1], w * 0.5, col)


# A thick line with a dark outline around it (tails, straws, handles, stems).
func inked_stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, ow: float = LW) -> void:
	stroke(ci, pts, INK, w + ow * 2.0)
	stroke(ci, pts, col, w)


func clip(a: PackedVector2Array, b: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		if p.size() >= 3:
			out.append(p)
	return out


# Text with a chunky dark outline (floaters, labels drawn in callbacks).
func outlined_text(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int, col: Color,
		outline_px: int = 4, line: Color = INK, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if outline_px > 0:
		ci.draw_string_outline(font, pos, text, align, width, size, outline_px, line)
	ci.draw_string(font, pos, text, align, width, size, col)


# =========================================================================================
# ICONS, designed in a 32 x 32 box centred on (0, 0).
# =========================================================================================
func draw_icon(ci: CanvasItem, id: String, center: Vector2, size: float, xf: Transform2D = Transform2D.IDENTITY) -> void:
	var s: float = size / 32.0
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(s, s), 0.0, center))
	match id:
		"pail":
			_icon_pail(ci)
		"churn":
			_icon_churn(ci)
		"cheese":
			_icon_cheese(ci)
		"icecream":
			_icon_icecream(ci)
		"yogurt":
			_icon_yogurt(ci)
		"diner":
			_icon_shake(ci)
		"cosmic":
			_icon_rocket(ci)
		"moon":
			_icon_moon(ci)
		"eggbasket":
			_icon_eggbasket(ci)
		"friedegg":
			_icon_friedegg(ci)
		"omelette":
			_icon_omelette(ci)
		"custard":
			_icon_custard(ci)
		"cake":
			_icon_cake(ci)
		"eggnog":
			_icon_eggnog(ci)
		"hatchery":
			_icon_hatchery(ci)
		"fancyegg":
			_icon_fancyegg(ci)
		"bunch":
			_icon_bunch(ci)
		"smoothie":
			_icon_smoothie(ci)
		"bread":
			_icon_bread(ci)
		"split":
			_icon_split(ci)
		"chips":
			_icon_chips(ci)
		"pie":
			_icon_pie(ci)
		"boat":
			_icon_boat(ci)
		"planet":
			_icon_planet(ci)
		"goldegg":
			_icon_goldegg(ci)
		"goldbanana":
			_icon_goldbanana(ci)
		"egg":
			_icon_egg(ci)
		"banana":
			_icon_banana(ci)
		"cowface":
			_icon_cowface(ci)
		"henface":
			_icon_henface(ci)
		"monkeyface":
			_icon_monkeyface(ci)
		"lock":
			_icon_lock(ci)
		"coin":
			_icon_coin(ci)
		"bell":
			_icon_bell(ci)
		"farmhand":
			_icon_farmhand(ci)
		"drop":
			_icon_drop(ci)
		"star":
			_icon_star(ci)
		"gear":
			_icon_gear(ci)
		_:
			push_warning("Art.draw_icon: unknown icon '%s'" % id)
			_icon_coin(ci)
	ci.draw_set_transform_matrix(xf)


func _shine(ci: CanvasItem, a: Vector2, b: Vector2, w: float = 2.0) -> void:
	stroke(ci, PackedVector2Array([a, b]), Color(1, 1, 1, 0.75), w)


func _icon_pail(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(0, -3), 12.5, PI * 1.02, PI * 1.98, 20, INK, 4.6)
	ci.draw_arc(Vector2(0, -3), 12.5, PI * 1.04, PI * 1.96, 20, Color("#8fa3b8"), 2.0)
	var body: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-12.5, -4), Vector2(12.5, -4), Vector2(9.0, 14), Vector2(-9.0, 14)]), 2.5)
	fill(ci, body, Color("#bcd0e2"))
	for yy: float in [3.0, 10.0]:
		var hw: float = lerpf(12.5, 9.0, (yy + 4.0) / 18.0) - 0.8
		ci.draw_line(Vector2(-hw, yy), Vector2(hw, yy), Color("#7f97ae"), 1.8)
	_shine(ci, Vector2(-7.5, 0), Vector2(-6.0, 10))
	fill(ci, ellipse(Vector2(0, -4), 13.0, 3.8), Color("#dfe9f2"))
	ci.draw_colored_polygon(ellipse(Vector2(0, -3.6), 10.4, 2.4), WHITE)
	fill(ci, teardrop(Vector2(9.5, -6), Vector2(10.5, 1.5), 2.6), WHITE, INK, 1.6)


func _icon_churn(ci: CanvasItem) -> void:
	inked_stroke(ci, PackedVector2Array([Vector2(0, -15), Vector2(0, -6)]), Color("#e0b07a"), 2.6, 1.6)
	circle(ci, Vector2(0, -15.5), 3.0, Color("#e0b07a"), INK, 1.8)
	var body: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-8, -7), Vector2(8, -7), Vector2(10.5, 3), Vector2(8.5, 14), Vector2(-8.5, 14), Vector2(-10.5, 3)]), 3.0)
	fill(ci, body, Color("#d68f4c"))
	for yy: float in [-1.5, 9.0]:
		var band: Array[PackedVector2Array] = clip(body, rrect(Rect2(-14, yy - 1.6, 28, 3.2), 0.5, 1))
		for p: PackedVector2Array in band:
			ci.draw_colored_polygon(p, Color("#7a4520"))
	ci.draw_line(Vector2(-3, -4), Vector2(-3.5, 11), Color(1, 1, 1, 0.35), 1.6)
	outline(ci, body)
	fill(ci, ellipse(Vector2(0, -7), 8.6, 2.6), Color("#eab47a"))
	# A pat of butter in front.
	fill(ci, round_poly(PackedVector2Array([Vector2(3, 8), Vector2(15, 8), Vector2(15, 15), Vector2(3, 15)]), 1.8), Color("#ffe066"), INK, 1.8)
	ci.draw_colored_polygon(rrect(Rect2(4.2, 9.2, 9.6, 1.8), 0.8, 2), Color("#fff5b8"))


func _icon_cheese(ci: CanvasItem) -> void:
	var top: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-15, 1), Vector2(9, -11), Vector2(15, -3)]), 1.6)
	var front: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-15, 1), Vector2(15, -3), Vector2(15, 10), Vector2(-15, 12)]), 1.8)
	fill(ci, front, Color("#ffc22e"))
	for h: Vector3 in [Vector3(-8, 6, 2.4), Vector3(1, 3, 1.8), Vector3(8, 6, 2.6), Vector3(-1, 9, 1.4)]:
		ci.draw_circle(Vector2(h.x, h.y), h.z, Color("#e39a12"))
	fill(ci, top, Color("#ffe27a"))
	ci.draw_circle(Vector2(5, -5), 2.0, Color("#f2c24a"))
	ci.draw_circle(Vector2(-4, -1), 1.4, Color("#f2c24a"))
	outline(ci, front)


func _icon_icecream(ci: CanvasItem) -> void:
	var cone: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-8.5, 0), Vector2(8.5, 0), Vector2(0, 16)]), 2.0)
	fill(ci, cone, Color("#eaaa5a"))
	for k: int in range(-3, 4):
		var o: float = float(k) * 4.5
		for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
				PackedVector2Array([Vector2(o - 10, -2), Vector2(o + 10, 18)]), cone):
			ci.draw_polyline(seg, Color("#bf7a30"), 1.2)
		for seg2: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
				PackedVector2Array([Vector2(o + 10, -2), Vector2(o - 10, 18)]), cone):
			ci.draw_polyline(seg2, Color("#bf7a30"), 1.2)
	outline(ci, cone)
	var scoop: PackedVector2Array = blob(Vector2(0, -5), 9.5, 0.6, 0.05)
	fill(ci, scoop, PINK)
	var ruffle: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var x: float = lerpf(-10.5, 10.5, float(i) / 12.0)
		ruffle.append(Vector2(x, 0.5 + (2.2 if i % 2 == 0 else 0.0)))
	ruffle.append(Vector2(10.5, -3))
	ruffle.append(Vector2(-10.5, -3))
	fill(ci, round_poly(ruffle, 1.2, 2), PINK)
	ci.draw_colored_polygon(rrect(Rect2(-9.5, -4, 19, 3.6), 1.0, 1), PINK)
	fill(ci, teardrop(Vector2(5, -1), Vector2(5.5, 5), 1.8), PINK, INK, 1.6)
	ci.draw_colored_polygon(ellipse(Vector2(-4, -9.5), 2.8, 1.6, -0.5), Color(1, 1, 1, 0.8))
	var sprinkle_cols: Array[Color] = [Color("#6ad1ff"), Color("#ffe066"), Color("#7ccf4a"), WHITE]
	var sp: Array[Vector3] = [Vector3(2, -10, 0.6), Vector3(5, -6, -0.4), Vector3(-2, -5, 1.2), Vector3(-6, -3.5, 0.2)]
	for i: int in range(sp.size()):
		var d: Vector2 = Vector2(cos(sp[i].z), sin(sp[i].z)) * 1.3
		stroke(ci, PackedVector2Array([Vector2(sp[i].x, sp[i].y) - d, Vector2(sp[i].x, sp[i].y) + d]), sprinkle_cols[i], 1.4)
	ci.draw_line(Vector2(1.5, -15), Vector2(4, -19), INK, 1.4)
	circle(ci, Vector2(1.5, -14.5), 3.0, Color("#e8343f"), INK, 1.8)
	ci.draw_circle(Vector2(0.6, -15.5), 0.9, Color(1, 1, 1, 0.85))


func _icon_yogurt(ci: CanvasItem) -> void:
	inked_stroke(ci, PackedVector2Array([Vector2(3, -6), Vector2(10, -15)]), Color("#c3d0da"), 2.4, 1.6)
	circle(ci, Vector2(10.3, -15.4), 2.2, Color("#c3d0da"), INK, 1.6)
	var cup: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-11, -5), Vector2(11, -5), Vector2(8.5, 14), Vector2(-8.5, 14)]), 2.5)
	fill(ci, cup, WHITE)
	for band: PackedVector2Array in clip(cup, PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(14, 9), Vector2(-14, 9)])):
		ci.draw_colored_polygon(band, PINK)
	fill(ci, heart(Vector2(0, 4.2), 7.5), Color("#e8343f"), INK, 1.4)
	outline(ci, cup)
	fill(ci, rrect(Rect2(-12.5, -8, 25, 3.8), 1.6), Color("#c9d6e3"))
	fill(ci, round_poly(PackedVector2Array([Vector2(6, -8), Vector2(13, -14), Vector2(15, -9)]), 1.2), Color("#e3ebf2"), INK, 1.8)


func _icon_shake(ci: CanvasItem) -> void:
	# Striped straw.
	inked_stroke(ci, PackedVector2Array([Vector2(2, -4), Vector2(9, -17)]), WHITE, 3.0, 1.6)
	for k: int in range(3):
		var a: Vector2 = Vector2(2, -4).lerp(Vector2(9, -17), 0.25 + float(k) * 0.25)
		ci.draw_line(a, a + Vector2(1.6, -3.0) * 0.5, Color("#e8343f"), 3.0)
	# Glass and foot.
	fill(ci, round_poly(PackedVector2Array([Vector2(-5, 15), Vector2(5, 15), Vector2(3, 11), Vector2(-3, 11)]), 1.2), Color("#d6e6f5"), INK, 1.8)
	var glass: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-9.5, -4), Vector2(9.5, -4), Vector2(5.5, 12), Vector2(-5.5, 12)]), 2.2)
	fill(ci, glass, PINK)
	_shine(ci, Vector2(-6, -1), Vector2(-4, 8), 1.8)
	# Whipped cream: outlines first, then fills, so the puffs merge into one cloud.
	var puffs: Array[Vector3] = [Vector3(-5.5, -5, 4.8), Vector3(5.5, -5, 4.8), Vector3(0, -8.5, 5.6)]
	for p: Vector3 in puffs:
		ci.draw_circle(Vector2(p.x, p.y), p.z + LW * 0.5, INK)
	for p2: Vector3 in puffs:
		ci.draw_circle(Vector2(p2.x, p2.y), p2.z - LW * 0.5, WHITE)
	ci.draw_line(Vector2(1.5, -15), Vector2(4.5, -19), INK, 1.4)
	circle(ci, Vector2(1.5, -14), 3.0, Color("#e8343f"), INK, 1.8)
	ci.draw_circle(Vector2(0.6, -15), 0.9, Color(1, 1, 1, 0.85))


func _icon_rocket(ci: CanvasItem) -> void:
	fill(ci, teardrop(Vector2(0, 18), Vector2(0, 11), 4.2), Color("#ff9a2e"), INK, 1.8)
	ci.draw_colored_polygon(teardrop(Vector2(0, 15.5), Vector2(0, 11), 2.2), Color("#ffe066"))
	for sx: float in [-1.0, 1.0]:
		var fin: PackedVector2Array = round_poly(PackedVector2Array([
			Vector2(5.5 * sx, 1), Vector2(12 * sx, 9), Vector2(12 * sx, 13), Vector2(5 * sx, 10)]), 1.6)
		fill(ci, fin, Color("#ef4b4b"))
	var body: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(0, -16), Vector2(6, -8), Vector2(7, 2), Vector2(5, 11), Vector2(-5, 11), Vector2(-7, 2), Vector2(-6, -8)]), 3.2)
	fill(ci, body, WHITE)
	for nose: PackedVector2Array in clip(body, rrect(Rect2(-10, -20, 20, 12.5), 0.5, 1)):
		ci.draw_colored_polygon(nose, Color("#ef4b4b"))
	ci.draw_line(Vector2(-6.4, -7.5), Vector2(6.4, -7.5), INK, 1.6)
	for spot: PackedVector2Array in clip(body, blob(Vector2(4.5, 6), 2.6, 1.0, 0.2, 16)):
		ci.draw_colored_polygon(spot, Color("#2f2a36"))
	for spot2: PackedVector2Array in clip(body, blob(Vector2(-5, 7.5), 1.8, 2.0, 0.2, 16)):
		ci.draw_colored_polygon(spot2, Color("#2f2a36"))
	outline(ci, body)
	circle(ci, Vector2(0, -1), 3.6, Color("#7fd6ff"), INK, 1.8)
	ci.draw_circle(Vector2(-1.2, -2.2), 1.1, Color(1, 1, 1, 0.9))


func _icon_moon(ci: CanvasItem) -> void:
	sparkle(ci, Vector2(-12, -11), 3.2, Color("#ffe066"))
	sparkle(ci, Vector2(13, 7), 2.4, Color("#ffe066"))
	circle(ci, Vector2(-2, 5), 11.0, Color("#e9e4d6"))
	for c: Vector3 in [Vector3(-7, 3, 2.8), Vector3(1, 11, 2.3), Vector3(3, 3, 1.7), Vector3(-4, 10.5, 1.2)]:
		circle(ci, Vector2(c.x, c.y), c.z, Color("#cfc7b2"), Color("#a89f88"), 1.0)
	# A tiny cow standing on the moon, drawn like the big one (scripts/cow.gd): a big round
	# head on a small body, a black ear, a pink muzzle and a shiny eye.
	ci.draw_line(Vector2(-0.5, -7), Vector2(-0.5, -3.2), INK, 2.2)
	ci.draw_line(Vector2(5.5, -7), Vector2(5.8, -3.6), INK, 2.2)
	ci.draw_line(Vector2(-3, -11), Vector2(-5.5, -8), INK, 1.4)
	var body: PackedVector2Array = rrect(Rect2(-3.5, -13, 11, 7), 3.4)
	fill(ci, body, WHITE, INK, 1.6)
	for sp: PackedVector2Array in clip(body, blob(Vector2(0.5, -11), 2.4, 0.5, 0.15, 14)):
		ci.draw_colored_polygon(sp, Color("#3b3440"))
	outline(ci, body, INK, 1.6)
	fill(ci, ellipse(Vector2(5.8, -17.2), 2.6, 1.5, -0.5), Color("#3b3440"), INK, 1.2)
	# Head and muzzle share one outline, so the muzzle reads as a snout, not an open mouth.
	var head: PackedVector2Array = ellipse(Vector2(10, -15), 5.0, 5.0, 0.0, 24)
	var snout: PackedVector2Array = ellipse(Vector2(11.8, -12.3), 3.4, 2.4, 0.0, 20)
	ci.draw_colored_polygon(head, WHITE)
	ci.draw_colored_polygon(snout, PINK)
	var both: Array[PackedVector2Array] = Geometry2D.merge_polygons(head, snout)  # one shape: they overlap
	outline(ci, both[0] if both.size() > 0 else head, INK, 1.6)
	ci.draw_circle(Vector2(13.8, -12.9), 0.6, PINK_DARK)
	ci.draw_circle(Vector2(7.4, -13.4), 1.1, Color(1.0, 0.45, 0.58, 0.55))
	ci.draw_circle(Vector2(10.6, -16.4), 1.1, INK)
	ci.draw_circle(Vector2(10.2, -16.8), 0.4, Color.WHITE)


func _icon_coin(ci: CanvasItem) -> void:
	circle(ci, Vector2(0, 0), 13.0, GOLD)
	ci.draw_arc(Vector2(0, 0), 9.5, 0.0, TAU, 32, GOLD_DARK, 1.6)
	var f: Font = font_bold
	if f == null:
		f = ThemeDB.fallback_font
	var sz: Vector2 = f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	var pos: Vector2 = Vector2(-sz.x * 0.5, f.get_ascent(17) * 0.5 - 1.5)
	ci.draw_string(f, pos, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD_DARK)
	ci.draw_arc(Vector2(0, 0), 10.8, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.8), 1.8)


func _icon_bell(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(0, -11), 4.0, PI, TAU, 12, INK, 4.4)
	ci.draw_arc(Vector2(0, -11), 4.0, PI * 1.02, PI * 1.98, 12, GOLD_DARK, 1.8)
	var body: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-6.5, -11), Vector2(6.5, -11), Vector2(10.5, 8), Vector2(-10.5, 8)]), 3.0)
	fill(ci, body, GOLD)
	circle(ci, Vector2(0, 10.5), 2.8, Color("#a86a00"), INK, 1.8)
	fill(ci, ellipse(Vector2(0, 8), 11.0, 3.0), GOLD_DARK)
	_shine(ci, Vector2(-4.5, -7), Vector2(-6.5, 3), 2.2)
	sparkle(ci, Vector2(11, -11), 4.0, WHITE)


func _icon_farmhand(ci: CanvasItem) -> void:
	circle(ci, Vector2(-10.5, 4), 2.8, Color("#f2b47e"))
	circle(ci, Vector2(10.5, 4), 2.8, Color("#f2b47e"))
	circle(ci, Vector2(0, 3.5), 10.5, Color("#f7c99a"))
	ci.draw_circle(Vector2(-6, 7), 2.2, Color(1.0, 0.45, 0.45, 0.45))
	ci.draw_circle(Vector2(6, 7), 2.2, Color(1.0, 0.45, 0.45, 0.45))
	ci.draw_circle(Vector2(-3.8, 3), 1.5, INK)
	ci.draw_circle(Vector2(3.8, 3), 1.5, INK)
	ci.draw_arc(Vector2(0, 6), 4.0, 0.25 * PI, 0.75 * PI, 10, INK, 1.6)
	inked_stroke(ci, PackedVector2Array([Vector2(3, 9), Vector2(13, 6)]), Color("#f4d35e"), 1.4, 1.0)
	# Straw hat.
	fill(ci, ellipse(Vector2(0, -5), 15.5, 4.2), Color("#f4d35e"))
	var crown: PackedVector2Array = round_poly(PackedVector2Array([
		Vector2(-8.5, -5), Vector2(-7, -15), Vector2(7, -15), Vector2(8.5, -5)]), 2.6)
	fill(ci, crown, Color("#f4d35e"))
	for band: PackedVector2Array in clip(crown, PackedVector2Array([Vector2(-10, -9.5), Vector2(10, -9.5), Vector2(10, -6), Vector2(-10, -6)])):
		ci.draw_colored_polygon(band, BARN)
	outline(ci, crown)


func _icon_drop(ci: CanvasItem) -> void:
	var d: PackedVector2Array = teardrop(Vector2(0, -15), Vector2(0, 4), 10.0, 28)
	fill(ci, d, WHITE)
	ci.draw_colored_polygon(ellipse(Vector2(-4, 3), 2.0, 3.6, 0.3), Color("#d4e6f5"))
	ci.draw_circle(Vector2(-4.5, -1), 1.6, Color(1, 1, 1, 1))
	ci.draw_arc(Vector2(0, 4), 7.0, 0.15 * PI, 0.75 * PI, 10, Color("#a9c6e0"), 1.6)


func _icon_star(ci: CanvasItem) -> void:
	var s: PackedVector2Array = round_poly(star(Vector2(0, 1.5), 15.0, 7.0), 1.8, 3)
	fill(ci, s, GOLD)
	ci.draw_circle(Vector2(-3, 1), 1.4, INK)
	ci.draw_circle(Vector2(3, 1), 1.4, INK)
	ci.draw_arc(Vector2(0, 3.5), 2.6, 0.2 * PI, 0.8 * PI, 8, INK, 1.4)


# The settings button: a chunky 8-tooth cog with a cream hole.
func _icon_gear(ci: CanvasItem) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var step: float = TAU / 8.0
	for i: int in range(8):
		var a: float = step * float(i)
		pts.append(Vector2.from_angle(a - step * 0.3) * 10.5)
		pts.append(Vector2.from_angle(a - step * 0.18) * 14.5)
		pts.append(Vector2.from_angle(a + step * 0.18) * 14.5)
		pts.append(Vector2.from_angle(a + step * 0.3) * 10.5)
	fill(ci, round_poly(pts, 1.4, 2), Color("#c4ced8"))
	ci.draw_arc(Vector2.ZERO, 8.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.75), 2.0)
	fill(ci, ellipse(Vector2.ZERO, 4.6, 4.6), Color("#fff3d6"))


# A twinkly four-point star (the cow and the farm use it too).

# --- The hen's businesses ---

const EGG_COL: Color = Color("#fff3df")
const YOLK: Color = Color("#ffc21e")
const BANANA_COL: Color = Color("#ffd94a")
const BANANA_DARK: Color = Color("#e0a91c")


func _egg(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color = EGG_COL, rot: float = 0.0, w: float = LW) -> void:
	fill(ci, ellipse(c, rx, ry, rot, 24), col, INK, w)
	ci.draw_colored_polygon(ellipse(c + Vector2(-rx * 0.35, -ry * 0.4), rx * 0.26, ry * 0.28, rot - 0.4, 10), Color(1, 1, 1, 0.85))


func _banana(ci: CanvasItem, c: Vector2, size: float, rot: float, col: Color = BANANA_COL) -> void:
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		var a: float = lerpf(-1.05, 1.05, float(i) / 12.0)
		outer.append(Vector2(sin(a) * size, -cos(a) * size + size * 0.8))
		inner.append(Vector2(sin(a) * size * 0.78, -cos(a) * size * 0.6 + size * 0.8))
	var shape: PackedVector2Array = outer.duplicate()
	for i2: int in range(inner.size() - 1, -1, -1):
		shape.append(inner[i2])
	var xf: Transform2D = Transform2D(rot, c)
	fill(ci, xf * round_poly(shape, 1.2, 2), col, INK, 2.0)
	ci.draw_circle(xf * outer[0], size * 0.14, Color("#7a5a2a"))
	ci.draw_circle(xf * outer[outer.size() - 1], size * 0.12, Color("#7a5a2a"))
	ci.draw_line(xf * Vector2(-size * 0.35, -size * 0.02), xf * Vector2(size * 0.25, -size * 0.05), Color(1, 1, 1, 0.6), 1.4)


func _icon_eggbasket(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(0, 0), 12.0, PI * 1.05, PI * 1.95, 18, INK, 4.6)
	ci.draw_arc(Vector2(0, 0), 12.0, PI * 1.07, PI * 1.93, 18, Color("#c98a4b"), 2.0)
	_egg(ci, Vector2(-6, -1), 5.0, 6.5)
	_egg(ci, Vector2(6, -1), 5.0, 6.5)
	_egg(ci, Vector2(0, -4), 5.0, 6.5)
	var body: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-14, 1), Vector2(14, 1), Vector2(10, 14), Vector2(-10, 14)]), 2.5)
	fill(ci, body, Color("#d99a55"))
	for yy: float in [5.0, 9.5]:
		ci.draw_line(Vector2(-12.0 + (yy - 1.0) * 0.25, yy), Vector2(12.0 - (yy - 1.0) * 0.25, yy), Color("#a8683a"), 1.6)
	for xx: float in [-5.0, 0.0, 5.0]:
		ci.draw_line(Vector2(xx, 2.5), Vector2(xx * 0.8, 13.0), Color("#a8683a"), 1.4)


func _icon_friedegg(ci: CanvasItem) -> void:
	inked_stroke(ci, PackedVector2Array([Vector2(9, 9), Vector2(15, 15)]), Color("#5a4a44"), 3.4, 1.8)
	circle(ci, Vector2(-1, -1), 13.5, Color("#5f6b78"))
	ci.draw_circle(Vector2(-1, -1), 10.5, Color("#47525e"))
	fill(ci, blob(Vector2(-1, -1), 9.5, 2.0, 0.16, 24), WHITE, INK, 2.0)
	circle(ci, Vector2(0, -2), 4.4, YOLK, INK, 1.8)
	ci.draw_circle(Vector2(-1.4, -3.4), 1.3, Color(1, 1, 1, 0.85))


func _icon_omelette(ci: CanvasItem) -> void:
	var plate: PackedVector2Array = ellipse(Vector2(0, 6), 15.0, 6.0)
	fill(ci, plate, Color("#e6f1f8"))
	var om: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI + PI * float(i) / 16.0
		om.append(Vector2(cos(a) * 12.0, 4.0 + sin(a) * 11.0))
	fill(ci, om, Color("#ffd447"))
	ci.draw_arc(Vector2(0, 4), 8.5, PI * 1.15, PI * 1.85, 12, Color("#f0b52a"), 1.6)
	for h: Vector2 in [Vector2(-4, -1), Vector2(3, -3), Vector2(5, 1)]:
		ci.draw_circle(h, 1.3, Color("#58a83a"))
	ci.draw_circle(Vector2(-1, 1), 1.4, Color("#e8483a"))


func _icon_custard(ci: CanvasItem) -> void:
	fill(ci, ellipse(Vector2(0, 10), 15.0, 4.5), Color("#e6f1f8"))
	var body: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-11, 9), Vector2(-8, -6), Vector2(8, -6), Vector2(11, 9)]), 2.0)
	fill(ci, body, Color("#ffe08a"))
	var top: PackedVector2Array = ellipse(Vector2(0, -6), 8.0, 3.0)
	fill(ci, top, Color("#c9741e"))
	ci.draw_line(Vector2(-6, -4), Vector2(-8, 6), Color("#c9741e"), 2.2)
	ci.draw_line(Vector2(4, -4), Vector2(5, 3), Color("#c9741e"), 2.0)
	_shine(ci, Vector2(-5, 0), Vector2(-6, 6), 1.8)


func _icon_cake(ci: CanvasItem) -> void:
	var slice: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-14, 12), Vector2(-14, -2), Vector2(13, -9), Vector2(13, 6)]), 1.8)
	fill(ci, slice, Color("#ffe6b8"))
	ci.draw_line(Vector2(-14, 4), Vector2(13, -2), Color("#ff8fb6"), 3.0)
	var top: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-14, -2), Vector2(4, -14), Vector2(13, -9)]), 1.6)
	fill(ci, top, Color("#ffb3cf"))
	outline(ci, slice)
	circle(ci, Vector2(3, -14), 3.0, Color("#ff3d4e"), INK, 1.8)
	ci.draw_line(Vector2(3, -17), Vector2(5, -20), Color("#3f8f2c"), 1.6)


func _icon_eggnog(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(10, 2), 5.5, -PI * 0.5, PI * 0.5, 12, INK, 4.4)
	ci.draw_arc(Vector2(10, 2), 5.5, -PI * 0.45, PI * 0.45, 12, Color("#e8f0f6"), 2.0)
	var mug: PackedVector2Array = rrect(Rect2(-11, -6, 21, 20), 3.0)
	fill(ci, mug, Color("#e8483a"))
	ci.draw_line(Vector2(-9, 3), Vector2(8, 3), Color(1, 1, 1, 0.9), 2.4)
	for k: int in range(3):
		ci.draw_circle(Vector2(-5.0 + 5.0 * float(k), 3.0), 1.2, Color("#3f8f2c"))
	fill(ci, blob(Vector2(-0.5, -7), 10.0, 1.0, 0.18, 20), Color("#fff8e0"), INK, 2.0)
	ci.draw_circle(Vector2(1, -9), 1.2, Color("#a86a2a"))
	ci.draw_circle(Vector2(-4, -8), 1.0, Color("#a86a2a"))


func _icon_hatchery(ci: CanvasItem) -> void:
	_egg(ci, Vector2(0, 5), 11.0, 10.0)
	var chick: PackedVector2Array = ellipse(Vector2(0, -4), 9.0, 8.5)
	fill(ci, chick, Color("#ffe14a"))
	ci.draw_circle(Vector2(-3, -6), 1.5, INK)
	ci.draw_circle(Vector2(3, -6), 1.5, INK)
	fill(ci, PackedVector2Array([Vector2(-2, -3), Vector2(2, -3), Vector2(0, 0)]), Color("#ff9f1c"), INK, 1.4)
	var shell: PackedVector2Array = PackedVector2Array([Vector2(-11, 3), Vector2(-7, -1), Vector2(-3, 3), Vector2(1, -1), Vector2(5, 3), Vector2(9, -1), Vector2(11, 3),
		Vector2(11, 6), Vector2(0, 15), Vector2(-11, 6)])
	fill(ci, shell, EGG_COL)
	ci.draw_colored_polygon(ellipse(Vector2(-6, 7), 2.0, 2.8, 0.0, 10), Color(1, 1, 1, 0.8))


func _icon_fancyegg(ci: CanvasItem) -> void:
	fill(ci, rrect(Rect2(-9, 10, 18, 5), 1.5), GOLD)
	_egg(ci, Vector2(0, -2), 10.5, 13.0, Color("#6fb8ff"))
	ci.draw_line(Vector2(-10, -4), Vector2(10, -4), GOLD, 2.6)
	ci.draw_line(Vector2(-9, 3), Vector2(9, 3), GOLD, 2.6)
	for g: Vector3 in [Vector3(-5, 0, 0.0), Vector3(0, 0, 1.0), Vector3(5, 0, 2.0)]:
		ci.draw_circle(Vector2(g.x, g.y - 0.5), 1.8, [Color("#ff3d6e"), Color("#5fe08a"), Color("#ffffff")][int(g.z)])
	sparkle(ci, Vector2(10, -12), 4.0, WHITE)


# --- The monkey's businesses ---

func _icon_bunch(ci: CanvasItem) -> void:
	fill(ci, rrect(Rect2(-3, -15, 6, 7), 1.8), Color("#7a5a2a"))
	for k: int in range(4):
		var a: float = -0.75 + 0.5 * float(k)
		_banana(ci, Vector2(0, -8) + Vector2.from_angle(a + PI * 0.5) * 8.0, 10.0, a)


func _icon_smoothie(ci: CanvasItem) -> void:
	inked_stroke(ci, PackedVector2Array([Vector2(3, -8), Vector2(7, -16)]), Color("#ff6fae"), 2.4, 1.6)
	var cup: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-10, -8), Vector2(10, -8), Vector2(7, 14), Vector2(-7, 14)]), 2.0)
	fill(ci, cup, Color("#ffe58a"))
	ci.draw_line(Vector2(-9, -2), Vector2(9, -2), Color("#fff6c2"), 2.0)
	fill(ci, ellipse(Vector2(0, -8), 11.0, 3.2), Color("#fff1b0"))
	_banana(ci, Vector2(-8, -10), 6.0, -0.6)
	_shine(ci, Vector2(-5, 1), Vector2(-4, 10), 1.8)


func _icon_bread(ci: CanvasItem) -> void:
	var loaf: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-14, 10), Vector2(-14, -1), Vector2(-9, -9), Vector2(9, -9), Vector2(14, -1), Vector2(14, 10)]), 4.0)
	fill(ci, loaf, Color("#b8733a"))
	fill(ci, round_poly(PackedVector2Array([Vector2(-11, -2), Vector2(-7, -7), Vector2(7, -7), Vector2(11, -2), Vector2(11, 1), Vector2(-11, 1)]), 2.5), Color("#8f5426"), INK, 0.0)
	_banana(ci, Vector2(0, -6), 7.0, 0.0)
	for x: float in [-7.0, 0.0, 7.0]:
		ci.draw_line(Vector2(x - 1.5, 4), Vector2(x + 1.5, 8), Color("#8f5426"), 1.6)


func _icon_split(ci: CanvasItem) -> void:
	var boat: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-15, 2), Vector2(15, 2), Vector2(10, 12), Vector2(-10, 12)]), 3.0)
	_banana(ci, Vector2(-7, -2), 7.0, -1.3)
	_banana(ci, Vector2(7, -2), 7.0, 1.3)
	for sc: Vector3 in [Vector3(-6, -3, 0.0), Vector3(0, -6, 1.0), Vector3(6, -3, 2.0)]:
		circle(ci, Vector2(sc.x, sc.y), 5.0, [Color("#fff4dc"), Color("#ff9cc0"), Color("#8a5232")][int(sc.z)], INK, 1.8)
	circle(ci, Vector2(0, -12), 2.4, Color("#ff3d4e"), INK, 1.6)
	fill(ci, boat, Color("#e6f1f8"))


func _icon_chips(ci: CanvasItem) -> void:
	var bag: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-11, -13), Vector2(11, -13), Vector2(12, 13), Vector2(-12, 13)]), 2.5)
	fill(ci, bag, Color("#3fb0ec"))
	ci.draw_line(Vector2(-11, -9), Vector2(11, -9), Color("#2a86c0"), 2.0)
	for c: Vector2 in [Vector2(-4, 2), Vector2(4, 4), Vector2(0, -3)]:
		circle(ci, c, 4.5, Color("#ffe58a"), INK, 1.6)
		ci.draw_circle(c, 1.4, Color("#e0a91c"))


func _icon_pie(ci: CanvasItem) -> void:
	var tin: PackedVector2Array = round_poly(PackedVector2Array([Vector2(-15, 2), Vector2(15, 2), Vector2(11, 11), Vector2(-11, 11)]), 2.0)
	fill(ci, tin, Color("#d9a35e"))
	for x: float in [-8.0, -2.5, 3.0, 8.5]:
		ci.draw_line(Vector2(x, 3.5), Vector2(x - 0.8, 10), Color("#b07a3a"), 1.4)
	fill(ci, blob(Vector2(0, -2), 13.0, 0.5, 0.12, 24), Color("#fff8e6"), INK, 2.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-15, 2), Vector2(15, 2), Vector2(15, 4), Vector2(-15, 4)]), Color("#fff8e6"))
	outline(ci, tin)
	for b: Vector2 in [Vector2(-5, -6), Vector2(4, -7), Vector2(0, -2)]:
		circle(ci, b, 2.6, BANANA_COL, INK, 1.4)


func _icon_boat(ci: CanvasItem) -> void:
	inked_stroke(ci, PackedVector2Array([Vector2(0, 4), Vector2(0, -15)]), Color("#8a5a32"), 2.2, 1.6)
	fill(ci, PackedVector2Array([Vector2(1, -14), Vector2(12, 0), Vector2(1, 0)]), WHITE, INK, 2.0)
	_banana(ci, Vector2(0, 0), 15.0, 0.0, BANANA_COL)
	ci.draw_arc(Vector2(-8, 14), 3.0, PI, TAU, 8, Color("#3fb0ec"), 2.0)
	ci.draw_arc(Vector2(6, 14), 3.0, PI, TAU, 8, Color("#3fb0ec"), 2.0)


func _icon_planet(ci: CanvasItem) -> void:
	circle(ci, Vector2(0, 0), 11.0, BANANA_COL)
	ci.draw_arc(Vector2(-3, 2), 6.0, PI * 0.2, PI * 0.9, 10, BANANA_DARK, 2.0)
	ci.draw_circle(Vector2(4, -4), 2.0, BANANA_DARK)
	var ring: PackedVector2Array = ellipse(Vector2(0, 1), 16.0, 4.5, -0.25, 32)
	ci.draw_polyline(ring + PackedVector2Array([ring[0]]), INK, 4.2)
	ci.draw_polyline(ring + PackedVector2Array([ring[0]]), Color("#a07cff"), 2.0)
	ci.draw_arc(Vector2(0, 0), 11.0, PI * 1.05, PI * 1.95, 16, INK, LW)
	ci.draw_colored_polygon(ellipse(Vector2(-4, -5), 2.6, 1.6, -0.5, 10), Color(1, 1, 1, 0.8))
	sparkle(ci, Vector2(12, -11), 3.5, WHITE)


# --- Golden items, click icons, animal faces ---

func _icon_goldegg(ci: CanvasItem) -> void:
	_egg(ci, Vector2(0, 1), 10.0, 13.0, GOLD)
	ci.draw_arc(Vector2(0, 1), 7.0, PI * 0.15, PI * 0.6, 10, GOLD_DARK, 1.8)
	sparkle(ci, Vector2(10, -11), 4.0, WHITE)


func _icon_goldbanana(ci: CanvasItem) -> void:
	_banana(ci, Vector2(0, -2), 14.0, -0.35, GOLD)
	sparkle(ci, Vector2(11, -11), 4.0, WHITE)


func _icon_egg(ci: CanvasItem) -> void:
	_egg(ci, Vector2(0, 1), 10.0, 13.0)


func _icon_banana(ci: CanvasItem) -> void:
	_banana(ci, Vector2(0, -2), 14.0, -0.35)


func _icon_cowface(ci: CanvasItem) -> void:
	for side: float in [-1.0, 1.0]:
		fill(ci, ellipse(Vector2(13.0 * side, -6), 6.0, 3.6, side * 0.35), WHITE)
	fill(ci, ellipse(Vector2(0, -2), 12.0, 11.0), WHITE)
	ci.draw_colored_polygon(ellipse(Vector2(-7, -8), 3.6, 3.0, 0.4, 12), Color("#3b3440"))
	fill(ci, ellipse(Vector2(0, 6), 9.0, 5.5), Color("#ffb3c8"))
	for side2: float in [-1.0, 1.0]:
		ci.draw_circle(Vector2(4.5 * side2, -3), 1.9, INK)
		ci.draw_circle(Vector2(3.0 * side2, 6), 1.1, Color("#e77897"))


func _icon_henface(ci: CanvasItem) -> void:
	for cb: Vector3 in [Vector3(-5, -12, 3.5), Vector3(0, -14, 4.2), Vector3(5, -12, 3.5)]:
		circle(ci, Vector2(cb.x, cb.y), cb.z, Color("#ff5247"), INK, 1.8)
	fill(ci, ellipse(Vector2(0, -1), 11.5, 11.0), WHITE)
	for side: float in [-1.0, 1.0]:
		ci.draw_circle(Vector2(4.5 * side, -3), 1.9, INK)
	fill(ci, PackedVector2Array([Vector2(-3.5, 1), Vector2(3.5, 1), Vector2(0, 6)]), Color("#ffb52e"), INK, 1.6)
	circle(ci, Vector2(0, 8.5), 2.0, Color("#ff5247"), INK, 1.4)


func _icon_monkeyface(ci: CanvasItem) -> void:
	for side: float in [-1.0, 1.0]:
		circle(ci, Vector2(12.0 * side, -1), 4.8, Color("#a8693d"), INK, 1.8)
		ci.draw_circle(Vector2(12.0 * side, -1), 2.6, Color("#f2a99e"))
	fill(ci, ellipse(Vector2(0, -1), 11.0, 11.0), Color("#a8693d"))
	fill(ci, ellipse(Vector2(0, 3), 7.5, 6.0), Color("#f8d9ab"), INK, 1.6)
	for side2: float in [-1.0, 1.0]:
		ci.draw_circle(Vector2(4.0 * side2, -4), 1.9, INK)
	ci.draw_arc(Vector2(0, 3), 3.0, PI * 0.2, PI * 0.8, 8, INK, 1.4)


func _icon_lock(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(0, -4), 6.5, PI, TAU, 14, INK, 5.4)
	ci.draw_arc(Vector2(0, -4), 6.5, PI * 1.03, PI * 1.97, 14, Color("#c7cfd8"), 2.4)
	fill(ci, rrect(Rect2(-9, -4, 18, 15), 3.0), GOLD)
	ci.draw_circle(Vector2(0, 2.5), 2.4, INK)
	ci.draw_line(Vector2(0, 3), Vector2(0, 7), INK, 2.0)


func sparkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(round_poly(star(c, r, r * 0.32, 4, 0.0), r * 0.15, 2), col)
