extends Node

# Sound effects, synthesized at startup into AudioStreamWAVs (no audio files).
# Sfx.play("squirt"). Names: squirt, coin, buy, cant, milestone, moo, hire, rush, bell, ui.
# "squirt" (the milking squeeze) and "moo" have several takes; play() picks one at random
# so repeated clicks don't sound like a loop.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 10

var _streams: Dictionary = {}
var _variants: Dictionary = {} # name -> Array of AudioStreamWAV takes
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_variants["squirt"] = [_squeeze(11, 1.0), _squeeze(23, 0.9), _squeeze(37, 1.12), _squeeze(41, 0.96)]
	_streams["squirt"] = _variants["squirt"][0]
	_streams["coin"] = _notes([1320.0, 1760.0], 0.05, 0, 0.35)
	_streams["buy"] = _notes([660.0, 880.0], 0.045, 1, 0.3)
	_streams["cant"] = _notes([220.0, 180.0], 0.07, 1, 0.3)
	_streams["milestone"] = _notes([523.0, 659.0, 784.0, 1047.0], 0.07, 1, 0.35)
	_streams["hire"] = _notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.06, 1, 0.35)
	_streams["bell"] = _notes([1568.0, 2093.0, 2637.0, 3136.0, 2637.0, 3136.0], 0.08, 0, 0.3)
	_streams["rush"] = _sweep(300.0, 1400.0, 0.45)
	_variants["moo"] = [_moo_voice(1.25, 1.0, 5), _moo_voice(1.5, 0.86, 9), _moo_voice(0.85, 1.12, 13)]
	_streams["moo"] = _variants["moo"][0]
	_streams["ui"] = _notes([990.0], 0.03, 1, 0.25)


func play(name: String, vol_db: float = -6.0, jitter: float = 0.05) -> void:
	if not _streams.has(name) or Farm.sfx_volume <= 0.01:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	if _variants.has(name):
		var takes: Array = _variants[name]
		p.stream = takes[randi() % takes.size()]
	else:
		p.stream = _streams[name]
	p.volume_db = vol_db + linear_to_db(Farm.sfx_volume)
	p.pitch_scale = randf_range(1.0 - jitter, 1.0 + jitter)
	p.play()


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = bytes
	return s


