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
		var entrance: Vector3 = cut.points[0]
		var basis := Basis.looking_at((cut.points[1]-entrance).normalized())
		label_at(cut.name+" / SHORTCUT",Transform3D(basis,entrance),4,0.014)
		for end in cut.points:
			for side in [-1,1]:
				flag(end+basis.x*side*5,Color("f1b34e"))
	for distance in range(35,int(length),25):
		var pose := pose_at(distance)
		for side in [-1,1]:
			var p: Vector3 = pose.origin+pose.basis.x*side*(Valley.TRAIL_HALF_WIDTH+0.55)
			p.y = Ground.height_at(p.x,p.z)
			flag(p,Color("dccd9e"))
	for entry in [[Vector3(0,0,-100),"DIRT / 土路"],[Vector3(-210,0,-410),"GRAVEL / 碎石"],[Vector3(-490,0,-740),"MUD / 泥泞减速"],[Vector3(-130,0,-970),"GRASS / 草坡横切"],[Vector3(200,0,-830),"RIVER / 浅水慢行"],[Vector3(425,0,-530),"CANYON / 主路左绕 · 捷径喷射"]]:
		var p: Vector3 = entry[0]
		p.y = Ground.height_at(p.x,p.z)
		label_at(entry[1],Transform3D(Basis.IDENTITY,p),4.3,0.014)
	flush_batches()

func flag(p: Vector3,color: Color) -> void:
	Geo.cylinder(self,0.055,1.9,p+Vector3.UP*0.95,Geo.material(Color("555143")))
	Geo.box(self,Vector3(0.48,0.38,0.035),p+Vector3(0.2,1.65,0),Geo.material(color))

func recovery_at_gate(index: int) -> Transform3D:
	var pose := pose_at(gate_distances[index]+10)
	pose.origin += Vector3.UP*0.9
	return pose

func road_height_at(p: Vector3) -> float:
	return Ground.height_at(p.x,p.z)
