extends Node2D

# Udderly Idle: the whole screen is built here in code (640x360, integer-scaled).
# Left: the farm and the cow (click to squeeze the udder). Right: four tabs:
#   DAIRY      your businesses: click an icon to sell, buy more, watch the bars fill
#   UPGRADES   one-time profit multipliers
#   FARMHANDS  hire one per business so it runs by itself (and while the game is closed)
#   PASTURE    golden cowbells (prestige), stats and settings
# All state lives in the Farm autoload; this script draws it and forwards input.

const Data = preload("res://scripts/game_data.gd")
const Fmt = preload("res://scripts/num_fmt.gd")

const W: float = 640.0
const H: float = 360.0
const LEFT_W: float = 230.0
const TOP_H: float = 34.0
const RX: float = 234.0  # right panel content x
const ROW_Y: float = 52.0
const ROW_H: float = 38.0
const FONT_SZ: int = 10

const COL_PANEL: Color = Color("#3b2618")
const COL_PANEL_DARK: Color = Color("#24170e")
const COL_BORDER: Color = Color("#f2d49b")
const COL_TEXT: Color = Color("#fff6e0")
const COL_DIM: Color = Color("#b49a78")
const COL_GOLD: Color = Color("#ffd23f")
const COL_GREEN: Color = Color("#5cb85c")
const COL_PINK: Color = Color("#ff9ec2")

enum Tab { DAIRY, UPGRADES, FARMHANDS, PASTURE }
const BUY_MODES: Array[String] = ["x1", "x10", "x100", "NEXT", "MAX"]

var ui: CanvasLayer
var tab: Tab = Tab.DAIRY
var buy_mode: int = 0

# Left panel
var cow_rect: TextureRect
var cow_btn: Button
var fx: Control
var click_lbl: Label
var rush_bar: Control
# Top bar
var money_lbl: Label
var rate_lbl: Label
var tab_btns: Array[Button] = []
var toast_lbl: Label
var toast_box: Panel
var hint_lbl: Label
var _toast_t: float = 0.0
# Tab pages
var pages: Array[Control] = []
var buy_mode_btns: Array[Button] = []
var biz_icon_btns: Array[Button] = []
var biz_name_lbls: Array[Label] = []
var biz_sub_lbls: Array[Label] = []
var biz_buy_btns: Array[Button] = []
var biz_bars: Array[Control] = []
var upg_rows: Array[Control] = []
var upg_name_lbls: Array[Label] = []
var upg_desc_lbls: Array[Label] = []
var upg_btns: Array[Button] = []
var upg_ids: Array[String] = []
var upg_header: Label
var hand_btns: Array[Button] = []
var hand_lbls: Array[Label] = []
var hand_sub_lbls: Array[Label] = []
var pasture_lbl: Label
var move_btn: Button
var sfx_btn: Button
var offline_panel: Panel
var offline_lbl: Label

# Cow animation and effects
var _blink_t: float = 2.5
var _squeeze_t: float = 0.0
var _clicks_since_moo: int = 0
var _drops: Array[Dictionary] = []   # milk drops: pos, vel, life
var _floaters: Array[Dictionary] = [] # "+$12" texts: pos, text, life, color


func _ready() -> void:
	_build_ui()
	Farm.milestone_reached.connect(_on_milestone)
	Farm.rush_started.connect(_on_rush_started)
	Farm.rush_ended.connect(func() -> void: _toast("MOO RUSH OVER", COL_DIM))
	_set_tab(Tab.DAIRY)
	_refresh_all()
	hint_lbl.visible = Farm.total_clicks < 20
	if "--smoke-test" in OS.get_cmdline_user_args():
		_run_smoke_test()
		return
	if Farm.last_offline_earned > 0.0:
		offline_lbl.text = "WELCOME BACK!\n\nYOUR FARMHANDS EARNED\n%s\nWHILE YOU WERE AWAY (%s)." % [
			Fmt.money(Farm.last_offline_earned), Fmt.duration(float(Farm.last_offline_seconds))]
		offline_panel.visible = true


