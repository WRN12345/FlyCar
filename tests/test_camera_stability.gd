extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var car := RigidBody3D.new()
	car.freeze = true
	root.add_child(car)
	var camera := Camera3D.new()
	root.add_child(camera)
	var look = load("res://scripts/orbit_camera.gd").new()
	camera.position = look.desired(car)
	var previous := 0.0
	var shake := 0.0
	for i in 180:
		car.position.y = 0.08 if i%2 else -0.08
		look.update(camera,car,1.0/60)
		if i>60:
			shake = maxf(shake,absf(camera.rotation.x-previous))
		previous = camera.rotation.x
	print("Suspension pitch shake radians/frame: ",shake)
	check(shake<0.003,"Suspension bounce does not directly shake the look-at target")
	car.position = Vector3.ZERO
	look.reset()
	look.obstructed = true
	look.safe_position = Vector3(0,0.6,0)+(look.desired(car)-Vector3(0,0.6,0)).normalized()*3
	for i in 30: look.update(camera,car,1.0/60)
	var last := camera.position
	var pop := 0.0
	for i in 120:
		look.safe_position = Vector3(0,0.6,0)+(look.desired(car)-Vector3(0,0.6,0)).normalized()*(3.0 if i%2 else 4.0)
		look.update(camera,car,1.0/60)
		pop = maxf(pop,camera.position.distance_to(last))
		last = camera.position
	print("Alternating fence occlusion camera jump metres/frame: ",pop)
	check(pop<0.2,"Alternating rail/post occlusion does not snap the camera in and out")
	look.obstructed = false
	last = camera.position
	look.update(camera,car,1.0/60)
	check(camera.position.distance_to(last)<0.2,"Clearing a fence does not pop back to full distance")
	for i in 120: look.update(camera,car,1.0/60)
	check(camera.position.distance_to(look.desired(car))<0.5,"Camera smoothly restores its normal distance after clearance")
	look.reset()
	car.position = Vector3(100,20,-80)
	look.update(camera,car,1.0/60)
	check(camera.position.distance_to(look.desired(car))<0.01,"Checkpoint reset discards stale follow and collision state")
	car.position = Vector3.ZERO
	look.reset()
	look.update(camera,car,1.0/60)
	var facing := camera.global_basis.z
	for angle in [1.55,1.59]:
		car.rotation.x = angle
		look.update(camera,car,1.0/60)
	check(facing.dot(camera.global_basis.z)>0.999,"Pitching through vertical cannot flip the chase heading")
	car.rotation = Vector3.ZERO
	var results: Array[Vector3] = []
	for fps in [30,60,144]:
		car.position = Vector3.ZERO
		look.reset()
		look.update(camera,car,1.0/fps)
		car.position.y = 1
		for i in fps: look.update(camera,car,1.0/fps)
		results.append(camera.position)
	check(results[0].distance_to(results[1])<0.02 and results[1].distance_to(results[2])<0.02,"Follow response is consistent at 30, 60 and 144 FPS")
	car.position = Vector3.ZERO
	look.reset()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,20,1)
	collider.shape = box
	wall.add_child(collider)
	wall.position.z = 5
	root.add_child(wall)
	var collision_safe := true
	for i in 120:
		car.position.x = sin(i*0.035)*0.7
		car.rotation.y = sin(i*0.04)*0.15
		look.yaw = sin(i*0.05)*0.15
		wall.position.z = 4.5+sin(i*0.03)*0.3
		await physics_frame
		look.step(camera,car,1.0/120)
		look.render(camera)
		if camera.position.z>wall.position.z-0.7:
			collision_safe = false
	check(collision_safe,"Moving and orbiting beside a real collider keeps both physics and rendered camera clear")
	wall.free()
	look.reset()
	car.position = Vector3(100,20,-80)
	look.step(camera,car,1.0/120)
	look.render(camera)
	check(camera.position.distance_to(look.desired(car))<0.01,"Reset also clears the render interpolation history")
	print("Camera stability: %d/%d passed"%[checks-failures,checks])
	car.free()
	camera.free()
	quit(1 if failures else 0)
