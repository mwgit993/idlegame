extends Node2D

# Udderly Idle: the whole screen is built here in code (a 640x360 layout, scaled smoothly to
# the window). Left: the farm and the cow (click to squeeze the udder). Right: four tabs:
#   DAIRY      your businesses: click an icon to sell, buy more, watch the bars fill
#   UPGRADES   one-time profit multipliers
#   FARMHANDS  hire one per business so it runs by itself (and while the game is closed)
#   PASTURE    golden cowbells (prestige), stats and settings
# All state lives in the Farm autoload; this script draws it and forwards input. The art is
# cartoon vector drawing: the cow is scripts/cow.gd, the background scripts/farm_scene.gd,
# icons and shape helpers are in the Art autoload.

const Data = preload("res://scripts/game_data.gd")
const Fmt = preload("res://scripts/num_fmt.gd")
const Cow = preload("res://scripts/cow.gd")
const FarmScene = preload("res://scripts/farm_scene.gd")

const W: float = 640.0
const H: float = 360.0
const LEFT_W: float = 230.0
const TOP_H: float = 34.0
const PANEL: Rect2 = Rect2(234, 38, 402, 319)  # the right-hand cream panel
const RX: float = 240.0  # right panel content x
const ROW_Y: float = 60.0
const ROW_H: float = 36.5
const BTN_X: float = RX + 285.0  # buy / hire buttons
const FS: int = 11         # body text
const FS_SMALL: int = 9
const FS_MONEY: int = 20

const INK: Color = Color("#2b1e1a")
const COL_TEXT: Color = Color("#4a2c17")
const COL_DIM: Color = Color("#9a7552")
const COL_LIGHT: Color = Color("#fff8e8")
const COL_CREAM: Color = Color("#fff3d6")
const COL_CARD: Color = Color("#fffaf0")
const COL_WOOD: Color = Color("#a8622c")
const COL_GOLD: Color = Color("#ffcc2e")
const COL_GREEN: Color = Color("#5fc23a")
const COL_PINK: Color = Color("#ff6fae")
const COL_BARN: Color = Color("#d8433a")
const COL_TAN: Color = Color("#c9a77a")

enum Tab { DAIRY, UPGRADES, FARMHANDS, PASTURE }
const BUY_MODES: Array[String] = ["x1", "x10", "x100", "NEXT", "MAX"]
const TAB_NAMES: Array[String] = ["DAIRY", "UPGRADES", "FARMHANDS", "PASTURE"]

var ui: CanvasLayer
var tab: Tab = Tab.DAIRY
var buy_mode: int = 0

# Left panel
var farm_scene: Control
var cow: Control
var cow_btn: Button
var fx: Control
var click_lbl: Label
var rush_bar: Control
# Top bar
var money_lbl: Label
var rate_lbl: Label
var tab_btns: Array[Button] = []
var _tab_flags: Array[bool] = [false, false, false, false]
var toast_lbl: Label
var toast_box: Panel
var _toast_sb: StyleBoxFlat
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
var upg_icons: Array[Control] = []
var upg_name_lbls: Array[Label] = []
var upg_desc_lbls: Array[Label] = []
var upg_btns: Array[Button] = []
var upg_ids: Array[String] = []
var upg_header: Label
var hand_btns: Array[Button] = []
var hand_faces: Array[Control] = []
var hand_lbls: Array[Label] = []
var hand_sub_lbls: Array[Label] = []
var pasture_lbl: Label
var move_btn: Button
var sfx_btn: Button
var music_btn: Button
# Welcome-back popup
var offline_panel: Control
var offline_card: Panel
var offline_lbl: Label
var offline_money_lbl: Label
var offline_time_lbl: Label

var _t: float = 0.0
var _clicks_since_moo: int = 0
var _floaters: Array[Dictionary] = []  # "+$12" texts: pos, text, life, max, col, drift
var _btn_styles: Dictionary = {}       # kind -> {state -> StyleBox}
var _sb_track: StyleBoxFlat
var _sb_fill_green: StyleBoxFlat
var _sb_fill_gold: StyleBoxFlat
var _sb_fill_pink: StyleBoxFlat
var _sb_shine: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_build_ui()
	Farm.milestone_reached.connect(_on_milestone)
	Farm.rush_started.connect(_on_rush_started)
	Farm.rush_ended.connect(func() -> void: _toast("MOO RUSH OVER", COL_TAN))
	_set_tab(Tab.DAIRY)
	_refresh_all()
	hint_lbl.visible = Farm.total_clicks < 20
	if "--smoke-test" in OS.get_cmdline_user_args():
		_run_smoke_test()
		return
	if Farm.last_offline_earned > 0.0:
		_show_offline(Farm.last_offline_earned, Farm.last_offline_seconds)


