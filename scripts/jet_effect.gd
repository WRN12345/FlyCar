extends Node3D
## Fixed emitter budget; white cold-gas exhaust follows actual nozzle output.
const Thrusters = preload("res://scripts/thruster_control.gd")
var plumes: Array[CPUParticles3D] = []
var mists: Array[CPUParticles3D] = []
var audio: AudioStreamPlayer3D
static var gas_sound: AudioStreamWAV

func _ready() -> void:
	name = "JetEffects"
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void vertex() {
    MODELVIEW_MATRIX = mat4(vec4(length(MODEL_MATRIX[0].xyz),0.,0.,0.), vec4(0.,length(MODEL_MATRIX[1].xyz),0.,0.), vec4(0.,0.,length(MODEL_MATRIX[2].xyz),0.), MODELVIEW_MATRIX[3]);
}
void fragment() {
    vec2 p = UV * 2. - 1.;
    float soft_edge = pow(max(0., 1. - dot(p,p)), 2.);
    ALBEDO = vec3(0.91,0.96,1.);
    float turbulence = 0.8 + 0.2 * sin(p.x*9. + TIME*8.) * sin(p.y*7. - TIME*6.);
    ALPHA = soft_edge * turbulence * COLOR.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = material
	for nozzle in Thrusters.NOZZLES:
		var plume := emitter(mesh, false)
		plume.position = nozzle
		plumes.append(plume)
		var mist := emitter(mesh, true)
		mist.top_level = true
		mists.append(mist)
	if gas_sound == null:
		gas_sound = build_sound()
	audio = AudioStreamPlayer3D.new()
	audio.stream = gas_sound
	audio.unit_size = 12
	audio.max_distance = 65
	add_child(audio)

func _exit_tree() -> void:
	if audio != null:
		audio.stop()

func emitter(mesh: Mesh, surface: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.mesh = mesh
	particles.amount = 32 if surface else 80
	particles.lifetime = 0.65 if surface else 0.3
	particles.local_coords = false
	particles.direction = Vector3.UP if surface else Vector3.DOWN
	particles.spread = 82 if surface else 9
	particles.gravity = Vector3(0, 0.35, 0) if surface else Vector3.ZERO
	particles.initial_velocity_min = 2.2 if surface else 9
	particles.initial_velocity_max = 4.2 if surface else 14
	particles.scale_amount_min = 1.3 if surface else 0.4
	particles.scale_amount_max = 2.3 if surface else 0.7
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.35))
	scale_curve.add_point(Vector2(1, 1))
	particles.scale_amount_curve = scale_curve
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.15, 0.6, 1])
	gradient.colors = PackedColorArray([Color(0.85,0.93,1,0), Color(0.9,0.96,1,0.65), Color(0.92,0.96,1,0.3), Color(1,1,1,0)])
	particles.color_ramp = gradient
	add_child(particles)
	return particles

static func build_sound() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var count := 11025
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3901
	var low := 0.0
	for i in count:
		var noise := rng.randf_range(-1, 1)
		low = lerpf(low, noise, 0.18)
		var sample := noise * 0.38 + low * 0.4 + sin(TAU * i * 80.0 / sound.mix_rate) * 0.05
		bytes.encode_s16(i * 2, int(sample * 19000))
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = count
	return sound

func clear() -> void:
	for particles in plumes + mists:
		particles.emitting = false
		particles.visible = false
		# Clear old world-space particles before a teleport or a new race.
		particles.restart()
		particles.emitting = false
	if audio != null:
		audio.stop()

func update_output(car: RigidBody3D) -> void:
	if car.freeze or car.pending_reset or not car.visible:
		clear()
		return
	var total := 0.0
	for i in 4:
		var duty: float = car.nozzle_duties[i]
		total += duty
		plumes[i].visible = true
		plumes[i].direction = car.global_basis.inverse() * -car.thrust_direction
		if duty > 0.001:
			plumes[i].color.a = duty
		plumes[i].emitting = duty > 0.001
		var hit: Dictionary = car.exhaust_hits[i] if i < car.exhaust_hits.size() else {}
		var close := false
		if not hit.is_empty():
			var origin: Vector3 = car.global_transform * Thrusters.NOZZLES[i]
			var offset: Vector3 = hit.position - origin
			close = offset.length() < 3.5 and offset.normalized().dot(-car.thrust_direction) > 0.75 and hit.normal.dot(Vector3.UP) > 0.65
			mists[i].global_position = hit.position + hit.normal * 0.08
			mists[i].direction = hit.normal
		mists[i].visible = true
		if duty > 0.001:
			mists[i].color.a = duty
		mists[i].emitting = duty > 0.001 and close
	if total > 0.001:
		audio.volume_db = linear_to_db(total / 4) - 10
		audio.pitch_scale = lerpf(0.85, 1.05, total / 4)
		if not audio.playing:
			audio.play()
	else:
		audio.stop()
