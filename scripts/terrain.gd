extends Node3D
## The same rectangles define visible ground, solid collisions and surface queries.
const Geo = preload("res://scripts/geometry.gd")
const WATER_HEIGHT := 0.0
const LAND_HEIGHT := 1.0
var bounds := Rect2()
var route_bounds := Rect2()
var base_kind := "land"
var regions: Array = []

func build(data: Dictionary, points: Array[Vector3]) -> void:
	name = "SurroundingTerrain"
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		minimum = minimum.min(Vector2(point.x, point.z))
		maximum = maximum.max(Vector2(point.x, point.z))
	route_bounds = Rect2(minimum, maximum - minimum)
	bounds = route_bounds.grow(220)
	var definition: Dictionary = data.get("terrain", {"base": "land", "regions": []})
	base_kind = definition.get("base", "land")
	for region in definition.get("regions", []):
		var r: Array = region.rect
		var rect := Rect2(route_bounds.position + route_bounds.size * Vector2(r[0], r[1]), route_bounds.size * Vector2(r[2] - r[0], r[3] - r[1])).intersection(bounds)
		if rect.has_area():
			regions.append({"kind": region.kind, "rect": rect})
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 world_pos; void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float w=sin(world_pos.x*0.045+TIME*0.6)*sin(world_pos.z*0.055-TIME*0.5); ALBEDO=mix(vec3(0.07,0.22,0.28),vec3(0.12,0.35,0.40),0.5+w*0.22); ROUGHNESS=0.38; SPECULAR=0.3;}"
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	Geo.mesh_node(self, plane, Vector3.ZERO, water_material).name = "WaterSurface"
	# Partition along every region boundary so no invisible land collider exists below water.
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	for region in regions:
		for x in [region.rect.position.x, region.rect.end.x]:
			if not x in xs:
				xs.append(x)
		for z in [region.rect.position.y, region.rect.end.y]:
			if not z in zs:
				zs.append(z)
	xs.sort()
	zs.sort()
	var grass := Geo.material(Color("506b47"))
	grass.roughness = 1.0
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var center := Vector3((xs[i] + xs[i + 1]) / 2, LAND_HEIGHT - 2, (zs[j] + zs[j + 1]) / 2)
			if surface_at(center).kind == "land":
				var ground := Geo.solid(self, Vector3(xs[i + 1] - xs[i], 4, zs[j + 1] - zs[j]), center, grass)
				ground.set_meta("surface_kind", "land")
	# Simple original vegetation gives the ground a visible scale reference.
	var rng := RandomNumberGenerator.new()
	rng.seed = 922
	var bark := Geo.material(Color("534a34"))
	var foliage := Geo.material(Color("34543e"))
	for i in 65:
		var p := Vector3(rng.randf_range(bounds.position.x, bounds.end.x), LAND_HEIGHT, rng.randf_range(bounds.position.y, bounds.end.y))
		if surface_at(p).kind == "land":
			Geo.cylinder(self, 0.45, 4, p + Vector3.UP * 2, bark)
			var crown := SphereMesh.new()
			crown.radius = 3.5
			crown.height = 7
			Geo.mesh_node(self, crown, p + Vector3.UP * 5.5, foliage)

func surface_at(position: Vector3) -> Dictionary:
	var flat := Vector2(position.x, position.z)
	var kind := base_kind if bounds.has_point(flat) else "water"
	for region in regions:
		if region.rect.has_point(flat):
			kind = region.kind
	return {"kind": kind, "height": LAND_HEIGHT if kind == "land" else WATER_HEIGHT}