# =========================================================================================
# STYLES
# =========================================================================================
func _sb(bg: Color, border: Color, bw: int = 2, radius: int = 8, bottom: int = -1, shadow: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	if bottom >= 0:
		sb.border_width_bottom = bottom
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.set_content_margin_all(2.0)
	if shadow > 0:
		sb.shadow_color = Color(0.2, 0.1, 0.02, 0.3)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0.0, float(shadow) * 0.6)
	return sb


func _build_styles() -> void:
	var kinds: Dictionary = {
		"cream": COL_CREAM, "green": COL_GREEN, "gold": Color("#ffbf1f"), "red": COL_BARN,
		"pink": COL_PINK, "card": Color("#fff6e2"), "hired": COL_GREEN,
	}
	for k: String in kinds:
		var bg: Color = kinds[k]
		var pressed: StyleBoxFlat = _sb(bg.darkened(0.12), INK, 2, 8, 2)
		pressed.content_margin_top = 4.0
		_btn_styles[k] = {
			"normal": _sb(bg, INK, 2, 8, 4),
			"hover": _sb(bg.lightened(0.15), INK, 2, 8, 4),
			"pressed": pressed,
			"disabled": _sb(Color("#ece0c6"), Color("#bba584"), 2, 8, 3),
			"focus": StyleBoxEmpty.new(),
		}
	# A hired farmhand's button is disabled but should look happy, not greyed out.
	var hired: Dictionary = _btn_styles["hired"]
	hired["disabled"] = _sb(Color("#dcf5c8"), Color("#5fae4f"), 2, 8, 3)
	_sb_track = _sb(Color("#8a5a35"), INK, 2, 6)
	_sb_fill_green = _sb(Color("#7fdc4c"), Color(0, 0, 0, 0), 0, 5)
	_sb_fill_gold = _sb(COL_GOLD, Color(0, 0, 0, 0), 0, 5)
	_sb_fill_pink = _sb(COL_PINK, Color(0, 0, 0, 0), 0, 6)
	_sb_shine = _sb(Color(1, 1, 1, 0.38), Color(0, 0, 0, 0), 0, 3)


# Styles a button: "cream" (dark text), or a bright kind with white outlined text.
func _style_btn(b: Button, kind: String = "cream", fsize: int = FS) -> void:
	var st: Dictionary = _btn_styles[kind]
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, st[state] as StyleBox)
	var light: bool = kind != "cream" and kind != "card"
	var fg: Color = Color.WHITE if light else COL_TEXT
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color("#3f8f2c") if kind == "hired" else Color("#a68c6a"))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 4 if light and not b.disabled else 0)
	b.add_theme_font_size_override("font_size", fsize)
	b.set_meta("kind", kind)
	b.focus_mode = Control.FOCUS_NONE


func _set_kind(b: Button, kind: String) -> void:
	if String(b.get_meta("kind", "")) != kind:
		_style_btn(b, kind, b.get_theme_font_size("font_size"))


# Enables/disables a button (white outlined text loses its outline while disabled).
func _set_enabled(b: Button, on: bool) -> void:
	if b.disabled == (not on):
		return
	b.disabled = not on
	if not on and b.scale != Vector2.ONE:
		_boing(b, Vector2.ONE, 0.3, Tween.TRANS_BACK)
	var kind: String = String(b.get_meta("kind", "cream"))
	var light: bool = kind != "cream" and kind != "card"
	b.add_theme_constant_override("outline_size", 4 if light and on else 0)


# Chunky buttons squash when pressed and boing back when released.
func _bouncy(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	b.button_down.connect(func() -> void: _boing(b, Vector2(1.08, 0.84), 0.05, Tween.TRANS_QUAD))
	b.button_up.connect(func() -> void: _boing(b, Vector2.ONE, 0.5, Tween.TRANS_ELASTIC))
	# Hidden mid-press (tab switch) never sends button_up: don't stay squashed.
	b.visibility_changed.connect(func() -> void: b.scale = Vector2.ONE)


func _boing(c: Control, to: Vector2, dur: float, trans: Tween.TransitionType) -> void:
	if c.has_meta("tween"):
		var old: Tween = c.get_meta("tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", to, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
	c.set_meta("tween", tw)


# The biggest font size (from big down to small) at which text fits in width.
func _fit_size(font: Font, text: String, width: float, big: int, small: int) -> int:
	var sz: int = big
	while sz > small and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		sz -= 1
	return sz


# Only touches the override when the size changes (setting it re-lays-out the text).
func _set_font_size(c: Control, sz: int) -> void:
	if c.get_theme_font_size("font_size") != sz:
		c.add_theme_font_size_override("font_size", sz)


func _label(parent: Node, pos: Vector2, size: Vector2, text: String = "", col: Color = COL_TEXT, fsize: int = FS, outline_px: int = 0) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if outline_px > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline_px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, pos: Vector2, size: Vector2, text: String, cb: Callable, kind: String = "cream", fsize: int = FS) -> Button:
	var b: Button = Button.new()
	b.position = pos
	b.size = size
	b.text = text
	_style_btn(b, kind, fsize)
	b.pressed.connect(cb)
	parent.add_child(b)
	_bouncy(b)
	return b


func _panel(parent: Node, rect: Rect2, sb: StyleBox) -> Panel:
	var p: Panel = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


# A Control that draws once with cb(control) (redraw it with queue_redraw()).
func _canvas(parent: Node, rect: Rect2, cb: Callable) -> Control:
	var c: Control = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: cb.call(c))
	parent.add_child(c)
	return c


