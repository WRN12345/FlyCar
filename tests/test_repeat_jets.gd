extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:
	call_deferred("run")
func frames(n:int)->void:
	for i in n:
		await physics_frame
func run()->void:
	var ground:=StaticBody3D.new()
	var c:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(300,1,300)
	c.shape=box
	c.position.y=-0.5
	ground.add_child(c)
	root.add_child(ground)
	var car=load("res://scripts/car.gd").new()
	root.add_child(car)
	car.reset_to(Transform3D(Basis.IDENTITY,Vector3(0,1,0)))
	car.fuel=0
	Input.action_press("burst")
	await frames(360)
	check(car.fuel>0.9 and not car.burning,"held empty trigger recharges on supported ground without sputtering jets")
	Input.action_release("burst")
	await frames(3)
	for cycle in 3:
		var before:float=car.position.y
		Input.action_press("burst")
		await frames(30)
		Input.action_release("burst")
		await frames(15)
		check(car.position.y>before+0.3,"launch remains available after recharge: cycle %d"%cycle)
		await frames(420)
		check(car.fuel>0.9,"tank returns to ready between ordinary jumps: cycle %d"%cycle)
	car.fuel=.2
	Input.action_press("burst")
	await frames(40)
	check(car.fuel<=.001 and car.burst_locked,"actual nozzle firing exhausts the remaining tank and enters release protection")
	await frames(480)
	check(car.fuel>.9 and not car.burning,"actual exhausted flight lands and refills without trigger sputtering")
	Input.action_release("burst")
	await frames(3)
	var height:float=car.position.y
	Input.action_press("burst")
	await frames(30)
	Input.action_release("burst")
	await frames(15)
	check(car.position.y>height+.3,"real exhaust-land-refill chain permits a new flight")
	await frames(420)
	var wall:=StaticBody3D.new()
	var wall_shape:=CollisionShape3D.new()
	var wall_box:=BoxShape3D.new()
	wall_box.size=Vector3(1,50,10)
	wall_shape.shape=wall_box
	wall.position=Vector3(-.5,20,0)
	wall.add_child(wall_shape)
	root.add_child(wall)
	car.reset_to(Transform3D(Basis(Vector3.FORWARD,deg_to_rad(40)),Vector3(1.1,20,0)))
	car.fuel=.3
	await frames(3)
	car.recharge_delay=0
	await frames(3)
	check(car.contacts>=2,"wall grazing fixture places two suspension rays against a vertical wall")
	check(is_equal_approx(car.fuel,.3),"vertical-wall grazing cannot count as weight-bearing ground recharge")
	var model=load("res://scripts/vehicle_math.gd")
	if model.has_method("can_recharge"):
		check(model.can_recharge(2,9000,1.0,1650),"two load-bearing tires can recharge on uneven ground")
		check(not model.can_recharge(2,100,1.0,1650) and not model.can_recharge(2,9000,-1.0,1650),"light grazing or inversion cannot refill the tank")
	else:
		check(false,"load-based recharge not implemented")
	print("Repeated jets: ",checks-failures,"/",checks," passed")
	car.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
