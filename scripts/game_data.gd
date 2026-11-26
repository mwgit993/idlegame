extends RefCounted

# All balance numbers for Udderly Idle live here. Nothing in this file runs; Farm reads it.
#
# A business earns `revenue` x owned every `time` seconds. Its price for the next unit is
# `cost` x `growth` ^ owned. Before you hire its farmhand you click the business to start
# each cycle; after, it runs by itself (and keeps earning while the game is closed).

const BUSINESSES: Array[Dictionary] = [
	{"id": "pail", "name": "MILK PAIL STAND", "cost": 5.0, "growth": 1.07, "revenue": 1.5, "time": 1.0,
		"farmhand": "FARMER FRAN", "farmhand_cost": 1000.0},
	{"id": "churn", "name": "BUTTER CHURN", "cost": 75.0, "growth": 1.14, "revenue": 40.0, "time": 3.0,
		"farmhand": "BUTTER BOB", "farmhand_cost": 15000.0},
	{"id": "cheese", "name": "CHEESE CAVE", "cost": 900.0, "growth": 1.13, "revenue": 350.0, "time": 6.0,
		"farmhand": "CHEDDAR CHARLIE", "farmhand_cost": 100000.0},
	{"id": "icecream", "name": "ICE CREAM CART", "cost": 11000.0, "growth": 1.12, "revenue": 3000.0, "time": 12.0,
		"farmhand": "SCOOPS MCGEE", "farmhand_cost": 500000.0},
	{"id": "yogurt", "name": "YOGURT WORKS", "cost": 140000.0, "growth": 1.115, "revenue": 32000.0, "time": 25.0,
		"farmhand": "CULTURED CLAIRE", "farmhand_cost": 1.2e6},
	{"id": "diner", "name": "MILKSHAKE DINER", "cost": 1.8e6, "growth": 1.11, "revenue": 400000.0, "time": 60.0,
		"farmhand": "SHAKE SHELLY", "farmhand_cost": 1.0e7},
	{"id": "cosmic", "name": "COSMIC CREAMERY", "cost": 2.5e7, "growth": 1.10, "revenue": 6.0e6, "time": 180.0,
		"farmhand": "CAPTAIN MOO", "farmhand_cost": 1.11e8},
	{"id": "moon", "name": "MOON COW RANCH", "cost": 4.0e8, "growth": 1.09, "revenue": 1.1e8, "time": 600.0,
		"farmhand": "LUNA THE LUNAR COW", "farmhand_cost": 5.55e8},
]

# Owning this many of one business doubles its speed (halves its cycle time) each time...
const SPEED_MILESTONES: Array[int] = [25, 50, 100, 200, 300, 400]
# ...and these double its profits.
const PROFIT_MILESTONES: Array[int] = [500, 600, 700, 800, 900, 1000]

