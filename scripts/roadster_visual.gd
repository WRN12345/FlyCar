extends RefCounted
## Original game mesh interpreted from the user's silver Roadster reference, not CAD.
const Geo = preload("res://scripts/geometry.gd")
const WHEEL_Z := [-1.36, 1.36]
const ARCH_CENTER_Y := -0.46
const ARCH_RADIUS := 0.44

static func paint() -> StandardMaterial3D:
	var material := Geo.material(Color("777e88"), 0.65)
	material.roughness = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func sample_profile(z: float, values: Array) -> float:
	for i in range(values.size() - 1):
		if z <= values[i + 1][0]:
			return lerpf(values[i][1], values[i + 1][1], clampf((z - values[i][0]) / (values[i + 1][0] - values[i][0]), 0, 1))
	return values[-1][1]

static func add_quad(vertices: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for triangle in [[a, b, c], [a, c, d]]:
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).length_squared() > 1e-14:
			vertices.append_array(triangle)

static func surface(parent: Node3D, name: String, vertices: Array[Vector3], material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		tool.add_vertex(vertex)
	tool.index()
	tool.generate_normals()
	var mesh := Geo.mesh_node(parent, tool.commit(), Vector3.ZERO, material)
	mesh.name = name
	return mesh

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var node := Geo.cylinder(parent, radius, a.distance_to(b), (a + b) * 0.5, material)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

static func build(parent: Node3D) -> void:
	var body := Node3D.new()
	body.name = "RoadsterBody"
	parent.add_child(body)
	var silver := paint()
	var black := Geo.material(Color("101319"), 0.35)
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := Geo.material(Color("20252c"), 0.38)
	glass.roughness = 0.24
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var red := Geo.material(Color("e8000f"), 0, 1.1)
	var white := Geo.material(Color("d5efff"), 0, 1.6)
	var seam := Geo.material(Color("343b43"), 0.25)
	Geo.loft(body, [[-2.3,0.58,-0.52,-0.14],[-1.9,0.62,-0.55,-0.01],[-1.2,0.62,-0.55,0.08],[-0.6,0.62,-0.55,0.1],[0.65,0.62,-0.55,0.14],[1.4,0.62,-0.53,0.2],[2.2,0.65,-0.44,0.1]], silver)
	body.get_child(body.get_child_count() - 1).name = "LowerHull"
	var widths := [[-2.3,0.70],[-2.05,0.94],[-1.36,1.02],[-0.6,0.96],[0.6,0.98],[1.36,1.05],[2.2,0.98]]
	var heights := [[-2.3,-0.14],[-1.9,-0.01],[-1.36,0.07],[-0.65,0.1],[0.65,0.15],[1.36,0.2],[2.2,0.10]]
	var fender_vertices: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var rings: Array = []
		for i in 181:
			var z := lerpf(-2.3, 2.2, float(i) / 180)
			var width := sample_profile(z, widths)
			var height := sample_profile(z, heights)
			var bottom := -0.53
			var arch_bulge := 0.0
			for wheel_z in WHEEL_Z:
				var distance := absf(z - wheel_z)
				arch_bulge = maxf(arch_bulge, exp(-pow(distance / 0.5, 2)) * 0.07)
				if distance < ARCH_RADIUS:
					bottom = maxf(bottom, ARCH_CENTER_Y + sqrt(maxf(0, ARCH_RADIUS * ARCH_RADIUS - distance * distance)))
			rings.append([Vector3(side * 0.61, height, z), Vector3(side * width * 0.95, height + arch_bulge, z), Vector3(side * width, height + arch_bulge - 0.055, z), Vector3(side * width * 0.98, bottom, z)])
		for i in range(rings.size() - 1):
			for j in 3:
				add_quad(fender_vertices, rings[i][j], rings[i+1][j], rings[i+1][j+1], rings[i][j+1])
		for index in [0, rings.size() - 1]:
			var ring: Array = rings[index]
			var inner_bottom := Vector3(side * 0.61, -0.53, ring[0].z)
			for j in range(1, 4):
				fender_vertices.append_array([ring[0], ring[j], ring[j+1] if j < 3 else inner_bottom])
	surface(body, "SculptedFendersWithWheelOpenings", fender_vertices, silver)
	Geo.loft(body, [[-1.03,0.66,0.07,0.11],[-0.4,0.64,0.1,0.51],[0.25,0.64,0.12,0.57],[0.7,0.61,0.14,0.49],[1.47,0.54,0.16,0.22]], glass)
	body.get_child(body.get_child_count() - 1).name = "FastbackGlassCanopy"
	# Window frames, triangular rear quarters and flush door details.
	for side in [-1.0, 1.0]:
		var rail := [Vector3(side*0.66,0.10,-1.02),Vector3(side*0.64,0.41,-0.4),Vector3(side*0.64,0.47,0.25),Vector3(side*0.61,0.39,0.7),Vector3(side*0.54,0.202,1.47)]
		for i in range(rail.size()-1):
			beam(body, rail[i], rail[i+1], 0.022, silver)
		var quarter: Array[Vector3] = []
		add_quad(quarter, Vector3(side*0.61,0.39,0.7), Vector3(side*0.96,0.16,0.62), Vector3(side*1.01,0.16,1.6), Vector3(side*0.54,0.202,1.47))
		surface(body, "SilverRearQuarter", quarter, silver)
		beam(body, Vector3(side*0.66,0.14,0.25), Vector3(side*0.64,0.47,0.25), 0.012, seam)
		beam(body, Vector3(side*0.96,0.1,0.65), Vector3(side*0.96,-0.42,0.68), 0.005, seam)
		beam(body, Vector3(side*0.96,-0.42,0.68), Vector3(side*0.96,-0.44,-0.86), 0.005, seam)
		beam(body, Vector3(side*0.96,-0.44,-0.86), Vector3(side*0.96,0.04,-0.88), 0.005, seam)
		Geo.box(body, Vector3(0.018,0.022,0.17), Vector3(side*0.977,-0.03,0.22), seam)
		Geo.box(body, Vector3(0.09,0.1,1.75), Vector3(side*0.97,-0.5,-0.08), black)
		Geo.box(body, Vector3(0.18,0.07,0.22), Vector3(side*0.94,0.19,-0.77), silver)
		var headlight := Geo.box(body, Vector3(0.53,0.065,0.07), Vector3(side*0.58,-0.115,-2.17), black)
		headlight.rotation.y = side * -0.18
		var led := Geo.box(body, Vector3(0.47,0.018,0.075), Vector3(side*0.58,-0.10,-2.20), white)
		led.rotation.y = side * -0.18
		Geo.box(body, Vector3(0.05,0.025,0.12), Vector3(side*0.94,-0.12,-1.97), Geo.material(Color("ff9a30"),0,0.5))
		Geo.box(body, Vector3(0.05,0.24,0.36), Vector3(side*0.97,-0.17,1.97), black)
	Geo.box(body, Vector3(1.65,0.08,0.15), Vector3(0,-0.45,-2.25), black)
	Geo.box(body, Vector3(1.96,0.07,0.12), Vector3(0,0.155,2.16), silver)
	Geo.box(body, Vector3(1.96,0.20,0.09), Vector3(0,0.07,2.21), black)
	var tail := Geo.box(body, Vector3(1.89,0.026,0.018), Vector3(0,0.125,2.265), red)
	tail.name = "FullWidthTailLight"
	Geo.box(body, Vector3(1.88,0.008,0.018), Vector3(0,0.075,2.265), Geo.material(Color("69000a"),0,0.25))
	Geo.loft(body, [[1.65,0.76,-0.57,-0.28],[2.26,0.87,-0.57,-0.23]], black)
	body.get_child(body.get_child_count() - 1).name = "RearDiffuser"
	for x in [-0.68,-0.34,0,0.34,0.68]:
		Geo.box(body, Vector3(0.035,0.23,0.48), Vector3(x,-0.45,2.04), black)
	var plate := Geo.box(body, Vector3(0.35,0.17,0.025), Vector3(0,-0.10,2.27), Geo.material(Color("b8bdc2"),0.25))
	plate.rotation.x = -0.12
	var label := Label3D.new()
	label.text = "RDSTR"
	label.font_size = 32
	label.pixel_size = 0.0018
	label.outline_size = 0
	label.modulate = Color("26313b")
	label.position = Vector3(0,-0.1,2.288)
	label.rotation.x = -0.12
	body.add_child(label)

static func build_wheel(parent: Node3D, side: float, radius: float) -> void:
	var spin := Node3D.new()
	spin.name = "WheelVisual"
	parent.add_child(spin)
	var rubber := Geo.material(Color("111317"))
	rubber.roughness = 0.95
	var dark := Geo.material(Color("282d34"),0.7)
	var alloy := Geo.material(Color("9ba3ac"),0.85)
	alloy.roughness = 0.27
	alloy.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tire := CylinderMesh.new()
	tire.top_radius = radius
	tire.bottom_radius = radius
	tire.height = 0.28
	tire.radial_segments = 64
	Geo.mesh_node(spin,tire,Vector3.ZERO,rubber).rotation.z = PI/2
	Geo.cylinder(spin,0.285,0.285,Vector3.ZERO,dark).rotation.z = PI/2
	Geo.cylinder(spin,0.21,0.018,Vector3(side*0.147,0,0),Geo.material(Color("555d66"),0.7)).rotation.z = PI/2
	var lip := TorusMesh.new()
	lip.inner_radius = 0.267
	lip.outer_radius = 0.285
	lip.rings = 64
	lip.ring_segments = 12
	Geo.mesh_node(spin,lip,Vector3(side*0.153,0,0),alloy).rotation.z = PI/2
	for i in 5:
		var angle := TAU*i/5
		var blade: Array[Vector3] = []
		var p: Array[Vector3] = []
		for shape in [[0.065,-0.30],[0.274,-0.04],[0.274,0.32],[0.09,0.33]]:
			p.append(Vector3(side*0.163,cos(angle+shape[1])*shape[0],sin(angle+shape[1])*shape[0]))
		add_quad(blade,p[0],p[1],p[2],p[3])
		surface(spin,"MachinedSpoke%d"%i,blade,alloy)
	Geo.cylinder(spin,0.067,0.025,Vector3(side*0.173,0,0),dark).rotation.z = PI/2
	Geo.box(parent,Vector3(0.035,0.13,0.11),Vector3(side*0.14,0.13,-0.13),Geo.material(Color("a83735")))
