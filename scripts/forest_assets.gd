extends RefCounted
## Original reusable meshes/materials. No downloaded model or texture dependency.
static var trees:Array[Mesh]=[]
static var plants:Array[Mesh]=[]
static var bark:ShaderMaterial
static var foliage:ShaderMaterial
static var rock:ShaderMaterial

static func prepare()->void:
	if not trees.is_empty():
		return
	var noise_code:="""varying vec3 world_pos;
float hash(vec2 p){vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
vec3 bump(vec3 n,float h,vec3 p){vec3 dx=dFdx(p);vec3 dy=dFdy(p);vec3 r1=cross(dy,n);vec3 r2=cross(n,dx);float det=dot(dx,r1);return normalize(max(abs(det),.00001)*n-sign(det)*(dFdx(h)*r1+dFdy(h)*r2));}
"""
	bark=shader_material("shader_type spatial;\n"+noise_code+"""
void fragment(){
    float grain=noise(world_pos.xz*22.+world_pos.y*.13);
    float ridge=pow(abs(sin(world_pos.x*27.+world_pos.z*19.+grain*3.)),.35);
    ALBEDO=mix(vec3(.025,.018,.011),vec3(.14,.095,.052),ridge)*(.7+.5*grain)*COLOR.rgb;
    ROUGHNESS=.97;
    NORMAL=bump(NORMAL,grain*.012,VERTEX);
}
""")
	rock=shader_material("shader_type spatial;\n"+noise_code+"""
void fragment(){
    float n=noise(world_pos.xz*.8+world_pos.y*.4);
    float grain=noise(world_pos.xz*9.+world_pos.y*2.);
    float layers=smoothstep(.12,.25,abs(sin(world_pos.y*1.6+n*4.)));
    ALBEDO=mix(vec3(.055,.063,.056),vec3(.23,.245,.215),n)*(.72+.28*layers);
    ALBEDO=mix(ALBEDO,vec3(.035,.064,.025),smoothstep(.65,.85,n)*.7);
    ROUGHNESS=.92;
    ALBEDO*=.94+.12*noise(world_pos.xy*1.5+world_pos.z*.4);
}
""")
	foliage=shader_material("""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_map:filter_linear_mipmap,repeat_disable;
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.x+=sin(p.x*.9+p.z*.7+TIME*.9)*.04*clamp(VERTEX.y/10.,0.,1.);}
void fragment(){vec4 leaf=texture(leaf_map,UV);ALBEDO=leaf.rgb*COLOR.rgb;ALPHA=leaf.a;ALPHA_SCISSOR_THRESHOLD=.24;ROUGHNESS=.95;if(!FRONT_FACING){NORMAL=-NORMAL;}}
""")
	foliage.set_shader_parameter("leaf_map",leaf_texture())
	for kind in 2:
		trees.append(build_tree(kind))
		plants.append(build_plant(kind))

static func shader_material(code:String)->ShaderMaterial:
	var shader:=Shader.new()
	shader.code=code
	var material:=ShaderMaterial.new()
	material.shader=shader
	return material

