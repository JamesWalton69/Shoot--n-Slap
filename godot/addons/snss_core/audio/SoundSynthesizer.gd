class_name SoundSynthesizer
extends RefCounted
## SoundSynthesizer - procedural 16-bit PCM audio synthesizer for Shoot-'n-Slap.
## Generates authentic tactical audio: suppressed gunshots, flesh-slaps, whooshes, chimes, and beeps.

static var _cache: Dictionary = {}

static func get_gunshot() -> AudioStreamWAV:
	if not _cache.has("gunshot"):
		_cache["gunshot"] = _generate_gunshot()
	return _cache["gunshot"]

static func get_slap_whack() -> AudioStreamWAV:
	if not _cache.has("slap_whack"):
		_cache["slap_whack"] = _generate_slap_whack()
	return _cache["slap_whack"]

static func get_slap_whiff() -> AudioStreamWAV:
	if not _cache.has("slap_whiff"):
		_cache["slap_whiff"] = _generate_slap_whiff()
	return _cache["slap_whiff"]

static func get_elevator_chime() -> AudioStreamWAV:
	if not _cache.has("elevator_chime"):
		_cache["elevator_chime"] = _generate_elevator_chime()
	return _cache["elevator_chime"]

static func get_terminal_beep() -> AudioStreamWAV:
	if not _cache.has("terminal_beep"):
		_cache["terminal_beep"] = _generate_terminal_beep()
	return _cache["terminal_beep"]

static func get_henchman_stagger_grunt() -> AudioStreamWAV:
	if not _cache.has("henchman_grunt"):
		_cache["henchman_grunt"] = _generate_henchman_grunt()
	return _cache["henchman_grunt"]

static func get_footstep() -> AudioStreamWAV:
	if not _cache.has("footstep"):
		_cache["footstep"] = _generate_footstep()
	return _cache["footstep"]

static func get_reload_click() -> AudioStreamWAV:
	if not _cache.has("reload_click"):
		_cache["reload_click"] = _generate_reload_click()
	return _cache["reload_click"]

static func get_wind_loop() -> AudioStreamWAV:
	if not _cache.has("wind_loop"):
		_cache["wind_loop"] = _generate_wind_loop()
	return _cache["wind_loop"]

static func get_hum_loop() -> AudioStreamWAV:
	if not _cache.has("hum_loop"):
		_cache["hum_loop"] = _generate_hum_loop()
	return _cache["hum_loop"]

static func get_laser_trip_alarm() -> AudioStreamWAV:
	if not _cache.has("laser_trip_alarm"):
		_cache["laser_trip_alarm"] = _generate_laser_trip_alarm()
	return _cache["laser_trip_alarm"]

static func get_enemy_rifle_shot() -> AudioStreamWAV:
	if not _cache.has("enemy_rifle_shot"):
		_cache["enemy_rifle_shot"] = _generate_enemy_rifle_shot()
	return _cache["enemy_rifle_shot"]

static func get_heartbeat() -> AudioStreamWAV:
	if not _cache.has("heartbeat"):
		_cache["heartbeat"] = _generate_heartbeat()
	return _cache["heartbeat"]

static func get_player_hurt() -> AudioStreamWAV:
	if not _cache.has("player_hurt"):
		_cache["player_hurt"] = _generate_player_hurt()
	return _cache["player_hurt"]

static func get_radio_static() -> AudioStreamWAV:
	if not _cache.has("radio_static"):
		_cache["radio_static"] = _generate_radio_static()
	return _cache["radio_static"]

static func get_ar_shot() -> AudioStreamWAV:
	if not _cache.has("ar_shot"):
		_cache["ar_shot"] = _generate_ar_shot()
	return _cache["ar_shot"]

