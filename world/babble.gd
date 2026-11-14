class_name WBabble
extends AudioStreamPlayer
## The people of the waste speak in a murmur of made-up syllables while their words come up on the page.
## Each voice is drawn from the speaker's name, so it is always the same voice: its pitch, its pace,
## how breathy or nasal it is, and which sounds it favours.

const RATE := 22050
## Vowel colours: two resonances each, in Hz
const VOWELS := [[730, 1090], [270, 2290], [300, 870], [530, 1840], [570, 840], [440, 1020], [660, 1700]]


## A voice from a name: base pitch, how far it rises and falls, syllable length, brightness, breath.
static func voice_of(who: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(who)
	var low := r.randf() < 0.5
	return {
		"pitch": r.randf_range(95.0, 140.0) if low else r.randf_range(170.0, 260.0),
		"swing": r.randf_range(0.06, 0.22),
		"syl": r.randf_range(0.065, 0.11),
		"gap": r.randf_range(0.012, 0.035),
		"bright": r.randf_range(0.6, 1.4),
		"breath": r.randf_range(0.0, 0.18),
		"nasal": r.randf_range(0.0, 0.5),
		"vowels": [r.randi() % VOWELS.size(), r.randi() % VOWELS.size(), r.randi() % VOWELS.size()],
		"seed": hash(who),
	}


func _ready() -> void:
	volume_db = -9.0


## Murmurs a line in a voice, for about as long as the words take to come up.
func speak(who: String, text: String, secs: float) -> void:
	var v := voice_of(who)
	var r := RandomNumberGenerator.new()
	r.seed = int(v.seed) ^ hash(text)
	var syl_n := clampi(int(minf(secs, 2.6) / (float(v.syl) + float(v.gap))), 2, 26)
	var data := PackedByteArray()
	var total := 0
	var parts: Array = []
	for i in syl_n:
		var dur := float(v.syl) * r.randf_range(0.7, 1.3)
		var gap := float(v.gap) * r.randf_range(0.5, 2.5) + (0.12 if r.randf() < 0.12 else 0.0)
		var f0 := float(v.pitch) * (1.0 + r.randf_range(-1.0, 1.0) * float(v.swing))
		# A line falls a little toward its end, the way speech does
		f0 *= lerpf(1.04, 0.9, float(i) / syl_n)
		var vw: Array = VOWELS[v.vowels[r.randi() % 3] if r.randf() < 0.75 else r.randi() % VOWELS.size()]
		parts.append([dur, gap, f0, vw])
		total += int((dur + gap) * RATE)
	data.resize(total * 2)
	var at := 0
	var phase := 0.0
	var noise := 0.0
	for p in parts:
		var n := int(p[0] * RATE)
		var f0: float = p[2]
		var f1: float = p[3][0]
		var f2: float = p[3][1] * float(v.bright)
		var gains := PackedFloat32Array()
		for hmn in range(1, 7):
			var fh := f0 * hmn
			var gg := exp(-pow((fh - f1) / 180.0, 2.0)) + 0.7 * exp(-pow((fh - f2) / 260.0, 2.0)) + 0.08 / hmn
			gains.append(gg + float(v.nasal) * exp(-pow((fh - 250.0) / 90.0, 2.0)))
		for k in n:
			var t := float(k) / n
			var env := minf(1.0, t * 12.0) * pow(1.0 - t, 1.6)
			phase += f0 / RATE
			# A buzz at the voice's pitch, its harmonics lifted where the vowel rings
			var s := 0.0
			var ph := TAU * phase
			for hi in 6:
				s += sin(ph * (hi + 1)) * gains[hi]
			noise = lerpf(noise, randf_range(-1.0, 1.0), 0.5)
			s = s * 0.26 + noise * float(v.breath)
			var val := int(clampf(s * env, -1.0, 1.0) * 26000.0)
			data.encode_s16(at * 2, val)
			at += 1
		var g := int(p[1] * RATE)
		for k in g:
			if at < total:
				data.encode_s16(at * 2, 0)
				at += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	stream = wav
	play()


func hush() -> void:
	stop()
