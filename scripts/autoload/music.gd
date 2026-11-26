extends Node

# Background music: a light, bouncy barnyard tune, synthesized in code. The whole 32-bar
# loop is rendered once on a background thread at startup into an AudioStreamWAV, so
# playing it costs nothing per frame. Volume follows Farm.music_volume (0 = off).
#
# Band: whistle melody, oom-pah tuba bass, accordion chord stabs on the off-beats, banjo
# rolls, woodblock on 2 and 4, a soft kick and shaker, and a cowbell now and then.
# Form: A B A' B' (8 bars each). The repeat adds the banjo and cowbell, and a harmony
# whistle in the B section.

const RATE: int = 22050
const BPM: float = 120.0
const SWING: float = 0.14       # off-beat 8ths land a little late, for a bouncy shuffle
const STEPS_PER_BAR: int = 8    # 8th notes
const BASE_DB: float = -9.0

# Chords per bar. Root / fifth for the tuba, triad for the accordion and banjo (MIDI).
const CHORDS: Dictionary = {
	"G": {"root": 43, "fifth": 50, "triad": [55, 59, 62]},
	"C": {"root": 48, "fifth": 43, "triad": [55, 60, 64]},
	"D": {"root": 38, "fifth": 45, "triad": [57, 62, 66]},
	"Em": {"root": 40, "fifth": 47, "triad": [55, 59, 64]},
}
const PROG_A: Array[String] = ["G", "C", "G", "D", "G", "C", "D", "G"]
const PROG_B: Array[String] = ["C", "G", "Em", "D", "C", "G", "D", "G"]

# Melody, one token per 8th note: a note name, "-" to hold the previous note, "." for rest.
const MEL_A: Array[String] = [
	"B4", "B4", "D5", ".", "B4", ".", "G4", ".",
	"C5", "C5", "E5", ".", "C5", ".", "A4", ".",
	"B4", "B4", "D5", ".", "G5", ".", "D5", ".",
	"C5", "B4", "A4", ".", "F#4", ".", "A4", ".",
	"B4", "B4", "D5", ".", "B4", ".", "G4", ".",
	"C5", "C5", "E5", ".", "G5", ".", "E5", ".",
	"D5", "C5", "B4", ".", "A4", ".", "F#4", "A4",
	"G4", "-", "-", "-", ".", ".", ".", ".",
]
const MEL_B: Array[String] = [
	"E5", ".", "E5", "D5", "C5", ".", "E5", ".",
	"D5", ".", "D5", "C5", "B4", ".", "D5", ".",
	"E5", ".", "G5", ".", "E5", "D5", "B4", ".",
	"A4", ".", "B4", "C5", "D5", "-", "-", ".",
	"E5", ".", "E5", "D5", "C5", ".", "E5", ".",
	"D5", ".", "B4", ".", "G4", ".", "B4", "D5",
	"C5", ".", "A4", ".", "F#4", ".", "A4", "C5",
	"B4", "-", "G4", "-", "G4", "-", ".", ".",
]
const G_MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11] # pitch classes from G, for the harmony line

var _player: AudioStreamPlayer
var _thread: Thread
var _stream: AudioStreamWAV
var _ready_to_play: bool = false
var _applied_volume: float = -1.0
var _fade: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)
	if "--smoke-test" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return # headless runs (CI) don't need the full render
	_thread = Thread.new()
	_thread.start(_render_thread)


func _render_thread() -> void:
	var data: PackedByteArray = render_loop(4)
	call_deferred("_on_rendered", data)


func _on_rendered(data: PackedByteArray) -> void:
	_thread.wait_to_finish()
	_stream = AudioStreamWAV.new()
	_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_stream.mix_rate = RATE
	_stream.stereo = true
	_stream.data = data
	_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream.loop_begin = 0
	_stream.loop_end = data.size() / 4
	_player.stream = _stream
	_ready_to_play = true
	_fade = 0.0


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	var target: float = Farm.music_volume
	if target <= 0.01:
		if _player.playing:
			_player.stop()
		_applied_volume = 0.0
		return
	if not _player.playing:
		_player.play()
		_fade = 0.0
	_fade = minf(1.0, _fade + delta / 2.5)
	var vol: float = target * _fade
	if absf(vol - _applied_volume) > 0.001:
		_applied_volume = vol
		_player.volume_db = BASE_DB + linear_to_db(maxf(vol, 0.0001))


func is_ready_to_play() -> bool:
	return _ready_to_play


# =========================================================================================
# RENDERING
# =========================================================================================

static func _midi_hz(m: int) -> float:
	return 440.0 * pow(2.0, float(m - 69) / 12.0)


static func _note_midi(name: String) -> int:
	var pcs: Dictionary = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var pc: int = int(pcs[name.substr(0, 1)])
	var rest: String = name.substr(1)
	if rest.begins_with("#"):
		pc += 1
		rest = rest.substr(1)
	return (int(rest) + 1) * 12 + pc


