extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var look = load("res://scripts/orbit_camera.gd").new()
	look.dragging = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200,10000)
	check(look.handle(motion) and absf(look.yaw)>0.5 and look.pitch<=1.25,"Orbit input and pitch limit")
	look.end_drag()
	var old_yaw: float = look.yaw
	look.handle(motion)
	check(look.yaw==old_yaw,"Released drag preserves view")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in 50: look.handle(wheel)
	check(look.distance==4.0,"Zoom minimum")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 50: look.handle(wheel)
	check(look.distance==22.0,"Zoom maximum")
	wheel.button_index = MOUSE_BUTTON_MIDDLE
	look.handle(wheel)
	check(look.yaw==0.0 and is_equal_approx(look.pitch,0.35) and not look.dragging,"Middle button resets view")
	var car := RigidBody3D.new()
	car.freeze = true
	root.add_child(car)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,20,1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0,0,5)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	look.probe(car)
	check(look.obstructed and look.safe_position.z<5.0,"Camera boom stops before wall")
	var course = load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json")))
	check(course.gates.size()==8 and course.gate_lights.is_empty(),"Invisible timing gates retained")
	check(course.find_children("*","Label3D",true,false).is_empty(),"No floating route signs")
	var areas := 0
	var visible_markers := 0
	for child in course.get_children():
		if child is Area3D: areas += 1
		if child is MeshInstance3D: visible_markers += 1
	check(areas==8 and visible_markers==0,"Checkpoint triggers retained without flags or arches")

	course.free()
	var world = load("res://scripts/main.gd").new()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.mouse_look.dragging = true
	world.open_maps()
	check(not world.mouse_look.dragging and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Map releases mouse")
	world.close_maps()
	world.mouse_look.dragging = true
	world.get_window().focus_exited.emit()
	check(not world.mouse_look.dragging,"Focus loss releases mouse")
	world.mouse_look.yaw = 1.2
	world.restart_race()
	check(world.mouse_look.yaw==0.0,"Race restart resets orbit")
	world.free()

	car.free()
	wall.free()
	print("PASS: mouse look %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
