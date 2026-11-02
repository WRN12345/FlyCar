extends SceneTree
var course
var car
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func release() -> void:
	for action in ["throttle","brake","steer_left","steer_right","burst","pitch_forward","pitch_back","roll_left","roll_right"]:
		Input.action_release(action)
func trial(site: Dictionary, jets: bool) -> bool:
	release()
	var pose: Transform3D = course.pose_at(site.distance-15)
	pose.origin += Vector3.UP*0.9
	car.reset_to(pose)
	car.fuel = 1.0
	for i in 30: await physics_frame
	car.linear_velocity = -pose.basis.z*7
	var launch_ticks := 0
	var launched := false
	var crossed := false
	var site_pose: Transform3D = course.pose_at(site.distance)
	var axis := -site_pose.basis.z
	axis.y = 0
	axis = axis.normalized()
	for tick in 1000:
		await physics_frame
		var along: float = (car.position-site.position).dot(axis)
		var target: Vector3 = course.pose_at(site.distance+12).origin-car.position
		target.y = 0
		var forward: Vector3 = -car.global_basis.z
		forward.y = 0
		var error := forward.normalized().signed_angle_to(target.normalized(),Vector3.UP)
		var speed: float = car.linear_velocity.dot(forward.normalized())
		Input.action_press("steer_left",clampf(error*2.8,0,1))
		Input.action_press("steer_right",clampf(-error*2.8,0,1))
		Input.action_press("throttle",0.8 if speed<7 else 0)
		Input.action_press("brake",0.4 if speed>8 else 0)
		if jets and not launched and along> -7.5:
			launched = true
		if launched:
			launch_ticks += 1
			if launch_ticks<=54: Input.action_press("burst")
			else: Input.action_release("burst")
		if jets and car.contacts==0:
			var omega: Vector3 = car.global_basis.inverse()*car.angular_velocity
			var pitch: float = clampf(-asin(clampf(-car.global_basis.z.y,-1,1))*1.5-omega.x*0.35,-0.6,0.6)
			var roll: float = clampf(asin(clampf(car.global_basis.x.y,-1,1))*1.5+omega.z*0.35,-0.6,0.6)
			Input.action_press("pitch_forward",maxf(0,pitch))
			Input.action_press("pitch_back",maxf(0,-pitch))
			Input.action_press("roll_left",maxf(0,roll))
			Input.action_press("roll_right",maxf(0,-roll))
		if along>5:
			crossed = true
			if not jets or car.contacts>=3:
				break
		if not course.within_boundary(car.position) or (jets and car.severe_impact_speed>=12):
			print("Trial rejected kind=",site.kind," jet=",jets," along=",along," at=",car.position," impact=",car.severe_impact_speed)
			crossed = false
			break
	release()
	print("Mandatory jump kind=",site.kind," jets=",jets," crossed=",crossed," at=",car.position)
	return crossed
func run() -> void:
	course = load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json")))
	car = load("res://scripts/car.gd").new()
	root.add_child(car)
	car.surface_provider = course.terrain
	var sites: Array = course.get_node("TrailObstacles").sites
	for site in sites:
		if await trial(site,false):
			failures += 1
			push_error("Ground driving bypassed a mandatory obstacle")
		if not await trial(site,true):
			failures += 1
			push_error("Jet jump could not cross the obstacle")
	print("Mandatory physical jumps: %d/%d passed"%[sites.size()*2-failures,sites.size()*2])
	car.free()
	course.free()
	quit(1 if failures else 0)
