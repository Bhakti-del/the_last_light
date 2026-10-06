extends Node
## Procedural audio. Every sound in the game is synthesised at runtime into an
## AudioStreamWAV — no .wav files ship with the project.

const MIX := 22050
const POOL_2D := 10
const POOL_3D := 12

const BUS_SFX := &"Sfx"
const BUS_AMB := &"Ambience"
const BUS_MUSIC := &"Music"

var _cache: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
## 3D voices parented to a node (creature growl, torch hum).
var _loops: Dictionary = {}
## 2D switchable beds (ambience per part of the house).
var _beds: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _ready_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0x7A11
	_init_buses()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = BUS_SFX
		p3.max_distance = 45.0
		p3.unit_size = 6.0
		add_child(p3)
		_pool3d.append(p3)
	_ready_done = true
	# the constant musical bed; ambience voices are separate and swappable
	_start_bed(&"music", &"drone", BUS_MUSIC, -17.0)


func _init_buses() -> void:
	for bus_name in [BUS_SFX, BUS_AMB, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, String(bus_name))
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")


# --- Playback --------------------------------------------------------------

func play_2d(name: StringName, volume_db: float = 0.0, pitch: float = 1.0, bus: StringName = BUS_SFX) -> void:
	if not _ready_done:
		return
	var stream := get_stream(name)
	if stream == null:
		return
	for p in _pool2d:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.bus = bus
			p.play()
			return
	var p0 := _pool2d[0]
	p0.stream = stream
	p0.volume_db = volume_db
	p0.pitch_scale = pitch
	p0.bus = bus
	p0.play()


