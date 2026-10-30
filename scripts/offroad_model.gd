extends RefCounted
## Deterministic original valley terrain. Heights and collider triangles share a 4m grid.
const CELL := 4.0
const WATER_HEIGHT := 2.24
const BOUNDS := Rect2(-700, -1160, 1320, 1440)
static var profiles: Dictionary = {}

static func raw_height(x: float, z: float) -> float:
	var h := 10.0 + sin(x * 0.005) * 6.0 + sin(z * 0.005) * 5.0
	var canyon_corridor := smoothstep(300.0,370.0,x)*(1-smoothstep(570.0,620.0,x))*smoothstep(-650.0,-570.0,z)*(1-smoothstep(-300.0,-250.0,z))
	var start_blend:=smoothstep(40.0,100.0,Vector2(x,z).length())
	h += (7.5*sin(z*0.022)+5.5*sin(x*0.018+z*0.007))*(1-canyon_corridor)*start_blend
	# Scenic interior ridges leave the perimeter driving corridor comparatively gentle.
	h += 52.0 * exp(-pow((x+130)/105,2)-pow((z+650)/115,2))
	h += 40.0 * exp(-pow((x-120)/85,2)-pow((z+350)/105,2))
	h += 11.0 * exp(-pow((x + 425) / 130, 2) - pow((z + 740) / 170, 2))
	h += 7.0 * exp(-pow((x - 430) / 150, 2) - pow((z + 200) / 180, 2))
	h += sin(x * 0.19) * sin(z * 0.22) * 0.07
	var rock_bed := smoothstep(270.0,310.0,x)*(1-smoothstep(480.0,530.0,x))*smoothstep(-610.0,-560.0,z)*(1-smoothstep(-300.0,-260.0,z))
	h += sin(x*0.42)*sin(z*0.51)*0.12*rock_bed*(1-canyon_corridor)
	var river := (1.0 - smoothstep(35.0, 110.0, absf(x - 255))) * smoothstep(-1160.0, -1100.0, z) * (1.0 - smoothstep(-640.0,-580.0,z))
	var bed := 2.0 - 3.2 * exp(-pow((x - 255) / 25, 2) - pow((z + 1040) / 40, 2))
	h = lerpf(h, bed, river)
	var canyon := (1.0 - smoothstep(9.0,16.0,absf(z + 430))) * smoothstep(340.0,370.0,x) * (1.0 - smoothstep(550.0,590.0,x))
	h -= canyon * 23.0
	# Small launch ridge on the optional canyon line, clear of the main bypass.
	h += 1.8 * exp(-pow((x - 438) / 40,2) - pow((z + 471) / 12,2))
	return h

static func height_at(x: float, z: float) -> float:
	var gx := floorf(x / CELL) * CELL
	var gz := floorf(z / CELL) * CELL
	var u := (x - gx) / CELL
	var v := (z - gz) / CELL
	var a := raw_height(gx,gz)
	var b := raw_height(gx+CELL,gz)
	var c := raw_height(gx,gz+CELL)
	if u + v <= 1:
		return a + (b-a)*u + (c-a)*v
	var d := raw_height(gx+CELL,gz+CELL)
	return d + (c-d)*(1-u) + (b-d)*(1-v)

static func normal_at(x: float, z: float) -> Vector3:
	var gx := floorf(x / CELL) * CELL
	var gz := floorf(z / CELL) * CELL
	var a := Vector3(gx,raw_height(gx,gz),gz)
	var b := Vector3(gx+CELL,raw_height(gx+CELL,gz),gz)
	var c := Vector3(gx,raw_height(gx,gz+CELL),gz+CELL)
	if (x-gx+z-gz)/CELL <= 1:
		return (c-a).cross(b-a).normalized()
	var d := Vector3(gx+CELL,raw_height(gx+CELL,gz+CELL),gz+CELL)
	return (c-b).cross(d-b).normalized()

static func water_depth(x: float, z: float) -> float:
	if x < 220 or x > 290 or z < -1120 or z > -600:
		return 0.0
	return maxf(0, WATER_HEIGHT - height_at(x,z))

static func material_at(x: float, z: float, on_trail: bool = true) -> String:
	if water_depth(x,z) > 0.03:
		return "water"
	if not on_trail:
		return "rock" if x > 355 and z > -540 and z < -320 else "grass"
	if x < -365 and z < -620:
		return "mud"
	if z < -890:
		return "grass"
	if x > 270 and z > -610 and z < -280:
		return "rock"
	if x < -80 and z > -650:
		return "gravel"
	return "dirt"

static func profile(kind: String) -> Dictionary:
	if profiles.has(kind):
		return profiles[kind]
	var values := {"dirt":[1.0,12.0,"967049","夯实土路"], "gravel":[0.72,23.0,"9b9d8c","碎石"], "mud":[0.48,62.0,"55412d","泥地"], "grass":[0.65,30.0,"536c3e","草坡"], "water":[0.60,85.0,"547775","浅水涉渡"], "rock":[0.86,20.0,"7a7770","岩石"]}
	var p: Array = values.get(kind, values.dirt)
	profiles[kind] = {"grip":p[0], "rolling":p[1], "color":Color(p[2]), "label":p[3]}
	return profiles[kind]
