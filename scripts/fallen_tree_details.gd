extends RefCounted
## Uprooted tree: tapering crown, forked limbs, leaf sprays and exposed roots.
const Assets = preload("res://scripts/forest_assets.gd")
const Geo = preload("res://scripts/geometry.gd")

static func add_to(body: StaticBody3D, growth: float, seed_value: int, crown_offset: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+67291
	var timber := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := Vector3(0,growth*crown_offset,0)
	var tip := Vector3(0.15,growth*7.7,0.45)+offset
	var start := Vector3(0,growth*2.65,0)+offset
	var middle := Vector3(0.12,growth*5,0.25)+offset
	Assets.cylinder(timber,start,middle,0.46,0.14,Color.WHITE)
	Assets.cylinder(timber,middle,tip,0.14,0.025,Color.WHITE)
	add_collision(body,start,middle,0.44,0.13)
	for i in 15:
		var t := float(i)/15
		var angle := i*2.39996
		var origin := Vector3(0,growth*(1.0+t*5.8),0.2*t)+offset
		# Local Y follows the fallen trunk; local Z points above the ground.
		var radial := Vector3(cos(angle),0,0.25+0.65*absf(sin(angle)))
		var reach := (1-t*0.5)*rng.randf_range(1.7,2.8)
		var elbow := origin+radial*reach*0.55+Vector3(0,growth*0.45,0.15)
		var end := origin+radial*reach+Vector3(0,growth*1.0,0.3)
		Assets.cylinder(timber,origin,elbow,0.09*(1-t*0.55),0.045,Color.WHITE)
		Assets.cylinder(timber,elbow,end,0.045,0.008,Color.WHITE)
		add_collision(body,origin,elbow,0.09*(1-t*0.55),0.04)
		for fork in [-1,1]:
			var twig := elbow.lerp(end,0.65)+Vector3(fork*0.45,growth*0.55,0.25)
			Assets.cylinder(timber,elbow,twig,0.025,0.004,Color.WHITE)
			for j in 16:
				var p := elbow.lerp(twig,rng.randf_range(0.25,1.1))
				p += Vector3(rng.randf_range(-0.32,0.32),rng.randf_range(-0.3,0.3),rng.randf_range(-0.15,0.3))
				var spin := rng.randf_range(-PI,PI)
				var right := Vector3(cos(spin),sin(spin),0.15)*rng.randf_range(0.20,0.36)
				var up := Vector3(-sin(spin)*0.5,cos(spin)*0.5,0.85)*rng.randf_range(0.24,0.42)
				Assets.leaf_card(leaves,p,right,up,Color(rng.randf_range(0.72,1.02),rng.randf_range(0.78,1.0),0.65))
	var crown := timber.commit()
	crown.surface_set_material(0,Assets.bark)
	leaves.commit(crown)
	crown.surface_set_material(1,Assets.foliage)
	Geo.mesh_node(body,crown,Vector3.ZERO,null).name = "BranchedLeafyCrown"
	add_roots(body,growth,rng)

static func add_collision(body: StaticBody3D, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = a.distance_to(b)
	mesh.bottom_radius = r0
	mesh.top_radius = r1
	mesh.radial_segments = 8
	var axis := (b-a).normalized()
	var across := axis.cross(Vector3.UP).normalized()
	if across.length_squared()<0.01:
		across = axis.cross(Vector3.RIGHT).normalized()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	shape.transform = Transform3D(Basis(across,axis,across.cross(axis)),(a+b)*0.5)
	body.add_child(shape)

static func add_roots(body: StaticBody3D, growth: float, rng: RandomNumberGenerator) -> void:
	var plate := Vector3(0,-growth*2.65,0.65)
	var soil := Geo.material(Color("241b12"))
	# Separated soil clods expose gaps between roots instead of a solid oval slab.
	Geo.mesh_node(body,Assets.sculpt_rock(Vector3(0.46,0.18,0.5),234),plate,soil).name = "UprootedSoilPlate"
	for i in 9:
		var angle := TAU*i/9
		var at := plate+Vector3(cos(angle)*0.65,-growth*0.16,sin(angle)*0.65)
		Geo.mesh_node(body,Assets.sculpt_rock(Vector3(0.24,0.16,0.27),i+49),at,soil)
	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Vector3(0,-growth*2.65,0)
	for i in 14:
		var angle := TAU*i/14
		var end := plate+Vector3(cos(angle)*rng.randf_range(0.8,1.3),growth*rng.randf_range(-0.12,0.35),sin(angle)*rng.randf_range(0.7,1.0))
		var elbow := root.lerp(end,0.55)+Vector3(0,growth*0.1,0.12)
		Assets.cylinder(timber,root,elbow,0.14,0.07,Color.WHITE)
		Assets.cylinder(timber,elbow,end,0.07,0.015,Color.WHITE)
		for fork in [-1,1]:
			Assets.cylinder(timber,end,end+Vector3(fork*0.2,growth*0.14,0.18),0.025,0.003,Color.WHITE)
	var mesh := timber.commit()
	Geo.mesh_node(body,mesh,Vector3.ZERO,Assets.bark).name = "ExposedForkedRoots"
	var collision := CollisionShape3D.new()
	collision.shape = Assets.sculpt_rock(Vector3(0.9,0.22,0.95),234).create_convex_shape()
	collision.position = plate
	body.add_child(collision)
