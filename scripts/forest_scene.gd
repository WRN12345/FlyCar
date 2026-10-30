extends Node3D
const Assets=preload("res://scripts/forest_assets.gd")
const Model=preload("res://scripts/offroad_model.gd")
const Geo=preload("res://scripts/geometry.gd")
var terrain:Node3D
var batches:Dictionary={}
var cliff_positions:Array[Vector3]=[]
var cliff_radii:Array[float]=[]
var tree_count:=0
var cliff_count:=0
var rng:=RandomNumberGenerator.new()

func build(owner_terrain:Node3D)->void:
	name="ForestValley"
	terrain=owner_terrain
	rng.seed=473921
	Assets.prepare()
	build_cliffs()
	build_ridge()
	build_trees()
	build_undergrowth()
	build_creek()
	flush()
	for node in terrain.find_children("TrailRock*","StaticBody3D",true,false):
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=Assets.rock

func clear_corridor(p:Vector3,margin:float)->bool:
	var flat:=Vector2(p.x,p.z)
	if terrain.trail_distance(flat)<margin or Model.water_depth(p.x,p.z)>0.02:
		return false
	if terrain.distance_to_segment(flat,terrain.grass_cut[0],terrain.grass_cut[1])<10:
		return false
	if p.x>350 and p.x<590 and p.z> -610 and p.z< -260:
		return false
	return true

func instance(mesh:Mesh,pose:Transform3D,color:Color,prefix:String,kind:int)->void:
	var key:="%s_%d_%d_%d"%[prefix,floori(pose.origin.x/64),floori(pose.origin.z/64),kind]
	if not batches.has(key):
		batches[key]={"mesh":mesh,"poses":[],"colors":[],"tree":prefix=="Tree"}
	batches[key].poses.append(pose)
	batches[key].colors.append(color)

func build_trees()->void:
	var bounds:Rect2=Model.BOUNDS.grow(-20)
	for x in range(int(bounds.position.x),int(bounds.end.x),18):
		for z in range(int(bounds.position.y),int(bounds.end.y),18):
			if rng.randf()<.16:
				continue
			var p:=Vector3(x+rng.randf_range(-7,7),0,z+rng.randf_range(-7,7))
			if not clear_corridor(p,5.5):
				continue
			var blocked:=false
			for i in cliff_positions.size():
				if Vector2(p.x-cliff_positions[i].x,p.z-cliff_positions[i].z).length()<cliff_radii[i]+3:
					blocked=true
			if blocked:
				continue
			p.y=Model.height_at(p.x,p.z)
			var kind:=1 if rng.randf()<.45 else 0
			var size:=rng.randf_range(.8,1.3)
			var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(rng.randf_range(.85,1.15),size,rng.randf_range(.85,1.15)))
			instance(Assets.trees[kind],Transform3D(basis,p),Color(rng.randf_range(.8,1.05),rng.randf_range(.85,1.1),rng.randf_range(.75,.95)),"Tree",kind)
			var body:=StaticBody3D.new()
			body.name="ForestTrunk_%04d"%tree_count
			body.position=p+Vector3.UP*7*size
			var shape:=CylinderShape3D.new()
			shape.radius=.26
			shape.height=14*size
			var collision:=CollisionShape3D.new()
			collision.shape=shape
			body.add_child(collision)
			add_child(body)
			tree_count+=1

func build_undergrowth()->void:
	for i in range(0,terrain.route.size(),3):
		var center:Vector3=terrain.route[i]
		var delta:Vector3=terrain.route[(i+1)%terrain.route.size()]-center
		delta.y=0
		var side:=delta.normalized().cross(Vector3.UP)
		for sign_value in [-1,1]:
			for j in 12:
				var p:Vector3=center+side*sign_value*rng.randf_range(3.3,12)+delta.normalized()*rng.randf_range(-3,3)
				if Model.water_depth(p.x,p.z)>.02 or Model.material_at(p.x,p.z,false)=="rock":
					continue
				p.y=Model.height_at(p.x,p.z)
				var scale:=rng.randf_range(.65,1.3)
				var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale)
				instance(Assets.plants[0],Transform3D(basis,p),Color(.75,.9,.65),"Understory",0)