# =========================================================================================
# UI CONSTRUCTION
# =========================================================================================
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	farm_scene = FarmScene.new()
	ui.add_child(farm_scene)
	_build_cow_panel()
	_build_top_bar()

	_panel(ui, PANEL, _sb(COL_CREAM, COL_WOOD, 3, 14, 5, 6))
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

	_toast_sb = _sb(COL_GREEN, INK, 2, 14, 4, 3)
	toast_box = _panel(ui, Rect2(12.0, TOP_H + 8.0, LEFT_W - 24.0, 36.0), _toast_sb)
	toast_box.pivot_offset = toast_box.size * 0.5
	toast_box.visible = false
	toast_lbl = _label(toast_box, Vector2(6.0, 0.0), Vector2(LEFT_W - 36.0, 32.0), "", Color.WHITE, FS, 4)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_offline_popup()


func _build_cow_panel() -> void:
	cow = Cow.new()
	cow.size = Vector2(W, H)
	ui.add_child(cow)

	cow_btn = Button.new()
	cow_btn.position = Vector2(14.0, 152.0)
	cow_btn.size = Vector2(212.0, 158.0)
	cow_btn.flat = true
	cow_btn.focus_mode = Control.FOCUS_NONE
	cow_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus"]:
		cow_btn.add_theme_stylebox_override(st, empty)
	cow_btn.button_down.connect(_on_squeeze)
	ui.add_child(cow_btn)

	hint_lbl = _label(ui, Vector2(0.0, 114.0), Vector2(LEFT_W, 18.0), "CLICK THE COW TO MILK HER!", Color.WHITE, 12, 5)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.pivot_offset = hint_lbl.size * 0.5

	_panel(ui, Rect2(5.0, 317.0, LEFT_W - 10.0, 39.0), _sb(COL_CREAM, COL_WOOD, 3, 12, 4, 3))
	click_lbl = _label(ui, Vector2(14.0, 319.0), Vector2(LEFT_W - 28.0, 15.0), "", COL_TEXT, 10)
	rush_bar = _canvas(ui, Rect2(11.0, 334.0, LEFT_W - 22.0, 16.0), func(_c: Control) -> void: _draw_rush_bar())

	fx = _canvas(ui, Rect2(0.0, 0.0, W, H), func(_c: Control) -> void: _draw_fx())


func _build_top_bar() -> void:
	_panel(ui, Rect2(-6.0, -12.0, W + 12.0, TOP_H + 12.0), _sb(COL_BARN, INK, 2, 12, 4, 4))
	_canvas(ui, Rect2(2.0, 3.0, 26.0, 26.0), func(c: Control) -> void: Art.draw_icon(c, "coin", Vector2(13.0, 13.0), 23.0))
	money_lbl = _label(ui, Vector2(30.0, -2.0), Vector2(200.0, 26.0), "", COL_GOLD, FS_MONEY, 6)
	money_lbl.add_theme_font_override("font", Art.font_bold)
	money_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_lbl = _label(ui, Vector2(31.0, 20.0), Vector2(200.0, 12.0), "", COL_LIGHT, FS_SMALL, 3)
	for t: int in range(4):
		var b: Button = _button(ui, Vector2(RX - 4.0 + float(t) * 100.0, 4.0), Vector2(96.0, 25.0), TAB_NAMES[t], _set_tab.bind(t), "cream", 12)
		b.draw.connect(_draw_tab_badge.bind(b, t))
		tab_btns.append(b)


func _row_card(page: Control, ry: float, h: float) -> Panel:
	return _panel(page, Rect2(RX - 2.0, ry, 394.0, h), _sb(COL_CARD, Color("#e6c99a"), 2, 9))


