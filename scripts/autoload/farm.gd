extends Node

# The whole game state and economy: money, businesses, farmhands, upgrades, MOO RUSH,
# golden cowbells, offline earnings and the save file. main.gd only draws it and forwards
# clicks. Balance numbers are in game_data.gd.

const Data = preload("res://scripts/game_data.gd")
const Fmt = preload("res://scripts/num_fmt.gd")
const SAVE_VERSION: int = 1
const AUTOSAVE_SECONDS: float = 10.0

signal milestone_reached(biz_idx: int, count: int)
signal rush_started
signal rush_ended
signal business_paid(biz_idx: int, amount: float)

var save_path: String = "user://udderly_save.json"

var money: float = 0.0
var pasture_earned: float = 0.0 # since the last move to a bigger pasture
var total_earned: float = 0.0   # all time; decides how many golden cowbells you've earned
var owned: Array[int] = []
var farmhands: Array[bool] = []
var progress: Array[float] = []  # 0..1 through the current cycle
var running: Array[bool] = []    # a manually started cycle is in progress
var upgrades: Dictionary = {}    # upgrade id -> true
var bells: int = 0
var total_clicks: int = 0
var pastures_moved: int = 0
var rush_meter: float = 0.0
var rush_left: float = 0.0
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var fullscreen: bool = false  # Settings -> DISPLAY; apply_display() applies it
var last_offline_earned: float = 0.0
var last_offline_seconds: int = 0

var _autosave_timer: float = 0.0
# Upgrade-derived multipliers, rebuilt whenever an upgrade is bought.
var _biz_mult: Array[float] = []
var _click_mult: float = 1.0
var _click_share: float = 0.0


func _ready() -> void:
	reset_pasture()
	if "--smoke-test" not in OS.get_cmdline_user_args():
		load_game()
		apply_display()


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


func biz_count() -> int:
	return Data.BUSINESSES.size()


func biz(i: int) -> Dictionary:
	return Data.BUSINESSES[i]


# A fresh pasture: one milk pail stand, no money, no farmhands, no upgrades. Bells and
# lifetime stats stay.
func reset_pasture() -> void:
	var n: int = biz_count()
	money = 0.0
	pasture_earned = 0.0
	owned.clear()
	farmhands.clear()
	progress.clear()
	running.clear()
	for i: int in range(n):
		owned.append(1 if i == 0 else 0)
		farmhands.append(false)
		progress.append(0.0)
		running.append(false)
	upgrades.clear()
	rush_meter = 0.0
	rush_left = 0.0
	_rebuild_multipliers()


# --- Prices -------------------------------------------------------------------------------

func cost_of(i: int, count: int) -> float:
	var b: Dictionary = biz(i)
	var g: float = float(b["growth"])
	var first: float = float(b["cost"]) * pow(g, float(owned[i]))
	return first * (pow(g, float(count)) - 1.0) / (g - 1.0)


# How many units of business i the current money buys (0 if not even one).
func max_affordable(i: int) -> int:
	var b: Dictionary = biz(i)
	var g: float = float(b["growth"])
	var first: float = float(b["cost"]) * pow(g, float(owned[i]))
	if money < first:
		return 0
	var n: int = int(floor(log(money * (g - 1.0) / first + 1.0) / log(g)))
	while n > 0 and cost_of(i, n) > money:
		n -= 1
	return n


# Units needed to reach business i's next milestone (or 1 past the last one).
func to_next_milestone(i: int) -> int:
	for m: int in Data.SPEED_MILESTONES + Data.PROFIT_MILESTONES:
		if owned[i] < m:
			return m - owned[i]
	return 1


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
		if before < m and owned[i] >= m:
			milestone_reached.emit(i, m)
	return true


func hire(i: int) -> bool:
	var c: float = float(biz(i)["farmhand_cost"])
	if farmhands[i] or owned[i] <= 0 or money < c:
		return false
	money -= c
	farmhands[i] = true
	return true


func can_buy_upgrade(u: Dictionary) -> bool:
	return not upgrades.has(String(u["id"])) and money >= float(u["cost"])


func buy_upgrade(id: String) -> bool:
	for u: Dictionary in Data.UPGRADES:
		if String(u["id"]) == id:
			if not can_buy_upgrade(u):
				return false
			money -= float(u["cost"])
			upgrades[id] = true
			_rebuild_multipliers()
			return true
	return false


# --- Earnings -----------------------------------------------------------------------------

func _rebuild_multipliers() -> void:
	_biz_mult.clear()
	for i: int in range(biz_count()):
		_biz_mult.append(1.0)
	_click_mult = 1.0
	_click_share = 0.0
	for u: Dictionary in Data.UPGRADES:
		if not upgrades.has(String(u["id"])):
			continue
		var v: float = float(u["value"])
		match String(u["kind"]):
			"biz":
				var t: int = int(u["target"])
				_biz_mult[t] *= v
			"all":
				for i: int in range(biz_count()):
					_biz_mult[i] *= v
			"click":
				_click_mult *= v
			"click_share":
				_click_share += v


func bell_mult() -> float:
	return 1.0 + Data.BELL_BONUS * float(bells)


func rush_mult() -> float:
	return Data.RUSH_MULT if rush_left > 0.0 else 1.0


func speed_level(i: int) -> int:
	var lvl: int = 0
	for m: int in Data.SPEED_MILESTONES:
		if owned[i] >= m:
			lvl += 1
	return lvl