func add_cliff(p:Vector3,size:Vector3)->void:
	if terrain.trail_distance(Vector2(p.x,p.z))<maxf(size.x,size.z)+5:
		return
	if terrain.distance_to_segment(Vector2(p.x,p.z),terrain.grass_cut[0],terrain.grass_cut[1])<maxf(size.x,size.z)+12:
		return
	p.y=Model.height_at(p.x,p.z)+size.y*.4
	var mesh:=Assets.sculpt_rock(size,cliff_count+51)
	var body:=StaticBody3D.new()
	body.name="Cliff_%03d"%cliff_count
	body.position=p
	var collision:=CollisionShape3D.new()
	collision.shape=mesh.create_convex_shape()
	body.add_child(collision)
	add_child(body)
	Geo.mesh_node(body,mesh,Vector3.ZERO,Assets.rock)
	cliff_positions.append(p)
	cliff_radii.append(maxf(size.x,size.z))
	cliff_count+=1

func build_cliffs()->void:
	for i in range(10,terrain.route.size(),12):
		var p:Vector3=terrain.route[i]
		if p.x<270 or p.x>355 or p.z< -580 or p.z> -300:
			continue
		var delta:Vector3=terrain.route[(i+1)%terrain.route.size()]-p
		delta.y=0
		var side:=delta.normalized().cross(Vector3.UP)
		for sign_value in [-1,1]:
			add_cliff(p+side*sign_value*18,Vector3(rng.randf_range(4,7),rng.randf_range(5,10),rng.randf_range(4,7)))
	for p in [Vector3(-150,0,-560),Vector3(-110,0,-640),Vector3(-90,0,-700),Vector3(70,0,-340),Vector3(110,0,-390),Vector3(180,0,-450),Vector3(-250,0,-760),Vector3(-70,0,-800),Vector3(70,0,-600),Vector3(170,0,-590)]:
		add_cliff(p,Vector3(rng.randf_range(7,12),rng.randf_range(7,15),rng.randf_range(6,10)))

func build_ridge()->void:
	var rings:Array=[]
	for row in 4:
		var ring:Array[Vector3]=[]
		for i in 100:
			var angle:=TAU*i/100
			var radius:=1.0 if row==0 else 1.18 if row==1 else 1.47 if row==2 else 1.7
			var y:float=-30 if row==0 or row==3 else 80+110*absf(sin(i*.43))+70*absf(sin(i*.91)) if row==1 else 100+170*absf(sin(i*.37+1))
			ring.append(Vector3(-40+cos(angle)*900*radius,y,-440+sin(angle)*1070*radius))
		rings.append(ring)
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 3:
		for i in 100:
			var j:=(i+1)%100
			var a:Vector3=rings[row][i]
			var b:Vector3=rings[row][j]
			var c:Vector3=rings[row+1][i]
			var d:Vector3=rings[row+1][j]
			Assets.triangle(tool,a,c,b,-(c-a).cross(b-a).normalized(),Color.WHITE)
			Assets.triangle(tool,b,c,d,-(c-b).cross(d-b).normalized(),Color.WHITE)
	Geo.mesh_node(self,tool.commit(),Vector3.ZERO,Assets.rock).name="MountainRidge"

func build_creek()->void:
	var banks:=Node3D.new()
	banks.name="CreekBanks"
	add_child(banks)
	for z in range(-1100,-610,9):
		for x in [216.0,294.0]:
			var p:=Vector3(x+rng.randf_range(-3,3),0,z+rng.randf_range(-3,3))
			if terrain.trail_distance(Vector2(p.x,p.z))<9:
				continue
			p.y=Model.height_at(p.x,p.z)
			var mesh:=Assets.sculpt_rock(Vector3(rng.randf_range(.5,1.2),rng.randf_range(.3,.6),rng.randf_range(.5,1.2)),z)
			Geo.mesh_node(banks,mesh,p,Assets.rock)
			for i in 4:
				var at:=p+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2))
				at.y=Model.height_at(at.x,at.z)
				instance(Assets.plants[1],Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)),at),Color(.7,.85,.6),"Reeds",1)

func flush()->void:
	for key in batches:
		var batch:Dictionary=batches[key]
		var mesh:=MultiMesh.new()
		mesh.transform_format=MultiMesh.TRANSFORM_3D
		mesh.use_colors=true
		mesh.mesh=batch.mesh
		mesh.instance_count=batch.poses.size()
		for i in batch.poses.size():
			mesh.set_instance_transform(i,batch.poses[i])
			mesh.set_instance_color(i,batch.colors[i])
		var node:=MultiMeshInstance3D.new()
		node.name=key
		node.multimesh=mesh
		node.set_meta("forest_tree",batch.tree)
		node.visibility_range_end=650 if batch.tree else 200
		if not batch.tree:
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	batches.clear()
