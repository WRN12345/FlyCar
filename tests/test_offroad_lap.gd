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
	var count: int = world.route.size()
	var done := false
	for tick in 60000:
		await physics_frame
		if world.death_remaining>0 or world.race.recoveries>0:
			push_error("Main route driver crashed near point %d / CP %d" % [index,world.race.next_gate])
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
		var delta: Vector3 = world.route[(index+6)%count]-world.car.position
		delta.y = 0
		delta = delta.normalized()
		var forward: Vector3 = -world.car.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var error := atan2(forward.cross(delta).y,forward.dot(delta))
		var surface: Dictionary = world.course.terrain.surface_at(world.car.position)
		var target: float = {"dirt":15.0,"gravel":12.0,"mud":9.0,"grass":12.0,"water":7.0,"rock":11.0}[surface.material]
		target *= clampf(1-absf(error),0.3,1)
		var speed: float = world.car.linear_velocity.dot(forward)
		Input.action_press("steer_left",clampf(error*2.8,0,1))
		Input.action_press("steer_right",clampf(-error*2.8,0,1))
		Input.action_press("throttle",1.0 if speed<target else 0.0)
		Input.action_press("brake",0.45 if speed>target+0.5 else 0.0)
		if tick%6000==0:
			print("Lap tick=",tick," index=",index," CP=",world.race.next_gate," speed=",speed)
	for action in ["throttle","brake","steer_left","steer_right"]:
		Input.action_release(action)
	print("Physical off-road lap: ","1/1 passed" if done else "0/1 passed", " time=",world.race.elapsed," CP=",world.race.next_gate)
	world.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.record_path))
	await process_frame
	quit(0 if done else 1)
