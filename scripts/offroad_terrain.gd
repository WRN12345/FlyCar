extends Node3D
const Model = preload("res://scripts/offroad_model.gd")
const Geo = preload("res://scripts/geometry.gd")
const Forest=preload("res://scripts/forest_scene.gd")
var bounds := Model.BOUNDS
var regions: Array = []
var bins: Dictionary = {}
var route: Array[Vector3] = []
var grass_cut := [Vector2(-423,-599),Vector2(-381,-896)]
const TRAIL_HALF_WIDTH := 2.35
const TRAIL_EDGE := 0.3
const MASK_SCALE := 2.0
var trail_image: Image
var trail_rock_count:=0

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
	build_trail_mask()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform sampler2D trail_map: filter_linear_mipmap,repeat_disable;
uniform vec4 map_bounds;
varying vec3 pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
vec3 bump(vec3 n,float h,vec3 p){vec3 dx=dFdx(p);vec3 dy=dFdy(p);vec3 a=cross(dy,n);vec3 b=cross(n,dx);float det=dot(dx,a);return normalize(max(abs(det),.00001)*n-sign(det)*(dFdx(h)*a+dFdy(h)*b));}
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec4 trail=texture(trail_map,(pos.xz-map_bounds.xy)/map_bounds.zw);
    float detail=(noise(pos.xz*2.1)-.5)/(1.+length(fwidth(pos.xz))*5.);
    float variation=.94+.12*noise(pos.xz*.19)+.12*detail;
    ALBEDO=mix(COLOR.rgb,trail.rgb,trail.a)*variation;
    NORMAL=bump(NORMAL,detail*.018*trail.a,VERTEX);
    ROUGHNESS=.98;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	trail_image.generate_mipmaps()
	material.set_shader_parameter("trail_map",ImageTexture.create_from_image(trail_image))
	material.set_shader_parameter("map_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
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
	build_trail_rocks()
	var forest:=Forest.new()
	add_child(forest)
	forest.build(self)

static func distance_to_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
	var delta := b-a
	return p.distance_to(a+delta*clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.001),0,1))

func trail_distance(p: Vector2) -> float:
	var distance := INF
	for segment in bins.get(Vector2i(floori(p.x/32),floori(p.y/32)),[]):
		distance = minf(distance,distance_to_segment(p,segment[0],segment[1]))
	return distance

func ground_color(p: Vector3) -> Color:
	var base: Color = Model.profile(Model.material_at(p.x,p.z,false)).color
	return base*(0.96+0.04*sin(p.x*0.13+p.z*0.18))

func trail_coverage(p: Vector2) -> float:
	return 1.0-smoothstep(TRAIL_HALF_WIDTH-TRAIL_EDGE,TRAIL_HALF_WIDTH+TRAIL_EDGE,trail_distance(p))

func build_trail_mask() -> void:
	trail_image=Image.create(int(bounds.size.x*MASK_SCALE),int(bounds.size.y*MASK_SCALE),false,Image.FORMAT_RGBA8)
	trail_image.fill(Color(0,0,0,0))
	for i in route.size():
		var a:=Vector2(route[i].x,route[i].z)
		var b:=Vector2(route[(i+1)%route.size()].x,route[(i+1)%route.size()].z)
		var steps:=maxi(1,ceili(a.distance_to(b)*MASK_SCALE))
		for j in steps:
			var p:=a.lerp(b,float(j)/steps)
			paint_trail(p,TRAIL_HALF_WIDTH,Model.profile(Model.material_at(p.x,p.y)).color,(b-a).normalized().orthogonal())
	var length: float=grass_cut[0].distance_to(grass_cut[1])
	for i in ceili(length*MASK_SCALE):
		paint_trail(grass_cut[0].lerp(grass_cut[1],i/(length*MASK_SCALE)),1.65,Color("71814c"),(grass_cut[1]-grass_cut[0]).normalized().orthogonal())

