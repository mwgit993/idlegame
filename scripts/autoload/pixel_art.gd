extends Node

# Every sprite in the game, painted in code at startup (no image files besides the font).
# Look one up with Art.tex("name"). Names: cow_idle, cow_blink, cow_squeeze, farm_bg,
# icon_<business id>, coin, bell, farmhand, lock.

const OUTLINE: Color = Color("#1b1a26")
const WHITE: Color = Color("#f6f3ea")
const SHADE: Color = Color("#d9d3c6")
const SPOT: Color = Color("#24222e")
const PINK: Color = Color("#f4a6b8")
const PINK_DARK: Color = Color("#d9768f")

const BAYER4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _cache: Dictionary = {}


func _ready() -> void:
	_build_all()


func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	push_warning("Art.tex: unknown texture '%s'" % key)
	return _cache.get("coin", null)


func _build_all() -> void:
	_cache["cow_idle"] = _tex(_paint_cow(false, false))
	_cache["cow_blink"] = _tex(_paint_cow(true, false))
	_cache["cow_squeeze"] = _tex(_paint_cow(false, true))
	_cache["farm_bg"] = _tex(_paint_farm(230, 330))
	_cache["icon_pail"] = _tex(_icon_pail())
	_cache["icon_churn"] = _tex(_icon_churn())
	_cache["icon_cheese"] = _tex(_icon_cheese())
	_cache["icon_icecream"] = _tex(_icon_icecream())
	_cache["icon_yogurt"] = _tex(_icon_yogurt())
	_cache["icon_diner"] = _tex(_icon_shake())
	_cache["icon_cosmic"] = _tex(_icon_rocket())
	_cache["icon_moon"] = _tex(_icon_moon())
	_cache["coin"] = _tex(_icon_coin())
	_cache["bell"] = _tex(_icon_bell())
	_cache["farmhand"] = _tex(_icon_farmhand())
	_cache["lock"] = _tex(_icon_lock())


# =========================================================================================
# HELPERS
# =========================================================================================
func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _img(w: int, h: int) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_px(img, xx, yy, c)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y: int in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x: int in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


