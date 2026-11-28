extends RefCounted

# All balance numbers for Udderly Idle live here. Nothing in this file runs; Farm reads it.
#
# There are four animals, each with its own part of the farm (see ANIMALS at the bottom):
# the cow (dairy), the hen (eggs), the monkey (bananas) and the bee (honey). Each runs its own economy with the
# same rules: its own money, businesses, upgrades, farmhands and golden prestige item.
#
# A business earns `revenue` x owned every `time` seconds. Its price for the next unit is
# `cost` x `growth` ^ owned. Before you hire its farmhand you click the business to start
# each cycle; after, it runs by itself (and keeps earning while the game is closed).

# The cow's dairy.
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

# The hen's eggs. Same curve as the dairy: every animal starts from scratch.
const CHICKEN_BUSINESSES: Array[Dictionary] = [
	{"id": "eggbasket", "name": "EGG BASKET", "cost": 5.0, "growth": 1.07, "revenue": 1.5, "time": 1.0,
		"farmhand": "HENNY PENNY", "farmhand_cost": 1000.0},
	{"id": "friedegg", "name": "FRIED EGG GRIDDLE", "cost": 75.0, "growth": 1.14, "revenue": 40.0, "time": 3.0,
		"farmhand": "SUNNY SIDE SAM", "farmhand_cost": 15000.0},
	{"id": "omelette", "name": "OMELETTE STATION", "cost": 900.0, "growth": 1.13, "revenue": 350.0, "time": 6.0,
		"farmhand": "OMAR LETT", "farmhand_cost": 100000.0},
	{"id": "custard", "name": "CUSTARD CAFE", "cost": 11000.0, "growth": 1.12, "revenue": 3000.0, "time": 12.0,
		"farmhand": "CUSTARD CORA", "farmhand_cost": 500000.0},
	{"id": "cake", "name": "CAKE BAKERY", "cost": 140000.0, "growth": 1.115, "revenue": 32000.0, "time": 25.0,
		"farmhand": "BAKER BETTY", "farmhand_cost": 1.2e6},
	{"id": "eggnog", "name": "EGGNOG FACTORY", "cost": 1.8e6, "growth": 1.11, "revenue": 400000.0, "time": 60.0,
		"farmhand": "NOG NORBERT", "farmhand_cost": 1.0e7},
	{"id": "hatchery", "name": "CHICK HATCHERY", "cost": 2.5e7, "growth": 1.10, "revenue": 6.0e6, "time": 180.0,
		"farmhand": "MOTHER HEN", "farmhand_cost": 1.11e8},
	{"id": "fancyegg", "name": "FANCY EGG MUSEUM", "cost": 4.0e8, "growth": 1.09, "revenue": 1.1e8, "time": 600.0,
		"farmhand": "DUCHESS YOLKSWORTH", "farmhand_cost": 5.55e8},
]

# The monkey's bananas.
const MONKEY_BUSINESSES: Array[Dictionary] = [
	{"id": "bunch", "name": "BANANA TREE", "cost": 5.0, "growth": 1.07, "revenue": 1.5, "time": 1.0,
		"farmhand": "BONGO", "farmhand_cost": 1000.0},
	{"id": "smoothie", "name": "SMOOTHIE SHACK", "cost": 75.0, "growth": 1.14, "revenue": 40.0, "time": 3.0,
		"farmhand": "SLURPY SUE", "farmhand_cost": 15000.0},
	{"id": "bread", "name": "BANANA BREAD BAKERY", "cost": 900.0, "growth": 1.13, "revenue": 350.0, "time": 6.0,
		"farmhand": "BREADLEY", "farmhand_cost": 100000.0},
	{"id": "split", "name": "BANANA SPLIT PARLOR", "cost": 11000.0, "growth": 1.12, "revenue": 3000.0, "time": 12.0,
		"farmhand": "SUNDAE SAL", "farmhand_cost": 500000.0},
	{"id": "chips", "name": "BANANA CHIP FACTORY", "cost": 140000.0, "growth": 1.115, "revenue": 32000.0, "time": 25.0,
		"farmhand": "CRUNCHY CARL", "farmhand_cost": 1.2e6},
	{"id": "pie", "name": "BANANA CREAM PIE CO.", "cost": 1.8e6, "growth": 1.11, "revenue": 400000.0, "time": 60.0,
		"farmhand": "PIE-RATE PETE", "farmhand_cost": 1.0e7},
	{"id": "boat", "name": "BANANA BOAT FLEET", "cost": 2.5e7, "growth": 1.10, "revenue": 6.0e6, "time": 180.0,
		"farmhand": "CAPTAIN PEEL", "farmhand_cost": 1.11e8},
	{"id": "planet", "name": "PLANET BANANA", "cost": 4.0e8, "growth": 1.09, "revenue": 1.1e8, "time": 600.0,
		"farmhand": "COSMO THE SPACE MONKEY", "farmhand_cost": 5.55e8},
]