# Start time (seconds) of each 8th-note step, with swing.
static func _step_time(step: int) -> float:
	var eighth: float = 60.0 / BPM / 2.0
	var pair: int = step / 2
	var t: float = float(pair) * eighth * 2.0
	if step % 2 == 1:
		t += eighth * (1.0 + SWING)
	return t


# Renders `passes` x 8 bars (4 = the full A B A' B' loop) and returns 16-bit stereo PCM.
# The echo tail that runs past the end is wrapped onto the start so the loop is seamless.
func render_loop(passes: int) -> PackedByteArray:
	var bars: int = passes * 8
	var total_steps: int = bars * STEPS_PER_BAR
	var length: float = _step_time(total_steps)
	var n: int = int(length * float(RATE))
	var tail: int = int(1.5 * float(RATE))
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	left.resize(n + tail)
	right.resize(n + tail)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var eighth: float = 60.0 / BPM / 2.0

	for bar: int in range(bars):
		var section: int = bar / 8          # 0 A, 1 B, 2 A', 3 B'
		var is_b: bool = section % 2 == 1
		var repeat: bool = section >= 2
		var chord_name: String = PROG_A[bar % 8]
		var mel: Array[String] = MEL_A
		if is_b:
			chord_name = PROG_B[bar % 8]
			mel = MEL_B
		var chord: Dictionary = CHORDS[chord_name]
		var triad: Array = chord["triad"]
		for s: int in range(STEPS_PER_BAR):
			var step: int = bar * STEPS_PER_BAR + s
			var t0: float = _step_time(step)
			# Tuba: root on beat 1, fifth on beat 3.
			if s == 0 or s == 4:
				_tuba(left, right, t0, int(chord["root"] if s == 0 else chord["fifth"]), 0.34)
			# Accordion stab on beats 2 and 4.
			if s == 2 or s == 6:
				for m: Variant in triad:
					_accordion(left, right, t0, int(m), 0.15)
			# Percussion.
			if s == 0 or s == 4:
				_kick(left, right, t0, 0.55 if s == 0 else 0.42)
			if s == 2 or s == 6:
				_woodblock(left, right, t0, 0.5)
			_shaker(left, right, t0, 0.22 if s % 2 == 1 else 0.12, rng)
			if repeat and s == 0 and bar % 2 == 0:
				_cowbell(left, right, t0, 0.32)
			# Banjo rolls on the repeat.
			if repeat:
				var roll: Array[int] = [0, 1, 2, 0, 1, 2, 0, 1]
				var bm: int = int(triad[roll[s]]) + 12
				_banjo(left, right, t0, bm, 0.24, rng)
			# Melody (and a harmony a third below in the repeated B section).
			var tok: String = mel[(bar % 8) * STEPS_PER_BAR + s]
			if tok != "." and tok != "-":
				var held: int = 1
				while (bar % 8) * STEPS_PER_BAR + s + held < mel.size() and mel[(bar % 8) * STEPS_PER_BAR + s + held] == "-":
					held += 1
				var dur: float = eighth * float(held) * 0.92
				var mm: int = _note_midi(tok)
				_whistle(left, right, t0, mm, dur, 0.30, bar * 8 + s)
				if repeat and is_b:
					_whistle(left, right, t0, _third_below(mm), dur, 0.17, bar * 8 + s + 99)

	_echo(left, right, eighth * 3.0, 0.9, 0.3)
	# Wrap the tail onto the start, then trim to the loop length.
	for i: int in range(tail):
		left[i] += left[n + i]
		right[i] += right[n + i]
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 4)
	var peak: float = 0.0001
	for i: int in range(n):
		peak = maxf(peak, maxf(absf(left[i]), absf(right[i])))
	var g: float = minf(1.0, 0.82 / peak)
	for i: int in range(n):
		bytes.encode_s16(i * 4, int(clampf(left[i] * g, -1.0, 1.0) * 32000.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(right[i] * g, -1.0, 1.0) * 32000.0))
	return bytes


static func _third_below(m: int) -> int:
	# Diatonic third below in G major.
	var pc: int = posmod(m - 7, 12)
	var idx: int = G_MAJOR.find(pc)
	if idx < 0:
		return m - 4
	var target: int = G_MAJOR[posmod(idx - 2, 7)]
	var down: int = posmod(pc - target, 12)
	return m - down


func _add(left: PackedFloat32Array, right: PackedFloat32Array, i: int, v: float, pan: float) -> void:
	if i >= 0 and i < left.size():
		left[i] += v * (1.0 - pan)
		right[i] += v * (1.0 + pan)