# =========================================================================================
# UI CONSTRUCTION
# =========================================================================================
func _box(bg: Color, border: Color, bw: int = 1, margin: float = 2.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(margin)
	return sb


func _style_btn(b: Button, accent: Color = COL_GOLD) -> void:
	b.add_theme_font_size_override("font_size", FONT_SZ)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#7d6650"))
	b.add_theme_stylebox_override("normal", _box(Color("#5a3a22"), Color("#c9a26b")))
	b.add_theme_stylebox_override("hover", _box(Color("#74502f"), accent, 2))
	b.add_theme_stylebox_override("pressed", _box(Color("#8a6038"), Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", _box(Color("#2e1f13"), Color("#5e4630")))
	b.add_theme_stylebox_override("focus", _box(Color("#74502f"), accent, 2))
	b.focus_mode = Control.FOCUS_NONE


func _label(parent: Node, pos: Vector2, size: Vector2, text: String = "", col: Color = COL_TEXT, fsize: int = FONT_SZ) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, pos: Vector2, size: Vector2, text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.position = pos
	b.size = size
	b.text = text
	_style_btn(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var bg: ColorRect = ColorRect.new()
	bg.size = Vector2(W, H)
	bg.color = COL_PANEL_DARK
	ui.add_child(bg)

	_build_cow_panel()
	_build_top_bar()

	var right: Panel = Panel.new()
	right.position = Vector2(LEFT_W, TOP_H)
	right.size = Vector2(W - LEFT_W, H - TOP_H)
	right.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_BORDER, 2))
	ui.add_child(right)

	for t: int in range(4):
		var page: Control = Control.new()
		page.size = Vector2(W, H)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(page)
		pages.append(page)
	_build_dairy_page(pages[Tab.DAIRY])
	_build_upgrades_page(pages[Tab.UPGRADES])
	_build_farmhands_page(pages[Tab.FARMHANDS])
	_build_pasture_page(pages[Tab.PASTURE])

	toast_box = Panel.new()
	toast_box.position = Vector2(6.0, TOP_H + 6.0)
	toast_box.size = Vector2(LEFT_W - 12.0, 30.0)
	toast_box.add_theme_stylebox_override("panel", _box(Color(0.14, 0.09, 0.05, 0.88), COL_GOLD))
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.visible = false
	ui.add_child(toast_box)
	toast_lbl = _label(toast_box, Vector2(4.0, 2.0), Vector2(LEFT_W - 20.0, 26.0), "", COL_GOLD)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_offline_popup()


func _build_cow_panel() -> void:
	var farm: TextureRect = TextureRect.new()
	farm.texture = Art.tex("farm_bg")
	farm.position = Vector2(0.0, TOP_H - 4.0)
	ui.add_child(farm)

	cow_rect = TextureRect.new()
	cow_rect.texture = Art.tex("cow_idle")
	cow_rect.position = Vector2(26.0, 158.0)
	ui.add_child(cow_rect)

	cow_btn = Button.new()
	cow_btn.position = Vector2(30.0, 170.0)
	cow_btn.size = Vector2(170.0, 112.0)
	cow_btn.flat = true
	cow_btn.focus_mode = Control.FOCUS_NONE
	cow_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus"]:
		cow_btn.add_theme_stylebox_override(st, empty)
	cow_btn.button_down.connect(_on_squeeze)
	ui.add_child(cow_btn)

	hint_lbl = _label(ui, Vector2(0.0, 112.0), Vector2(LEFT_W, 12.0), "CLICK THE COW TO MILK HER!", Color.WHITE)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.15, 0.3, 0.9))

	fx = Control.new()
	fx.size = Vector2(W, H)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	ui.add_child(fx)

	var meter_box: Panel = Panel.new()
	meter_box.position = Vector2(4.0, H - 40.0)
	meter_box.size = Vector2(LEFT_W - 8.0, 36.0)
	meter_box.add_theme_stylebox_override("panel", _box(Color(0.14, 0.09, 0.05, 0.85), COL_BORDER))
	ui.add_child(meter_box)
	click_lbl = _label(ui, Vector2(10.0, H - 38.0), Vector2(LEFT_W - 20.0, 12.0), "", COL_TEXT)
	rush_bar = Control.new()
	rush_bar.position = Vector2(10.0, H - 23.0)
	rush_bar.size = Vector2(LEFT_W - 20.0, 14.0)
	rush_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rush_bar.draw.connect(_draw_rush_bar)
	ui.add_child(rush_bar)


func _build_top_bar() -> void:
	var top: Panel = Panel.new()
	top.size = Vector2(W, TOP_H)
	top.add_theme_stylebox_override("panel", _box(COL_PANEL_DARK, COL_BORDER, 2))
	ui.add_child(top)
	var coin: TextureRect = TextureRect.new()
	coin.texture = Art.tex("coin")
	coin.position = Vector2(6.0, 5.0)
	ui.add_child(coin)
	money_lbl = _label(ui, Vector2(21.0, 3.0), Vector2(210.0, 20.0), "", COL_GOLD, 20)
	money_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_lbl = _label(ui, Vector2(8.0, 22.0), Vector2(222.0, 12.0), "", COL_TEXT)
	var names: Array[String] = ["DAIRY", "UPGRADES", "FARMHANDS", "PASTURE"]
	for t: int in range(4):
		var b: Button = _button(ui, Vector2(RX + 2.0 + float(t) * 101.0, 6.0), Vector2(97.0, 22.0), names[t], _set_tab.bind(t))
		tab_btns.append(b)