# The bee's honey.
const BEE_BUSINESSES: Array[Dictionary] = [
	{"id": "honeyjar", "name": "HONEY JAR STAND", "cost": 5.0, "growth": 1.07, "revenue": 1.5, "time": 1.0,
		"farmhand": "BUZZY BEA", "farmhand_cost": 1000.0},
	{"id": "candle", "name": "BEESWAX CANDLE SHOP", "cost": 75.0, "growth": 1.14, "revenue": 40.0, "time": 3.0,
		"farmhand": "WICK WILLOW", "farmhand_cost": 15000.0},
	{"id": "honeybun", "name": "HONEY BUN BAKERY", "cost": 900.0, "growth": 1.13, "revenue": 350.0, "time": 6.0,
		"farmhand": "STICKY STAN", "farmhand_cost": 100000.0},
	{"id": "tea", "name": "HONEY TEA HOUSE", "cost": 11000.0, "growth": 1.12, "revenue": 3000.0, "time": 12.0,
		"farmhand": "LADY STEEPWELL", "farmhand_cost": 500000.0},
	{"id": "cereal", "name": "HONEY CRUNCH CEREAL", "cost": 140000.0, "growth": 1.115, "revenue": 32000.0, "time": 25.0,
		"farmhand": "CRISPY CRAIG", "farmhand_cost": 1.2e6},
	{"id": "royaljelly", "name": "ROYAL JELLY PALACE", "cost": 1.8e6, "growth": 1.11, "revenue": 400000.0, "time": 60.0,
		"farmhand": "QUEEN BEATRICE", "farmhand_cost": 1.0e7},
	{"id": "blimp", "name": "HONEY BLIMP FLEET", "cost": 2.5e7, "growth": 1.10, "revenue": 6.0e6, "time": 180.0,
		"farmhand": "CAPTAIN STINGER", "farmhand_cost": 1.11e8},
	{"id": "honeymoon", "name": "HONEYMOON HIVE", "cost": 4.0e8, "growth": 1.09, "revenue": 1.1e8, "time": 600.0,
		"farmhand": "ZIGGY THE SPACE BEE", "farmhand_cost": 5.55e8},
]

# Owning this many of one business doubles its speed (halves its cycle time) each time...
const SPEED_MILESTONES: Array[int] = [25, 50, 100, 200, 300, 400]
# ...and these double its profits.
const PROFIT_MILESTONES: Array[int] = [500, 600, 700, 800, 900, 1000]

