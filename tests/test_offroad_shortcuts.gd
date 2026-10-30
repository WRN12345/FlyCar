extends SceneTree
var world
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func control(target: Vector3,speed: float) -> void:
	var delta: Vector3 = target-world.car.position
	delta.y=0
	var forward: Vector3 = -world.car.global_basis.z
	forward.y=0
	forward=forward.normalized()
	var error := atan2(forward.cross(delta.normalized()).y,forward.dot(delta.normalized()))
	Input.action_press("steer_left",clampf(error*2.8,0,1))
	Input.action_press("steer_right",clampf(-error*2.8,0,1))
	var velocity: float = world.car.linear_velocity.dot(forward)
	Input.action_press("throttle",1 if velocity<speed else 0)
	Input.action_press("brake",0.4 if velocity>speed+1 else 0)
func stop() -> void:
	for action in ["throttle","brake","steer_left","steer_right","burst"]:
		Input.action_release(action)
func run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.countdown=0
	world.car.freeze=false
	world.race.next_gate=3
	var ground=load("res://scripts/offroad_model.gd")
	var start:=Vector3(-423,ground.height_at(-423,-599)+0.9,-599)
	var end: Vector3=world.gates[3].origin-world.gates[3].basis.z*15
	world.car.reset_to(Transform3D(Basis.looking_at((end-start).normalized()),start))
	for tick in 6000:
		await physics_frame
		if tick%4==0:
			control(end,12)
		if world.race.next_gate==4 or world.death_remaining>0:
			break
	var grass_ok: bool=world.race.next_gate==4 and world.death_remaining==0
	print("Grass shortcut: ",grass_ok," CP=",world.race.next_gate," at=",world.car.position)
	if not grass_ok:
		failures+=1
	stop()
	world.restart_race()
	for i in 4:
		await physics_frame
	world.countdown=0
	world.car.freeze=false
	world.race.next_gate=6
	start=Vector3(439,ground.height_at(439,-535)+0.9,-535)
	world.car.reset_to(Transform3D(Basis.looking_at(Vector3(0,0,1)),start))
	end=world.gates[6].origin-world.gates[6].basis.z*15
	var launched:=false
	var burst_ticks:=0
	var landing_ticks:=0
	for tick in 1800:
		await physics_frame
		if tick%4==0:
			control(end,24)
		if not launched and world.car.position.z > -460:
			launched=true
			print("Launch: ",world.car.position," v=",world.car.linear_velocity," tilt=",world.car.rotation_degrees)
			Input.action_press("burst")
		if launched:
			burst_ticks+=1
			if burst_ticks==102:
				Input.action_release("burst")
			if burst_ticks>102 and world.car.position.z>-430 and world.car.linear_velocity.y < -1 and landing_ticks==0:
				landing_ticks=1
				Input.action_press("burst")
		if landing_ticks>0:
			landing_ticks+=1
			if landing_ticks==31:
				Input.action_release("burst")
		if world.race.next_gate==7 or world.death_remaining>0:
			break
	var canyon_ok: bool=world.race.next_gate==7 and world.death_remaining==0 and launched
	print("Canyon shortcut: ",canyon_ok," CP=",world.race.next_gate," at=",world.car.position," fuel=",world.car.fuel," v=",world.car.linear_velocity," tilt=",world.car.rotation_degrees," impact=",world.car.severe_impact_speed)
	if not canyon_ok:
		failures+=1
	stop()
	print("Off-road physical shortcuts: ",2-failures,"/2 passed")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