func paint_trail(p:Vector2,half_width:float,color:Color,side:Vector2) -> void:
	var pixel:=(p-bounds.position)*MASK_SCALE
	var linear:=color.srgb_to_linear()
	var radius:=ceili((half_width+TRAIL_EDGE)*MASK_SCALE)+1
	for x in range(maxi(0,floori(pixel.x)-radius),mini(trail_image.get_width(),ceili(pixel.x)+radius+1)):
		for z in range(maxi(0,floori(pixel.y)-radius),mini(trail_image.get_height(),ceili(pixel.y)+radius+1)):
			var distance:=Vector2(x+0.5,z+0.5).distance_to(pixel)/MASK_SCALE
			var alpha:=1-smoothstep(half_width-TRAIL_EDGE,half_width+TRAIL_EDGE,distance)
			if alpha>trail_image.get_pixel(x,z).a:
				var lateral:=((Vector2(x+.5,z+.5)-pixel)/MASK_SCALE).dot(side)
				var wear:=.82+.18*smoothstep(.09,.32,absf(absf(lateral)-.85))
				trail_image.set_pixel(x,z,Color(linear.r*wear,linear.g*wear,linear.b*wear,alpha))

func surface_at(p: Vector3) -> Dictionary:
	var depth: float = Model.water_depth(p.x,p.z)
	var on_trail := trail_distance(Vector2(p.x,p.z)) < TRAIL_HALF_WIDTH
	var kind: String = Model.material_at(p.x,p.z,on_trail)
	if distance_to_segment(Vector2(p.x,p.z),grass_cut[0],grass_cut[1]) < 1.65:
		kind = "grass"
	var profile: Dictionary = Model.profile(kind)
	return {"kind":"water" if depth>0.9 else "land", "height":Model.height_at(p.x,p.z), "water_height":Model.WATER_HEIGHT, "water_depth":depth, "normal":Model.normal_at(p.x,p.z), "material":kind, "grip":profile.grip, "rolling":profile.rolling, "label":profile.label}

func build_water() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;} void fragment(){float ripple=sin(p.x*.45+p.z*.8-TIME*1.2)+.5*sin(p.x*1.2-p.z*.35+TIME*.7); ALBEDO=mix(vec3(.018,.065,.055),vec3(.06,.18,.145),.5+.12*ripple); NORMAL_MAP=vec3(.5+.012*ripple,.5+.008*sin(p.z*.9+p.x*.7-TIME),1.); ROUGHNESS=.38;SPECULAR=.35;ALPHA=.76;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(70,520)
	Geo.mesh_node(self,plane,Vector3(255,Model.WATER_HEIGHT,-860),material).name = "River"

func build_trail_rocks() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=80031
	var material:=Geo.material(Color("77766e"))
	for i in range(12,route.size(),4):
		var p:=route[i]
		var kind: String=Model.material_at(p.x,p.z)
		if kind not in ["rock","gravel"]:
			continue
		if p.x>370 and p.z> -580 and p.z< -300:
			continue
		var forward:Vector3=route[(i+1)%route.size()]-route[(i-1+route.size())%route.size()]
		forward.y=0
		var side:=forward.normalized().cross(Vector3.UP)
		for direction in [-1,1]:
			var at:Vector3=p+side*direction*(TRAIL_HALF_WIDTH+1.6+rng.randf_range(0,0.8))
			at.y=Model.height_at(at.x,at.z)
			add_trail_rock(at,rng.randf_range(0.6,1.25),rng.randf_range(0.7,1.4),material)
		if kind=="rock":
			var at:=p+side*(0.85 if i%3 else -0.85)
			at.y=Model.height_at(at.x,at.z)-0.02
			add_trail_rock(at,0.32,0.20,material)

func add_trail_rock(at:Vector3,radius:float,height:float,material:Material) -> void:
	if height>0.3:
		at.y+=height*0.25
	var mesh:=SphereMesh.new()
	mesh.radius=radius
	mesh.height=height
	mesh.radial_segments=7
	mesh.rings=4
	var body:=StaticBody3D.new()
	body.name="TrailRock_%03d"%trail_rock_count
	trail_rock_count+=1
	body.set_meta("trail_rock",true)
	body.position=at
	var collision:=CollisionShape3D.new()
	collision.shape=mesh.create_convex_shape()
	body.add_child(collision)
	add_child(body)
	Geo.mesh_node(body,mesh,Vector3.ZERO,material)