func cycle_time(i: int) -> float:
	return float(biz(i)["time"]) / pow(2.0, float(speed_level(i)))


func profit_mult(i: int) -> float:
	var m: float = _biz_mult[i] * bell_mult()
	for pm: int in Data.PROFIT_MILESTONES:
		if owned[i] >= pm:
			m *= 2.0
	return m


# What one cycle of business i pays right now (MOO RUSH included).
func revenue(i: int) -> float:
	return float(biz(i)["revenue"]) * float(owned[i]) * profit_mult(i) * rush_mult()


# Income per second if every owned business ran nonstop (without MOO RUSH).
func income_per_sec() -> float:
	var total: float = 0.0
	for i: int in range(biz_count()):
		if owned[i] > 0:
			total += float(biz(i)["revenue"]) * float(owned[i]) * profit_mult(i) / cycle_time(i)
	return total


# Income per second from businesses that run by themselves (have a farmhand).
func idle_income_per_sec() -> float:
	var total: float = 0.0
	for i: int in range(biz_count()):
		if owned[i] > 0 and farmhands[i]:
			total += float(biz(i)["revenue"]) * float(owned[i]) * profit_mult(i) / cycle_time(i)
	return total


func click_value() -> float:
	return (Data.BASE_CLICK * _click_mult + income_per_sec() * _click_share) * bell_mult() * rush_mult()


func earn(amount: float) -> void:
	money += amount
	pasture_earned += amount
	total_earned += amount


# Squeeze the udder. Returns what it earned.
func squeeze() -> float:
	var v: float = click_value()
	earn(v)
	total_clicks += 1
	if rush_left <= 0.0:
		rush_meter = minf(1.0, rush_meter + Data.RUSH_PER_CLICK)
		if rush_meter >= 1.0:
			rush_meter = 0.0
			rush_left = Data.RUSH_SECONDS
			rush_started.emit()
	return v


# Click a business: starts its cycle if it has no farmhand and isn't already running.
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
			rush_ended.emit()
	else:
		rush_meter = maxf(0.0, rush_meter - Data.RUSH_DECAY_PER_SEC * dt)

	for i: int in range(biz_count()):
		if owned[i] <= 0 or not (farmhands[i] or running[i]):
			continue
		progress[i] += dt / cycle_time(i)
		if progress[i] < 1.0:
			continue
		if farmhands[i]:
			var cycles: float = floorf(progress[i])
			progress[i] -= cycles
			var paid: float = revenue(i) * cycles
			earn(paid)
			business_paid.emit(i, paid)
		else:
			progress[i] = 0.0
			running[i] = false
			var paid1: float = revenue(i)
			earn(paid1)
			business_paid.emit(i, paid1)

	_autosave_timer += dt
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()


# --- Golden cowbells (prestige) -----------------------------------------------------------

func bells_for_total(earned: float) -> int:
	return int(floor(Data.BELL_SCALE * sqrt(maxf(0.0, earned) / Data.BELL_UNIT)))


func claimable_bells() -> int:
	return maxi(0, bells_for_total(total_earned) - bells)


# Earnings needed (all time) for the next bell to become claimable.
func earned_for_next_bell() -> float:
	var target: float = float(bells_for_total(total_earned) + 1)
	return Data.BELL_UNIT * pow(target / Data.BELL_SCALE, 2.0)


func move_pasture() -> int:
	var gained: int = claimable_bells()
	if gained <= 0:
		return 0
	bells += gained
	pastures_moved += 1
	reset_pasture()
	save_game()
	return gained


# --- Offline earnings and saving ----------------------------------------------------------

# Pays what the farmhands would have made in `seconds` (MOO RUSH doesn't run offline).
func apply_offline(seconds: float) -> float:
	if seconds <= 1.0:
		return 0.0
	var earned: float = idle_income_per_sec() * seconds
	if earned > 0.0:
		earn(earned)
	return earned


func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"money": money,
		"pasture_earned": pasture_earned,
		"total_earned": total_earned,
		"owned": owned,
		"farmhands": farmhands,
		"progress": progress,
		"upgrades": upgrades.keys(),
		"bells": bells,
		"total_clicks": total_clicks,
		"pastures_moved": pastures_moved,
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
	reset_pasture()
	money = float(d.get("money", 0.0))
	pasture_earned = float(d.get("pasture_earned", 0.0))
	total_earned = float(d.get("total_earned", 0.0))
	var o: Array = d.get("owned", [])
	var fh: Array = d.get("farmhands", [])
	var pr: Array = d.get("progress", [])
	for i: int in range(biz_count()):
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
	_rebuild_multipliers()
	bells = maxi(0, int(d.get("bells", 0)))
	total_clicks = int(d.get("total_clicks", 0))
	pastures_moved = int(d.get("pastures_moved", 0))
	sfx_volume = clampf(float(d.get("sfx_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", 0.6)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", false))
	Fmt.style = clampi(int(d.get("number_style", 0)), 0, Fmt.STYLE_COUNT - 1)
	var saved_at: int = int(d.get("saved_at", 0))
	var away: int = int(Time.get_unix_time_from_system()) - saved_at
	if saved_at > 0 and away > 0:
		last_offline_seconds = away
		last_offline_earned = apply_offline(float(away))


func reset_save() -> void:
	bells = 0
	total_earned = 0.0
	total_clicks = 0
	pastures_moved = 0
	reset_pasture()
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if "--smoke-test" not in OS.get_cmdline_user_args():
			save_game()
