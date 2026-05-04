extends Node
## 自動載入：基本音效（採集／攻擊／烹飪／製作／放置／拾取／互動／技能）。於執行期合成短 PCM，無需外部音檔。

const POOL_SIZE := 10
const SAMPLE_RATE := 22050

var _pool: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _rr: int = 0
var volume_scale: float = 1.0
var muted: bool = false


func _ready() -> void:
	_streams[&"attack_chop"] = _make_attack_chop()
	_streams[&"cook"] = _make_cook()
	_streams[&"craft"] = _make_craft()
	_streams[&"interact"] = _make_interact()
	_streams[&"pickup"] = _make_pickup()
	_streams[&"place"] = _make_place()
	_streams[&"skill_whoosh"] = _make_skill_whoosh()
	_streams[&"eat"] = _make_eat()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func play_attack_chop(pitch_scale: float = 1.0, volume_db: float = -2.0) -> void:
	_play_named(&"attack_chop", pitch_scale, volume_db)


func play_cook(volume_db: float = -1.0) -> void:
	_play_named(&"cook", 1.0, volume_db)


func play_craft(volume_db: float = -1.0) -> void:
	_play_named(&"craft", 1.0, volume_db)


func play_interact(volume_db: float = -4.0) -> void:
	_play_named(&"interact", 1.0, volume_db)


func play_pickup(volume_db: float = -3.0) -> void:
	_play_named(&"pickup", 1.0, volume_db)


func play_place(volume_db: float = -2.0) -> void:
	_play_named(&"place", 1.0, volume_db)


func play_skill_whoosh(pitch_scale: float = 1.0, volume_db: float = -3.0) -> void:
	_play_named(&"skill_whoosh", pitch_scale, volume_db)


func play_eat(volume_db: float = -5.0) -> void:
	_play_named(&"eat", 1.0, volume_db)


func _play_named(key: StringName, pitch_scale: float, volume_db: float) -> void:
	if muted or volume_scale <= 0.001:
		return
	var st: AudioStreamWAV = _streams.get(key, null) as AudioStreamWAV
	if st == null:
		return
	var pl := _acquire_player()
	pl.stream = st
	pl.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	pl.volume_db = volume_db + linear_to_db(volume_scale)
	pl.play()


func _acquire_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	var pl := _pool[_rr % _pool.size()]
	_rr += 1
	pl.stop()
	return pl


func _pack_mono16(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _env_linear(i: int, n: int, fade_in: int, fade_out: int) -> float:
	var v := 1.0
	if fade_in > 0 and i < fade_in:
		v = float(i) / float(fade_in)
	var j := n - 1 - i
	if fade_out > 0 and j < fade_out:
		v = minf(v, float(j) / float(fade_out))
	return v


func _make_attack_chop() -> AudioStreamWAV:
	var dur := 0.11
	var n := int(SAMPLE_RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 8, 40)
		var thump := 0.55 * sin(TAU * 95.0 * t) * exp(-t * 38.0)
		var noise := (rng.randf() * 2.0 - 1.0) * 0.35 * exp(-t * 55.0)
		var mid := 0.12 * sin(TAU * 420.0 * t) * exp(-t * 30.0)
		buf[i] = (thump + noise + mid) * env
	return _pack_mono16(buf)


func _make_cook() -> AudioStreamWAV:
	var dur := 0.22
	var n := int(SAMPLE_RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 20, 60)
		var crack := (rng.randf() * 2.0 - 1.0) * 0.22 * (0.5 + 0.5 * sin(TAU * 6.0 * t))
		var hiss := (rng.randf() * 2.0 - 1.0) * 0.08
		buf[i] = (crack + hiss) * env * (0.65 + 0.35 * sin(TAU * 2.2 * t))
	return _pack_mono16(buf)


func _make_craft() -> AudioStreamWAV:
	var total := int(SAMPLE_RATE * 0.2)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for k in buf.size():
		buf[k] = 0.0
	for hit in range(2):
		var start_sec := 0.015 if hit == 0 else 0.09
		var f0 := 540.0 if hit == 0 else 360.0
		var start := int(SAMPLE_RATE * start_sec)
		var seg_n := int(SAMPLE_RATE * 0.055)
		for j in seg_n:
			var idx := start + j
			if idx >= total:
				break
			var tt := float(j) / float(SAMPLE_RATE)
			var env := exp(-tt * 30.0)
			var s := 0.44 * sin(TAU * f0 * tt) + 0.1 * sin(TAU * f0 * 2.4 * tt)
			buf[idx] += s * env
	return _pack_mono16(buf)


func _make_interact() -> AudioStreamWAV:
	var dur := 0.07
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 4, 20)
		buf[i] = (
			0.32 * (sin(TAU * 660.0 * t) + 0.45 * sin(TAU * 990.0 * t)) * env
		)
	return _pack_mono16(buf)


func _make_pickup() -> AudioStreamWAV:
	var dur := 0.09
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 6, 25)
		var f := 380.0 + 620.0 * (t / (dur * 0.95))
		buf[i] = 0.34 * sin(TAU * f * t) * env
	return _pack_mono16(buf)


func _make_place() -> AudioStreamWAV:
	var dur := 0.14
	var n := int(SAMPLE_RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 4, 45)
		var body := 0.5 * sin(TAU * 70.0 * t) * exp(-t * 22.0)
		var tap := 0.18 * sin(TAU * 200.0 * t) * exp(-t * 40.0)
		var nse := (rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 35.0)
		buf[i] = (body + tap + nse) * env
	return _pack_mono16(buf)


func _make_skill_whoosh() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(SAMPLE_RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 10, 50)
		var f := 800.0 + 2200.0 * (t / dur)
		var car := sin(TAU * f * t * 0.015)
		var ns := (rng.randf() * 2.0 - 1.0) * 0.35
		buf[i] = ns * (0.4 + 0.6 * absf(car)) * exp(-t * 8.0) * env
	return _pack_mono16(buf)


func _make_eat() -> AudioStreamWAV:
	var dur := 0.08
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := _env_linear(i, n, 4, 25)
		buf[i] = 0.22 * sin(TAU * 180.0 * t) * sin(TAU * 45.0 * t) * env
	return _pack_mono16(buf)
