class_name ATISfxLibrary
extends RefCounted

## Tiny synthesized placeholder effects. These keep audio iteration inside the
## project until the game has an art/audio direction worth sourcing assets for.

const SAMPLE_RATE: int = 22050
static var _cache: Dictionary = {}


static func get_effect(effect_name: String) -> AudioStreamWAV:
	if _cache.has(effect_name):
		return _cache[effect_name]

	var duration := _effect_duration(effect_name)
	var frame_count := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)

	for frame in frame_count:
		var time := float(frame) / SAMPLE_RATE
		var progress := time / duration
		var sample := _effect_sample(effect_name, time, progress, frame)
		var encoded := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes[frame * 2] = encoded & 0xff
		bytes[frame * 2 + 1] = (encoded >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	_cache[effect_name] = stream
	return stream


static func _effect_duration(effect_name: String) -> float:
	match effect_name:
		"slide": return 0.34
		"slick": return 0.32
		"slip": return 0.23
		"throw": return 0.25
		"round_end": return 0.62
		"tag": return 0.28
		"pickup": return 0.3
		"stun_shot": return 0.22
		"stunned": return 0.42
		"air_horn": return 0.5
		"invisibility": return 0.48
		"swap_bell": return 1.35
		"spring": return 0.34
		"deploy": return 0.24
		"rewind": return 0.55
		"chair_cannon": return 0.34
		"door_open": return 0.52
		"door": return 0.3
		_: return 0.17


static func _effect_sample(effect_name: String, time: float, progress: float, frame: int) -> float:
	var decay := pow(1.0 - progress, 2.0)
	var noise := _noise(frame)
	match effect_name:
		"jump":
			return sin(TAU * (210.0 * time + 520.0 * time * time)) * decay * 0.38
		"slide":
			return (noise * 0.28 + sin(TAU * 74.0 * time) * 0.12) * sin(PI * progress) * 0.7
		"grab":
			return (sin(TAU * 105.0 * time) * 0.5 + noise * 0.16) * decay
		"throw":
			return (noise * 0.35 + sin(TAU * (190.0 - 100.0 * progress) * time) * 0.12) * sin(PI * progress)
		"slick":
			return (sin(TAU * (150.0 - 75.0 * progress) * time) * 0.32 + noise * 0.15) * sin(PI * progress)
		"slip":
			return (sin(TAU * (310.0 + 190.0 * progress) * time) * 0.25 + noise * 0.2) * decay
		"tag":
			var first := sin(TAU * 520.0 * time)
			var second := sin(TAU * 780.0 * time) if progress > 0.42 else 0.0
			return (first + second * 0.7) * decay * 0.3
		"ready":
			return sin(TAU * 880.0 * time) * decay * 0.24
		"pickup":
			var rise := 420.0 + 660.0 * progress
			return sin(TAU * rise * time) * decay * 0.34
		"stun_shot":
			return (sin(TAU * (1050.0 - 420.0 * progress) * time) * 0.34 + noise * 0.22) * decay
		"stunned":
			var wobble := 118.0 + sin(time * 42.0) * 24.0
			return (sin(TAU * wobble * time) * 0.32 + noise * 0.12) * decay
		"air_horn":
			return (sin(TAU * 132.0 * time) * 0.3 + sin(TAU * 198.0 * time) * 0.2 + noise * 0.08) * sin(PI * progress)
		"invisibility":
			return (sin(TAU * (920.0 - 610.0 * progress) * time) * 0.24 + noise * 0.1) * sin(PI * progress)
		"swap_bell":
			var ring := sin(TAU * 880.0 * time) * exp(-3.0 * time)
			ring += sin(TAU * 2376.0 * time) * exp(-6.0 * time) * 0.45
			ring += sin(TAU * 4752.0 * time) * exp(-10.0 * time) * 0.2
			return (ring * 0.5 + noise * exp(-90.0 * time) * 0.12) * minf(time * 800.0, 1.0) * (1.0 - progress)
		"spring":
			return sin(TAU * (180.0 + 720.0 * progress) * time) * decay * 0.34
		"deploy":
			return (sin(TAU * 280.0 * time) * 0.26 + noise * 0.08) * decay
		"rewind":
			return (sin(TAU * (760.0 - 610.0 * progress) * time) * 0.28 + noise * 0.08) * sin(PI * progress)
		"chair_cannon":
			return (sin(TAU * (150.0 - 80.0 * progress) * time) * 0.28 + noise * 0.28) * decay
		"door_open":
			return (sin(TAU * (220.0 + 380.0 * progress) * time) * 0.25 + sin(TAU * 330.0 * time) * 0.12) * sin(PI * progress)
		"door":
			return sin(TAU * (520.0 - 240.0 * progress) * time) * decay * 0.3
		"round_end":
			var chord := sin(TAU * 330.0 * time) + sin(TAU * 440.0 * time) + sin(TAU * 550.0 * time)
			return chord / 3.0 * decay * 0.42
		_:
			return sin(TAU * 440.0 * time) * decay * 0.25


static func _noise(frame: int) -> float:
	var value := sin(float(frame) * 12.9898) * 43758.5453
	return (value - floor(value)) * 2.0 - 1.0
