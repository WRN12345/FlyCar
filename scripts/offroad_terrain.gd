extends Node3D
const Model = preload("res://scripts/offroad_model.gd")
const Geo = preload("res://scripts/geometry.gd")
var bounds := Model.BOUNDS
var regions: Array = []
var bins: Dictionary = {}
var route: Array[Vector3] = []
var grass_cut := [Vector2(-423,-599),Vector2(-381,-896)]

func build(points: Array[Vector3]) -> void:
	name = "ValleyTerrain"
	route = points
	for i in route.size():
		var a := Vector2(route[i].x,route[i].z)
		var b := Vector2(route[(i+1)%route.size()].x,route[(i+1)%route.size()].z)
		var lo := (a.min(b)-Vector2.ONE*16)/32
		var hi := (a.max(b)+Vector2.ONE*16)/32
		for x in range(floori(lo.x),floori(hi.x)+1):
			for z in range(floori(lo.y),floori(hi.y)+1):
				var key := Vector2i(x,z)
				if not bins.has(key):
					bins[key] = []
				bins[key].append([a,b])
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 pos; void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;} void fragment(){float grain=sin(pos.x*.027+sin(pos.z*.039))*sin(pos.z*.031); ALBEDO=COLOR.rgb*(0.96+grain*0.04); ROUGHNESS=0.98;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	# 32-cell chunks share exact global grid vertices, including the final partial chunks.
	var nx := int(bounds.size.x/Model.CELL)
	var nz := int(bounds.size.y/Model.CELL)
	var stride := nz+1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for x in nx+1:
		for z in nz+1:
			var xx := bounds.position.x+x*Model.CELL
			var zz := bounds.position.y+z*Model.CELL
			var p := Vector3(xx,Model.raw_height(xx,zz),zz)
			vertices.append(p)
			normals.append(Model.normal_at(xx+0.001,zz+0.001))
			colors.append(ground_color(p).srgb_to_linear())
	for cx in range(0,nx,32):
		for cz in range(0,nz,32):
			var faces := PackedVector3Array()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(cx,mini(cx+32,nx)):
				for z in range(cz,mini(cz+32,nz)):
					var a := x*stride+z
					var b := (x+1)*stride+z
					var c := a+1
					var d := b+1
					for index in [a,b,c,b,d,c]:
						st.set_color(colors[index])
						st.set_normal(normals[index])
						st.add_vertex(vertices[index])
						faces.append(vertices[index])
			var body := StaticBody3D.new()
			body.set_meta("offroad_terrain", self)
			var collider := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			collider.shape = shape
			body.add_child(collider)
			add_child(body)
			Geo.mesh_node(body,st.commit(),Vector3.ZERO,material)
	build_water()
	build_scenery()

static func distance_to_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
	var delta := b-a
	return p.distance_to(a+delta*clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.001),0,1))

func trail_distance(p: Vector2) -> float:
	var distance := INF
	for segment in bins.get(Vector2i(floori(p.x/32),floori(p.y/32)),[]):
		distance = minf(distance,distance_to_segment(p,segment[0],segment[1]))
	return distance

func ground_color(p: Vector3) -> Color:
	var distance := trail_distance(Vector2(p.x,p.z))
	var base: Color = Model.profile(Model.material_at(p.x,p.z,false)).color
	var trail: Color = Model.profile(Model.material_at(p.x,p.z)).color
	if Model.material_at(p.x,p.z) == "grass":
		trail = Color("7a8050")
	var weight := 1.0-smoothstep(4.5,10.0,distance)
	var color := base.lerp(trail,weight)
	var cut := distance_to_segment(Vector2(p.x,p.z),grass_cut[0],grass_cut[1])
	if cut < 5:
		color = color.lerp(Color("71814c"),1-smoothstep(2.5,5.0,cut))
	return color * (0.96+0.04*sin(p.x*0.13+p.z*0.18))

func surface_at(p: Vector3) -> Dictionary:
	var depth: float = Model.water_depth(p.x,p.z)
	var on_trail := trail_distance(Vector2(p.x,p.z)) < 9
	var kind: String = Model.material_at(p.x,p.z,on_trail)
	if distance_to_segment(Vector2(p.x,p.z),grass_cut[0],grass_cut[1]) < 5:
		kind = "grass"
	var profile: Dictionary = Model.profile(kind)
	return {"kind":"water" if depth>0.9 else "land", "height":Model.height_at(p.x,p.z), "water_height":Model.WATER_HEIGHT, "water_depth":depth, "normal":Model.normal_at(p.x,p.z), "material":kind, "grip":profile.grip, "rolling":profile.rolling, "label":profile.label}

func build_water() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;} void fragment(){ALBEDO=mix(vec3(.08,.25,.29),vec3(.20,.43,.43),.5+.2*sin(p.x*1.5+TIME)*sin(p.z*.8-TIME)); ROUGHNESS=.28;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(70,520)
	Geo.mesh_node(self,plane,Vector3(255,Model.WATER_HEIGHT,-860),material).name = "River"

func build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61027
	var bark := Geo.material(Color("51412e"))
	var leaf := Geo.material(Color("35583b"))
	var rock := Geo.material(Color("6b706a"))
	for i in 200:
		var p := Vector3(rng.randf_range(-650,590),0,rng.randf_range(-1120,230))
		if trail_distance(Vector2(p.x,p.z)) < 20 or Model.water_depth(p.x,p.z)>0 or distance_to_segment(Vector2(p.x,p.z),grass_cut[0],grass_cut[1])<15:
			continue
		if p.x>350 and p.z> -550 and p.z < -290:
			continue
		p.y = Model.height_at(p.x,p.z)
		if i%3:
			Geo.cylinder(self,0.25,3.5,p+Vector3.UP*1.75,bark)
			var trunk_body := StaticBody3D.new()
			var trunk_collision := CollisionShape3D.new()
			var trunk_shape := CylinderShape3D.new()
			trunk_shape.radius = 0.25
			trunk_shape.height = 3.5
			trunk_collision.shape = trunk_shape
			trunk_body.position = p+Vector3.UP*1.75
			trunk_body.add_child(trunk_collision)
			add_child(trunk_body)
			var crown := CylinderMesh.new()
			crown.top_radius = 0
			crown.bottom_radius = rng.randf_range(1.5,2.6)
			crown.height = 5
			crown.radial_segments = 7
			Geo.mesh_node(self,crown,p+Vector3.UP*5,leaf)
		else:
			var stone := SphereMesh.new()
			stone.radius = rng.randf_range(0.7,1.8)
			stone.height = stone.radius*1.4
			stone.radial_segments = 7
			stone.rings = 4
			var stone_body := StaticBody3D.new()
			stone_body.position = p
			var collider := CollisionShape3D.new()
			collider.shape = stone.create_convex_shape()
			stone_body.add_child(collider)
			add_child(stone_body)
			Geo.mesh_node(stone_body,stone,Vector3.ZERO,rock)
