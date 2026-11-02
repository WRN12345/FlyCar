extends Node3D
## Deterministic, collidable hazards on the existing forest route.
const Assets = preload("res://scripts/forest_assets.gd")
const Model = preload("res://scripts/offroad_model.gd")
const Geo = preload("res://scripts/geometry.gd")
var sites: Array[Dictionary] = []

func build(course: Node3D) -> void:
	name = "TrailObstacles"
	Assets.prepare()
	var sequence := 0
	for distance in range(120, int(course.length)-80, 105):
		var pose: Transform3D = course.pose_at(distance)
		var p := pose.origin
		var safe := true
		for gate in course.gates:
			if Vector2(p.x-gate.origin.x,p.z-gate.origin.z).length() < 36:
				safe = false
		# Keep the river crossing and canyon take-off/landing approaches clear.
		if not safe or Model.water_depth(p.x,p.z) > 0.02 or (p.x>370 and p.z> -610 and p.z< -280):
			continue
		var side := pose.basis.x
		side.y = 0
		side = side.normalized()
		var sign_value := 1.0 if sequence%2==0 else -1.0
		var kind := sequence%3
		var site := {"distance":float(distance), "position":p, "kind":kind, "blocked_side":sign_value}
		sites.append(site)
		if kind == 0:
			rock(p+side*sign_value*1.35, Vector3(0.72,0.65,0.85), sequence)
		elif kind == 1:
			fallen_tree(p, side, sequence, sign_value)
		else:
			# A low rock garden occupies one side, leaving a continuous escape lane.
			for j in 4:
				var at := p+side*sign_value*(1.2+0.15*(j%2))-pose.basis.z*(j-1.5)*1.25
				rock(at, Vector3(0.35+0.04*j,0.16+0.03*j,0.4), sequence*7+j)
		sequence += 1

func rock(p: Vector3, size: Vector3, seed_value: int) -> void:
	var mesh := Assets.sculpt_rock(size,seed_value+913)
	# Sculpted geometry extends below its origin; embed the foot in the terrain.
	p.y = Model.height_at(p.x,p.z)+size.y*0.65
	var body := StaticBody3D.new()
	body.name = "RouteRock_%03d"%get_child_count()
	body.position = p
	body.set_meta("trail_hazard",true)
	add_child(body)
	Geo.mesh_node(body,mesh,Vector3.ZERO,Assets.rock)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	body.add_child(collision)

func fallen_tree(p: Vector3, side: Vector3, index: int, blocked_side: float) -> void:
	# The original growing point stays in the forest; the crown falls diagonally
	# onto the near half of the trail, leaving the other half driveable.
	var root := p+side*blocked_side*6.8
	var forward := Vector3.UP.cross(side).normalized()
	var axis := (-side*blocked_side*0.5+forward*0.8660254).normalized()
	var a := root-axis*0.25
	var b := root+axis*5.55
	a.y = Model.height_at(a.x,a.z)+0.27
	b.y = Model.height_at(b.x,b.z)+0.27
	axis = (b-a).normalized()
	var across := axis.cross(Vector3.UP).normalized()
	var basis := Basis(across,axis,across.cross(axis)).orthonormalized()
	var body := StaticBody3D.new()
	body.name = "FallenTree_%03d"%index
	body.transform = Transform3D(basis,(a+b)*0.5)
	body.set_meta("trail_hazard",true)
	body.set_meta("root_anchor",root)
	add_child(body)
	var length := a.distance_to(b)
	var mesh := CylinderMesh.new()
	mesh.height = length
	mesh.top_radius = 0.27
	mesh.bottom_radius = 0.34
	mesh.radial_segments = 14
	Geo.mesh_node(body,mesh,Vector3.ZERO,Assets.bark)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	body.add_child(collision)
	# Broken limbs follow the root-to-crown direction, independent of road side.
	for j in 3:
		var limb := Geo.cylinder(body,0.09+0.015*j,0.85+0.15*j,Vector3(0.12,1.7+j*0.3,0.1),Assets.bark)
		limb.rotation = Vector3(0.7+j*0.6,0,0.8+j*0.4)
		var limb_collision := CollisionShape3D.new()
		limb_collision.shape = limb.mesh.create_convex_shape()
		limb_collision.transform = limb.transform
		body.add_child(limb_collision)
	preload("res://scripts/fallen_tree_details.gd").add_to(body,1.0,index)