func _build_dairy_page(page: Control) -> void:
	_label(page, Vector2(RX + 4.0, TOP_H + 4.0), Vector2(60.0, 12.0), "BUY:", COL_DIM)
	for m: int in range(BUY_MODES.size()):
		var b: Button = _button(page, Vector2(RX + 36.0 + float(m) * 46.0, TOP_H + 2.0), Vector2(42.0, 15.0), BUY_MODES[m], _set_buy_mode.bind(m))
		buy_mode_btns.append(b)
	for i: int in range(Farm.biz_count()):
		var ry: float = ROW_Y + float(i) * ROW_H
		var icon_b: Button = Button.new()
		icon_b.position = Vector2(RX + 2.0, ry + 2.0)
		icon_b.size = Vector2(34.0, 34.0)
		icon_b.icon = Art.tex("icon_" + String(Farm.biz(i)["id"]))
		icon_b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_b.expand_icon = false
		_style_btn(icon_b)
		icon_b.pressed.connect(_on_biz_clicked.bind(i))
		page.add_child(icon_b)
		biz_icon_btns.append(icon_b)

		biz_name_lbls.append(_label(page, Vector2(RX + 40.0, ry + 1.0), Vector2(250.0, 12.0)))
		var bar: Control = Control.new()
		bar.position = Vector2(RX + 40.0, ry + 13.0)
		bar.size = Vector2(246.0, 13.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_biz_bar.bind(bar, i))
		page.add_child(bar)
		biz_bars.append(bar)
		biz_sub_lbls.append(_label(page, Vector2(RX + 40.0, ry + 26.0), Vector2(250.0, 12.0), "", COL_DIM))

		var buy_b: Button = _button(page, Vector2(RX + 290.0, ry + 2.0), Vector2(112.0, 34.0), "", _on_buy_biz.bind(i))
		biz_buy_btns.append(buy_b)


func _build_upgrades_page(page: Control) -> void:
	upg_header = _label(page, Vector2(RX + 6.0, TOP_H + 4.0), Vector2(380.0, 12.0), "", COL_DIM)
	for r: int in range(7):
		var ry: float = ROW_Y + float(r) * 43.0
		var row: Control = Control.new()
		row.position = Vector2(0, 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(row)
		upg_rows.append(row)
		var frame: Panel = Panel.new()
		frame.position = Vector2(RX + 2.0, ry)
		frame.size = Vector2(400.0, 40.0)
		frame.add_theme_stylebox_override("panel", _box(COL_PANEL_DARK, Color("#6e5236")))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)
		upg_name_lbls.append(_label(row, Vector2(RX + 8.0, ry + 4.0), Vector2(270.0, 12.0), "", COL_GOLD))
		upg_desc_lbls.append(_label(row, Vector2(RX + 8.0, ry + 20.0), Vector2(270.0, 12.0), "", COL_TEXT))
		upg_btns.append(_button(row, Vector2(RX + 290.0, ry + 4.0), Vector2(108.0, 32.0), "", _on_buy_upgrade.bind(r)))
		upg_ids.append("")


func _build_farmhands_page(page: Control) -> void:
	_label(page, Vector2(RX + 6.0, TOP_H + 4.0), Vector2(380.0, 12.0), "A FARMHAND RUNS ONE BUSINESS FOR YOU, EVEN WHILE YOU'RE AWAY.", COL_DIM)
	for i: int in range(Farm.biz_count()):
		var ry: float = ROW_Y + float(i) * ROW_H
		var face: TextureRect = TextureRect.new()
		face.texture = Art.tex("farmhand")
		face.position = Vector2(RX + 6.0, ry + 4.0)
		page.add_child(face)
		var icon: TextureRect = TextureRect.new()
		icon.texture = Art.tex("icon_" + String(Farm.biz(i)["id"]))
		icon.position = Vector2(RX + 22.0, ry + 6.0)
		icon.scale = Vector2(0.5, 0.5)
		page.add_child(icon)
		hand_lbls.append(_label(page, Vector2(RX + 42.0, ry + 4.0), Vector2(240.0, 12.0), String(Farm.biz(i)["farmhand"]), COL_TEXT))
		hand_sub_lbls.append(_label(page, Vector2(RX + 42.0, ry + 18.0), Vector2(240.0, 12.0), "", COL_DIM))
		hand_btns.append(_button(page, Vector2(RX + 290.0, ry + 2.0), Vector2(112.0, 34.0), "", _on_hire.bind(i)))


func _build_pasture_page(page: Control) -> void:
	var bell: TextureRect = TextureRect.new()
	bell.texture = Art.tex("bell")
	bell.position = Vector2(RX + 6.0, TOP_H + 8.0)
	page.add_child(bell)
	_label(page, Vector2(RX + 24.0, TOP_H + 8.0), Vector2(360.0, 12.0), "GOLDEN COWBELLS", COL_GOLD)
	pasture_lbl = _label(page, Vector2(RX + 8.0, TOP_H + 26.0), Vector2(392.0, 200.0), "", COL_TEXT)
	pasture_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move_btn = _button(page, Vector2(RX + 60.0, 236.0), Vector2(290.0, 30.0), "", _on_move_pasture)
	sfx_btn = _button(page, Vector2(RX + 8.0, 318.0), Vector2(140.0, 22.0), "", _on_sfx_toggle)
	_button(page, Vector2(RX + 262.0, 318.0), Vector2(140.0, 22.0), "SAVE NOW", func() -> void:
		Farm.save_game()
		Sfx.play("ui")
		_toast("GAME SAVED", COL_GREEN)
	)


