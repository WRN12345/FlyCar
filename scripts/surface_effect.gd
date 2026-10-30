extends Node3D
## Four pooled tire emitters: soil dust, mud and shallow-water spray.
var emitters: Array[CPUParticles3D] = []
func _ready() -> void:
	name = "SurfaceEffects"
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
void vertex(){MODELVIEW_MATRIX=mat4(vec4(length(MODEL_MATRIX[0].xyz),0.,0.,0.),vec4(0.,length(MODEL_MATRIX[1].xyz),0.,0.),vec4(0.,0.,length(MODEL_MATRIX[2].xyz),0.),MODELVIEW_MATRIX[3]);}
void fragment(){vec2 p=UV*2.-1.; ALBEDO=COLOR.rgb; ALPHA=pow(max(0.,1.-dot(p,p)),2.)*COLOR.a;}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var mesh := QuadMesh.new()
	mesh.material = material
	for i in 4:
		var emitter := CPUParticles3D.new()
		emitter.emitting = false
		emitter.mesh = mesh
		emitter.amount = 24
		emitter.lifetime = 0.6
		emitter.local_coords = false
		emitter.top_level = true
		emitter.spread = 45
		emitter.scale_amount_min = 0.22
		emitter.scale_amount_max = 0.7
		emitter.initial_velocity_min = 1.0
		emitter.initial_velocity_max = 3.5
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0,0.15,1])
		ramp.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.5),Color(1,1,1,0)])
		emitter.color_ramp = ramp
		add_child(emitter)
		emitters.append(emitter)

func clear() -> void:
	for emitter in emitters:
		emitter.visible = false
		emitter.restart()
		emitter.emitting = false

func update_output(car: RigidBody3D) -> void:
	if car.freeze or car.pending_reset or not car.visible or not is_instance_valid(car.surface_provider):
		clear()
		return
	for i in 4:
		var emitter := emitters[i]
		emitter.visible = true
		var ray: RayCast3D = car.rays[i]
		var speed: float = car.linear_velocity.length()
		if not ray.is_colliding() or speed < 2:
			emitter.emitting = false
			continue
		var p := ray.get_collision_point()
		var surface: Dictionary = car.surface_provider.surface_at(p)
		var wet: bool = surface.water_depth > 0.03
		emitter.global_position = Vector3(p.x,surface.water_height if wet else p.y,p.z)+Vector3.UP*0.07
		emitter.direction = (-car.linear_velocity.normalized()+Vector3.UP*0.6).normalized()
		emitter.gravity = Vector3(0,-2.0,0) if wet else Vector3(0,0.4,0)
		emitter.color = Color(0.72,0.9,0.97,0.7) if wet else Color(0.55,0.43,0.28,0.3)
		emitter.emitting = true
