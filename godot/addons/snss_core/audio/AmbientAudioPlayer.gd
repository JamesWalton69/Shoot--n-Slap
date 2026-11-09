class_name AmbientAudioPlayer
extends AudioStreamPlayer
## AmbientAudioPlayer - procedural ambient audio source routed through the Ambient bus.
## Integrates seamless loops from SoundSynthesizer ('wind' or 'hum').
## Muted and playback disabled per user request to eliminate harsh procedural noise.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

@export_enum("wind", "hum") var ambient_type: String = "wind"

func _ready() -> void:
	bus = "Ambient"
	if ambient_type == "wind":
		stream = SoundSynthesizer.get_wind_loop()
	elif ambient_type == "hum":
		stream = SoundSynthesizer.get_hum_loop()
	autoplay = false
	stop()