func _build_offline_popup() -> void:
	offline_panel = Panel.new()
	offline_panel.position = Vector2(170.0, 90.0)
	offline_panel.size = Vector2(300.0, 160.0)
	offline_panel.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_GOLD, 2, 6.0))
	offline_panel.visible = false
	ui.add_child(offline_panel)
	offline_lbl = _label(offline_panel, Vector2(10.0, 12.0), Vector2(280.0, 100.0), "", COL_TEXT)
	offline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(offline_panel, Vector2(100.0, 120.0), Vector2(100.0, 26.0), "COLLECT", func() -> void:
		offline_panel.visible = false
		Sfx.play("coin")
	)


# =========================================================================================
# INPUT
# =========================================================================================
func _on_squeeze() -> void:
	var v: float = Farm.squeeze()
	_squeeze_t = 0.12
	Sfx.play("squirt", -8.0, 0.12)
	_clicks_since_moo += 1
	if _clicks_since_moo >= 25 and randf() < 0.15:
		_clicks_since_moo = 0
		Sfx.play("moo", -4.0, 0.08)
	var udder: Vector2 = cow_rect.position + Vector2(64.0, 108.0)
	for k: int in range(3):
		_drops.append({"pos": udder + Vector2(randf_range(-10.0, 10.0), 0.0), "vel": Vector2(randf_range(-20.0, 20.0), randf_range(40.0, 90.0)), "life": 0.6})
	hint_lbl.visible = Farm.total_clicks < 20
	_floaters.append({"pos": cow_rect.position + Vector2(randf_range(30.0, 130.0), randf_range(4.0, 30.0)), "text": "+" + Fmt.short_money(v), "life": 0.9,
		"col": COL_GOLD if Farm.rush_left > 0.0 else Color.WHITE})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and (k.physical_keycode == KEY_SPACE or k.physical_keycode == KEY_ENTER):
			_on_squeeze()
		elif k.pressed and not k.echo and k.physical_keycode == KEY_B:
			_set_buy_mode((buy_mode + 1) % BUY_MODES.size())
	elif event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event as InputEventJoypadButton
		if jb.pressed and jb.button_index == JOY_BUTTON_A:
			_on_squeeze()


func _set_tab(t: int) -> void:
	tab = t as Tab
	for i: int in range(pages.size()):
		pages[i].visible = i == t
	Sfx.play("ui", -10.0)
	_refresh_all()


func _set_buy_mode(m: int) -> void:
	buy_mode = m
	Sfx.play("ui", -10.0)
	_refresh_all()


func _buy_count(i: int) -> int:
	match BUY_MODES[buy_mode]:
		"x1":
			return 1
		"x10":
			return 10
		"x100":
			return 100
		"NEXT":
			return Farm.to_next_milestone(i)
		"MAX":
			return maxi(1, Farm.max_affordable(i))
	return 1


func _on_biz_clicked(i: int) -> void:
	if Farm.start_cycle(i):
		Sfx.play("ui", -10.0, 0.1)


func _on_buy_biz(i: int) -> void:
	var was_zero: bool = Farm.owned[i] == 0
	if Farm.buy(i, _buy_count(i)):
		Sfx.play("buy")
		if was_zero:
			_toast("NEW BUSINESS: %s!" % String(Farm.biz(i)["name"]), COL_GREEN)
	else:
		Sfx.play("cant", -10.0)
	_refresh_all()


func _on_buy_upgrade(row: int) -> void:
	var id: String = upg_ids[row]
	if id != "" and Farm.buy_upgrade(id):
		Sfx.play("milestone")
	else:
		Sfx.play("cant", -10.0)
	_refresh_all()


func _on_hire(i: int) -> void:
	if Farm.hire(i):
		Sfx.play("hire")
		_toast("%s JOINED THE FARM!" % String(Farm.biz(i)["farmhand"]), COL_GREEN)
	else:
		Sfx.play("cant", -10.0)
	_refresh_all()


func _on_move_pasture() -> void:
	var gained: int = Farm.move_pasture()
	if gained > 0:
		Sfx.play("bell")
		_toast("+%d GOLDEN COWBELLS! A FRESH PASTURE AWAITS." % gained, COL_GOLD)
		_set_tab(Tab.DAIRY)
	else:
		Sfx.play("cant", -10.0)


func _on_sfx_toggle() -> void:
	Farm.sfx_volume = 0.0 if Farm.sfx_volume > 0.0 else 0.8
	Farm.save_game()
	Sfx.play("ui")
	_refresh_all()