# Whistle: a nearly pure sine with a gentle vibrato that fades in, a little breath, and a
# soft attack and release.
func _whistle(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, m: int, dur: float, amp: float, seed: int) -> void:
	var f: float = _midi_hz(m)
	var start: int = int(t0 * float(RATE))
	var n: int = int((dur + 0.08) * float(RATE))
	var ph: float = 0.0
	var r: float = float(RATE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in range(n):
		var t: float = float(i) / r
		var vib: float = 1.0 + 0.007 * minf(1.0, t * 4.0) * sin(t * TAU * 5.5)
		var glide: float = 1.0 - 0.03 * maxf(0.0, 1.0 - t * 30.0) # slides up into the note
		ph = fmod(ph + f * vib * glide / r, 1.0)
		var env: float = minf(1.0, t * 40.0) * (1.0 - smoothstep(dur, dur + 0.08, t))
		var v: float = (sin(ph * TAU) + 0.08 * sin(ph * 2.0 * TAU) + rng.randf_range(-0.03, 0.03)) * env * amp
		_add(left, right, start + i, v, 0.0)


func _tuba(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, m: int, amp: float) -> void:
	var f: float = _midi_hz(m)
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.36 * float(RATE))
	var ph: float = 0.0
	var lp: float = 0.0
	var r: float = float(RATE)
	for i: int in range(n):
		var t: float = float(i) / r
		ph = fmod(ph + f / r, 1.0)
		var raw: float = (0.7 if ph < 0.5 else -0.7) + sin(ph * TAU) * 0.6
		var env: float = minf(1.0, t * 60.0) * exp(-t * 5.0)
		lp += (0.06 + 0.12 * env) * (raw - lp)
		_add(left, right, start + i, lp * env * amp, -0.05)


func _accordion(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, m: int, amp: float) -> void:
	var f: float = _midi_hz(m)
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.17 * float(RATE))
	var p1: float = 0.0
	var p2: float = 0.37
	var lp: float = 0.0
	var r: float = float(RATE)
	for i: int in range(n):
		var t: float = float(i) / r
		p1 = fmod(p1 + f * 0.997 / r, 1.0)
		p2 = fmod(p2 + f * 1.003 / r, 1.0)
		var raw: float = (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0)
		lp += 0.18 * (raw - lp)
		var env: float = minf(1.0, t * 90.0) * (1.0 - smoothstep(0.09, 0.17, t))
		_add(left, right, start + i, lp * env * amp * 0.5, 0.35)


# Banjo: Karplus-Strong plucked string.
func _banjo(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, m: int, amp: float, rng: RandomNumberGenerator) -> void:
	var r: float = float(RATE)
	var period: int = maxi(2, int(r / _midi_hz(m)))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(period)
	for k: int in range(period):
		buf[k] = rng.randf_range(-1.0, 1.0)
	var start: int = int(t0 * r)
	var n: int = int(0.32 * r)
	var idx: int = 0
	for i: int in range(n):
		var nxt: int = (idx + 1) % period
		var v: float = buf[idx]
		buf[idx] = (buf[idx] + buf[nxt]) * 0.496
		idx = nxt
		var env: float = 1.0 - smoothstep(0.24, 0.32, float(i) / r)
		_add(left, right, start + i, v * env * amp, -0.45)


func _kick(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, amp: float) -> void:
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.16 * float(RATE))
	var ph: float = 0.0
	var r: float = float(RATE)
	for i: int in range(n):
		var t: float = float(i) / r
		ph = fmod(ph + (50.0 + 90.0 * exp(-t * 30.0)) / r, 1.0)
		_add(left, right, start + i, sin(ph * TAU) * exp(-t * 18.0) * amp, 0.0)


func _woodblock(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, amp: float) -> void:
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.07 * float(RATE))
	var r: float = float(RATE)
	for i: int in range(n):
		var t: float = float(i) / r
		var v: float = (sin(TAU * 820.0 * t) + 0.4 * sin(TAU * 2140.0 * t)) * exp(-t * 60.0)
		_add(left, right, start + i, v * amp * 0.5, 0.2)


func _shaker(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, amp: float, rng: RandomNumberGenerator) -> void:
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.05 * float(RATE))
	var prev: float = 0.0
	var r: float = float(RATE)
	for i: int in range(n):
		var t: float = float(i) / r
		var x: float = rng.randf_range(-1.0, 1.0)
		var hp: float = x - prev
		prev = x
		var env: float = minf(1.0, t * 300.0) * exp(-t * 70.0)
		_add(left, right, start + i, hp * env * amp * 0.35, 0.3)


func _cowbell(left: PackedFloat32Array, right: PackedFloat32Array, t0: float, amp: float) -> void:
	var start: int = int(t0 * float(RATE))
	var n: int = int(0.35 * float(RATE))
	var r: float = float(RATE)
	var p1: float = 0.0
	var p2: float = 0.0
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / r
		p1 = fmod(p1 + 545.0 / r, 1.0)
		p2 = fmod(p2 + 815.0 / r, 1.0)
		var raw: float = (0.5 if p1 < 0.5 else -0.5) + (0.5 if p2 < 0.5 else -0.5)
		lp += 0.35 * (raw - lp)
		var env: float = exp(-t * 11.0) * 0.7 + exp(-t * 40.0) * 0.3
		_add(left, right, start + i, (raw - lp) * env * amp * 0.6, -0.2)


# A light stereo ping-pong echo over the whole mix.
func _echo(left: PackedFloat32Array, right: PackedFloat32Array, delay_s: float, feedback: float, wet: float) -> void:
	var d: int = int(delay_s * float(RATE))
	for i: int in range(d, left.size()):
		left[i] += right[i - d] * feedback * wet
		right[i] += left[i - d] * feedback * wet
