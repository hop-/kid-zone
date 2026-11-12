class_name SfxSynth
extends RefCounted
## Renders a sound effect from its `content/sfx.json` parameters into a 16-bit mono
## `AudioStreamWAV`.
##
## A sound is `{"wave": "square"|"triangle"|"noise", "volume": 0-1, "attack": s,
## "release": s}` plus either `"notes": [[hz, seconds], ...]` or `"sweep": [from_hz,
## to_hz]` with `"duration": s`.
##
## - The phase runs on across notes, so a note change never jumps the waveform.
## - A sweep glides exponentially (even steps in pitch) from `from_hz` to `to_hz`.
## - The square wave is band-limited (PolyBLEP), so high notes don't alias into harsh
##   overtones at 22050 Hz. Triangle has soft overtones of its own and is left as is.
## - Noise is sample-and-hold white noise, a new value twice per period of the note's
##   frequency, from a fixed seed so every render is identical.
## - A linear attack/release envelope over the whole sound prevents clicks. Each ramp
##   is at least `MIN_RAMP` seconds, and both are shortened when they would overlap.
##
## `Content.validate()` checks the format. Here, unusable parameters give null (or an
## empty sample buffer) and never crash.

const WAVES: PackedStringArray = ["square", "triangle", "noise"]
const DEFAULT_SAMPLE_RATE := 22050
## The shortest attack or release ramp, in seconds; a 0 ramp would click.
const MIN_RAMP := 0.002
## The noise generator's seed.
const NOISE_SEED := 0x5EED


## The sound as a 16-bit mono stream at `sample_rate`, or null when the parameters
## give no samples.
static func render(params: Dictionary, sample_rate: int = DEFAULT_SAMPLE_RATE) -> AudioStreamWAV:
	var samples := render_samples(params, sample_rate)
	if samples.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = to_pcm16(samples)
	return stream


## The sound as samples in -1..1, before 16-bit conversion. Empty when the parameters
## are unusable (unknown wave, no notes or sweep, a zero length).
static func render_samples(params: Dictionary, sample_rate: int = DEFAULT_SAMPLE_RATE) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if sample_rate <= 0:
		return out
	var wave: Variant = params.get("wave")
	if not (wave is String and WAVES.has(wave)):
		return out
	var segments := _segments(params)
	var total := 0
	for segment in segments:
		total += int(segment[2] * sample_rate)
	if total <= 0:
		return out
	out.resize(total)
	var volume := clampf(_number(params.get("volume"), 1.0), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var noise_value := rng.randf_range(-1.0, 1.0)
	var phase := 0.0
	var index := 0
	for segment in segments:
		var from_hz: float = segment[0]
		var to_hz: float = segment[1]
		var count := int(segment[2] * sample_rate)
		for i in count:
			var hz := from_hz
			if to_hz != from_hz:
				hz = from_hz * pow(to_hz / from_hz, float(i) / count)
			var step := hz / sample_rate
			var value: float
			match wave:
				"square":
					value = _square(phase, step)
				"triangle":
					value = 1.0 - 4.0 * absf(phase - 0.5)
				_:
					value = noise_value
			out[index] = value * volume
			index += 1
			var half_before := phase >= 0.5
			phase += step
			if phase >= 1.0:
				phase -= floorf(phase)
			if wave == "noise" and (phase >= 0.5) != half_before:
				noise_value = rng.randf_range(-1.0, 1.0)
	_apply_envelope(out, sample_rate, _number(params.get("attack"), 0.0),
			_number(params.get("release"), 0.0))
	return out


## Samples in -1..1 as little-endian signed 16-bit PCM.
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(roundf(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	return bytes


## The sound's length in seconds; 0 when the parameters are unusable.
static func duration(params: Dictionary) -> float:
	var length := 0.0
	for segment in _segments(params):
		length += segment[2]
	return length


## [from_hz, to_hz, seconds] for each note, or the one sweep. Bad entries are skipped.
static func _segments(params: Dictionary) -> Array[Array]:
	var segments: Array[Array] = []
	var notes: Variant = params.get("notes")
	if notes is Array:
		for note: Variant in notes:
			if note is Array and (note as Array).size() == 2:
				var hz := _number(note[0], 0.0)
				var seconds := _number(note[1], 0.0)
				if hz > 0.0 and seconds > 0.0:
					segments.append([hz, hz, seconds])
		return segments
	var sweep: Variant = params.get("sweep")
	if sweep is Array and (sweep as Array).size() == 2:
		var from_hz := _number(sweep[0], 0.0)
		var to_hz := _number(sweep[1], 0.0)
		var seconds := _number(params.get("duration"), 0.0)
		if from_hz > 0.0 and to_hz > 0.0 and seconds > 0.0:
			segments.append([from_hz, to_hz, seconds])
	return segments


## A band-limited square wave: the naive square with PolyBLEP corrections at the rising
## (phase 0) and falling (phase 0.5) edges.
static func _square(phase: float, step: float) -> float:
	var value := 1.0 if phase < 0.5 else -1.0
	value += _poly_blep(phase, step)
	value -= _poly_blep(fposmod(phase + 0.5, 1.0), step)
	return value


static func _poly_blep(t: float, dt: float) -> float:
	if dt <= 0.0:
		return 0.0
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


## Linear fade-in over `attack` seconds and fade-out over `release` seconds.
static func _apply_envelope(samples: PackedFloat32Array, sample_rate: int, attack: float,
		release: float) -> void:
	var total := samples.size()
	var attack_n := int(maxf(attack, MIN_RAMP) * sample_rate)
	var release_n := int(maxf(release, MIN_RAMP) * sample_rate)
	if attack_n + release_n > total:
		var scale := float(total) / (attack_n + release_n)
		attack_n = int(attack_n * scale)
		release_n = int(release_n * scale)
	for i in attack_n:
		samples[i] *= float(i) / attack_n
	for i in release_n:
		samples[total - 1 - i] *= float(i) / release_n


static func _number(value: Variant, fallback: float) -> float:
	return float(value) if value is float or value is int else fallback
