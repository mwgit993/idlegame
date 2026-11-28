extends Node

# The whole game state and economy: money, businesses, farmhands, upgrades, MOO RUSH,
# golden cowbells, offline earnings and the save file. main.gd only draws it and forwards
# clicks. Balance numbers are in game_data.gd.
#
# There are three animals (Data.ANIMALS): the cow, the hen and the monkey. Each has its own
# part of the farm, a Pen, with its own money, businesses, farmhands, upgrades, rush meter and
# golden items (cowbells, eggs, bananas). Every pen earns all the time, also while you look at
# another animal and while the game is closed. The fields and functions below (money, owned,
# buy(), squeeze()...) are the pen on screen, `pen`; switch with set_animal(). An animal opens
# once the previous one holds enough golden items (Data.ANIMALS "needs" / "needs_gold").

const Data = preload("res://scripts/game_data.gd")
const Fmt = preload("res://scripts/num_fmt.gd")
const SAVE_VERSION: int = 2
const AUTOSAVE_SECONDS: float = 10.0

# These fire for the animal on screen only.
signal milestone_reached(biz_idx: int, count: int)
signal rush_started
signal rush_ended
signal business_paid(biz_idx: int, amount: float)
# An animal's part of the farm just opened (any animal, on screen or not).
signal animal_opened(animal: int)