func _build_dairy_page(page: Control) -> void:
	_label(page, Vector2(RX + 2.0, 41.0), Vector2(40.0, 18.0), "BUY:", COL_DIM, FS)
	for m: int in range(BUY_MODES.size()):
		var b: Button = _button(page, Vector2(RX + 36.0 + float(m) * 50.0, 41.0), Vector2(46.0, 18.0), BUY_MODES[m], _set_buy_mode.bind(m), "cream", 10)
		buy_mode_btns.append(b)
	for i: int in range(Farm.biz_count()):
		var ry: float = ROW_Y + float(i) * ROW_H
		_row_card(page, ry, ROW_H - 2.0)
		var icon_b: Button = Button.new()
		icon_b.position = Vector2(RX + 1.0, ry + 2.0)
		icon_b.size = Vector2(30.0, 30.0)
		_style_btn(icon_b, "card")
		icon_b.pressed.connect(_on_biz_clicked.bind(i))
		icon_b.draw.connect(_draw_biz_icon.bind(icon_b, String(Farm.biz(i)["id"])))
		page.add_child(icon_b)
		_bouncy(icon_b)
		biz_icon_btns.append(icon_b)

		biz_name_lbls.append(_label(page, Vector2(RX + 37.0, ry - 0.5), Vector2(245.0, 15.0)))
		var bar: Control = Control.new()
		bar.position = Vector2(RX + 37.0, ry + 13.0)
		bar.size = Vector2(242.0, 10.5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_biz_bar.bind(bar, i))
		page.add_child(bar)
		biz_bars.append(bar)
		biz_sub_lbls.append(_label(page, Vector2(RX + 37.0, ry + 23.5), Vector2(245.0, 12.0), "", COL_DIM, FS_SMALL))

		var buy_b: Button = _button(page, Vector2(BTN_X, ry + 2.0), Vector2(106.0, 30.0), "", _on_buy_biz.bind(i), "green", 10)
		biz_buy_btns.append(buy_b)


func _build_upgrades_page(page: Control) -> void:
	upg_header = _label(page, Vector2(RX + 4.0, 41.0), Vector2(380.0, 18.0), "", COL_DIM, FS)
	for r: int in range(7):
		var ry: float = ROW_Y + float(r) * 41.0
		var row: Control = Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(row)
		upg_rows.append(row)
		_row_card(row, ry, 39.0)
		upg_icons.append(_canvas(row, Rect2(RX + 2.0, ry + 3.0, 32.0, 32.0), _draw_upgrade_icon.bind(r)))
		upg_name_lbls.append(_label(row, Vector2(RX + 40.0, ry + 3.0), Vector2(240.0, 16.0), "", COL_TEXT, 12))
		upg_desc_lbls.append(_label(row, Vector2(RX + 40.0, ry + 20.0), Vector2(240.0, 14.0), "", COL_DIM, 10))
		upg_btns.append(_button(row, Vector2(BTN_X, ry + 4.0), Vector2(106.0, 31.0), "", _on_buy_upgrade.bind(r), "gold", 10))
		upg_ids.append("")


func _build_farmhands_page(page: Control) -> void:
	_label(page, Vector2(RX + 4.0, 42.0), Vector2(390.0, 16.0), "A FARMHAND RUNS ONE BUSINESS FOR YOU, EVEN WHILE YOU'RE AWAY.", COL_DIM, FS_SMALL)
	for i: int in range(Farm.biz_count()):
		var ry: float = ROW_Y + float(i) * ROW_H
		_row_card(page, ry, ROW_H - 2.0)
		var id: String = String(Farm.biz(i)["id"])
		hand_faces.append(_canvas(page, Rect2(RX, ry, 36.0, 34.0), func(c: Control) -> void:
			Art.draw_icon(c, "farmhand", Vector2(16.0, 16.0), 28.0)
			Art.draw_icon(c, id, Vector2(29.0, 26.0), 16.0)))
		hand_lbls.append(_label(page, Vector2(RX + 40.0, ry + 2.0), Vector2(240.0, 15.0), String(Farm.biz(i)["farmhand"]), COL_TEXT, FS))
		hand_sub_lbls.append(_label(page, Vector2(RX + 40.0, ry + 17.0), Vector2(240.0, 14.0), "", COL_DIM, 10))
		hand_btns.append(_button(page, Vector2(BTN_X, ry + 2.0), Vector2(106.0, 30.0), "", _on_hire.bind(i), "red", 10))


