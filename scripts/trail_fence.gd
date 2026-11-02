extends Node3D
## Shared-vertex fence lines: smooth corners, sloping rails and chunked rendering.
const Ground = preload("res://scripts/offroad_model.gd")
const Geo = preload("res://scripts/geometry.gd")
const OFFSET := 2.95
const STEP := 3.0
var chunks: Dictionary = {}
var panels: Array[Dictionary] = []
var post_count := 0
var material: Material
var course: Node3D

func build(owner_course: Node3D) -> void:
	name = "TrailFence"
	course = owner_course
	material = Geo.material(Color("755739"))
	var count := ceili(course.length/STEP)
	for side in [-1.0,1.0]:
		var points: Array[Vector3] = []
		for i in count:
			var distance: float = course.length*i/count
			var pose: Transform3D = course.pose_at(distance)
			var normal := pose.basis.x
			normal.y = 0
			var p: Vector3 = pose.origin+normal.normalized()*side*OFFSET
			p.y = Ground.height_at(p.x,p.z)
			points.append(p)
		for i in count:
			var a := points[i]
			var b := points[(i+1)%count]
			# Opening panels are omitted, rather than leaving invisible colliders.
			if shortcut_opening(a,b):
				continue
			panel(a,b,side)
	flush()

func shortcut_opening(a: Vector3,b: Vector3) -> bool:
	for p in [a,a.lerp(b,0.5),b]:
		if course.in_shortcut_corridor(p,0.65):
			return true
	return false

func chunk(p: Vector3) -> Dictionary:
	var key := Vector2i(floori(p.x/64),floori(p.z/64))
	if not chunks.has(key):
		var body := StaticBody3D.new()
		var contact := PhysicsMaterial.new()
		contact.friction = 0.3
		contact.bounce = 0.0
		body.physics_material_override = contact
		body.name = "FenceCollision_%d_%d"%[key.x,key.y]
		body.set_meta("trail_fence",true)
		add_child(body)
		chunks[key] = {"body":body,"poses":[]}
	return chunks[key]

func box_pose(a: Vector3,b: Vector3,height: float) -> Transform3D:
	var basis := Basis.looking_at((b-a).normalized(),Vector3.UP)
	return Transform3D(basis,(a+b)*0.5+Vector3.UP*height)

func panel(a: Vector3,b: Vector3,side: float) -> void:
	var data := chunk((a+b)*0.5)
	var length := a.distance_to(b)
	for height in [0.48,1.0]:
		var pose := box_pose(a,b,height)
		wood_piece(data,pose,Vector3(0.14,0.14,length+0.08))
	wood_piece(data,Transform3D(Basis.IDENTITY,a+Vector3.UP*0.55),Vector3(0.2,1.35,0.2))
	post_count += 1
	panels.append({"a":a,"b":b,"side":side})

func wood_piece(data: Dictionary, pose: Transform3D, size: Vector3) -> void:
	# Rendering and collision use the same dimensions and transform.
	data.poses.append(Transform3D(pose.basis*Basis.from_scale(size),pose.origin))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.transform = pose
	data.body.add_child(collision)

func flush() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for key in chunks:
		var data: Dictionary = chunks[key]
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = box
		mesh.instance_count = data.poses.size()
		for i in data.poses.size():
			mesh.set_instance_transform(i,data.poses[i])
		var node := MultiMeshInstance3D.new()
		node.name = "FenceWood_%d_%d"%[key.x,key.y]
		node.multimesh = mesh
		node.material_override = material
		node.visibility_range_end = 450
		add_child(node)