# One animal's part of the farm and its economy.
class Pen:
	extends RefCounted

	var farm: Node
	var index: int = 0
	var info: Dictionary = {}
	var defs: Array[Dictionary] = []      # its businesses
	var upgrade_defs: Array[Dictionary] = []
	var open: bool = false
	var money: float = 0.0
	var pasture_earned: float = 0.0       # since the last prestige
	var total_earned: float = 0.0         # all time; decides how many golden items you've earned
	var owned: Array[int] = []
	var farmhands: Array[bool] = []
	var progress: Array[float] = []       # 0..1 through the current cycle
	var running: Array[bool] = []         # a manually started cycle is in progress
	var upgrades: Dictionary = {}         # upgrade id -> true
	var gold: int = 0                     # golden cowbells / eggs / bananas
	var clicks: int = 0
	var moves: int = 0                    # prestiges
	var rush_meter: float = 0.0
	var rush_left: float = 0.0
	var offline_earned: float = 0.0       # what its farmhands made while the game was closed
	var _biz_mult: Array[float] = []      # upgrade multipliers, rebuilt when one is bought
	var _click_mult: float = 1.0
	var _click_share: float = 0.0

	func _init(f: Node, i: int) -> void:
		farm = f
		index = i
		info = Data.ANIMALS[i]
		var b: Array = info["businesses"]
		for d: Variant in b:
			defs.append(d as Dictionary)
		var u: Array = info["upgrades"]
		for d2: Variant in u:
			upgrade_defs.append(d2 as Dictionary)
		open = int(info["needs"]) < 0
		reset()

	func on_screen() -> bool:
		return farm.pen == self

	# A fresh start: one of the first business, no money, no farmhands, no upgrades. Golden
	# items and lifetime stats stay.
	func reset() -> void:
		money = 0.0
		pasture_earned = 0.0
		owned.clear()
		farmhands.clear()
		progress.clear()
		running.clear()
		for i: int in range(defs.size()):
			owned.append(1 if i == 0 else 0)
			farmhands.append(false)
			progress.append(0.0)
			running.append(false)
		upgrades.clear()
		rush_meter = 0.0
		rush_left = 0.0
		rebuild_multipliers()

	# --- Prices ---

	func cost_of(i: int, count: int) -> float:
		var b: Dictionary = defs[i]
		var g: float = float(b["growth"])
		var first: float = float(b["cost"]) * pow(g, float(owned[i]))
		return first * (pow(g, float(count)) - 1.0) / (g - 1.0)

	func max_affordable(i: int) -> int:
		var b: Dictionary = defs[i]
		var g: float = float(b["growth"])
		var first: float = float(b["cost"]) * pow(g, float(owned[i]))
		if money < first:
			return 0
		var n: int = int(floor(log(money * (g - 1.0) / first + 1.0) / log(g)))
		while n > 0 and cost_of(i, n) > money:
			n -= 1
		return n

	func buy(i: int, count: int) -> bool:
		if count <= 0:
			return false
		var c: float = cost_of(i, count)
		if c > money:
			return false
		money -= c
		var before: int = owned[i]
		owned[i] += count
		for m: int in Data.SPEED_MILESTONES + Data.PROFIT_MILESTONES:
			if before < m and owned[i] >= m and on_screen():
				farm.milestone_reached.emit(i, m)
		return true

	func hire(i: int) -> bool:
		var c: float = float(defs[i]["farmhand_cost"])
		if farmhands[i] or owned[i] <= 0 or money < c:
			return false
		money -= c
		farmhands[i] = true
		return true

	func can_buy_upgrade(u: Dictionary) -> bool:
		return not upgrades.has(String(u["id"])) and money >= float(u["cost"])

	func buy_upgrade(id: String) -> bool:
		for u: Dictionary in upgrade_defs:
			if String(u["id"]) == id:
				if not can_buy_upgrade(u):
					return false
				money -= float(u["cost"])
				upgrades[id] = true
				rebuild_multipliers()
				return true
		return false

	# --- Earnings ---

	func rebuild_multipliers() -> void:
		_biz_mult.clear()
		for i: int in range(defs.size()):
			_biz_mult.append(1.0)
		_click_mult = 1.0
		_click_share = 0.0
		for u: Dictionary in upgrade_defs:
			if not upgrades.has(String(u["id"])):
				continue
			var v: float = float(u["value"])
			match String(u["kind"]):
				"biz":
					_biz_mult[int(u["target"])] *= v
				"all":
					for i: int in range(defs.size()):
						_biz_mult[i] *= v
				"click":
					_click_mult *= v
				"click_share":
					_click_share += v

	func gold_mult() -> float:
		return 1.0 + Data.BELL_BONUS * float(gold)

	func rush_mult() -> float:
		return Data.RUSH_MULT if rush_left > 0.0 else 1.0

	func speed_level(i: int) -> int:
		var lvl: int = 0
		for m: int in Data.SPEED_MILESTONES:
			if owned[i] >= m:
				lvl += 1
		return lvl

	func cycle_time(i: int) -> float:
		return float(defs[i]["time"]) / pow(2.0, float(speed_level(i)))

	func profit_mult(i: int) -> float:
		var m: float = _biz_mult[i] * gold_mult()
		for pm: int in Data.PROFIT_MILESTONES:
			if owned[i] >= pm:
				m *= 2.0
		return m

	func revenue(i: int) -> float:
		return float(defs[i]["revenue"]) * float(owned[i]) * profit_mult(i) * rush_mult()

	func income_per_sec(idle_only: bool = false) -> float:
		var total: float = 0.0
		for i: int in range(defs.size()):
			if owned[i] > 0 and (farmhands[i] or not idle_only):
				total += float(defs[i]["revenue"]) * float(owned[i]) * profit_mult(i) / cycle_time(i)
		return total

	func click_value() -> float:
		return (Data.BASE_CLICK * _click_mult + income_per_sec() * _click_share) * gold_mult() * rush_mult()

	func earn(amount: float) -> void:
		money += amount
		pasture_earned += amount
		total_earned += amount

	func click() -> float:
		var v: float = click_value()
		earn(v)
		clicks += 1
		if rush_left <= 0.0:
			rush_meter = minf(1.0, rush_meter + Data.RUSH_PER_CLICK)
			if rush_meter >= 1.0:
				rush_meter = 0.0
				rush_left = Data.RUSH_SECONDS
				if on_screen():
					farm.rush_started.emit()
		return v

	func start_cycle(i: int) -> bool:
		if owned[i] <= 0 or farmhands[i] or running[i]:
			return false
		running[i] = true
		return true

	func tick(dt: float) -> void:
		if rush_left > 0.0:
			rush_left -= dt
			if rush_left <= 0.0:
				rush_left = 0.0
				if on_screen():
					farm.rush_ended.emit()
		else:
			rush_meter = maxf(0.0, rush_meter - Data.RUSH_DECAY_PER_SEC * dt)
		for i: int in range(defs.size()):
			if owned[i] <= 0 or not (farmhands[i] or running[i]):
				continue
			progress[i] += dt / cycle_time(i)
			if progress[i] < 1.0:
				continue
			var paid: float = 0.0
			if farmhands[i]:
				var cycles: float = floorf(progress[i])
				progress[i] -= cycles
				paid = revenue(i) * cycles
			else:
				progress[i] = 0.0
				running[i] = false
				paid = revenue(i)
			earn(paid)
			if on_screen():
				farm.business_paid.emit(i, paid)

	# --- Golden items (prestige) ---

	func gold_for_total(earned: float) -> int:
		return int(floor(float(info["gold_scale"]) * sqrt(maxf(0.0, earned) / float(info["gold_unit"]))))

	func claimable_gold() -> int:
		return maxi(0, gold_for_total(total_earned) - gold)

	func earned_for_next_gold() -> float:
		var target: float = float(gold_for_total(total_earned) + 1)
		return float(info["gold_unit"]) * pow(target / float(info["gold_scale"]), 2.0)

	func prestige() -> int:
		var gained: int = claimable_gold()
		if gained <= 0:
			return 0
		gold += gained
		moves += 1
		reset()
		return gained

	# --- Saving ---

	func to_dict() -> Dictionary:
		return {"open": open, "money": money, "pasture_earned": pasture_earned, "total_earned": total_earned,
			"owned": owned, "farmhands": farmhands, "progress": progress, "upgrades": upgrades.keys(),
			"gold": gold, "clicks": clicks, "moves": moves}

	func from_dict(d: Dictionary) -> void:
		reset()
		open = open or bool(d.get("open", false))
		money = float(d.get("money", 0.0))
		pasture_earned = float(d.get("pasture_earned", 0.0))
		total_earned = float(d.get("total_earned", 0.0))
		var o: Array = d.get("owned", [])
		var fh: Array = d.get("farmhands", [])
		var pr: Array = d.get("progress", [])
		for i: int in range(defs.size()):
			if i < o.size():
				owned[i] = maxi(0, int(o[i]))
			if i < fh.size():
				farmhands[i] = bool(fh[i])
			if i < pr.size():
				progress[i] = clampf(float(pr[i]), 0.0, 0.999)
			running[i] = false
		upgrades.clear()
		var ups: Array = d.get("upgrades", [])
		for id: Variant in ups:
			upgrades[String(id)] = true
		rebuild_multipliers()
		gold = maxi(0, int(d.get("gold", 0)))
		clicks = int(d.get("clicks", 0))
		moves = int(d.get("moves", 0))