func _build_pasture_page(page: Control) -> void:
	_canvas(page, Rect2(RX + 2.0, 42.0, 30.0, 30.0), func(c: Control) -> void: Art.draw_icon(c, "bell", Vector2(15.0, 15.0), 28.0))
	var title: Label = _label(page, Vector2(RX + 38.0, 42.0), Vector2(300.0, 28.0), "GOLDEN COWBELLS", COL_GOLD, 18, 5)
	title.add_theme_font_override("font", Art.font_bold)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row_card(page, 74.0, 180.0)
	pasture_lbl = _label(page, Vector2(RX + 6.0, 79.0), Vector2(380.0, 172.0), "", COL_TEXT, 10)
	pasture_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pasture_lbl.add_theme_constant_override("line_spacing", 0)
	move_btn = _button(page, Vector2(RX + 34.0, 262.0), Vector2(322.0, 34.0), "", _on_move_pasture, "gold", 13)
	sfx_btn = _button(page, Vector2(RX, 318.0), Vector2(124.0, 28.0), "", _on_sfx_toggle, "cream", 11)
	music_btn = _button(page, Vector2(RX + 132.0, 318.0), Vector2(124.0, 28.0), "", _on_music_toggle, "cream", 11)
	_button(page, Vector2(RX + 264.0, 318.0), Vector2(124.0, 28.0), "SAVE NOW", func() -> void:
		Farm.save_game()
		Sfx.play("ui")
		_toast("GAME SAVED", COL_GREEN)
	, "green", 11)


