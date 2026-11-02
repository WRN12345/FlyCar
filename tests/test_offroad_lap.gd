extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.record_path="user://valley-lap-regression.cfg"
	world.best_time=0
	world.countdown = 0
	world.car.freeze = false
	for i in 180:
		await physics_frame
	var index := 4
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		index = int(arguments[0])
		var pose: Transform3D = world.course.pose_at(world.course.distances[index])
		pose.origin += Vector3.UP*0.9
		world.car.reset_to(pose)
		world.race.next_gate = int(arguments[1]) if arguments.size()>1 else 1
		for i in 4: await physics_frame
	var count: int = world.route.size()
	var done := false
	var stalled_ticks := 0
	var reversing_ticks := 0
	var jumped: Dictionary = {}
	var active_jump := -1
	var burst_ticks := 0
	for tick in 60000:
		await physics_frame
		if world.death_remaining>0 or world.race.recoveries>0 or world.race_failed:
			push_error("Main route driver crashed near point %d / CP %d at=%s boundary=%s impact=%s" % [index,world.race.next_gate,world.car.position,world.race_failed,world.impact_kind])
			break
		if world.race.finished:
			done = true
			break
		if tick%4:
			continue
		var nearest := INF
		var next := index
		for offset in range(-12,35):
			var candidate := posmod(index+offset,count)
			var distance: float = world.car.position.distance_squared_to(world.route[candidate])
			if distance<nearest:
				nearest = distance
				next = candidate
		index = next
		var target_point: Vector3 = world.route[(index+3)%count]
		var sites: Array = world.course.get_node("TrailObstacles").sites
		if active_jump<0:
			for j in sites.size():
				var site: Dictionary = sites[j]
				var axis: Vector3 = -world.course.pose_at(site.distance).basis.z
				axis.y = 0
				var along: float = (world.car.position-site.position).dot(axis.normalized())
				if not jumped.has(j) and along> -7.5 and along<5 and world.car.position.distance_to(site.position)<12 and world.car.fuel>0.35:
					active_jump = j
					burst_ticks = 0
					break
		if active_jump>=0:
			burst_ticks += 4
			if burst_ticks<=54: Input.action_press("burst")
			else: Input.action_release("burst")
			var exit_pose: Transform3D = world.course.pose_at(sites[active_jump].distance+8)
			if burst_ticks>100 and world.car.contacts>=3:
				if world.car.position.distance_to(exit_pose.origin)<6:
					jumped[active_jump] = true
				active_jump = -1
		if world.car.contacts==0:
			var omega: Vector3 = world.car.global_basis.inverse()*world.car.angular_velocity
			var pitch: float = clampf(-asin(clampf(-world.car.global_basis.z.y,-1,1))*1.5-omega.x*0.35,-0.6,0.6)
			var roll: float = clampf(asin(clampf(world.car.global_basis.x.y,-1,1))*1.5+omega.z*0.35,-0.6,0.6)
			Input.action_press("pitch_forward",maxf(0,pitch))
			Input.action_press("pitch_back",maxf(0,-pitch))
			Input.action_press("roll_left",maxf(0,roll))
			Input.action_press("roll_right",maxf(0,-roll))
		else:
			for action in ["pitch_forward","pitch_back","roll_left","roll_right"]: Input.action_release(action)
		var delta: Vector3 = target_point-world.car.position
		delta.y = 0
		delta = delta.normalized()
		var forward: Vector3 = -world.car.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var error := atan2(forward.cross(delta).y,forward.dot(delta))
		var surface: Dictionary = world.course.terrain.surface_at(world.car.position)
		var target: float = {"dirt":15.0,"gravel":12.0,"mud":9.0,"grass":12.0,"water":7.0,"rock":11.0}[surface.material]
		for site in world.course.get_node("TrailObstacles").sites:
			if Vector2(world.car.position.x-site.position.x,world.car.position.z-site.position.z).length()<36:
				target = minf(target,6.0)
		target *= clampf(1-absf(error),0.3,1)
		var speed: float = world.car.linear_velocity.dot(forward)
		stalled_ticks = stalled_ticks+4 if absf(speed)<0.3 else 0
		if stalled_ticks>180:
			reversing_ticks = 120
			stalled_ticks = 0
		if reversing_ticks>0:
			Input.action_press("throttle",0)
			Input.action_press("brake",1)
			Input.action_press("steer_left",clampf(-error*2.8,0,1))
			Input.action_press("steer_right",clampf(error*2.8,0,1))
			reversing_ticks -= 4
			continue
		Input.action_press("steer_left",clampf(error*2.8,0,1))
		Input.action_press("steer_right",clampf(-error*2.8,0,1))
		Input.action_press("throttle",1.0 if speed<target else 0.0)
		Input.action_press("brake",0.45 if speed>target+0.5 else 0.0)
		if tick%6000==0:
			print("Lap tick=",tick," index=",index," CP=",world.race.next_gate," speed=",speed," at=",world.car.position," error=",error)
	for action in ["throttle","brake","steer_left","steer_right","burst","pitch_forward","pitch_back","roll_left","roll_right"]:
		Input.action_release(action)
	print("Physical off-road lap: ","1/1 passed" if done else "0/1 passed", " time=",world.race.elapsed," CP=",world.race.next_gate)
	world.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.record_path))
	await process_frame
	quit(0 if done else 1)