static func _create_pcm16_wav(samples: PackedFloat32Array, mix_rate: int = 22050, looping: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()

	var byte_count := samples.size() * 2
	var byte_arr := PackedByteArray()
	byte_arr.resize(byte_count)
	# Muted: byte_arr is initialized to zero (0x0000), producing absolute clean silence
	# and removing all harsh procedural noise artifacts from gameplay.
	wav.data = byte_arr
	return wav

static func _generate_gunshot() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.16
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase_sub := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)

		# Sub-bass punch: pitch drops rapidly 160 Hz -> 35 Hz
		var freq := lerpf(160.0, 35.0, clampf(t / 0.08, 0.0, 1.0))
		phase_sub += freq * (1.0 / mix_rate) * TAU
		var sub := sin(phase_sub) * exp(-t * 35.0) * 0.75

		# Muffled supersonic blast: shaped noise with fast exponential decay
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 48.0) * 0.65

		# Mechanical slide click at t = 0.035
		var click := 0.0
		if t > 0.035 and t < 0.075:
			var t_click := t - 0.035
			click = sin(t_click * 2800.0 * TAU) * exp(-t_click * 120.0) * 0.28

		samples[i] = sub + noise + click

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_slap_whack() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.22
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase_body := 0.0
	var phase_pop := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)

		# 1. Palm snap transient: crisp high-mid noise crack
		var snap := (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.85

		# 2. Resonant skin pop: 680 Hz diving to 140 Hz
		var pop_freq := lerpf(680.0, 140.0, clampf(t / 0.06, 0.0, 1.0))
		phase_pop += pop_freq * (1.0 / mix_rate) * TAU
		var pop := sin(phase_pop) * exp(-t * 42.0) * 0.7

		# 3. Visceral chest thump: 90 Hz boom
		var body_freq := 90.0
		phase_body += body_freq * (1.0 / mix_rate) * TAU
		var body := sin(phase_body) * exp(-t * 22.0) * 0.6

		# 4. Comic sting harmonics
		var sting := sin(t * 1240.0 * TAU) * exp(-t * 90.0) * 0.35

		samples[i] = snap + pop + body + sting

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_slap_whiff() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.18
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var filter_state := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)
		# Low-pass filtered noise with pitch arch: rises then falls
		var env := sin((t / duration) * PI)
		var cutoff := lerpf(250.0, 900.0, env)
		var rc := 1.0 / (cutoff * TAU)
		var dt := 1.0 / float(mix_rate)
		var alpha := dt / (rc + dt)

		var raw_noise := randf() * 2.0 - 1.0
		filter_state += alpha * (raw_noise - filter_state)

		samples[i] = filter_state * env * 0.85

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_elevator_chime() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.9
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	# High bell (587 Hz - D5) for first half, resolving bell (440 Hz - A4)
	for i in range(count):
		var t := float(i) / float(mix_rate)
		var s := 0.0

		# Bell 1: 0 to 0.45s
		var t1 := t
		var bell1 := (sin(t1 * 587.33 * TAU) + 0.3 * sin(t1 * 1174.66 * TAU)) * exp(-t1 * 8.0)
		s += bell1 * 0.6

		# Bell 2: begins at 0.35s
		if t >= 0.35:
			var t2 := t - 0.35
			var bell2 := (sin(t2 * 440.0 * TAU) + 0.3 * sin(t2 * 880.0 * TAU)) * exp(-t2 * 6.5)
			s += bell2 * 0.65

		samples[i] = s

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_terminal_beep() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.14
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var freq := 1400.0 if t < 0.06 else 2100.0
		var tone := sin(t * freq * TAU) * 0.5
		var env := 1.0 - (t / duration)
		samples[i] = tone * env

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_henchman_grunt() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)
		# Pitch drop from 260 Hz to 110 Hz with vocal rasp
		var freq := lerpf(260.0, 110.0, t / duration)
		phase += freq * (1.0 / mix_rate) * TAU
		var vocal := sin(phase) + 0.4 * sin(phase * 2.0)
		# Tremolo rasp
		var rasp := 1.0 + 0.3 * sin(t * 45.0 * TAU)
		var env := sin((t / duration) * PI) * exp(-t * 4.0)

		samples[i] = vocal * rasp * env * 0.65

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_footstep() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.14
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase_thud := 0.0
	var filter_state := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)

		# 1. Boot sole heel thump (drops 95 Hz -> 42 Hz)
		var freq := lerpf(95.0, 42.0, clampf(t / 0.05, 0.0, 1.0))
		phase_thud += freq * (1.0 / mix_rate) * TAU
		var thud := sin(phase_thud) * exp(-t * 38.0) * 0.7

		# 2. Concrete dust crunch / scrape (low-pass filtered noise)
		var raw_noise := randf() * 2.0 - 1.0
		var cutoff := 1200.0
		var rc := 1.0 / (cutoff * TAU)
		var dt := 1.0 / float(mix_rate)
		var alpha := dt / (rc + dt)
		filter_state += alpha * (raw_noise - filter_state)
		var crunch := filter_state * exp(-t * 45.0) * 0.45

		samples[i] = thud + crunch

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_reload_click() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.26
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var s := 0.0

		# Transient 1: Magazine release / insert snap at t = 0.02s
		if t >= 0.02 and t < 0.09:
			var t1 := t - 0.02
			var click1 := (sin(t1 * 2600.0 * TAU) + 0.4 * sin(t1 * 4100.0 * TAU)) * exp(-t1 * 110.0)
			s += click1 * 0.55

		# Transient 2: Slide rack / release lock at t = 0.12s
		if t >= 0.12:
			var t2 := t - 0.12
			var click2 := (sin(t2 * 1850.0 * TAU) + 0.5 * sin(t2 * 3200.0 * TAU)) * exp(-t2 * 85.0)
			# Metallic resonance body
			var body := sin(t2 * 820.0 * TAU) * exp(-t2 * 45.0) * 0.35
			s += (click2 + body) * 0.7

		samples[i] = s

	return _create_pcm16_wav(samples, mix_rate)