func _build_offline_popup() -> void:
	offline_panel = Control.new()
	offline_panel.size = Vector2(W, H)
	offline_panel.visible = false
	ui.add_child(offline_panel)
	var dim: ColorRect = ColorRect.new()
	dim.size = Vector2(W, H)
	dim.color = Color(0.1, 0.05, 0.02, 0.45)
	offline_panel.add_child(dim)  # also swallows clicks until COLLECT

	offline_card = Panel.new()
	offline_card.position = Vector2(160.0, 84.0)
	offline_card.size = Vector2(320.0, 196.0)
	offline_card.pivot_offset = offline_card.size * 0.5
	offline_card.add_theme_stylebox_override("panel", _sb(COL_CREAM, COL_WOOD, 4, 18, 6, 10))
	offline_panel.add_child(offline_card)
	var ribbon: Panel = _panel(offline_card, Rect2(30.0, -16.0, 260.0, 38.0), _sb(COL_BARN, INK, 2, 12, 5, 3))
	var title: Label = _label(ribbon, Vector2(0.0, 0.0), Vector2(260.0, 33.0), "WELCOME BACK!", Color.WHITE, 20, 5)
	title.add_theme_font_override("font", Art.font_bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	offline_lbl = _label(offline_card, Vector2(20.0, 34.0), Vector2(280.0, 16.0), "YOUR FARMHANDS EARNED", COL_TEXT, 12)
	offline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas(offline_card, Rect2(0.0, 0.0, 320.0, 196.0), func(c: Control) -> void:
		Art.draw_icon(c, "farmhand", Vector2(40.0, 82.0), 44.0)
		Art.draw_icon(c, "coin", Vector2(282.0, 76.0), 30.0)
		Art.draw_icon(c, "coin", Vector2(270.0, 94.0), 24.0)
		Art.sparkle(c, Vector2(298.0, 98.0), 5.0, Color("#ffe066"))
		Art.sparkle(c, Vector2(22.0, 56.0), 4.0, Color("#ffe066")))
	offline_money_lbl = _label(offline_card, Vector2(66.0, 54.0), Vector2(188.0, 40.0), "", COL_GOLD, 26, 6)
	offline_money_lbl.add_theme_font_override("font", Art.font_bold)
	offline_money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline_money_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	offline_time_lbl = _label(offline_card, Vector2(20.0, 102.0), Vector2(280.0, 30.0), "", COL_DIM, 11)
	offline_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline_time_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(offline_card, Vector2(90.0, 138.0), Vector2(140.0, 38.0), "COLLECT", func() -> void:
		_hide_offline()
		Sfx.play("coin")
	, "green", 16)


func _show_offline(amount: float, seconds: int) -> void:
	offline_money_lbl.text = Fmt.money(amount)
	_set_font_size(offline_money_lbl, _fit_size(offline_money_lbl.get_theme_font("font"), offline_money_lbl.text, offline_money_lbl.size.x, 26, 12))
	offline_time_lbl.text = "WHILE YOU WERE AWAY (%s)." % Fmt.duration(float(seconds))
	offline_panel.visible = true
	offline_card.scale = Vector2(0.4, 0.4)
	var tw: Tween = offline_card.create_tween()
	tw.tween_property(offline_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_offline() -> void:
	offline_panel.visible = false


# =========================================================================================
# INPUT
# =========================================================================================
func _on_squeeze() -> void:
	var v: float = Farm.squeeze()
	cow.squeeze()
	Sfx.play("squirt", -8.0, 0.12)
	_clicks_since_moo += 1
	# She moos now and then (roughly every 15 squeezes), never twice in a row too quickly.
	if _clicks_since_moo >= 10 and randf() < 0.2:
		_clicks_since_moo = 0
		Sfx.play("moo", -4.0, 0.08)
	hint_lbl.visible = Farm.total_clicks < 20
	if _floaters.size() < 40:
		var g: Vector2 = cow.ground
		_floaters.append({"pos": g + Vector2(randf_range(-75.0, 70.0), randf_range(-178.0, -140.0)), "text": "+" + Fmt.short_money(v),
			"life": 1.0, "max": 1.0, "col": COL_GOLD if Farm.rush_left > 0.0 else Color.WHITE, "drift": randf_range(-14.0, 14.0)})


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
		_toast("+%d GOLDEN COWBELLS! A FRESH PASTURE AWAITS." % gained, Color("#f0a800"))
		_set_tab(Tab.DAIRY)
	else:
		Sfx.play("cant", -10.0)


func _on_sfx_toggle() -> void:
	Farm.sfx_volume = 0.0 if Farm.sfx_volume > 0.0 else 0.8
	Farm.save_game()
	Sfx.play("ui")
	_refresh_all()


# The music player reads Farm.music_volume; this only flips and saves it.
func _on_music_toggle() -> void:
	Farm.music_volume = 0.0 if Farm.music_volume > 0.0 else 0.6
	Farm.save_game()
	Sfx.play("ui")
	_refresh_all()


func _on_milestone(i: int, count: int) -> void:
	var speed: bool = count in Data.SPEED_MILESTONES
	_toast("%s x%d: %s!" % [String(Farm.biz(i)["name"]), count, "DOUBLE SPEED" if speed else "DOUBLE PROFITS"], Color("#f0a800"))
	Sfx.play("milestone")


func _on_rush_started() -> void:
	_toast("MOO RUSH! EVERYTHING EARNS x3!", COL_PINK)
	Sfx.play("rush")
	Sfx.play("moo", -2.0, 0.0)


func _toast(text: String, col: Color) -> void:
	toast_lbl.text = text
	_toast_sb.bg_color = col
	toast_box.visible = true
	toast_box.modulate.a = 1.0
	_toast_t = 2.6
	toast_box.scale = Vector2(0.3, 0.3)
	_boing(toast_box, Vector2.ONE, 0.4, Tween.TRANS_BACK)


# =========================================================================================
# PER-FRAME UPDATE
# =========================================================================================
func _process(delta: float) -> void:
	Farm.tick(delta)
	_t += delta

	if hint_lbl.visible:
		hint_lbl.rotation = sin(_t * 3.0) * 0.05
		hint_lbl.scale = Vector2.ONE * (1.0 + sin(_t * 6.0) * 0.04)

	for f: Dictionary in _floaters:
		var age: float = float(f["max"]) - float(f["life"])
		f["pos"] = (f["pos"] as Vector2) + Vector2(float(f["drift"]), -46.0 * exp(-age * 1.5)) * delta
		f["life"] = float(f["life"]) - delta
	var live_floaters: Array[Dictionary] = []
	for f: Dictionary in _floaters:
		if float(f["life"]) > 0.0:
			live_floaters.append(f)
	_floaters = live_floaters
	fx.queue_redraw()

	if _toast_t > 0.0:
		_toast_t -= delta
		toast_box.modulate.a = clampf(_toast_t / 0.3, 0.0, 1.0)
		if _toast_t <= 0.0:
			toast_box.visible = false

	_refresh_all()


func _refresh_all() -> void:
	money_lbl.text = Fmt.money(Farm.money)
	_set_font_size(money_lbl, _fit_size(money_lbl.get_theme_font("font"), money_lbl.text, money_lbl.size.x, FS_MONEY, 11))
	var rate: float = Farm.idle_income_per_sec() * Farm.rush_mult()
	rate_lbl.text = "%s /SEC FROM FARMHANDS" % Fmt.money(rate) if rate > 0.0 else "HIRE FARMHANDS FOR IDLE INCOME"
	_set_font_size(rate_lbl, _fit_size(rate_lbl.get_theme_font("font"), rate_lbl.text, rate_lbl.size.x, FS_SMALL, 7))
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
		_set_kind(tab_btns[t], "gold" if t == int(tab) else "cream")
		if flags[t] != _tab_flags[t]:
			_tab_flags[t] = flags[t]
			tab_btns[t].queue_redraw()


func _refresh_dairy() -> void:
	for m: int in range(buy_mode_btns.size()):
		_set_kind(buy_mode_btns[m], "green" if m == buy_mode else "cream")
	for i: int in range(Farm.biz_count()):
		var b: Dictionary = Farm.biz(i)
		var own: int = Farm.owned[i]
		var n: int = _buy_count(i)
		var cost: float = Farm.cost_of(i, n)
		biz_buy_btns[i].text = "BUY x%d\n%s" % [n, Fmt.short_money(cost)]
		_set_enabled(biz_buy_btns[i], cost <= Farm.money)
		biz_icon_btns[i].modulate = Color.WHITE if own > 0 else Color(0.62, 0.58, 0.55, 0.8)
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
			if upg_ids[r] != String(u["id"]):
				upg_ids[r] = String(u["id"])
				upg_icons[r].queue_redraw()
			upg_name_lbls[r].text = String(u["name"])
			upg_desc_lbls[r].text = String(u["desc"])
			upg_btns[r].text = "BUY\n%s" % Fmt.short_money(float(u["cost"]))
			_set_enabled(upg_btns[r], Farm.can_buy_upgrade(u))
		else:
			upg_rows[r].visible = false
			upg_ids[r] = ""


func _refresh_farmhands() -> void:
	for i: int in range(Farm.biz_count()):
		var b: Dictionary = Farm.biz(i)
		var cost: float = float(b["farmhand_cost"])
		if Farm.farmhands[i]:
			hand_btns[i].text = "HIRED!"
			_set_kind(hand_btns[i], "hired")
			_set_enabled(hand_btns[i], false)
			hand_faces[i].modulate = Color.WHITE
			hand_sub_lbls[i].text = "RUNS YOUR %s" % String(b["name"])
		else:
			hand_btns[i].text = "HIRE\n%s" % Fmt.short_money(cost)
			_set_kind(hand_btns[i], "red")
			_set_enabled(hand_btns[i], Farm.owned[i] > 0 and Farm.money >= cost)
			hand_faces[i].modulate = Color(1, 1, 1, 0.55)
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
	_set_font_size(move_btn, _fit_size(move_btn.get_theme_font("font"), move_btn.text, move_btn.size.x - 18.0, 13, 8))
	_set_enabled(move_btn, claim > 0)
	sfx_btn.text = "SOUND: %s" % ("ON" if Farm.sfx_volume > 0.0 else "OFF")
	music_btn.text = "MUSIC: %s" % ("ON" if Farm.music_volume > 0.0 else "OFF")


# =========================================================================================
# DRAWING
# =========================================================================================
func _draw_bar_text(c: Control, txt: String, r: Rect2, fsize: int) -> void:
	var font: Font = Art.font_bold
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var y: float = r.size.y * 0.5 + font.get_ascent(fsize) * 0.36
	Art.outlined_text(c, font, Vector2((r.size.x - tw) * 0.5, y), txt, fsize, Color.WHITE, 3)


func _draw_fill(c: Control, r: Rect2, frac: float, sb: StyleBoxFlat) -> void:
	var inner: Rect2 = r.grow(-2.0)
	var w: float = inner.size.x * clampf(frac, 0.0, 1.0)
	if w < 3.0:
		return
	var fr: Rect2 = Rect2(inner.position, Vector2(w, inner.size.y))
	c.draw_style_box(sb, fr)
	if fr.size.x > 8.0:
		c.draw_style_box(_sb_shine, Rect2(fr.position + Vector2(3.0, 1.5), Vector2(fr.size.x - 6.0, maxf(2.0, fr.size.y * 0.3))))


func _draw_biz_bar(bar: Control, i: int) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, bar.size)
	bar.draw_style_box(_sb_track, r)
	if Farm.owned[i] > 0:
		var ct: float = Farm.cycle_time(i)
		var fill: float = 1.0 if ct < 0.2 and (Farm.farmhands[i] or Farm.running[i]) else Farm.progress[i]
		_draw_fill(bar, r, fill, _sb_fill_gold if Farm.rush_left > 0.0 else _sb_fill_green)
		var txt: String = Fmt.money(Farm.revenue(i))
		if ct < 0.2:
			txt = "%s /SEC" % Fmt.money(Farm.revenue(i) / ct)
		_draw_bar_text(bar, txt, r, 9)


func _draw_rush_bar() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, rush_bar.size)
	rush_bar.draw_style_box(_sb_track, r)
	var on: bool = Farm.rush_left > 0.0
	var fill: float = Farm.rush_left / Data.RUSH_SECONDS if on else Farm.rush_meter
	if on:
		_sb_fill_pink.bg_color = COL_PINK.lerp(Color("#ffb3d6"), 0.5 + 0.5 * sin(_t * 12.0))
	else:
		_sb_fill_pink.bg_color = Color("#ef5c9c")
	_draw_fill(rush_bar, r, fill, _sb_fill_pink)
	var txt: String = "MOO RUSH! x3  %s" % Fmt.duration(Farm.rush_left) if on else "MOO RUSH METER (KEEP MILKING!)"
	_draw_bar_text(rush_bar, txt, Rect2(14.0, 0.0, r.size.x - 14.0, r.size.y), 9)
	var beat: float = 1.0 + (0.18 * maxf(0.0, sin(_t * 9.0)) if on else 0.0)
	Art.fill(rush_bar, Art.heart(Vector2(9.0, r.size.y * 0.5), 15.0 * beat, 28), Color("#ff3d6e"), INK, 1.8)


