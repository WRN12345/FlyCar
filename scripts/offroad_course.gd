extends "res://scripts/course.gd"
const Valley = preload("res://scripts/offroad_terrain.gd")
const Ground = preload("res://scripts/offroad_model.gd")
var gate_distances: Array[float] = []
var shortcuts: Array = []

func build(definition: Dictionary) -> void:
	data = definition
	name = "ActiveCourse"
	route = Catalog.sample(data)
	for i in route.size():
		distances.append(length)
		length += route[i].distance_to(route[(i+1)%route.size()])
	terrain = Valley.new()
	add_child(terrain)
	terrain.build(route)
	accent = Geo.material(Color(data.color),0,0.2)
	selected = Geo.material(Color("b5ec67"),0,0.3)
	for key in ["dark","white"]:
		batches[key] = {"material":Geo.material(Color("39463b") if key=="dark" else Color("eee2ba")),"transforms":[]}
	for anchor in data.checkpoint_anchors:
		var best := INF
		var at := 0
		var target: Vector3 = Catalog.world_point(data,anchor)
		for i in route.size():
			if route[i].distance_squared_to(target) < best:
				best = route[i].distance_squared_to(target)
				at = i
		gate_distances.append(distances[at])
	for i in 8:
		var pose := pose_at(gate_distances[i])
		gates.append(pose)
		create_gate(i,pose)
	spawn = recovery_at_gate(0)
	barrier_pose = pose_at(90)
	gap_pose = Transform3D(Basis.IDENTITY,Vector3(435,Ground.height_at(435,-430),-430))
	shortcuts = [{"name":"草坡切弯", "points":[Vector3(-423,0,-599),Vector3(-381,0,-896)], "entry_gate":2, "exit_gate":3}, {"name":"峡谷飞跃", "points":[Vector3(438,0,-478),Vector3(421,0,-373)], "entry_gate":5, "exit_gate":6}]
	for cut in shortcuts:
		for i in cut.points.size():
			cut.points[i].y = Ground.height_at(cut.points[i].x,cut.points[i].z)

func create_gate(index: int, pose: Transform3D) -> void:
	# Keep timing and recovery triggers without placing artificial scenery.
	var area := Area3D.new()
	area.transform = pose
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,64,1)
	node.shape = shape
	node.position.y = 30
	area.add_child(node)
	add_child(area)
	area.body_entered.connect(func(body): gate_entered.emit(body,index))

func recovery_at_gate(index: int) -> Transform3D:
	var pose := pose_at(gate_distances[index]+10)
	pose.origin += Vector3.UP*0.9
	return pose

func road_height_at(p: Vector3) -> float:
	return Ground.height_at(p.x,p.z)