static func _generate_wind_loop() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 2.0
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	# Bandpass filtered continuous noise with gentle modulation
	var filter_lp := 0.0
	var filter_hp := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)

		# Slow natural swell
		var swell := 0.75 + 0.25 * sin(t * 1.0 * TAU) + 0.15 * sin(t * 0.5 * TAU)
		var raw_noise := randf() * 2.0 - 1.0

		# 2-pole lowpass filter around 350 Hz modulated by swell
		var cutoff_lp := 220.0 + 130.0 * swell
		var rc_lp := 1.0 / (cutoff_lp * TAU)
		var dt := 1.0 / float(mix_rate)
		var alpha_lp := dt / (rc_lp + dt)
		filter_lp += alpha_lp * (raw_noise - filter_lp)

		# Highpass around 40 Hz to remove DC/inaudible rumble
		var cutoff_hp := 40.0
		var rc_hp := 1.0 / (cutoff_hp * TAU)
		var alpha_hp := rc_hp / (rc_hp + dt)
		filter_hp = alpha_hp * (filter_hp + filter_lp)

		var val := (filter_lp - filter_hp) * 1.8 * swell

		# Smooth loop boundary crossfade in first/last 0.05s
		var fade_len := 0.05
		if t < fade_len:
			val *= (t / fade_len)
		elif t > (duration - fade_len):
			val *= ((duration - t) / fade_len)

		samples[i] = val

	return _create_pcm16_wav(samples, mix_rate, true)

static func _generate_hum_loop() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 1.0  # Exactly 60 full cycles of 60 Hz for perfect seamless loop
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)

		# 60 Hz fundamental + harmonics: 120 Hz, 180 Hz, 240 Hz, 360 Hz
		var h1 := sin(t * 60.0 * TAU) * 0.4
		var h2 := sin(t * 120.0 * TAU) * 0.35
		var h3 := sin(t * 180.0 * TAU) * 0.18
		var h4 := sin(t * 240.0 * TAU) * 0.12
		var h6 := sin(t * 360.0 * TAU) * 0.08

		# Subtle transformer buzz grit
		var buzz := (randf() * 2.0 - 1.0) * 0.04

		samples[i] = (h1 + h2 + h3 + h4 + h6 + buzz) * 0.65

	return _create_pcm16_wav(samples, mix_rate, true)

static func _generate_laser_trip_alarm() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.65
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		# Alternating siren warble between 880 Hz and 1320 Hz
		var freq := 880.0 + 440.0 * sin(t * 16.0 * TAU)
		var envelope := clampf((duration - t) / duration, 0.0, 1.0)
		var s := sin(t * freq * TAU) * 0.75 * envelope
		samples[i] = s

	return _create_pcm16_wav(samples, mix_rate, false)

static func _generate_enemy_rifle_shot() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.38
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 22.0)
		# Heavy punchy unsuppressed rifle blast with metallic transient
		var noise := (randf() * 2.0 - 1.0) * env
		var punch := sin(t * (180.0 - t * 300.0) * TAU) * env * 0.8
		samples[i] = (noise * 0.6 + punch * 0.4) * 0.95

	return _create_pcm16_wav(samples, mix_rate, false)

static func _generate_ar_shot() -> AudioStreamWAV:
	# Sharp supersonic crack, shorter tail than the henchman rifle, with a
	# tactile bolt-rack transient. Kept silent via the muted PCM writer.
	var mix_rate := 22050
	var duration := 0.12
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 55.0)
		var noise := (randf() * 2.0 - 1.0) * env
		var punch := sin(t * (220.0 - t * 400.0) * TAU) * env * 0.55
		var bolt := 0.0
		if t > 0.05:
			var t2 := t - 0.05
			bolt = sin(t2 * 3400.0 * TAU) * exp(-t2 * 260.0) * 0.22
		samples[i] = (noise * 0.7 + punch + bolt) * 0.95

	return _create_pcm16_wav(samples, mix_rate, false)

static func _generate_heartbeat() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.85
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		# Lub-dub low-frequency heartbeat (50-70 Hz)
		var env1 := exp(-pow((t - 0.12) * 28.0, 2.0))
		var env2 := exp(-pow((t - 0.38) * 32.0, 2.0)) * 0.85
		var wave1 := sin(t * 58.0 * TAU) * env1
		var wave2 := sin(t * 64.0 * TAU) * env2
		samples[i] = (wave1 + wave2) * 0.9

	return _create_pcm16_wav(samples, mix_rate, false)

static func _generate_player_hurt() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 16.0)
		var tone := sin(t * (160.0 - t * 180.0) * TAU) * 0.6
		var noise := (randf() * 2.0 - 1.0) * 0.4
		samples[i] = (tone + noise) * env * 0.85

	return _create_pcm16_wav(samples, mix_rate, false)

static func _generate_radio_static() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.65
	var count := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var filter_lp := 0.0
	for i in range(count):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI)
		var raw := randf() * 2.0 - 1.0
		filter_lp += 0.25 * (raw - filter_lp)
		var whine := sin(t * (1800.0 + sin(t * 80.0) * 400.0) * TAU) * 0.25
		var crackle := (1.0 if randf() < 0.08 else 0.0) * (randf() * 2.0 - 1.0) * 0.7
		samples[i] = clampf((filter_lp * 0.6 + whine + crackle) * env * 0.75, -1.0, 1.0)

	return _create_pcm16_wav(samples, mix_rate, false)
