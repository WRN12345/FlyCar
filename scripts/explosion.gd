extends Node3D
const Geo = preload("res://scripts/geometry.gd")
var elapsed := 0.0
var fire: MeshInstance3D
var shock: MeshInstance3D
var light: OmniLight3D
var debris: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
static var blast_sound: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 481
	var fire_mat := Geo.material(Color("ff9a35"), 0, 3)
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	fire = Geo.mesh_node(self, sphere, Vector3.ZERO, fire_mat)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	shock = Geo.mesh_node(self, ring, Vector3.ZERO, fire_mat.duplicate())
	light = OmniLight3D.new()
	light.light_color = Color("ff932f")
	light.omni_range = 24
	add_child(light)
	var shard_mat := Geo.material(Color("872e2c"), 0.65)
	for i in 26:
		var shard := Geo.box(self, Vector3(rng.randf_range(0.08, 0.35), 0.12, rng.randf_range(0.15, 0.6)), Vector3.ZERO, shard_mat)
		debris.append(shard)
		velocities.append(Vector3(rng.randf_range(-13, 13), rng.randf_range(3, 15), rng.randf_range(-13, 13)))
	if blast_sound == null:
		blast_sound = AudioStreamWAV.new()
		blast_sound.format = AudioStreamWAV.FORMAT_16_BITS
		blast_sound.mix_rate = 22050
		var samples := PackedByteArray()
		samples.resize(15435 * 2)
		var filtered := 0.0
		for i in 15435:
			var t := float(i) / 22050
			filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.2)
			var value := (filtered * 0.8 + sin(TAU * 65 * t) * 0.2) * pow(1 - float(i) / 15435, 3)
			samples.encode_s16(i * 2, int(value * 28000))
		blast_sound.data = samples
	var audio := AudioStreamPlayer3D.new()
	audio.stream = blast_sound
	audio.volume_db = -3
	audio.unit_size = 18
	add_child(audio)
	audio.play()

func _process(dt: float) -> void:
	elapsed += dt
	fire.scale = Vector3.ONE * (0.5 + minf(elapsed * 12, 6))
	fire.material_override.albedo_color.a = clampf(1 - elapsed / 0.9, 0, 1)
	shock.scale = Vector3.ONE * (1 + elapsed * 16)
	shock.material_override.albedo_color.a = clampf(1 - elapsed / 0.7, 0, 1)
	light.light_energy = maxf(0, 8 - elapsed * 12)
	for i in debris.size():
		debris[i].position += velocities[i] * dt
		velocities[i].y -= 15 * dt
		debris[i].rotation += Vector3(3, 5, 2) * dt