static func leaf_texture()->ImageTexture:
	var image:=Image.create(256,256,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var rng:=RandomNumberGenerator.new()
	rng.seed=38271
	for leaf in 21:
		var t:=float(leaf)/21
		var side:=1.0 if leaf%2 else -1.0
		var center:=Vector2(.20+t*.59,.81-t*.61)+Vector2(side*.10,side*.08)
		var angle:float=side*.65-.5+rng.randf_range(-.2,.2)
		var size:=Vector2(rng.randf_range(.06,.10),rng.randf_range(.12,.18))
		for x in range(maxi(0,int((center.x-.24)*256)),mini(256,int((center.x+.24)*256))):
			for y in range(maxi(0,int((center.y-.24)*256)),mini(256,int((center.y+.24)*256))):
				var p:=(Vector2(x,y)/256-center).rotated(-angle)/size
				var distance:=p.length()
				var alpha:=clampf((1-distance)*18,0,1)
				if alpha>image.get_pixel(x,y).a:
					var shade:=.75+.25*sqrt(maxf(0,1-distance))
					var color:=Color("77934b")*shade
					if absf(p.x)<.025:
						color*=1.15
					color=color.srgb_to_linear()
					image.set_pixel(x,y,Color(color.r,color.g,color.b,alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,color:Color)->void:
	for p in [a,b,c]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(p)

static func cylinder(tool:SurfaceTool,a:Vector3,b:Vector3,r0:float,r1:float,color:Color)->void:
	var axis:=(b-a).normalized()
	var x:=axis.cross(Vector3.FORWARD).normalized()
	if x.length_squared()<.1:
		x=axis.cross(Vector3.RIGHT).normalized()
	var z:=axis.cross(x).normalized()
	for i in 7:
		var d0:=x*cos(TAU*i/7)+z*sin(TAU*i/7)
		var d1:=x*cos(TAU*(i+1)/7)+z*sin(TAU*(i+1)/7)
		var normal:=(d0+d1).normalized()
		triangle(tool,a+d0*r0,b+d0*r1,a+d1*r0,normal,color)
		triangle(tool,a+d1*r0,b+d0*r1,b+d1*r1,normal,color)

static func leaf_card(tool:SurfaceTool,p:Vector3,right:Vector3,up:Vector3,color:Color)->void:
	var vertices:=[p-right-up,p+right-up,p-right+up,p+right+up]
	var uv:=[Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]
	var normal:=-right.cross(up).normalized()
	for index in [0,1,2,1,3,2]:
		tool.set_normal(normal)
		tool.set_uv(uv[index])
		tool.set_color(color)
		tool.add_vertex(vertices[index])

static func build_tree(kind:int)->Mesh:
	var timber:=SurfaceTool.new()
	var leaves:=SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new()
	rng.seed=9187+kind
	cylinder(timber,Vector3.ZERO,Vector3(.1,6,0),.32,.19,Color.WHITE)
	cylinder(timber,Vector3(.1,6,0),Vector3(-.12,11,.13),.19,.08,Color.WHITE)
	cylinder(timber,Vector3(-.12,11,.13),Vector3(.1,14.5,0),.08,.015,Color.WHITE)
	var branches:=64 if kind else 28
	for i in branches:
		var t:=float(i)/branches
		var angle:=i*2.39996
		var y:=4.2+t*9.5 if kind else rng.randf_range(6.4,12.5)
		var radius:=3.4*(1-t*.8) if kind else rng.randf_range(2.4,4.2)
		var radial:=Vector3(cos(angle),0,sin(angle))
		var side:=radial.cross(Vector3.UP)
		var start:=Vector3(0,y,0)
		var end:=start+radial*radius+Vector3.UP*(.9 if kind==0 else -.35)
		cylinder(timber,start,end,.065*(1-t*.65),.012,Color(.8,.85,.8))
		var count:=5 if kind else 12
		for j in count:
			var at:=start.lerp(end,rng.randf_range(.35,1.0))
			at+=side*rng.randf_range(-.65,.65)+Vector3.UP*rng.randf_range(-.3,.7)
			var rotation:=rng.randf_range(-.65,.65)
			var right:=side.rotated(radial,rotation)*rng.randf_range(.45,.8)
			var up:=Vector3.UP.rotated(radial,rotation)*rng.randf_range(.4,.7)
			leaf_card(leaves,at,right,up,Color(rng.randf_range(.7,1.05),rng.randf_range(.8,1.1),.8))
	var mesh:=timber.commit()
	mesh.surface_set_material(0,bark)
	leaves.commit(mesh)
	mesh.surface_set_material(1,foliage)
	return mesh

static func build_plant(kind:int)->Mesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var angle:=TAU*i/9
		var radial:=Vector3(cos(angle),0,sin(angle))
		leaf_card(tool,radial*.25+Vector3.UP*(.6 if kind else .32),radial.cross(Vector3.UP)*.24,(radial*.25+Vector3.UP*(.8 if kind else .4)),Color(.8,.9,.65))
	var mesh:=tool.commit()
	mesh.surface_set_material(0,foliage)
	return mesh

static func sculpt_rock(size:Vector3,seed_value:int)->Mesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array=[]
	for y in range(1,7):
		var ring:Array[Vector3]=[]
		var latitude:=PI*y/7
		for i in 10:
			var angle:=TAU*i/10
			var shape:=1+.14*sin(i*7.13+y*3.7+seed_value)
			ring.append(Vector3(sin(latitude)*cos(angle),cos(latitude),sin(latitude)*sin(angle))*size*shape)
		rings.append(ring)
	for y in range(rings.size()-1):
		for i in 10:
			var j:=(i+1)%10
			var a:Vector3=rings[y][i]
			var b:Vector3=rings[y][j]
			var c:Vector3=rings[y+1][i]
			var d:Vector3=rings[y+1][j]
			triangle(tool,a,c,b,(b-a).cross(c-a).normalized(),Color.WHITE)
			triangle(tool,b,c,d,(d-b).cross(c-b).normalized(),Color.WHITE)
	for i in 10:
		var j:=(i+1)%10
		triangle(tool,Vector3(0,size.y,0),rings[0][i],rings[0][j],Vector3.UP,Color.WHITE)
		triangle(tool,Vector3(0,-size.y,0),rings[-1][j],rings[-1][i],Vector3.DOWN,Color.WHITE)
	var mesh:=tool.commit()
	mesh.surface_set_material(0,rock)
	return mesh