var save_path: String = "user://udderly_save.json"

var pens: Array[Pen] = []
var pen: Pen                       # the animal on screen
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var fullscreen: bool = false  # Settings -> DISPLAY; apply_display() applies it
var last_offline_earned: float = 0.0  # the animal on screen at load; each pen has offline_earned
var last_offline_seconds: int = 0

var _autosave_timer: float = 0.0

# The animal on screen's state. Arrays are the pen's own, so Farm.owned[i] += 1 works.
var animal: int:
	get: return pen.index
var money: float:
	get: return pen.money
	set(v): pen.money = v
var pasture_earned: float:
	get: return pen.pasture_earned
	set(v): pen.pasture_earned = v
var total_earned: float:
	get: return pen.total_earned
	set(v): pen.total_earned = v
var owned: Array[int]:
	get: return pen.owned
var farmhands: Array[bool]:
	get: return pen.farmhands
var progress: Array[float]:
	get: return pen.progress
var running: Array[bool]:
	get: return pen.running
var upgrades: Dictionary:
	get: return pen.upgrades
var bells: int:  # golden cowbells for the cow, golden eggs for the hen, golden bananas for the monkey
	get: return pen.gold
	set(v): pen.gold = v
var total_clicks: int:
	get: return pen.clicks
	set(v): pen.clicks = v
var pastures_moved: int:
	get: return pen.moves
	set(v): pen.moves = v
var rush_meter: float:
	get: return pen.rush_meter
	set(v): pen.rush_meter = v
var rush_left: float:
	get: return pen.rush_left
	set(v): pen.rush_left = v


func _init() -> void:
	for i: int in range(Data.ANIMALS.size()):
		pens.append(Pen.new(self, i))
	pen = pens[0]