# Upgrades. kind: "biz" multiplies one business's profits ("target" = business index),
# "all" multiplies every business, "click" multiplies what a squeeze earns, and
# "click_share" makes each squeeze also earn that fraction of your income per second.
const UPGRADES: Array[Dictionary] = [  # the cow's
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

# The hen's, the monkey's and the bee's upgrades follow the same price schedule as the cow's.
const CHICKEN_UPGRADES: Array[Dictionary] = [
	{"id": "c_corn", "name": "CRACKED CORN", "desc": "CLUCKS EARN x2", "cost": 50.0, "kind": "click", "value": 2.0},
	{"id": "c_perch", "name": "COMFY PERCH", "desc": "CLUCKS EARN x2", "cost": 500.0, "kind": "click", "value": 2.0},
	{"id": "c_wicker", "name": "WICKER BASKETS", "desc": "EGG BASKET PROFITS x3", "cost": 2500.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "c_yolks", "name": "DOUBLE YOLKS", "desc": "CLUCKS ALSO EARN 5% OF INCOME/SEC", "cost": 5000.0, "kind": "click_share", "value": 0.05},
	{"id": "c_spatula", "name": "FLIPPY SPATULA", "desc": "FRIED EGG GRIDDLE PROFITS x3", "cost": 30000.0, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "c_worms", "name": "JUICY WORMS", "desc": "CLUCKS EARN x3", "cost": 250000.0, "kind": "click", "value": 3.0},
	{"id": "c_cheesy", "name": "CHEESY OMELETTES", "desc": "OMELETTE STATION PROFITS x3", "cost": 250000.0, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "c_big_baskets", "name": "BIGGER BASKETS", "desc": "EGG BASKET PROFITS x3", "cost": 500000.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "c_caramel", "name": "CARAMEL TOPPING", "desc": "CUSTARD CAFE PROFITS x3", "cost": 2.0e6, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "c_buttered", "name": "BUTTERED GRIDDLE", "desc": "FRIED EGG GRIDDLE PROFITS x3", "cost": 4.0e6, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "c_frosting", "name": "EXTRA FROSTING", "desc": "CAKE BAKERY PROFITS x3", "cost": 2.0e7, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "c_fluffy", "name": "FLUFFY FOLDS", "desc": "OMELETTE STATION PROFITS x3", "cost": 3.0e7, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "c_straw", "name": "SOFT STRAW", "desc": "CLUCKS ALSO EARN 10% OF INCOME/SEC", "cost": 5.0e7, "kind": "click_share", "value": 0.10},
	{"id": "c_happy", "name": "HAPPY HENS", "desc": "ALL PROFITS x3", "cost": 1.0e8, "kind": "all", "value": 3.0},
	{"id": "c_nutmeg", "name": "NUTMEG SPRINKLE", "desc": "EGGNOG FACTORY PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "c_vanilla", "name": "VANILLA BEANS", "desc": "CUSTARD CAFE PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "c_gold_baskets", "name": "GOLDEN BASKETS", "desc": "EGG BASKET PROFITS x3", "cost": 5.0e8, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "c_incubator", "name": "WARM INCUBATORS", "desc": "CHICK HATCHERY PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "c_cast_iron", "name": "CAST IRON PANS", "desc": "FRIED EGG GRIDDLE PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "c_layers", "name": "SEVEN LAYERS", "desc": "CAKE BAKERY PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "c_truffle", "name": "TRUFFLE OMELETTES", "desc": "OMELETTE STATION PROFITS x3", "cost": 1.0e10, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "c_cinnamon", "name": "CINNAMON STICKS", "desc": "EGGNOG FACTORY PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "c_jewels", "name": "SPARKLY JEWELS", "desc": "FANCY EGG MUSEUM PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "c_gold_feed", "name": "GOLDEN FEED", "desc": "CLUCKS EARN x5", "cost": 5.0e10, "kind": "click", "value": 5.0},
	{"id": "c_brulee", "name": "CREME BRULEE", "desc": "CUSTARD CAFE PROFITS x3", "cost": 5.0e10, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "c_radio", "name": "RADIO IN THE COOP", "desc": "ALL PROFITS x3", "cost": 1.0e11, "kind": "all", "value": 3.0},
	{"id": "c_lullaby", "name": "CHICK LULLABIES", "desc": "CHICK HATCHERY PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "c_wedding", "name": "WEDDING CAKES", "desc": "CAKE BAKERY PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "c_festive", "name": "FESTIVE MUGS", "desc": "EGGNOG FACTORY PROFITS x3", "cost": 1.0e12, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "c_velvet", "name": "VELVET CUSHIONS", "desc": "FANCY EGG MUSEUM PROFITS x3", "cost": 2.0e12, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "c_nursery", "name": "CHICK NURSERY", "desc": "CHICK HATCHERY PROFITS x3", "cost": 1.0e13, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "c_free_range", "name": "FREE RANGE", "desc": "ALL PROFITS x3", "cost": 1.0e14, "kind": "all", "value": 3.0},
	{"id": "c_royal", "name": "ROYAL COLLECTION", "desc": "FANCY EGG MUSEUM PROFITS x3", "cost": 1.0e14, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "c_hen_spa", "name": "HEN SPA", "desc": "ALL PROFITS x3", "cost": 1.0e17, "kind": "all", "value": 3.0},
]

const MONKEY_UPGRADES: Array[Dictionary] = [
	{"id": "m_peeling", "name": "QUICK PEELING", "desc": "PICKS EARN x2", "cost": 50.0, "kind": "click", "value": 2.0},
	{"id": "m_vine", "name": "SWINGY VINE", "desc": "PICKS EARN x2", "cost": 500.0, "kind": "click", "value": 2.0},
	{"id": "m_fertilizer", "name": "JUNGLE FERTILIZER", "desc": "BANANA TREE PROFITS x3", "cost": 2500.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "m_tail", "name": "TAIL GRAB", "desc": "PICKS ALSO EARN 5% OF INCOME/SEC", "cost": 5000.0, "kind": "click_share", "value": 0.05},
	{"id": "m_blender", "name": "TURBO BLENDER", "desc": "SMOOTHIE SHACK PROFITS x3", "cost": 30000.0, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "m_long_arms", "name": "EXTRA LONG ARMS", "desc": "PICKS EARN x3", "cost": 250000.0, "kind": "click", "value": 3.0},
	{"id": "m_walnuts", "name": "WALNUT BITS", "desc": "BANANA BREAD BAKERY PROFITS x3", "cost": 250000.0, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "m_taller", "name": "TALLER TREES", "desc": "BANANA TREE PROFITS x3", "cost": 500000.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "m_cherry", "name": "A CHERRY ON TOP", "desc": "BANANA SPLIT PARLOR PROFITS x3", "cost": 2.0e6, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "m_berries", "name": "BERRY BLAST", "desc": "SMOOTHIE SHACK PROFITS x3", "cost": 4.0e6, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "m_crunch", "name": "EXTRA CRUNCH", "desc": "BANANA CHIP FACTORY PROFITS x3", "cost": 2.0e7, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "m_choc_chips", "name": "CHOCOLATE CHIPS", "desc": "BANANA BREAD BAKERY PROFITS x3", "cost": 3.0e7, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "m_hammock", "name": "COZY HAMMOCK", "desc": "PICKS ALSO EARN 10% OF INCOME/SEC", "cost": 5.0e7, "kind": "click_share", "value": 0.10},
	{"id": "m_happy", "name": "HAPPY MONKEYS", "desc": "ALL PROFITS x3", "cost": 1.0e8, "kind": "all", "value": 3.0},
	{"id": "m_whipped", "name": "WHIPPED CREAM", "desc": "BANANA CREAM PIE CO. PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "m_hot_fudge", "name": "HOT FUDGE", "desc": "BANANA SPLIT PARLOR PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "m_gold_trees", "name": "GOLDEN TREES", "desc": "BANANA TREE PROFITS x3", "cost": 5.0e8, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "m_sails", "name": "BIGGER SAILS", "desc": "BANANA BOAT FLEET PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "m_protein", "name": "PROTEIN SCOOP", "desc": "SMOOTHIE SHACK PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "m_honey", "name": "HONEY GLAZE", "desc": "BANANA CHIP FACTORY PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "m_sourdough", "name": "SOURDOUGH STARTER", "desc": "BANANA BREAD BAKERY PROFITS x3", "cost": 1.0e10, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "m_graham", "name": "GRAHAM CRUST", "desc": "BANANA CREAM PIE CO. PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "m_rocket", "name": "ROCKET BOOSTERS", "desc": "PLANET BANANA PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "m_gold_mitts", "name": "GOLDEN MITTS", "desc": "PICKS EARN x5", "cost": 5.0e10, "kind": "click", "value": 5.0},
	{"id": "m_triple", "name": "TRIPLE SCOOP", "desc": "BANANA SPLIT PARLOR PROFITS x3", "cost": 5.0e10, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "m_drums", "name": "JUNGLE DRUMS", "desc": "ALL PROFITS x3", "cost": 1.0e11, "kind": "all", "value": 3.0},
	{"id": "m_parrot", "name": "PARROT LOOKOUT", "desc": "BANANA BOAT FLEET PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "m_maple", "name": "MAPLE DRIZZLE", "desc": "BANANA CHIP FACTORY PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "m_meringue", "name": "MILE-HIGH MERINGUE", "desc": "BANANA CREAM PIE CO. PROFITS x3", "cost": 1.0e12, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "m_moon_base", "name": "MOON BASE", "desc": "PLANET BANANA PROFITS x3", "cost": 2.0e12, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "m_cruise", "name": "CRUISE SHIPS", "desc": "BANANA BOAT FLEET PROFITS x3", "cost": 1.0e13, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "m_rainforest", "name": "RAINFOREST RAIN", "desc": "ALL PROFITS x3", "cost": 1.0e14, "kind": "all", "value": 3.0},
	{"id": "m_galaxy", "name": "BANANA GALAXY", "desc": "PLANET BANANA PROFITS x3", "cost": 1.0e14, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "m_spa", "name": "MONKEY SPA", "desc": "ALL PROFITS x3", "cost": 1.0e17, "kind": "all", "value": 3.0},
]

const BEE_UPGRADES: Array[Dictionary] = [
	{"id": "b_nectar", "name": "SWEET NECTAR", "desc": "BUZZES EARN x2", "cost": 50.0, "kind": "click", "value": 2.0},
	{"id": "b_clover", "name": "CLOVER PATCH", "desc": "BUZZES EARN x2", "cost": 500.0, "kind": "click", "value": 2.0},
	{"id": "b_labels", "name": "CUTE LABELS", "desc": "HONEY JAR STAND PROFITS x3", "cost": 2500.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "b_waggle", "name": "WAGGLE DANCE", "desc": "BUZZES ALSO EARN 5% OF INCOME/SEC", "cost": 5000.0, "kind": "click_share", "value": 0.05},
	{"id": "b_wicks", "name": "LONGER WICKS", "desc": "BEESWAX CANDLE SHOP PROFITS x3", "cost": 30000.0, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "b_wings", "name": "TURBO WINGS", "desc": "BUZZES EARN x3", "cost": 250000.0, "kind": "click", "value": 3.0},
	{"id": "b_glaze", "name": "STICKY GLAZE", "desc": "HONEY BUN BAKERY PROFITS x3", "cost": 250000.0, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "b_bigger_jars", "name": "BIGGER JARS", "desc": "HONEY JAR STAND PROFITS x3", "cost": 500000.0, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "b_lemon", "name": "SLICE OF LEMON", "desc": "HONEY TEA HOUSE PROFITS x3", "cost": 2.0e6, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "b_scented", "name": "SCENTED CANDLES", "desc": "BEESWAX CANDLE SHOP PROFITS x3", "cost": 4.0e6, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "b_marshmallows", "name": "MARSHMALLOW BITS", "desc": "HONEY CRUNCH CEREAL PROFITS x3", "cost": 2.0e7, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "b_cinnamon", "name": "CINNAMON SWIRL", "desc": "HONEY BUN BAKERY PROFITS x3", "cost": 3.0e7, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "b_pollen", "name": "POLLEN BASKETS", "desc": "BUZZES ALSO EARN 10% OF INCOME/SEC", "cost": 5.0e7, "kind": "click_share", "value": 0.10},
	{"id": "b_happy", "name": "HAPPY BEES", "desc": "ALL PROFITS x3", "cost": 1.0e8, "kind": "all", "value": 3.0},
	{"id": "b_thrones", "name": "VELVET THRONES", "desc": "ROYAL JELLY PALACE PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "b_teapots", "name": "FANCY TEAPOTS", "desc": "HONEY TEA HOUSE PROFITS x3", "cost": 2.0e8, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "b_gold_jars", "name": "GOLDEN JARS", "desc": "HONEY JAR STAND PROFITS x3", "cost": 5.0e8, "kind": "biz", "target": 0, "value": 3.0},
	{"id": "b_helium", "name": "EXTRA HELIUM", "desc": "HONEY BLIMP FLEET PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "b_candelabra", "name": "CANDELABRAS", "desc": "BEESWAX CANDLE SHOP PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 1, "value": 3.0},
	{"id": "b_prize", "name": "PRIZE IN THE BOX", "desc": "HONEY CRUNCH CEREAL PROFITS x3", "cost": 2.0e9, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "b_drizzle", "name": "DOUBLE DRIZZLE", "desc": "HONEY BUN BAKERY PROFITS x3", "cost": 1.0e10, "kind": "biz", "target": 2, "value": 3.0},
	{"id": "b_spoons", "name": "GOLDEN SPOONS", "desc": "ROYAL JELLY PALACE PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "b_space_suits", "name": "TINY SPACE SUITS", "desc": "HONEYMOON HIVE PROFITS x3", "cost": 2.0e10, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "b_gold_wings", "name": "GOLDEN WINGS", "desc": "BUZZES EARN x5", "cost": 5.0e10, "kind": "click", "value": 5.0},
	{"id": "b_scones", "name": "SCONES ON THE SIDE", "desc": "HONEY TEA HOUSE PROFITS x3", "cost": 5.0e10, "kind": "biz", "target": 3, "value": 3.0},
	{"id": "b_meadow", "name": "WILDFLOWER MEADOW", "desc": "ALL PROFITS x3", "cost": 1.0e11, "kind": "all", "value": 3.0},
	{"id": "b_propellers", "name": "BIG PROPELLERS", "desc": "HONEY BLIMP FLEET PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "b_mascot", "name": "CEREAL MASCOT", "desc": "HONEY CRUNCH CEREAL PROFITS x3", "cost": 2.0e11, "kind": "biz", "target": 4, "value": 3.0},
	{"id": "b_royal_ball", "name": "ROYAL BALL", "desc": "ROYAL JELLY PALACE PROFITS x3", "cost": 1.0e12, "kind": "biz", "target": 5, "value": 3.0},
	{"id": "b_moon_flowers", "name": "MOON FLOWERS", "desc": "HONEYMOON HIVE PROFITS x3", "cost": 2.0e12, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "b_sky_parade", "name": "SKY PARADE", "desc": "HONEY BLIMP FLEET PROFITS x3", "cost": 1.0e13, "kind": "biz", "target": 6, "value": 3.0},
	{"id": "b_queen", "name": "QUEEN'S BLESSING", "desc": "ALL PROFITS x3", "cost": 1.0e14, "kind": "all", "value": 3.0},
	{"id": "b_galaxy", "name": "HONEY GALAXY", "desc": "HONEYMOON HIVE PROFITS x3", "cost": 1.0e14, "kind": "biz", "target": 7, "value": 3.0},
	{"id": "b_spa", "name": "BEE SPA", "desc": "ALL PROFITS x3", "cost": 1.0e17, "kind": "all", "value": 3.0},
]

# A click on the animal (a squeeze, cluck, pick or buzz) earns this before upgrades.
const BASE_CLICK: float = 1.0

# MOO RUSH (CLUCK RUSH, BANANA RUSH, BUZZ RUSH): every click fills the meter a bit; when it's full, that animal's
# businesses earn x3 for a while.
const RUSH_PER_CLICK: float = 0.04
const RUSH_DECAY_PER_SEC: float = 0.12
const RUSH_SECONDS: float = 12.0
const RUSH_MULT: float = 3.0

# GOLDEN COWBELLS (prestige): moving to a bigger pasture resets the farm but keeps your bells.
# Total bells for everything you've ever earned = BELL_SCALE x sqrt(earned / BELL_UNIT).
const BELL_SCALE: float = 10.0
const BELL_UNIT: float = 1.0e9
const BELL_BONUS: float = 0.02 # +2% profit per bell (golden eggs, bananas and honeypots work the same way)

# The animals, in unlock order. Each has its own part of the farm and its own economy. An animal
# opens once the animal at index "needs" holds "needs_gold" of its golden item; it stays open.
# Text fields are what the UI says for that animal.
const ANIMALS: Array[Dictionary] = [
	{"id": "cow", "name": "COW", "place": "THE PASTURE", "needs": -1, "needs_gold": 0,
		"click": "SQUEEZE", "clicks": "SQUEEZES", "verb": "MILK HER", "hint": "CLICK THE COW TO MILK HER!",
		"rush": "MOO RUSH", "gold": "GOLDEN COWBELLS", "gold_one": "GOLDEN COWBELL", "gold_icon": "bell",
		"move": "MOVE TO A BIGGER PASTURE", "moved": "PASTURES MOVED", "fresh": "A FRESH PASTURE AWAITS.",
		"move_desc": "MOVING TO A BIGGER PASTURE SELLS YOUR WHOLE FARM",
		"tabs": ["DAIRY", "UPGRADES", "FARMHANDS", "PASTURE"], "click_icon": "drop", "face": "cowface",
		"businesses": BUSINESSES, "upgrades": UPGRADES, "gold_scale": BELL_SCALE, "gold_unit": BELL_UNIT},
	{"id": "chicken", "name": "HEN", "place": "THE HEN HOUSE", "needs": 0, "needs_gold": 20,
		"click": "CLUCK", "clicks": "CLUCKS", "verb": "LAY AN EGG", "hint": "CLICK THE HEN TO LAY AN EGG!",
		"rush": "CLUCK RUSH", "gold": "GOLDEN EGGS", "gold_one": "GOLDEN EGG", "gold_icon": "goldegg",
		"move": "BUILD A BIGGER HEN HOUSE", "moved": "HEN HOUSES BUILT", "fresh": "A SHINY NEW HEN HOUSE!",
		"move_desc": "BUILDING A BIGGER HEN HOUSE SELLS YOUR WHOLE COOP",
		"tabs": ["EGGS", "UPGRADES", "FARMHANDS", "COOP"], "click_icon": "egg", "face": "henface",
		"businesses": CHICKEN_BUSINESSES, "upgrades": CHICKEN_UPGRADES, "gold_scale": BELL_SCALE, "gold_unit": BELL_UNIT},
	{"id": "monkey", "name": "MONKEY", "place": "THE BANANA GROVE", "needs": 1, "needs_gold": 3,
		"click": "PICK", "clicks": "PICKS", "verb": "PICK BANANAS", "hint": "CLICK THE MONKEY TO PICK BANANAS!",
		"rush": "BANANA RUSH", "gold": "GOLDEN BANANAS", "gold_one": "GOLDEN BANANA", "gold_icon": "goldbanana",
		"move": "MOVE TO A BIGGER GROVE", "moved": "GROVES MOVED", "fresh": "A FRESH GROVE AWAITS.",
		"move_desc": "MOVING TO A BIGGER GROVE SELLS YOUR WHOLE GROVE",
		"tabs": ["BANANAS", "UPGRADES", "FARMHANDS", "GROVE"], "click_icon": "banana", "face": "monkeyface",
		"businesses": MONKEY_BUSINESSES, "upgrades": MONKEY_UPGRADES, "gold_scale": BELL_SCALE, "gold_unit": BELL_UNIT},
	{"id": "bee", "name": "BEE", "place": "THE BEE MEADOW", "needs": 2, "needs_gold": 3,
		"click": "BUZZ", "clicks": "BUZZES", "verb": "MAKE HONEY", "hint": "CLICK THE BEE TO MAKE HONEY!",
		"rush": "BUZZ RUSH", "gold": "GOLDEN HONEYPOTS", "gold_one": "GOLDEN HONEYPOT", "gold_icon": "goldhoney",
		"move": "BUILD A BIGGER HIVE", "moved": "HIVES BUILT", "fresh": "A BUZZING NEW HIVE!",
		"move_desc": "BUILDING A BIGGER HIVE SELLS YOUR WHOLE HIVE",
		"tabs": ["HONEY", "UPGRADES", "FARMHANDS", "HIVE"], "click_icon": "honeydrop", "face": "beeface",
		"businesses": BEE_BUSINESSES, "upgrades": BEE_UPGRADES, "gold_scale": BELL_SCALE, "gold_unit": BELL_UNIT},
]