# A short run of notes. wave 0 = sine, 1 = square.
func _notes(freqs: Array[float], note_len: float, wave: int, amp: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	var per: int = int(note_len * float(MIX_RATE))
	var phase: float = 0.0
	for k: int in range(freqs.size()):
		var tail: int = per * (3 if k == freqs.size() - 1 else 1)
		for i: int in range(tail):
			phase = fmod(phase + freqs[k] / float(MIX_RATE), 1.0)
			var env: float = 1.0 - float(i) / float(tail)
			var v: float = sin(phase * TAU) if wave == 0 else (0.6 if phase < 0.5 else -0.6)
			out.append(v * env * env * amp)
	return _to_stream(out)


func _sweep(f0: float, f1: float, length: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = int(length * float(MIX_RATE))
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		phase = fmod(phase + lerpf(f0, f1, t * t) / float(MIX_RATE), 1.0)
		out.append((0.5 if phase < 0.5 else -0.5) * (1.0 - t) * 0.35)
	return _to_stream(out)


# --- Biquad band-pass, used to shape noise and to give the moo its vowel formants ---
class BandPass:
	var b0: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0

	func tune(freq: float, q: float, rate: float) -> void:
		var w0: float = TAU * clampf(freq, 20.0, rate * 0.45) / rate
		var alpha: float = sin(w0) / (2.0 * q)
		var a0: float = 1.0 + alpha
		b0 = alpha / a0
		b2 = -alpha / a0
		a1 = -2.0 * cos(w0) / a0
		a2 = (1.0 - alpha) / a0

	func process(x: float) -> float:
		var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


# Milking: a rubbery squeak as the teat is squeezed, a wet squelch, the "pssht" of milk
# spraying, and a faint ping as it hits the tin pail. `pitch` varies the take.
func _squeeze(seed: int, pitch: float) -> AudioStreamWAV:
	var rate: float = float(MIX_RATE)
	var n: int = int(0.42 * rate)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var squeak_bp: BandPass = BandPass.new()
	var squelch_bp: BandPass = BandPass.new()
	squelch_bp.tune(1100.0 * pitch, 2.2, rate)
	var spray_bp: BandPass = BandPass.new()
	spray_bp.tune(4200.0, 0.9, rate)
	var phase: float = 0.0
	var wob: float = rng.randf() * TAU
	for i: int in range(n):
		var t: float = float(i) / rate
		var v: float = 0.0
		# Squeak (0 - 0.11 s): a rubbery tone sweeping up, then sagging.
		if t < 0.11:
			var k: float = t / 0.11
			var f: float = (480.0 + 720.0 * sin(minf(1.0, k * 1.6) * PI * 0.5) - 260.0 * maxf(0.0, k - 0.6)) * pitch
			f *= 1.0 + 0.05 * sin(t * 260.0 + wob)
			phase = fmod(phase + f / rate, 1.0)
			var tone: float = sin(phase * TAU) + 0.45 * sin(phase * 2.0 * TAU) + 0.2 * sin(phase * 3.0 * TAU)
			squeak_bp.tune(f * 1.6, 3.0, rate)
			var env: float = minf(1.0, t * 160.0) * (1.0 - k) * (1.0 - k * 0.3)
			v += (tone * 0.35 + squeak_bp.process(tone) * 0.9) * env * 0.55
		# Squelch (0.02 - 0.12 s): wet, burbling band-passed noise.
		if t > 0.02 and t < 0.12:
			var k2: float = (t - 0.02) / 0.10
			var burble: float = 0.55 + 0.45 * sin(t * 190.0 + wob * 2.0)
			v += squelch_bp.process(rng.randf_range(-1.0, 1.0)) * burble * (1.0 - k2) * 1.6
		# Spray (0.05 - 0.32 s): the milk jet, a soft hiss that fades.
		if t > 0.05 and t < 0.32:
			var k3: float = (t - 0.05) / 0.27
			v += spray_bp.process(rng.randf_range(-1.0, 1.0)) * minf(1.0, k3 * 8.0) * (1.0 - k3) * (1.0 - k3) * 0.55
		# Pail ping (from 0.14 s): a few inharmonic partials, quiet.
		if t > 0.14:
			var tp: float = t - 0.14
			var pf: float = 1450.0 * pitch
			v += (sin(TAU * pf * tp) * exp(-tp * 9.0) + 0.5 * sin(TAU * pf * 2.76 * tp) * exp(-tp * 14.0) + 0.25 * sin(TAU * pf * 5.4 * tp) * exp(-tp * 22.0)) * 0.07
		out[i] = v
	return _to_stream(_normalize(out, 0.8))


# A cow's moo: a buzzy vocal-fold pulse train whose pitch rises and falls, shaped by vowel
# formants that open from a closed-mouth "mmm" through "ooo" to "uhh" and close again,
# with a bit of vocal fry at the start and breath noise throughout.
func _moo_voice(length: float, f0_scale: float, seed: int) -> AudioStreamWAV:
	var rate: float = float(MIX_RATE)
	var n: int = int(length * rate)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var f1: BandPass = BandPass.new()
	var f2: BandPass = BandPass.new()
	var f3: BandPass = BandPass.new()
	var nasal_lp: float = 0.0
	var phase: float = 0.0
	var src_lp: float = 0.0
	for i: int in range(n):
		var k: float = float(i) / float(n) # 0..1 through the moo
		# Pitch contour (Hz): rise, a slightly wavering hold, then a long fall.
		var f0: float = 0.0
		if k < 0.14:
			f0 = lerpf(92.0, 124.0, k / 0.14)
		elif k < 0.68:
			f0 = lerpf(124.0, 134.0, (k - 0.14) / 0.54)
		else:
			f0 = lerpf(134.0, 86.0, pow((k - 0.68) / 0.32, 1.3))
		f0 *= f0_scale * (1.0 + 0.018 * sin(float(i) / rate * TAU * 5.2) + rng.randf_range(-0.006, 0.006))
		phase = fmod(phase + f0 / rate, 1.0)
		# Glottal pulse: a sawtooth with its edge softened, plus breath.
		var saw: float = 1.0 - 2.0 * phase
		src_lp += 0.55 * (saw - src_lp)
		var src: float = src_lp + rng.randf_range(-1.0, 1.0) * 0.07
		# Vocal fry at the start: the voice "catches" before it opens up.
		if k < 0.22:
			src *= 1.0 - 0.45 * (1.0 - k / 0.22) * (0.5 + 0.5 * sin(float(i) / rate * TAU * 31.0))
		# Vowel: mmm (closed) -> ooo -> uhh -> ooo (closing).
		var open: float = 0.0
		if k < 0.12:
			open = 0.0
		elif k < 0.35:
			open = (k - 0.12) / 0.23 * 0.5
		elif k < 0.75:
			open = 0.5 + (k - 0.35) / 0.40 * 0.5
		else:
			open = 1.0 - (k - 0.75) / 0.25 * 0.7
		if i % 32 == 0:
			f1.tune(lerpf(260.0, 640.0, open) * sqrt(f0_scale), 5.0, rate)
			f2.tune(lerpf(700.0, 1050.0, open), 6.0, rate)
			f3.tune(lerpf(2300.0, 2550.0, open), 7.0, rate)
		var voiced: float = f1.process(src) * 1.0 + f2.process(src) * lerpf(0.25, 0.65, open) + f3.process(src) * 0.12
		# The closed-mouth hum is mostly low end coming through the nose.
		nasal_lp += 0.08 * (src - nasal_lp)
		var v: float = lerpf(nasal_lp * 0.5, voiced * 3.2, smoothstep(0.0, 0.35, open))
		# Quiet "mm" onset, swelling into the open vowel, then trailing off.
		var env: float = smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.8, 1.0, k)) * (0.45 + 0.55 * smoothstep(0.05, 0.45, k))
		out[i] = v * env
	return _to_stream(_normalize(out, 0.85))


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0001
	for x: float in buf:
		m = maxf(m, absf(x))
	var g: float = peak / m
	for i: int in range(buf.size()):
		buf[i] *= g
	return buf