func _on_milestone(i: int, count: int) -> void:
	var speed: bool = count in Data.SPEED_MILESTONES
	_toast("%s x%d: %s!" % [String(Farm.biz(i)["name"]), count, "DOUBLE SPEED" if speed else "DOUBLE PROFITS"], COL_GOLD)
	Sfx.play("milestone")


func _on_rush_started() -> void:
	_toast("MOO RUSH! EVERYTHING EARNS x3!", COL_PINK)
	Sfx.play("rush")
	Sfx.play("moo", -2.0, 0.0)


func _toast(text: String, col: Color) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", col)
	toast_box.visible = true
	_toast_t = 2.6


# =========================================================================================
# PER-FRAME UPDATE
# =========================================================================================
func _process(delta: float) -> void:
	Farm.tick(delta)

	_blink_t -= delta
	if _blink_t < -0.12:
		_blink_t = randf_range(2.0, 5.0)
	_squeeze_t = maxf(0.0, _squeeze_t - delta)
	if _squeeze_t > 0.0:
		cow_rect.texture = Art.tex("cow_squeeze")
	elif _blink_t < 0.0:
		cow_rect.texture = Art.tex("cow_blink")
	else:
		cow_rect.texture = Art.tex("cow_idle")
	var bob: float = sin(float(Time.get_ticks_msec()) * 0.002) * 1.5
	cow_rect.position.y = 158.0 + round(bob) + (1.0 if _squeeze_t > 0.0 else 0.0)
	cow_rect.modulate = Color(1.0, 0.92, 0.75) if Farm.rush_left > 0.0 and int(Time.get_ticks_msec() / 120) % 2 == 0 else Color.WHITE

	for d: Dictionary in _drops:
		var v: Vector2 = d["vel"]
		v.y += 260.0 * delta
		d["vel"] = v
		d["pos"] = (d["pos"] as Vector2) + v * delta
		d["life"] = float(d["life"]) - delta
	var live_drops: Array[Dictionary] = []
	for d: Dictionary in _drops:
		if float(d["life"]) > 0.0:
			live_drops.append(d)
	_drops = live_drops
	for f: Dictionary in _floaters:
		f["pos"] = (f["pos"] as Vector2) + Vector2(0.0, -28.0 * delta)
		f["life"] = float(f["life"]) - delta
	var live_floaters: Array[Dictionary] = []
	for f: Dictionary in _floaters:
		if float(f["life"]) > 0.0:
			live_floaters.append(f)
	_floaters = live_floaters
	fx.queue_redraw()

	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_box.visible = false

	_refresh_all()