func play_3d(name: StringName, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _ready_done:
		return
	var stream := get_stream(name)
	if stream == null:
		return
	for p in _pool3d:
		if not p.playing:
			p.stream = stream
			p.global_position = pos
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Attach a looping voice to a node (creature growl, flashlight hum).
func attach_loop(voice: StringName, parent: Node3D, name: StringName, volume_db: float = 0.0, pitch: float = 1.0, bus: StringName = BUS_SFX) -> void:
	if not _ready_done or _loops.has(voice):
		return
	var stream := get_stream(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = 45.0
	p.unit_size = 8.0
	parent.add_child(p)
	p.play()
	_loops[voice] = p


func set_loop(voice: StringName, volume_db: float = -60.0, pitch: float = 1.0) -> void:
	if not _loops.has(voice):
		return
	var p = _loops[voice]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if volume_db <= -59.0 and p.playing:
		p.stop()
	elif volume_db > -59.0 and not p.playing:
		p.play()


func stop_loop(voice: StringName) -> void:
	if _loops.has(voice):
		var p = _loops[voice]
		p.stop()
		p.queue_free()
		_loops.erase(voice)


func stop_all_loops() -> void:
	for v in _loops.keys():
		stop_loop(v)


## Start (or replace) a switchable 2D ambience bed.
func start_loop(name: StringName, bus: StringName, volume_db: float, pitch: float = 1.0) -> void:
	if not _ready_done:
		return
	var stream := get_stream(name)
	if stream == null:
		return
	stop_bus_voice(name)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	_beds[name] = p


func stop_bus_voice(name: StringName) -> void:
	if _beds.has(name):
		var p = _beds[name]
		p.stop()
		p.queue_free()
		_beds.erase(name)


func _start_bed(key: StringName, stream_name: StringName, bus: StringName,
		volume_db: float, pitch: float = 1.0) -> void:
	var stream := get_stream(stream_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	_beds[key] = p


# --- Stream factory --------------------------------------------------------

func get_stream(name: StringName) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var stream: AudioStream = _synth(name)
	_cache[name] = stream
	return stream


func _synth(name: StringName) -> AudioStream:
	match name:
		&"step_wood": return _wav(_step(0.135, 0.16, 0.0))
		&"step_soft": return _wav(_step(0.155, 0.10, 0.03))
		&"step_concrete": return _wav(_step(0.115, 0.26, 0.0))
		&"click": return _wav(_click(0.035, 0.55))
		&"light_on": return _wav(_double_click())
		&"light_off": return _wav(_click(0.05, 0.30))
		&"light_dead": return _wav(_dead_click())
		&"pickup": return _wav(_chime([523.25, 783.99], 0.22, 0.5))
		&"key": return _wav(_metal_ding(1180.0, 0.42))
		&"panel": return _wav(_paper_rustle())
		&"door_open": return _wav(_creak(0.95))
		&"door_locked": return _wav(_locked_rattle())
		&"dial": return _wav(_dial_click())
		&"lever": return _wav(_clunk())
		&"growl_idle": return _wav(_growl(2.4, 52.0, 0.35, 0.55), true)
		&"growl_alert": return _wav(_growl(1.3, 74.0, 1.0, 0.35))
		&"growl_chase": return _wav(_growl(1.5, 96.0, 1.7, 0.28))
		&"scream": return _wav(_scream())
		&"heart": return _wav(_heartbeat())
		&"sting": return _wav(_sting(1.5, 0.55))
		&"twist": return _wav(_sting(2.6, 1.0, 0.62))
		&"drone": return _wav(_drone(), true)
		&"hum": return _wav(_hum(), true)
		&"whisper": return _wav(_whisper(), true)
		&"success": return _wav(_chime([392.0, 523.25, 659.25, 783.99], 0.9, 0.6))
		&"page": return _wav(_page_turn())
	return null


# --- Sample helpers --------------------------------------------------------

func _wav(s: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n := s.size()
	if loop:
		s = _loop_fade(s, MIX / 12)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX
	st.stereo = false
	st.data = bytes
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = n
	return st


## Crossfade buffer tail into head so loops have no click.
func _loop_fade(s: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := s.size()
	fade = mini(fade, n / 3)
	if fade <= 1:
		return s
	var out := s.duplicate()
	for i in fade:
		var t := float(i) / fade
		var head := s[i]
		var tail := s[n - fade + i]
		out[i] = lerpf(tail, head, t)
	return out


func _blank(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(maxi(1, int(dur * MIX)))
	a.fill(0.0)
	return a


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


# --- Individual synths -----------------------------------------------------

func _step(dur: float, bright: float, sub: float) -> PackedFloat32Array:
	var out := _blank(dur)
	var lp := 0.0
	var lp2 := 0.0
	var seed_off := _rng.randi_range(0, 4096)
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = exp(-t * 15.0)
		var cut: float = lerpf(0.10, 0.62, bright) * (1.0 - t * 0.55)
		lp += cut * (_noise() - lp)
		lp2 += cut * 0.45 * (lp - lp2)
		var v := lp * env * 0.75
		if sub > 0.0:
			var f := TAU * lerpf(120.0, 55.0, t)
			v += sin(f * float(i) / MIX) * exp(-t * 22.0) * sub
		out[i] = v
	# tiny second scuff so steps do not sound identical
	var idx := seed_off % maxi(1, out.size() - 200)
	for k in 220:
		out[idx + k] += _noise() * exp(-float(k) / 40.0) * 0.18
	return out


func _click(dur: float, tone: float) -> PackedFloat32Array:
	var out := _blank(dur)
	var hp := 0.0
	var prev := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = exp(-t * 40.0)
		var n := _noise()
		hp = 0.72 * (hp + n - prev)
		prev = n
		out[i] = (hp * 0.85 + sin(TAU * lerpf(2600.0, 1500.0, t) * float(i) / MIX) * tone * 0.5) * env
	return out


func _double_click() -> PackedFloat32Array:
	var a := _click(0.04, 0.5)
	var b := _click(0.05, 0.35)
	var out := _blank(0.16)
	for i in a.size():
		out[i] += a[i] * 0.9
	for i in b.size():
		out[80 + i] += b[i] * 0.7
	return out


func _dead_click() -> PackedFloat32Array:
	var out := _blank(0.22)
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = exp(-t * 9.0)
		var f := lerpf(1500.0, 90.0, t)
		out[i] = (sin(TAU * f * float(i) / MIX) * 0.6 + _noise() * 0.2) * env
	return out


func _chime(freqs: Array, dur: float, decay: float) -> PackedFloat32Array:
	var out := _blank(dur)
	for k in freqs.size():
		var f: float = freqs[k]
		var start: int = int(k * MIX * 0.055)
		for i in range(start, out.size()):
			var t := float(i - start) / out.size()
			var env: float = exp(-t * (6.0 + k * 2.0) * decay * 4.0)
			var ph := TAU * f * float(i) / MIX
			out[i] += (sin(ph) * 0.6 + sin(ph * 2.01) * 0.2) * env * 0.4
	return out


func _metal_ding(freq: float, dur: float) -> PackedFloat32Array:
	var out := _blank(dur)
	var partials := [1.0, 2.76, 5.40, 8.93]
	for k in partials.size():
		var f: float = freq * partials[k]
		var amp: float = 0.55 / (1.0 + k * 1.1)
		for i in out.size():
			var t := float(i) / out.size()
			var env: float = exp(-t * (7.0 + k * 5.0))
			out[i] += sin(TAU * f * float(i) / MIX) * env * amp
	return out


func _paper_rustle() -> PackedFloat32Array:
	var out := _blank(0.42)
	var bp := 0.0
	var bp2 := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = sin(PI * clampf(t * 1.05, 0.0, 1.0))
		env *= 0.55 + 0.45 * sin(t * 46.0)
		var n := _noise()
		bp += 0.30 * (n - bp)
		bp2 += 0.09 * (bp - bp2)
		out[i] = (bp - bp2) * env * 0.8
	return out


func _page_turn() -> PackedFloat32Array:
	var out := _blank(0.3)
	var bp := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = sin(PI * t) * (0.4 + 0.6 * sin(t * 30.0))
		var n := _noise()
		bp += 0.35 * (n - bp)
		lp += 0.06 * (n - lp)
		out[i] = (bp * 0.6 + (n - lp) * 0.4) * env * 0.6
	return out


func _creak(dur: float) -> PackedFloat32Array:
	var out := _blank(dur)
	var phase := 0.0
	var mod := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = sin(PI * t) * 0.8
		var f: float = lerpf(120.0, 260.0, t * t)
		mod += 0.0016 * (f * (1.0 + 3.0 * sin(t * 90.0)) - mod)
		phase += TAU * mod / MIX
		var grind := sin(phase * 3.1) * 0.25 + sin(phase * 1.0) * 0.5
		out[i] = (grind * 0.7 + _noise() * 0.12) * env
	return out


func _locked_rattle() -> PackedFloat32Array:
	var out := _blank(0.45)
	for k in 5:
		var off := int(k * MIX * (0.03 + 0.02 * float(k % 3)))
		var c := _click(0.05, 0.2 + 0.06 * float(k))
		for i in c.size():
			if off + i < out.size():
				out[off + i] += c[i] * (0.55 - 0.07 * float(k))
	var thud := _step(0.3, 0.06, 0.5)
	for i in mini(thud.size(), out.size()):
		out[i] += thud[i] * 0.7
	return out


func _dial_click() -> PackedFloat32Array:
	var out := _blank(0.13)
	var d := _metal_ding(760.0, 0.12)
	for i in d.size():
		out[i] += d[i] * 0.55
	var c := _click(0.03, 0.3)
	for i in c.size():
		out[i] += c[i] * 0.6
	return out


func _clunk() -> PackedFloat32Array:
	var out := _blank(0.5)
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = exp(-t * 12.0)
		var f := lerpf(220.0, 70.0, t)
		out[i] = sin(TAU * f * float(i) / MIX) * env * 0.7
	var d := _metal_ding(520.0, 0.35)
	for i in d.size():
		out[i] += d[i] * 0.25
	return out


func _growl(dur: float, base: float, aggression: float, bright: float) -> PackedFloat32Array:
	var out := _blank(dur)
	var phase := 0.0
	var modph := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = sin(PI * clampf(t, 0.0, 1.0))
		env = pow(env, 0.6)
		var wobble := 1.0 + 0.16 * sin(t * TAU * 5.5) + aggression * 0.10 * sin(t * TAU * 17.0)
		var f := base * wobble * lerpf(1.0, 0.82, t)
		phase += TAU * f / MIX
		modph += TAU * (f * (2.0 + aggression * 3.0)) / MIX
		var fm := sin(modph) * (2.0 + aggression * 9.0)
		var v := sin(phase + fm * 0.35) + sin(phase * 0.5) * 0.4
		v += _noise() * bright * 0.25
		lp += 0.08 * (v - lp)
		out[i] = lp * env * 0.85
	return out


func _scream() -> PackedFloat32Array:
	var out := _blank(1.7)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = minf(1.0, t * 24.0) * exp(-t * 2.1)
		var f := lerpf(880.0, 110.0, pow(t, 0.7)) * (1.0 + 0.05 * sin(t * 70.0))
		phase += TAU * f / MIX
		var v := sin(phase) * 0.6 + sin(phase * 2.02) * 0.25 + _noise() * 0.18
		out[i] = v * env
	return out


func _heartbeat() -> PackedFloat32Array:
	var out := _blank(1.0)
	for beat in 2:
		var off := int(beat * MIX * 0.30)
		var th := _step(0.20, 0.05, 0.65)
		var amp := 1.0 if beat == 0 else 0.62
		for i in th.size():
			if off + i < out.size():
				out[off + i] += th[i] * amp
	return out


func _sting(dur: float, weight: float, dissonance: float = 0.55) -> PackedFloat32Array:
	var out := _blank(dur)
	var root := lerpf(146.83, 110.0, weight)
	var ratios := [1.0, 1.06 + dissonance * 0.08, 1.5, 2.0 + dissonance * 0.2, 2.99]
	for k in ratios.size():
		var f: float = root * ratios[k]
		var amp: float = (0.45 / (1.0 + k * 0.55)) * lerpf(0.6, 1.0, weight)
		var detune: float = 0.4 + k * 0.25
		for i in out.size():
			var t := float(i) / out.size()
			var env: float = minf(1.0, t * 40.0) * exp(-t * lerpf(3.2, 1.7, weight))
			var vib := 1.0 + detune * 0.006 * sin(t * TAU * (5.0 + k * 0.7))
			out[i] += sin(TAU * f * vib * float(i) / MIX) * env * amp
	# slow swelling noise underneath the tone, low-passed one sample at a time
	var lp := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var env: float = minf(1.0, t * 60.0) * exp(-t * 5.0)
		lp = lerpf(lp, _noise(), 0.02)
		out[i] += lp * env * 0.10 * weight
	return out


func _drone() -> PackedFloat32Array:
	var dur := 8.0
	var out := _blank(dur)
	var freqs := [27.5, 41.25, 55.0, 82.5, 110.0]
	var amps := [0.55, 0.30, 0.40, 0.16, 0.10]
	for k in freqs.size():
		var f: float = freqs[k]
		for i in out.size():
			var t := float(i) / MIX
			var trem: float = 1.0 + 0.22 * sin(TAU * (0.125 + 0.125 * k) * t)
			out[i] += sin(TAU * f * t) * amps[k] * trem
	for i in out.size():
		var t := float(i) / out.size()
		out[i] *= 0.35 + 0.65 * (0.5 - 0.5 * cos(TAU * t))
	return out


func _hum() -> PackedFloat32Array:
	var dur := 2.0
	var out := _blank(dur)
	for i in out.size():
		var t := float(i) / MIX
		out[i] = (sin(TAU * 100.0 * t) * 0.35 + sin(TAU * 150.0 * t) * 0.18) * 0.5
	return out


func _whisper() -> PackedFloat32Array:
	var dur := 6.0
	var out := _blank(dur)
	var bp := 0.0
	var bp2 := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		var n := _noise()
		bp += 0.22 * (n - bp)
		bp2 += 0.05 * (bp - bp2)
		var shape := 0.35 + 0.65 * absf(sin(TAU * 1.5 * t))
		var breath := sin(TAU * 3.25 * t) * 0.5 + 0.5
		out[i] = (bp - bp2) * shape * breath * 0.7
	return out