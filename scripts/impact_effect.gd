extends Node3D
const Geo = preload("res://scripts/geometry.gd")
var kind := "land"
var impact_velocity := Vector3.ZERO
var elapsed := 0.0
var parts: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []
var rings: Array[MeshInstance3D] = []
var rng := RandomNumberGenerator.new()
static var sound_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 481
	if kind == "water":
		build_splash()
	else:
		build_wreck()
	play_impact_sound()

func add_part(mesh: Mesh, pos: Vector3, material: Material, velocity: Vector3) -> MeshInstance3D:
	var part := Geo.mesh_node(self, mesh, pos, material)
	parts.append(part)
	velocities.append(velocity)
	return part

func build_wreck() -> void:
	var red := Geo.material(Color("af273b"), 0.45)
	var metal := Geo.material(Color("333e49"), 0.6)
	var glass := Geo.material(Color("19394a"), 0.4)
	# Hood, doors, roof and rear panels remain identifiable after impact.
	var panels := [[Vector3(1.5, 0.12, 1.15), Vector3(0, 0.3, -1.3)], [Vector3(0.13, 0.45, 1.6), Vector3(-0.9, 0.3, 0)], [Vector3(0.13, 0.45, 1.6), Vector3(0.9, 0.3, 0)], [Vector3(1.3, 0.14, 0.9), Vector3(0, 0.8, 0.1)], [Vector3(1.7, 0.25, 1.1), Vector3(0, 0.25, 1.4)]]
	for i in panels.size():
		var mesh := BoxMesh.new()
		mesh.size = panels[i][0]
		add_part(mesh, panels[i][1], glass if i == 3 else red, throw_velocity(5.0))
	for x in [-0.95, 0.95]:
		for z in [-1.35, 1.35]:
			var tire := CylinderMesh.new()
			tire.top_radius = 0.36
			tire.bottom_radius = 0.36
			tire.height = 0.29
			var wheel := add_part(tire, Vector3(x, 0.4, z), metal, throw_velocity(7.0))
			wheel.rotation.z = PI / 2
	for i in 20:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(0.07, 0.2), 0.08, rng.randf_range(0.1, 0.35))
		add_part(mesh, Vector3(0, 0.4, 0), metal if i % 2 else red, throw_velocity(9.0))

func throw_velocity(strength: float) -> Vector3:
	return Vector3(impact_velocity.x, 0, impact_velocity.z) * 0.25 + Vector3(rng.randf_range(-strength, strength), rng.randf_range(2, strength), rng.randf_range(-strength, strength))

func build_splash() -> void:
	var foam := Geo.material(Color("b5dde2"))
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 24:
		var drop := SphereMesh.new()
		drop.radius = rng.randf_range(0.05, 0.12)
		drop.height = drop.radius * 3
		var angle := TAU * i / 24
		add_part(drop, Vector3(cos(angle), 0.1, sin(angle)), foam, Vector3(cos(angle) * rng.randf_range(2, 6), rng.randf_range(3, 8), sin(angle) * rng.randf_range(2, 6)))
	for i in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.95
		ring.outer_radius = 1.0
		var node := Geo.mesh_node(self, ring, Vector3(0, 0.04 + i * 0.005, 0), foam.duplicate())
		rings.append(node)

func play_impact_sound() -> void:
	if not sound_cache.has(kind):
		var sound := AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = 22050
		var count := 15435 if kind == "water" else 6615
		var samples := PackedByteArray()
		samples.resize(count * 2)
		var filtered := 0.0
		for i in count:
			filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.08 if kind == "water" else 0.65)
			var envelope := pow(1 - float(i) / count, 1.4 if kind == "water" else 3.0)
			samples.encode_s16(i * 2, int(filtered * envelope * 24000))
		sound.data = samples
		sound_cache[kind] = sound
	var audio := AudioStreamPlayer3D.new()
	audio.stream = sound_cache[kind]
	audio.volume_db = -3
	audio.unit_size = 18
	add_child(audio)
	audio.play()

func _process(dt: float) -> void:
	elapsed += dt
	for i in parts.size():
		parts[i].position += velocities[i] * dt
		velocities[i].y -= 14 * dt
		if kind == "land":
			if parts[i].position.y < 0.25:
				parts[i].position.y = 0.25
				velocities[i] *= Vector3(0.75, -0.25, 0.75)
			parts[i].rotation += Vector3(3, 5, 2) * dt * minf(1, velocities[i].length() / 3)
		else:
			parts[i].visible = parts[i].position.y >= 0
	for i in rings.size():
		var radius := 1.2 + elapsed * (2 + i * 1.2)
		rings[i].scale = Vector3(radius, 0.05, radius)
		rings[i].material_override.albedo_color.a = clampf(0.8 - elapsed * 0.3, 0, 0.8)