func _refresh_all() -> void:
	money_lbl.text = Fmt.money(Farm.money)
	var mfont: Font = money_lbl.get_theme_default_font()
	var big_fits: bool = mfont.get_string_size(money_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= money_lbl.size.x
	money_lbl.add_theme_font_size_override("font_size", 20 if big_fits else FONT_SZ)
	var rate: float = Farm.idle_income_per_sec() * Farm.rush_mult()
	rate_lbl.text = "%s /SEC FROM FARMHANDS" % Fmt.money(rate) if rate > 0.0 else "HIRE FARMHANDS FOR IDLE INCOME"
	click_lbl.text = "SQUEEZE: +%s" % Fmt.money(Farm.click_value())
	rush_bar.queue_redraw()
	_refresh_tab_badges()
	match tab:
		Tab.DAIRY:
			_refresh_dairy()
		Tab.UPGRADES:
			_refresh_upgrades()
		Tab.FARMHANDS:
			_refresh_farmhands()
		Tab.PASTURE:
			_refresh_pasture()


func _refresh_tab_badges() -> void:
	var names: Array[String] = ["DAIRY", "UPGRADES", "FARMHANDS", "PASTURE"]
	var any_upg: bool = false
	for u: Dictionary in Data.UPGRADES:
		if Farm.can_buy_upgrade(u):
			any_upg = true
			break
	var any_hand: bool = false
	for i: int in range(Farm.biz_count()):
		if not Farm.farmhands[i] and Farm.owned[i] > 0 and Farm.money >= float(Farm.biz(i)["farmhand_cost"]):
			any_hand = true
			break
	var flags: Array[bool] = [false, any_upg, any_hand, Farm.claimable_bells() > 0]
	for t: int in range(4):
		tab_btns[t].text = names[t] + (" !" if flags[t] else "")
		tab_btns[t].add_theme_color_override("font_color", COL_GOLD if t == int(tab) else COL_TEXT)


func _refresh_dairy() -> void:
	for m: int in range(buy_mode_btns.size()):
		buy_mode_btns[m].add_theme_color_override("font_color", COL_GOLD if m == buy_mode else COL_DIM)
	for i: int in range(Farm.biz_count()):
		var b: Dictionary = Farm.biz(i)
		var own: int = Farm.owned[i]
		var n: int = _buy_count(i)
		var cost: float = Farm.cost_of(i, n)
		biz_buy_btns[i].text = "BUY x%d\n%s" % [n, Fmt.short_money(cost)]
		biz_buy_btns[i].disabled = cost > Farm.money
		biz_icon_btns[i].modulate = Color.WHITE if own > 0 else Color(0.4, 0.35, 0.3)
		biz_name_lbls[i].text = "%s  x%d" % [String(b["name"]), own] if own > 0 else String(b["name"])
		if own <= 0:
			biz_sub_lbls[i].text = "BUY ONE TO OPEN"
		elif Farm.farmhands[i]:
			biz_sub_lbls[i].text = "%s RUNS IT  -  %s" % [String(b["farmhand"]), _time_left(i)]
		elif Farm.running[i]:
			biz_sub_lbls[i].text = "SELLING...  %s" % _time_left(i)
		else:
			biz_sub_lbls[i].text = "CLICK THE ICON TO SELL"
		biz_bars[i].queue_redraw()


func _time_left(i: int) -> String:
	var ct: float = Farm.cycle_time(i)
	if ct < 0.2:
		return "NONSTOP"
	return Fmt.duration(ct * (1.0 - Farm.progress[i]))


func _refresh_upgrades() -> void:
	var avail: Array[Dictionary] = []
	for u: Dictionary in Data.UPGRADES:
		if not Farm.upgrades.has(String(u["id"])):
			avail.append(u)
	avail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cost"]) < float(b["cost"]))
	upg_header.text = "UPGRADES BOUGHT: %d / %d" % [Farm.upgrades.size(), Data.UPGRADES.size()]
	for r: int in range(upg_rows.size()):
		if r < avail.size():
			var u: Dictionary = avail[r]
			upg_rows[r].visible = true
			upg_ids[r] = String(u["id"])
			upg_name_lbls[r].text = String(u["name"])
			upg_desc_lbls[r].text = String(u["desc"])
			upg_btns[r].text = "BUY\n%s" % Fmt.short_money(float(u["cost"]))
			upg_btns[r].disabled = not Farm.can_buy_upgrade(u)
		else:
			upg_rows[r].visible = false
			upg_ids[r] = ""


func _refresh_farmhands() -> void:
	for i: int in range(Farm.biz_count()):
		var b: Dictionary = Farm.biz(i)
		var cost: float = float(b["farmhand_cost"])
		if Farm.farmhands[i]:
			hand_btns[i].text = "HIRED"
			hand_btns[i].disabled = true
			hand_sub_lbls[i].text = "RUNS YOUR %s" % String(b["name"])
		else:
			hand_btns[i].text = "HIRE\n%s" % Fmt.short_money(cost)
			hand_btns[i].disabled = Farm.owned[i] <= 0 or Farm.money < cost
			hand_sub_lbls[i].text = "WOULD RUN YOUR %s" % String(b["name"]) if Farm.owned[i] > 0 else "BUY A %s FIRST" % String(b["name"])


func _refresh_pasture() -> void:
	var claim: int = Farm.claimable_bells()
	pasture_lbl.text = (
		"YOU HAVE %d GOLDEN COWBELLS. EACH ONE GIVES +2%% PROFIT, SO YOU EARN x%.2f.\n\n"
		% [Farm.bells, Farm.bell_mult()]
		+ "MOVING TO A BIGGER PASTURE SELLS YOUR WHOLE FARM (MONEY, BUSINESSES, FARMHANDS AND UPGRADES) "
		+ "BUT KEEPS YOUR COWBELLS, AND GIVES YOU NEW ONES FOR EVERYTHING YOU'VE EARNED.\n\n"
		+ "MOVING NOW EARNS: %d COWBELLS\n" % claim
		+ "NEXT COWBELL AT %s TOTAL EARNED (NOW %s).\n\n" % [Fmt.money(Farm.earned_for_next_bell()), Fmt.money(Farm.total_earned)]
		+ "SQUEEZES: %s   PASTURES MOVED: %d" % [Fmt.commas(float(Farm.total_clicks)), Farm.pastures_moved]
	)
	move_btn.text = "MOVE TO A BIGGER PASTURE (+%d)" % claim
	move_btn.disabled = claim <= 0
	sfx_btn.text = "SOUND: %s" % ("ON" if Farm.sfx_volume > 0.0 else "OFF")


# =========================================================================================
# DRAWING
# =========================================================================================
func _draw_biz_bar(bar: Control, i: int) -> void:
	var font: Font = ThemeDB.fallback_font if bar.get_theme_default_font() == null else bar.get_theme_default_font()
	var r: Rect2 = Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, Color("#1a110a"))
	if Farm.owned[i] > 0:
		var ct: float = Farm.cycle_time(i)
		var fill: float = 1.0 if ct < 0.2 and (Farm.farmhands[i] or Farm.running[i]) else Farm.progress[i]
		var col: Color = COL_GOLD if Farm.rush_left > 0.0 else COL_GREEN
		if fill > 0.0:
			bar.draw_rect(Rect2(1.0, 1.0, (r.size.x - 2.0) * fill, r.size.y - 2.0), col)
			bar.draw_rect(Rect2(1.0, 1.0, (r.size.x - 2.0) * fill, 2.0), col.lightened(0.35))
		var txt: String = Fmt.money(Farm.revenue(i))
		if ct < 0.2:
			txt = "%s /SEC" % Fmt.money(Farm.revenue(i) / ct)
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ).x
		var tp: Vector2 = Vector2((r.size.x - tw) * 0.5, 10.0)
		bar.draw_string(font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, Color(0, 0, 0, 0.8))
		bar.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, COL_TEXT)
	bar.draw_rect(r, Color("#6e5236"), false, 1.0)