func _ready() -> void:
	if "--smoke-test" not in OS.get_cmdline_user_args():
		load_game()
		fit_window_to_screen()
		apply_display()


# The window opens at 1280x720 (the project setting), which is small on a 1440p or 4K screen.
# Grow it to about 80% of the screen, keeping 16:9, and centre it. Everything is drawn as
# vectors at the real window resolution, so a bigger window is sharper, not blurrier. This
# never shrinks the window. It runs before apply_display(), so leaving fullscreen comes back
# to this size.
func fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var area: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var k: float = minf(float(area.size.x) * 0.8 / 640.0, float(area.size.y) * 0.8 / 360.0)
	var want: Vector2i = Vector2i(roundi(640.0 * k), roundi(360.0 * k))
	if want.x <= DisplayServer.window_get_size().x:
		return
	DisplayServer.window_set_size(want)
	DisplayServer.window_set_position(area.position + (area.size - want) / 2)


# Puts the window in or out of fullscreen to match `fullscreen`. A maximized window counts as
# windowed and is left alone.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fs: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_fs != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# True if the window is fullscreen right now (the player may have used the OS's own button).
func window_is_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless":
		return fullscreen
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# --- Animals --------------------------------------------------------------------------------

func animal_count() -> int:
	return pens.size()


# The Data.ANIMALS entry (names and texts) for animal a, or the one on screen.
func info(a: int = -1) -> Dictionary:
	return pens[a].info if a >= 0 else pen.info


func is_open(a: int) -> bool:
	return pens[a].open


# Switches the screen to animal a. Returns false if it isn't open yet.
func set_animal(a: int) -> bool:
	if a < 0 or a >= pens.size() or not pens[a].open:
		return false
	pen = pens[a]
	return true


# Opens every animal whose requirement is met. Called after anything that changes golden items.
func check_unlocks() -> void:
	for p: Pen in pens:
		if p.open:
			continue
		var need: int = int(p.info["needs"])
		if need >= 0 and pens[need].gold >= int(p.info["needs_gold"]):
			p.open = true
			animal_opened.emit(p.index)


# "20 GOLDEN COWBELLS" for animal a's requirement.
func unlock_text(a: int) -> String:
	var need: int = int(pens[a].info["needs"])
	if need < 0:
		return ""
	return "%d %s" % [int(pens[a].info["needs_gold"]), String(pens[need].info["gold"])]


# --- The animal on screen -------------------------------------------------------------------

func biz_count() -> int:
	return pen.defs.size()


func biz(i: int) -> Dictionary:
	return pen.defs[i]


func upgrade_list() -> Array[Dictionary]:
	return pen.upgrade_defs


func reset_pasture() -> void:
	pen.reset()


func cost_of(i: int, count: int) -> float:
	return pen.cost_of(i, count)


# How many units of business i the current money buys (0 if not even one).
func max_affordable(i: int) -> int:
	return pen.max_affordable(i)


# Units needed to reach business i's next milestone (or 1 past the last one).
func to_next_milestone(i: int) -> int:
	for m: int in Data.SPEED_MILESTONES + Data.PROFIT_MILESTONES:
		if pen.owned[i] < m:
			return m - pen.owned[i]
	return 1


func buy(i: int, count: int) -> bool:
	return pen.buy(i, count)


func hire(i: int) -> bool:
	return pen.hire(i)


func can_buy_upgrade(u: Dictionary) -> bool:
	return pen.can_buy_upgrade(u)


func buy_upgrade(id: String) -> bool:
	return pen.buy_upgrade(id)


func bell_mult() -> float:
	return pen.gold_mult()


func rush_mult() -> float:
	return pen.rush_mult()


func speed_level(i: int) -> int:
	return pen.speed_level(i)


func cycle_time(i: int) -> float:
	return pen.cycle_time(i)


func profit_mult(i: int) -> float:
	return pen.profit_mult(i)


# What one cycle of business i pays right now (rush included).
func revenue(i: int) -> float:
	return pen.revenue(i)


# Income per second if every owned business ran nonstop (without the rush).
func income_per_sec() -> float:
	return pen.income_per_sec()


# Income per second from businesses that run by themselves (have a farmhand).
func idle_income_per_sec() -> float:
	return pen.income_per_sec(true)


func click_value() -> float:
	return pen.click_value()


