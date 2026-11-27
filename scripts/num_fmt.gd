extends RefCounted

# Number formatting for money and times.
#   money(1234.5)      -> "$1,234"        money(12.5) -> "$12.50"
#   money(3.2e9)       -> "$3.200 BILLION"
#   short(3.2e9)       -> "3.20B"         (for buttons)
#   duration(3725.0)   -> "1H 02M"
# Settings -> NUMBERS switches big numbers (a million and up) between three styles; Farm
# saves the choice in `style`:
#   WORDS       money(3.2e9) -> "$3.200 BILLION"   short(3.2e9) -> "3.20B"
#   SHORT       money(3.2e9) -> "$3.20B"           short(3.2e9) -> "3.20B"
#   SCIENTIFIC  money(3.2e9) -> "$3.200e9"         short(3.2e9) -> "3.20e9"

const BIG_NAMES: Array[String] = [
	"MILLION", "BILLION", "TRILLION", "QUADRILLION", "QUINTILLION", "SEXTILLION",
	"SEPTILLION", "OCTILLION", "NONILLION", "DECILLION", "UNDECILLION", "DUODECILLION",
]
const SHORT_NAMES: Array[String] = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd"]

enum Style { WORDS, SHORT, SCIENTIFIC }
const STYLE_COUNT: int = 3
static var style: int = Style.WORDS


static func commas(n: float) -> String:
	var s: String = str(int(floor(absf(n))))
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0.0 else "") + out


static func big(n: float) -> String:
	if absf(n) < 1.0e6:
		if absf(n) < 100.0 and absf(n - floor(n)) > 0.004:
			return "%.2f" % n
		return commas(n)
	if style == Style.SHORT:
		return short(n)
	if style == Style.SCIENTIFIC:
		return sci(n, 3)
	var tier: int = int(floor(log(absf(n)) / log(1000.0))) - 2
	if tier >= BIG_NAMES.size():
		return sci(n, 3)
	var scaled: float = n / pow(1000.0, float(tier + 2))
	return "%.3f %s" % [scaled, BIG_NAMES[tier]]


static func money(n: float) -> String:
	return "$" + big(n)


static func short(n: float) -> String:
	if absf(n) < 1000.0:
		if absf(n) < 100.0 and absf(n - floor(n)) > 0.004:
			return "%.2f" % n
		return str(int(floor(n)))
	if style == Style.SCIENTIFIC and absf(n) >= 1.0e6:
		return sci(n, 2)
	var tier: int = int(floor(log(absf(n)) / log(1000.0))) - 1
	if tier >= SHORT_NAMES.size():
		return sci(n, 2)
	var scaled: float = n / pow(1000.0, float(tier + 1))
	var digits: String = "%.2f" if scaled < 100.0 else "%.1f"
	return (digits % scaled) + SHORT_NAMES[tier]


# 3.2e9 -> "3.20e9" with 2 decimals. GDScript's % has no %e (it errors), so build it by hand.
static func sci(n: float, decimals: int) -> String:
	if n == 0.0:
		return "0"
	var fmt: String = "%." + str(decimals) + "f"
	var e: int = int(floor(log(absf(n)) / log(10.0)))
	var mant: String = fmt % (n / pow(10.0, float(e)))
	if absf(float(mant)) >= 10.0:  # log rounding, or 9.9996 rounding up to "10.000"
		e += 1
		mant = fmt % (n / pow(10.0, float(e)))
	elif absf(float(mant)) < 1.0:
		e -= 1
		mant = fmt % (n / pow(10.0, float(e)))
	return "%se%d" % [mant, e]


static func short_money(n: float) -> String:
	return "$" + short(n)


static func duration(seconds: float) -> String:
	var s: int = int(ceil(maxf(0.0, seconds)))
	if s < 60:
		return "%dS" % s
	if s < 3600:
		return "%dM %02dS" % [s / 60, s % 60]
	if s < 86400:
		return "%dH %02dM" % [s / 3600, (s % 3600) / 60]
	return "%dD %02dH" % [s / 86400, (s % 86400) / 3600]
