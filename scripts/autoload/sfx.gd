extends Node

# Sound effects, synthesized at startup into AudioStreamWAVs (no audio files).
# Sfx.play("squirt"). Names: squirt, coin, buy, cant, milestone, moo, hire, rush, bell, ui.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["squirt"] = _squirt()
	_streams["coin"] = _notes([1320.0, 1760.0], 0.05, 0, 0.35)
	_streams["buy"] = _notes([660.0, 880.0], 0.045, 1, 0.3)
	_streams["cant"] = _notes([220.0, 180.0], 0.07, 1, 0.3)
	_streams["milestone"] = _notes([523.0, 659.0, 784.0, 1047.0], 0.07, 1, 0.35)
	_streams["hire"] = _notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.06, 1, 0.35)
	_streams["bell"] = _notes([1568.0, 2093.0, 2637.0, 3136.0, 2637.0, 3136.0], 0.08, 0, 0.3)
	_streams["rush"] = _sweep(300.0, 1400.0, 0.45)
	_streams["moo"] = _moo()
	_streams["ui"] = _notes([990.0], 0.03, 1, 0.25)


func play(name: String, vol_db: float = -6.0, jitter: float = 0.05) -> void:
	if not _streams.has(name) or Farm.sfx_volume <= 0.01:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
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


# Milk squirt: a burst of filtered noise that falls in pitch.
func _squirt() -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = int(0.09 * float(MIX_RATE))
	var lp: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var k: float = lerpf(0.55, 0.08, t)
		lp += k * (rng.randf_range(-1.0, 1.0) - lp)
		out.append(lp * (1.0 - t) * 0.9)
	return _to_stream(out)


# Moo: a low buzzy saw that bends down, through a soft low-pass, with a little wobble.
func _moo() -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = int(0.75 * float(MIX_RATE))
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var f: float = lerpf(150.0, 105.0, t) * (1.0 + 0.02 * sin(t * 40.0))
		phase = fmod(phase + f / float(MIX_RATE), 1.0)
		var saw: float = 2.0 * phase - 1.0
		lp += 0.12 * (saw - lp)
		var env: float = minf(1.0, t * 12.0) * (1.0 - t)
		out.append(lp * env * 0.8)
	return _to_stream(out)