func _draw_rush_bar() -> void:
	var font: Font = rush_bar.get_theme_default_font()
	var r: Rect2 = Rect2(Vector2.ZERO, rush_bar.size)
	rush_bar.draw_rect(r, Color("#1a110a"))
	var fill: float = Farm.rush_left / Data.RUSH_SECONDS if Farm.rush_left > 0.0 else Farm.rush_meter
	var col: Color = COL_PINK if Farm.rush_left > 0.0 else Color("#c25b8a")
	rush_bar.draw_rect(Rect2(1.0, 1.0, (r.size.x - 2.0) * fill, r.size.y - 2.0), col)
	var txt: String = "MOO RUSH! x3  %s" % Fmt.duration(Farm.rush_left) if Farm.rush_left > 0.0 else "MOO RUSH METER (KEEP MILKING!)"
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ).x
	rush_bar.draw_string(font, Vector2((r.size.x - tw) * 0.5 + 1.0, 11.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, Color(0, 0, 0, 0.8))
	rush_bar.draw_string(font, Vector2((r.size.x - tw) * 0.5, 10.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, Color.WHITE)
	rush_bar.draw_rect(r, COL_BORDER, false, 1.0)


func _draw_fx() -> void:
	var font: Font = fx.get_theme_default_font()
	for d: Dictionary in _drops:
		var p: Vector2 = d["pos"]
		fx.draw_rect(Rect2(p.round(), Vector2(2, 3)), Color(1, 1, 1, clampf(float(d["life"]) * 2.0, 0.0, 1.0)))
	for f: Dictionary in _floaters:
		var a: float = clampf(float(f["life"]) * 1.6, 0.0, 1.0)
		var c: Color = f["col"]
		var p2: Vector2 = (f["pos"] as Vector2).round()
		fx.draw_string(font, p2 + Vector2(1, 1), String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, Color(0, 0, 0, a * 0.8))
		fx.draw_string(font, p2, String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SZ, Color(c.r, c.g, c.b, a))


# =========================================================================================
# SMOKE TEST (--smoke-test): drives the economy and every tab, then quits. Uses its own
# save file, so a real save is never touched.
# =========================================================================================
func _check(cond: bool, what: String) -> bool:
	if not cond:
		push_error("SMOKE: " + what)
	return cond


func _run_smoke_test() -> void:
	Farm.save_path = "user://smoke_test_save.json"
	Farm.reset_save()
	var ok: bool = true
	ok = _check(Fmt.money(1234.0) == "$1,234", "money format: " + Fmt.money(1234.0)) and ok
	ok = _check(Fmt.money(12.5) == "$12.50", "cents format: " + Fmt.money(12.5)) and ok
	ok = _check(Fmt.money(3.2e9) == "$3.200 BILLION", "big format: " + Fmt.money(3.2e9)) and ok
	ok = _check(Fmt.short(3.2e9) == "3.20B", "short format: " + Fmt.short(3.2e9)) and ok
	ok = _check(Fmt.duration(3725.0) == "1H 02M", "duration format: " + Fmt.duration(3725.0)) and ok

	# Squeezing and the first sale.
	for k: int in range(5):
		_on_squeeze()
	ok = _check(is_equal_approx(Farm.money, 5.0), "5 squeezes should earn $5, got %f" % Farm.money) and ok
	ok = _check(Farm.start_cycle(0), "could not start the milk pail") and ok
	Farm.tick(1.05)
	ok = _check(is_equal_approx(Farm.money, 6.5), "a pail cycle should pay $1.50, money %f" % Farm.money) and ok
	ok = _check(not Farm.running[0], "manual cycle should stop after paying") and ok

	# Buying, prices and milestones.
	var c1: float = Farm.cost_of(0, 1)
	ok = _check(is_equal_approx(c1, 5.0 * 1.07), "second pail should cost 5 x 1.07, got %f" % c1) and ok
	ok = _check(Farm.buy(0, 1) and Farm.owned[0] == 2, "buying a pail failed") and ok
	Farm.money = 1.0e9
	var before_ct: float = Farm.cycle_time(0)
	var milestones: Array[int] = []
	var cb: Callable = func(_i: int, m: int) -> void: milestones.append(m)
	Farm.milestone_reached.connect(cb)
	ok = _check(Farm.buy(0, 23), "buying 23 pails failed") and ok
	Farm.milestone_reached.disconnect(cb)
	ok = _check(milestones.size() == 1 and milestones[0] == 25, "reaching 25 pails should fire one milestone, got %s" % str(milestones)) and ok
	ok = _check(is_equal_approx(Farm.cycle_time(0), before_ct * 0.5), "25 pails should halve the cycle time") and ok
	var n_max: int = Farm.max_affordable(1)
	ok = _check(n_max > 0 and Farm.cost_of(1, n_max) <= Farm.money and Farm.cost_of(1, n_max + 1) > Farm.money, "max_affordable is off") and ok

	# Farmhands and idle income.
	ok = _check(Farm.hire(0), "hiring Farmer Fran failed") and ok
	var m0: float = Farm.money
	var expect: float = Farm.idle_income_per_sec() * 10.0
	for s: int in range(100):
		Farm.tick(0.1)
	ok = _check(absf((Farm.money - m0) - expect) < expect * 0.06 + 1.0, "farmhand earned %f in 10 s, expected about %f" % [Farm.money - m0, expect]) and ok

	# Upgrades.
	var pm: float = Farm.profit_mult(1)
	ok = _check(Farm.buy_upgrade("happy_cows"), "buying HAPPY COWS failed") and ok
	ok = _check(is_equal_approx(Farm.profit_mult(1), pm * 3.0), "HAPPY COWS should triple profits") and ok
	ok = _check(not Farm.buy_upgrade("happy_cows"), "an upgrade was bought twice") and ok
	var cv: float = Farm.click_value()
	ok = _check(Farm.buy_upgrade("warm_hands") and Farm.click_value() > cv, "WARM HANDS should raise squeezes") and ok

	# MOO RUSH.
	var rush_fired: Array[bool] = [false]
	var rcb: Callable = func() -> void: rush_fired[0] = true
	Farm.rush_started.connect(rcb)
	for k: int in range(30):
		Farm.squeeze()
	Farm.rush_started.disconnect(rcb)
	ok = _check(rush_fired[0] and Farm.rush_mult() == Data.RUSH_MULT, "MOO RUSH did not start after 30 squeezes") and ok
	Farm.tick(Data.RUSH_SECONDS + 0.5)
	ok = _check(Farm.rush_mult() == 1.0, "MOO RUSH did not end") and ok

	# Offline earnings.
	var off_expect: float = Farm.idle_income_per_sec() * 3600.0
	var m1: float = Farm.money
	var off: float = Farm.apply_offline(3600.0)
	ok = _check(is_equal_approx(off, off_expect) and is_equal_approx(Farm.money - m1, off_expect), "offline earnings are off") and ok

	# Every tab and every button path.
	for t: int in range(4):
		_set_tab(t)
		for m: int in range(BUY_MODES.size()):
			_set_buy_mode(m)
			_refresh_all()
	_set_tab(Tab.DAIRY)
	for i: int in range(Farm.biz_count()):
		Farm.money = 1.0e15
		_on_buy_biz(i)
		_on_biz_clicked(i)
		_on_hire(i)
	ok = _check(Farm.owned.min() >= 1 and not Farm.farmhands.has(false), "could not buy and staff every business") and ok
	_set_tab(Tab.UPGRADES)
	for r: int in range(upg_rows.size()):
		Farm.money = 1.0e18
		_refresh_all()
		_on_buy_upgrade(0)
	for k: int in range(30):
		_process(0.05)

	# Save and load.
	Farm.money = 123456.0
	Farm.bells = 3
	Farm.save_game()
	var owned_before: Array[int] = Farm.owned.duplicate()
	var ups_before: int = Farm.upgrades.size()
	Farm.reset_pasture()
	Farm.bells = 0
	Farm.load_game()
	ok = _check(Farm.owned == owned_before and Farm.bells == 3 and Farm.money >= 123456.0, "save/load lost data") and ok
	ok = _check(ups_before > 0 and Farm.upgrades.size() == ups_before, "upgrades were not bought by the UI pass or not saved") and ok

	# Golden cowbells.
	Farm.total_earned = 1.0e11
	Farm.bells = 0
	ok = _check(Farm.claimable_bells() == 100, "1e11 earned should give 100 bells, got %d" % Farm.claimable_bells()) and ok
	_set_tab(Tab.PASTURE)
	_on_move_pasture()
	ok = _check(Farm.bells == 100 and Farm.owned[0] == 1 and Farm.owned[1] == 0 and Farm.money == 0.0, "moving pasture did not reset correctly") and ok
	ok = _check(is_equal_approx(Farm.bell_mult(), 3.0), "100 bells should give x3") and ok
	ok = _check(Farm.claimable_bells() == 0, "bells were claimable twice") and ok

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_test_save.json"))
	if ok:
		print("UDDERLY_SMOKE_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("UDDERLY_SMOKE_TEST_FAILED")
		get_tree().quit(1)