# Upgrades. kind: "biz" multiplies one business's profits ("target" = business index),
# "all" multiplies every business, "click" multiplies what a squeeze earns, and
# "click_share" makes each squeeze also earn that fraction of your income per second.
const UPGRADES: Array[Dictionary] = [
	{"id": "warm_hands", "name": "WARM HANDS", "desc": "SQUEEZES EARN x2", "cost": 50.0, "kind": "click", "value": 2.0},
	{"id": "stool", "name": "MILKING STOOL", "desc": "SQUEEZES EARN x2", "cost": 500.0, "kind": "click", "value": 2.0},
	{"id": "shiny_pails", "name": "SHINY PAILS", "desc": "MILK PAIL STAND PROFITS x3", "cost": 2500.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "two_hands", "name": "TWO-HANDED MILKING", "desc": "SQUEEZES ALSO EARN 5% OF INCOME/SEC", "cost": 5000.0, "kind": "click_share", "value": 0.05},
	{"id": "paddles", "name": "FASTER PADDLES", "desc": "BUTTER CHURN PROFITS x3", "cost": 30000.0, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "gloves", "name": "MILKING GLOVES", "desc": "SQUEEZES EARN x3", "cost": 250000.0, "kind": "click", "value": 3.0},
	{"id": "cheddar", "name": "AGED CHEDDAR", "desc": "CHEESE CAVE PROFITS x3", "cost": 250000.0, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "bigger_pails", "name": "BIGGER PAILS", "desc": "MILK PAIL STAND PROFITS x3", "cost": 500000.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "sprinkles", "name": "SPRINKLES", "desc": "ICE CREAM CART PROFITS x3", "cost": 2.0e6, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "salted", "name": "SALTED BUTTER", "desc": "BUTTER CHURN PROFITS x3", "cost": 4.0e6, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "fruit", "name": "FRUIT ON THE BOTTOM", "desc": "YOGURT WORKS PROFITS x3", "cost": 2.0e7, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "caves2", "name": "DEEPER CAVES", "desc": "CHEESE CAVE PROFITS x3", "cost": 3.0e7, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "balm", "name": "UDDER BALM", "desc": "SQUEEZES ALSO EARN 10% OF INCOME/SEC", "cost": 5.0e7, "kind": "click_share", "value": 0.10},
	{"id": "happy_cows", "name": "HAPPY COWS", "desc": "ALL PROFITS x3", "cost": 1.0e8, "kind": "all", "value": 3.0},
	{"id": "thick", "name": "EXTRA THICK SHAKES", "desc": "MILKSHAKE DINER PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "cones", "name": "WAFFLE CONES", "desc": "ICE CREAM CART PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "golden_pails", "name": "GOLDEN PAILS", "desc": "MILK PAIL STAND PROFITS x3", "cost": 5.0e8, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "zero_g", "name": "ZERO-G CHURNS", "desc": "COSMIC CREAMERY PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "diamond_churn", "name": "DIAMOND CHURN", "desc": "BUTTER CHURN PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "greek", "name": "GREEK YOGURT", "desc": "YOGURT WORKS PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "moon_cheese", "name": "MOON CHEESE", "desc": "CHEESE CAVE PROFITS x3", "cost": 1.0e10, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "malt", "name": "MALTED MIX", "desc": "MILKSHAKE DINER PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "low_g", "name": "LOW-GRAVITY GRAZING", "desc": "MOON COW RANCH PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "golden_gloves", "name": "GOLDEN GLOVES", "desc": "SQUEEZES EARN x5", "cost": 5.0e10, "kind": "click", "value": 5.0},
	{"id": "rocky_road", "name": "ROCKY ROAD", "desc": "ICE CREAM CART PROFITS x3", "cost": 5.0e10, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "music", "name": "MUSIC IN THE BARN", "desc": "ALL PROFITS x3", "cost": 1.0e11, "kind": "all", "value": 3.0},
	{"id": "astro_cows", "name": "ASTRO-COWS", "desc": "COSMIC CREAMERY PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "froyo", "name": "FROZEN YOGURT", "desc": "YOGURT WORKS PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "neon_sign", "name": "NEON SIGN", "desc": "MILKSHAKE DINER PROFITS x3", "cost": 1.0e12, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "moon_boots", "name": "MOON BOOTS", "desc": "MOON COW RANCH PROFITS x3", "cost": 2.0e12, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "nebula", "name": "NEBULA CREAM", "desc": "COSMIC CREAMERY PROFITS x3", "cost": 1.0e13, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "organic", "name": "ORGANIC GRASS", "desc": "ALL PROFITS x3", "cost": 1.0e14, "kind": "all", "value": 3.0},
	{"id": "crater", "name": "CRATER CREAMERY", "desc": "MOON COW RANCH PROFITS x3", "cost": 1.0e14, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "cow_spa", "name": "COW SPA", "desc": "ALL PROFITS x3", "cost": 1.0e17, "kind": "all", "value": 3.0},
]

# A squeeze of the udder earns this before upgrades.
const BASE_CLICK: float = 1.0

# MOO RUSH: every squeeze fills the meter a bit; when it's full, everything earns x3 for a while.
const RUSH_PER_CLICK: float = 0.04
const RUSH_DECAY_PER_SEC: float = 0.12
const RUSH_SECONDS: float = 12.0
const RUSH_MULT: float = 3.0

# GOLDEN COWBELLS (prestige): moving to a bigger pasture resets the farm but keeps your bells.
# Total bells for everything you've ever earned = BELL_SCALE x sqrt(earned / BELL_UNIT).
const BELL_SCALE: float = 10.0
const BELL_UNIT: float = 1.0e9
const BELL_BONUS: float = 0.02 # +2% profit per bell