func _draw_tab_badge(b: Button, t: int) -> void:
	if not _tab_flags[t]:
		return
	var c: Vector2 = Vector2(b.size.x - 5.0, 4.0)
	Art.circle(b, c, 7.0, Color("#ff3b3b"), INK, 2.0)
	var font: Font = Art.font_bold
	var tw: float = font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	b.draw_string(font, c + Vector2(-tw * 0.5, 4.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_biz_icon(b: Button, id: String) -> void:
	var dy: float = 1.0 if b.button_pressed else -1.0
	Art.draw_icon(b, id, b.size * 0.5 + Vector2(0.0, dy), 26.0)


func _draw_upgrade_icon(c: Control, r: int) -> void:
	var id: String = upg_ids[r]
	if id == "":
		return
	var u: Dictionary = {}
	for x: Dictionary in Data.UPGRADES:
		if String(x["id"]) == id:
			u = x
			break
	var icon: String = "star"
	match String(u.get("kind", "all")):
		"biz":
			icon = String(Farm.biz(int(u["target"]))["id"])
		"click":
			icon = "drop"
		"click_share":
			icon = "coin"
	Art.draw_icon(c, icon, Vector2(16.0, 16.0), 28.0)


func _draw_fx() -> void:
	var font: Font = Art.font_bold
	for f: Dictionary in _floaters:
		var life: float = float(f["life"])
		var age: float = float(f["max"]) - life
		var s: float = 1.0
		if age < 0.1:
			s = 0.4 + 0.9 * (age / 0.1)
		elif age < 0.24:
			s = 1.3 - 0.3 * ((age - 0.1) / 0.14)
		var a: float = clampf(life / 0.35, 0.0, 1.0)
		var c: Color = f["col"]
		var txt: String = String(f["text"])
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		fx.draw_set_transform(f["pos"] as Vector2, 0.0, Vector2(s, s))
		Art.outlined_text(fx, font, Vector2(-tw * 0.5, 5.0), txt, 15, Color(c.r, c.g, c.b, a), 5, Color(INK.r, INK.g, INK.b, a))
	fx.draw_set_transform_matrix(Transform2D.IDENTITY)


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
	for b: Dictionary in Data.BUSINESSES:
		ok = _check(Art.has_icon(String(b["id"])), "no icon for business " + String(b["id"])) and ok

	# Squeezing and the first sale.
	for k: int in range(5):
		_on_squeeze()
	ok = _check(is_equal_approx(Farm.money, 5.0), "5 squeezes should earn $5, got %f" % Farm.money) and ok
	ok = _check(cow.particle_count() > 0, "squeezing should spray milk") and ok
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

	# Settings: the music toggle flips Farm.music_volume between 0.6 and 0.0.
	Farm.music_volume = 0.6
	_on_music_toggle()
	ok = _check(Farm.music_volume == 0.0, "MUSIC: OFF should set music_volume to 0") and ok
	_on_music_toggle()
	ok = _check(is_equal_approx(Farm.music_volume, 0.6), "MUSIC: ON should set music_volume to 0.6") and ok

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

	# Music: one 8-bar pass renders, isn't silent, and fits the loop length.
	var pcm: PackedByteArray = Music.render_loop(1)
	var loudest: int = 0
	for i: int in range(0, pcm.size() - 2, 4 * 97):
		loudest = maxi(loudest, absi(pcm.decode_s16(i)))
	ok = _check(pcm.size() > 22050 * 4 * 10 and loudest > 3000, "music render is empty or silent (%d bytes, peak %d)" % [pcm.size(), loudest]) and ok
	# Sound effects: every take of the milking squeeze and the moo exists.
	var sq: Array = Sfx._variants.get("squirt", [])
	var moo: Array = Sfx._variants.get("moo", [])
	ok = _check(sq.size() >= 3 and moo.size() >= 3, "missing squeeze or moo takes") and ok

	# Let a few real frames run so every draw callback (cow, farm, bars, icons, MOO RUSH,
	# the welcome-back popup) executes at least once.
	Farm.rush_left = 2.0
	_show_offline(1234.5, 3725)
	for t: int in range(4):
		_set_tab(t)
		_on_squeeze()
		await get_tree().process_frame
	_hide_offline()
	await get_tree().process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_test_save.json"))
	if ok:
		print("UDDERLY_SMOKE_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("UDDERLY_SMOKE_TEST_FAILED")
		get_tree().quit(1)