func earn(amount: float) -> void:
	pen.earn(amount)


# Click the animal on screen (squeeze the udder, pat the hen, pick a banana). Returns what it earned.
func squeeze() -> float:
	return pen.click()


# Click a business: starts its cycle if it has no farmhand and isn't already running.
func start_cycle(i: int) -> bool:
	return pen.start_cycle(i)


# Every animal earns, not just the one on screen.
func tick(dt: float) -> void:
	for p: Pen in pens:
		if p.open:
			p.tick(dt)
	check_unlocks()
	_autosave_timer += dt
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()


func bells_for_total(earned: float) -> int:
	return pen.gold_for_total(earned)


func claimable_bells() -> int:
	return pen.claimable_gold()


# Earnings needed (all time) for the next golden item to become claimable.
func earned_for_next_bell() -> float:
	return pen.earned_for_next_gold()


# Prestige the animal on screen (move pasture, build a bigger hen house...). Returns the
# golden items gained.
func move_pasture() -> int:
	var gained: int = pen.prestige()
	if gained > 0:
		check_unlocks()
		save_game()
	return gained


# --- Offline earnings and saving ----------------------------------------------------------

# Pays what every animal's farmhands would have made in `seconds` (rushes don't run offline).
# Returns what the animal on screen made; each pen keeps its own in offline_earned.
func apply_offline(seconds: float) -> float:
	for p: Pen in pens:
		p.offline_earned = 0.0
		if seconds <= 1.0 or not p.open:
			continue
		var earned: float = p.income_per_sec(true) * seconds
		if earned > 0.0:
			p.earn(earned)
			p.offline_earned = earned
	return pen.offline_earned


func save_game() -> void:
	var animals: Array[Dictionary] = []
	for p: Pen in pens:
		animals.append(p.to_dict())
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"animal": pen.index,
		"animals": animals,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"fullscreen": fullscreen,
		"number_style": Fmt.style,
	}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> void:
	last_offline_earned = 0.0
	last_offline_seconds = 0
	if not FileAccess.file_exists(save_path):
		return
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	for p: Pen in pens:
		p.open = int(p.info["needs"]) < 0
		p.gold = 0
		p.clicks = 0
		p.moves = 0
		p.total_earned = 0.0
		p.reset()
	if int(d.get("version", 1)) < 2:
		# Version 1 was the cow alone, with her fields at the top level.
		pens[0].from_dict({"money": d.get("money", 0.0), "pasture_earned": d.get("pasture_earned", 0.0),
			"total_earned": d.get("total_earned", 0.0), "owned": d.get("owned", []), "farmhands": d.get("farmhands", []),
			"progress": d.get("progress", []), "upgrades": d.get("upgrades", []), "gold": d.get("bells", 0),
			"clicks": d.get("total_clicks", 0), "moves": d.get("pastures_moved", 0)})
	else:
		var animals: Array = d.get("animals", [])
		for i: int in range(mini(animals.size(), pens.size())):
			if typeof(animals[i]) == TYPE_DICTIONARY:
				pens[i].from_dict(animals[i] as Dictionary)
	check_unlocks()
	pen = pens[0]
	set_animal(int(d.get("animal", 0)))
	sfx_volume = clampf(float(d.get("sfx_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", 0.6)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", false))
	Fmt.style = clampi(int(d.get("number_style", 0)), 0, Fmt.STYLE_COUNT - 1)
	var saved_at: int = int(d.get("saved_at", 0))
	var away: int = int(Time.get_unix_time_from_system()) - saved_at
	if saved_at > 0 and away > 0:
		last_offline_seconds = away
		last_offline_earned = apply_offline(float(away))


# Settings -> DELETE SAVE: a brand-new farm with no golden items, stats or extra animals.
# Settings (volume, fullscreen, number style) are kept.
func reset_save() -> void:
	last_offline_earned = 0.0
	last_offline_seconds = 0
	for p: Pen in pens:
		p.open = int(p.info["needs"]) < 0
		p.gold = 0
		p.total_earned = 0.0
		p.clicks = 0
		p.moves = 0
		p.offline_earned = 0.0
		p.reset()
	pen = pens[0]
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if "--smoke-test" not in OS.get_cmdline_user_args():
			save_game()
