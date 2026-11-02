extends SceneTree
class Fixture extends Node3D:
	var car: RigidBody3D
	var camera: Camera3D
	var look = preload("res://scripts/orbit_camera.gd").new()
	var frames := 0
	var previous_x := 0.0
	var maximum_error := 0.0
	var sum_error := 0.0
	var relative_min := INF
	var relative_max := -INF
	var fraction_min := INF
	var fraction_max := -INF
	var reset_car: RigidBody3D
	var reset_error := 0.0
	var failed := false
	func _ready() -> void:
		car = RigidBody3D.new()
		car.gravity_scale = 0
		car.linear_damp = 0
		car.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		car.linear_velocity = Vector3(8,0,0)
		add_child(car)
		var visual := MeshInstance3D.new()
		visual.mesh = BoxMesh.new()
		car.add_child(visual)
		car.get_global_transform_interpolated()
		camera = Camera3D.new()
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(camera)
		reset_car = preload("res://scripts/car.gd").new()
		add_child(reset_car)
		reset_car.gravity_scale = 0
		reset_car.visible = false
		reset_car.reset_to(Transform3D(Basis.IDENTITY,Vector3(20,10,0)))
	func _physics_process(dt: float) -> void:
		look.step(camera,car,dt)
	func _process(dt: float) -> void:
		look.render(camera)
		frames += 1
		if frames>120 and frames<=420:
			var error := absf(camera.position.x-previous_x-8*dt)
			maximum_error = maxf(maximum_error,error)
			sum_error += error
			var displayed: Vector3 = car.get_global_transform_interpolated().origin if get_tree().get("physics_interpolation") else car.global_position
			var relative := camera.unproject_position(displayed).x
			relative_min = minf(relative_min,relative)
			relative_max = maxf(relative_max,relative)
			fraction_min = minf(fraction_min,Engine.get_physics_interpolation_fraction())
			fraction_max = maxf(fraction_max,Engine.get_physics_interpolation_fraction())
		previous_x = camera.position.x
		if frames==420:
			print("Render synchronization: interpolation=",get_tree().get("physics_interpolation")," fps=",Engine.max_fps," mean_step_error=",sum_error/300," max_step_error=",maximum_error," subject_pixel_range=",relative_max-relative_min," fraction=",fraction_min,"..",fraction_max)
			failed = get_tree().get("physics_interpolation") and relative_max-relative_min>1.0
			if failed: push_error("Vehicle/camera render timelines are still mismatched")
			reset_car.reset_to(Transform3D(Basis.IDENTITY,Vector3(120,10,-80)))
		if frames>420 and not reset_car.pending_reset:
			reset_error = maxf(reset_error,reset_car.get_global_transform_interpolated().origin.distance_to(reset_car.global_position))
		if frames==450:
			print("Rendered vehicle reset deviation metres: ",reset_error)
			if reset_error>0.1: push_error("Checkpoint reset left stale vehicle interpolation history")
			get_tree().quit(1 if failed or reset_error>0.1 else 0)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Engine.max_fps = int(args[0]) if args.size()>0 else 144
	if args.size()>1:
		set("physics_interpolation",args[1]=="on")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.add_child.call_deferred(Fixture.new())