# Paints c only where the image is already opaque (for spots and shading inside a shape).
func _ellipse_on(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y: int in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x: int in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				if img.get_pixel(x, y).a > 0.5:
					img.set_pixel(x, y, c)


func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var steps: int = maxi(absi(x1 - x0), absi(y1 - y0))
	for s: int in range(steps + 1):
		var t: float = 0.0 if steps == 0 else float(s) / float(steps)
		_px(img, int(round(lerpf(float(x0), float(x1), t))), int(round(lerpf(float(y0), float(y1), t))), c)


# Adds a 1 px dark outline around everything opaque.
func _outline(img: Image, c: Color = OUTLINE) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			if src.get_pixel(x, y).a > 0.5:
				continue
			var near: bool = false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					near = true
					break
			if near:
				img.set_pixel(x, y, c)


func _dither(x: int, y: int, t: float) -> bool:
	return t * 16.0 > float(BAYER4[(y % 4) * 4 + (x % 4)])


# =========================================================================================
# THE COW (side view, facing right). 170 x 120 px.
# =========================================================================================
func _paint_cow(blink: bool, squeeze: bool) -> Image:
	var img: Image = _img(170, 124)
	var spot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	spot_rng.seed = 4242

	# Far legs (shaded) behind the body.
	_leg(img, 42, 78, SHADE)
	_leg(img, 112, 78, SHADE)
	# Tail.
	for i: int in range(26):
		_px(img, 18 - i / 6, 44 + i, OUTLINE)
		_px(img, 19 - i / 6, 44 + i, OUTLINE)
	_ellipse(img, 14.0, 72.0, 4.0, 6.0, SPOT)

	# Body, neck and head.
	_ellipse(img, 76.0, 58.0, 56.0, 30.0, WHITE)
	_ellipse(img, 124.0, 50.0, 16.0, 20.0, WHITE)
	_ellipse(img, 140.0, 40.0, 19.0, 16.0, WHITE)
	# Belly shade.
	for x: int in range(24, 130):
		for y: int in range(74, 90):
			if img.get_pixel(x, y).a > 0.5 and _dither(x, y, float(y - 74) / 18.0):
				img.set_pixel(x, y, SHADE)
	# Spots (only on the body).
	var spots: Array[Vector4] = [
		Vector4(44, 46, 15, 11), Vector4(78, 40, 12, 9), Vector4(100, 64, 14, 10),
		Vector4(60, 70, 10, 7), Vector4(30, 64, 8, 9), Vector4(118, 44, 6, 8),
	]
	for sp: Vector4 in spots:
		_ellipse_on(img, sp.x, sp.y, sp.z, sp.w, SPOT)
		_ellipse_on(img, sp.x + sp.z * 0.5, sp.y - sp.w * 0.7, sp.z * 0.45, sp.w * 0.5, SPOT)
	# Head patch over the eye.
	_ellipse_on(img, 138.0, 32.0, 9.0, 8.0, SPOT)

	# Near legs.
	_leg(img, 30, 80, WHITE)
	_leg(img, 98, 80, WHITE)

	# Udder and teats.
	var uy: float = 89.0 if not squeeze else 90.0
	var ury: float = 9.0 if not squeeze else 7.0
	_ellipse(img, 62.0, uy, 15.0, ury, PINK)
	_ellipse_on(img, 58.0, uy - 3.0, 8.0, 3.0, Color("#f9c7d2"))
	var teat_len: int = 7 if not squeeze else 10
	for tx: int in [52, 59, 66, 73]:
		_rect(img, tx, int(uy) + 5, 4, teat_len, PINK if tx % 2 == 0 else PINK_DARK)
		_rect(img, tx + 1, int(uy) + 5 + teat_len - 1, 2, 1, PINK_DARK)

	# Muzzle, nose, eye, ear, horns.
	_ellipse(img, 154.0, 47.0, 11.0, 9.0, PINK)
	_rect(img, 151, 45, 2, 3, PINK_DARK)
	_rect(img, 158, 45, 2, 3, PINK_DARK)
	_line(img, 150, 52, 158, 52, PINK_DARK)
	_ellipse(img, 126.0, 30.0, 7.0, 4.0, SPOT)
	_ellipse(img, 126.0, 30.0, 4.0, 2.0, PINK)
	_rect(img, 134, 18, 3, 7, Color("#efe3b8"))
	_rect(img, 146, 18, 3, 7, Color("#efe3b8"))
	_px(img, 134, 17, Color("#efe3b8"))
	_px(img, 148, 17, Color("#efe3b8"))

	_outline(img)

	if blink:
		_line(img, 138, 37, 144, 37, OUTLINE)
	else:
		_rect(img, 139, 33, 5, 6, OUTLINE)
		_rect(img, 140, 34, 2, 2, Color.WHITE)
	# Rosy cheek.
	_ellipse(img, 146.0, 44.0, 2.5, 1.5, Color("#f7b9c4"))
	return img


func _leg(img: Image, x: int, y: int, col: Color) -> void:
	_rect(img, x, y, 11, 30, col)
	_rect(img, x, y + 26, 11, 6, Color("#4a4048"))
	_rect(img, x + 5, y + 28, 1, 4, OUTLINE)


# =========================================================================================
# FARM BACKGROUND for the cow panel.
# =========================================================================================
func _paint_farm(w: int, h: int) -> Image:
	var img: Image = _img(w, h)
	var sky_top: Color = Color("#5fb3ea")
	var sky_bot: Color = Color("#c9ecfb")
	var horizon: int = int(float(h) * 0.42)
	for y: int in range(horizon + 20):
		var t: float = float(y) / float(horizon + 20)
		for x: int in range(w):
			var c: Color = sky_top.lerp(sky_bot, t)
			if _dither(x, y, fmod(t * 6.0, 1.0)):
				c = sky_top.lerp(sky_bot, minf(1.0, t + 1.0 / 6.0))
			img.set_pixel(x, y, c)
	# Sun.
	_ellipse(img, 190.0, 34.0, 15.0, 15.0, Color("#fff3a6"))
	_ellipse(img, 190.0, 34.0, 11.0, 11.0, Color("#ffe066"))
	# Clouds.
	for cl: Vector3 in [Vector3(40, 30, 1.0), Vector3(130, 54, 0.8), Vector3(70, 86, 0.6)]:
		var s: float = cl.z
		_ellipse(img, cl.x, cl.y, 18.0 * s, 8.0 * s, Color.WHITE)
		_ellipse(img, cl.x + 12.0 * s, cl.y - 5.0 * s, 12.0 * s, 8.0 * s, Color.WHITE)
		_ellipse(img, cl.x - 12.0 * s, cl.y + 1.0, 10.0 * s, 6.0 * s, Color("#eef8ff"))
	# Far hills.
	for x: int in range(w):
		var hy: int = horizon - int(10.0 + 8.0 * sin(float(x) * 0.035) + 5.0 * sin(float(x) * 0.09 + 1.0))
		for y: int in range(hy, horizon + 30):
			img.set_pixel(x, y, Color("#8fd07c") if y < hy + 2 else Color("#76bd67"))
	# Barn.
	var bx: int = 14
	var by: int = horizon - 34
	_rect(img, bx, by + 14, 56, 46, Color("#c23b32"))
	for i: int in range(30):
		_rect(img, bx - 2 + i, by + 14 - i / 2, 60 - i * 2, 1, Color("#9e2c25"))
	_rect(img, bx + 18, by + 30, 20, 30, Color("#7a1f1a"))
	_line(img, bx + 18, by + 30, bx + 37, by + 59, Color("#f6efe0"))
	_line(img, bx + 37, by + 30, bx + 18, by + 59, Color("#f6efe0"))
	_rect(img, bx + 18, by + 30, 20, 1, Color("#f6efe0"))
	_rect(img, bx + 23, by + 18, 10, 8, Color("#f6efe0"))
	_rect(img, bx + 24, by + 19, 8, 6, Color("#3d2a24"))
	# Silo.
	_rect(img, bx + 58, by + 2, 16, 58, Color("#b9c3cc"))
	_ellipse(img, float(bx + 66), float(by + 2), 8.0, 6.0, Color("#8a96a1"))
	for yy: int in range(by + 8, by + 60, 8):
		_rect(img, bx + 58, yy, 16, 1, Color("#97a3ad"))
	# Grass field.
	var field_top: int = horizon + 18
	for y: int in range(field_top, h):
		var t2: float = float(y - field_top) / float(h - field_top)
		for x: int in range(w):
			var c2: Color = Color("#5cb85c").lerp(Color("#3f9a45"), t2)
			if _dither(x, y, fmod(t2 * 5.0, 1.0)):
				c2 = Color("#5cb85c").lerp(Color("#3f9a45"), minf(1.0, t2 + 0.2))
			img.set_pixel(x, y, c2)
	# Fence.
	var fy: int = field_top + 4
	for x: int in range(0, w, 22):
		_rect(img, x + 4, fy - 14, 4, 18, Color("#8a5a35"))
		_rect(img, x + 4, fy - 14, 4, 1, Color("#a97446"))
	_rect(img, 0, fy - 10, w, 3, Color("#a97446"))
	_rect(img, 0, fy - 3, w, 3, Color("#a97446"))
	# Grass tufts and flowers.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in range(90):
		var gx: int = rng.randi_range(0, w - 1)
		var gy: int = rng.randi_range(field_top + 8, h - 2)
		_px(img, gx, gy, Color("#2f7d36"))
		_px(img, gx + 1, gy - 1, Color("#2f7d36"))
		_px(img, gx + 2, gy, Color("#2f7d36"))
	for i: int in range(26):
		var fx: int = rng.randi_range(0, w - 1)
		var fy2: int = rng.randi_range(field_top + 10, h - 2)
		var fc: Color = [Color("#ffffff"), Color("#ffe066"), Color("#ff9ec2")][i % 3]
		_px(img, fx, fy2, fc)
		_px(img, fx + 1, fy2, fc)
		_px(img, fx, fy2 + 1, Color("#2f7d36"))
	return img


# =========================================================================================
# ICONS (28 x 28)
# =========================================================================================
func _icon_pail() -> Image:
	var img: Image = _img(28, 28)
	for y: int in range(9, 25):
		var inset: int = (y - 9) / 4
		_rect(img, 5 + inset, y, 18 - inset * 2, 1, Color("#aeb8c2") if y % 5 != 0 else Color("#8d99a6"))
	_ellipse(img, 14.0, 9.5, 9.0, 2.5, Color("#ffffff"))
	for i: int in range(19):
		var a: float = PI + PI * float(i) / 18.0
		_px(img, 14 + int(round(cos(a) * 10.0)), 9 + int(round(sin(a) * 7.0)), Color("#6b7580"))
	_outline(img)
	return img


func _icon_churn() -> Image:
	var img: Image = _img(28, 28)
	_rect(img, 12, 1, 3, 10, Color("#c9a26b"))
	_ellipse(img, 13.5, 2.0, 3.0, 2.0, Color("#c9a26b"))
	for y: int in range(8, 26):
		var bulge: int = 1 if y > 11 and y < 22 else 0
		_rect(img, 7 - bulge, y, 14 + bulge * 2, 1, Color("#a8703c"))
	_rect(img, 6, 12, 16, 2, Color("#5e3b1c"))
	_rect(img, 6, 20, 16, 2, Color("#5e3b1c"))
	_ellipse(img, 14.0, 8.0, 7.0, 2.0, Color("#ffe8a3"))
	_outline(img)
	return img


func _icon_cheese() -> Image:
	var img: Image = _img(28, 28)
	for y: int in range(8, 24):
		var w: int = 4 + (y - 8) * 3 / 2
		_rect(img, 3, y, mini(22, w), 1, Color("#ffd23f"))
	_rect(img, 3, 22, 22, 3, Color("#f0b429"))
	for h: Vector3 in [Vector3(8, 17, 2.0), Vector3(15, 20, 2.0), Vector3(19, 22, 1.5), Vector3(6, 22, 1.2)]:
		_ellipse(img, h.x, h.y, h.z, h.z, Color("#d99a1e"))
	_outline(img)
	return img


func _icon_icecream() -> Image:
	var img: Image = _img(28, 28)
	for y: int in range(14, 27):
		var hw: int = (27 - y) / 2
		_rect(img, 14 - hw, y, hw * 2, 1, Color("#e3a857") if (y % 3) != 0 else Color("#c98a3d"))
	_ellipse(img, 14.0, 13.0, 7.0, 4.0, Color("#fff3e0"))
	_ellipse(img, 14.0, 8.0, 6.0, 5.0, Color("#ff9ec2"))
	_px(img, 12, 6, Color("#ffffff"))
	_px(img, 16, 9, Color("#6ad1ff"))
	_px(img, 11, 10, Color("#ffe066"))
	_ellipse(img, 14.0, 2.5, 2.0, 2.0, Color("#e23b4b"))
	_outline(img)
	return img


func _icon_yogurt() -> Image:
	var img: Image = _img(28, 28)
	for y: int in range(9, 26):
		var inset: int = (y - 9) / 6
		_rect(img, 6 + inset, y, 16 - inset * 2, 1, Color("#f6f3ea"))
	_rect(img, 7, 14, 14, 6, Color("#ff9ec2"))
	_rect(img, 9, 16, 10, 2, Color("#ffffff"))
	_ellipse(img, 14.0, 9.0, 8.0, 2.0, Color("#e0d8c8"))
	_line(img, 18, 2, 21, 10, Color("#aeb8c2"))
	_ellipse(img, 17.5, 2.0, 1.5, 2.0, Color("#aeb8c2"))
	_outline(img)
	return img


func _icon_shake() -> Image:
	var img: Image = _img(28, 28)
	_line(img, 17, 1, 15, 10, Color("#e23b4b"))
	_line(img, 18, 1, 16, 10, Color("#ffffff"))
	for y: int in range(11, 26):
		var inset: int = (y - 11) / 5
		_rect(img, 8 + inset, y, 12 - inset * 2, 1, Color("#ff9ec2"))
	_rect(img, 10, 25, 8, 2, Color("#dce6ff"))
	_ellipse(img, 14.0, 10.0, 7.0, 4.0, Color("#ffffff"))
	_ellipse(img, 14.0, 5.0, 2.0, 2.0, Color("#e23b4b"))
	_outline(img)
	return img


func _icon_rocket() -> Image:
	var img: Image = _img(28, 28)
	_ellipse(img, 14.0, 13.0, 5.0, 10.0, Color("#f6f3ea"))
	for i: int in range(4):
		_rect(img, 14 - i, 2 + i, i * 2 + 1, 1, Color("#e23b4b"))
	_ellipse(img, 14.0, 11.0, 2.5, 2.5, Color("#6ad1ff"))
	_rect(img, 7, 18, 3, 6, Color("#e23b4b"))
	_rect(img, 18, 18, 3, 6, Color("#e23b4b"))
	_ellipse_on(img, 12.0, 17.0, 2.0, 1.5, SPOT)
	_ellipse(img, 14.0, 25.0, 3.0, 2.0, Color("#ffb13b"))
	_px(img, 14, 27, Color("#ffe066"))
	_outline(img)
	return img


func _icon_moon() -> Image:
	var img: Image = _img(28, 28)
	_ellipse(img, 14.0, 14.0, 11.0, 11.0, Color("#d6d8e0"))
	_ellipse_on(img, 10.0, 10.0, 3.0, 3.0, Color("#b4b8c6"))
	_ellipse_on(img, 18.0, 17.0, 4.0, 3.0, Color("#b4b8c6"))
	_ellipse_on(img, 9.0, 19.0, 2.0, 2.0, Color("#b4b8c6"))
	# A tiny cow standing on top.
	_rect(img, 15, 3, 7, 3, Color("#ffffff"))
	_px(img, 22, 3, Color("#ffffff"))
	_px(img, 17, 4, SPOT)
	_px(img, 15, 6, SPOT)
	_px(img, 20, 6, SPOT)
	_outline(img)
	return img


func _icon_coin() -> Image:
	var img: Image = _img(12, 12)
	_ellipse(img, 6.0, 6.0, 5.0, 5.0, Color("#ffd23f"))
	_ellipse(img, 6.0, 6.0, 3.5, 3.5, Color("#f0b429"))
	_rect(img, 5, 3, 2, 6, Color("#ffe98a"))
	_outline(img)
	return img


func _icon_bell() -> Image:
	var img: Image = _img(14, 14)
	for y: int in range(2, 11):
		var hw: int = 2 + (y - 2) / 2
		_rect(img, 7 - hw, y, hw * 2, 1, Color("#ffd23f"))
	_rect(img, 1, 10, 12, 2, Color("#f0b429"))
	_ellipse(img, 7.0, 12.5, 1.5, 1.5, Color("#b07d12"))
	_rect(img, 6, 0, 2, 2, Color("#b07d12"))
	_px(img, 5, 4, Color("#fff3b0"))
	_outline(img)
	return img


func _icon_farmhand() -> Image:
	var img: Image = _img(16, 16)
	_ellipse(img, 8.0, 10.0, 4.5, 4.5, Color("#f1c27d"))
	_rect(img, 1, 6, 14, 2, Color("#e8c55a"))
	_rect(img, 4, 2, 8, 5, Color("#e8c55a"))
	_rect(img, 4, 5, 8, 1, Color("#c0392b"))
	_px(img, 6, 10, OUTLINE)
	_px(img, 10, 10, OUTLINE)
	_line(img, 6, 12, 10, 12, Color("#a0522d"))
	_outline(img)
	return img


func _icon_lock() -> Image:
	var img: Image = _img(12, 12)
	_rect(img, 2, 5, 8, 6, Color("#aeb8c2"))
	for i: int in range(5):
		_px(img, 3, 1 + i, Color("#6b7580"))
		_px(img, 8, 1 + i, Color("#6b7580"))
	_rect(img, 4, 0, 4, 1, Color("#6b7580"))
	_rect(img, 5, 7, 2, 2, OUTLINE)
	_outline(img)
	return img
