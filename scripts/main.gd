extends Node3D

const Geo = preload("res://scripts/geometry.gd")
const Car = preload("res://scripts/car.gd")
const Race = preload("res://scripts/race_state.gd")
const Map = preload("res://scripts/minimap.gd")
var car: RigidBody3D
var camera: Camera3D
var race = Race.new(8)
var route: Array[Vector3] = []
var gates: Array[Transform3D] = []
var gate_lights: Array[MeshInstance3D] = []
var countdown := 3.0
var recovery_pose := Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 85))
var hud_speed: Label
var hud_time: Label
var hud_gate: Label
var hud_status: Label
var hud_fuel: ProgressBar
var hud_hint: Label
var banner: Label
var map: Control
var message_time := 0.0
var best_time := 0.0
var cyan: Material
var lime: Material
var orange: Material
var dark: Material

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Car.configure_inputs()
	cyan = Geo.material(Color("77d9e5"), 0.25, 0.65)
	lime = Geo.material(Color("b5ec67"), 0.1, 0.5)
	orange = Geo.material(Color("ef8b47"))
	dark = Geo.material(Color("152d39"), 0.15)
	build_environment()
	build_course()
	car = Car.new()
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(car)
	car.position = Vector3(0, 0.79, 85)
	car.freeze = true
	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 1800
	add_child(camera)
	camera.position = car.position + Vector3(0, 4.5, 10)
	camera.look_at(car.position + Vector3(0, 0.5, -4))
	build_hud()
	var save := ConfigFile.new()
	if save.load("user://flycar.cfg") == OK:
		best_time = float(save.get_value("race", "best", 0.0))

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("274957")
	sky_material.sky_horizon_color = Color("c7cfc0")
	sky_material.ground_bottom_color = Color("183b45")
	sky_material.ground_horizon_color = Color("c7cfc0")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8d4dd")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("9dbab9")
	env.fog_density = 0.0009
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -38, 0)
	sun.light_color = Color("ffdfb0")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	add_child(sun)
	var water := Geo.material(Color("23515b"), 0.45)
	Geo.box(self, Vector3(2400, 1, 2400), Vector3(100, -14, 0), water)
	var island := Geo.material(Color("52675a"))
	Geo.solid(self, Vector3(195, 6, 185), Vector3(105, -7, 0), island)
	var rng := RandomNumberGenerator.new()
	rng.seed = 145
	for i in 55:
		var angle := rng.randf_range(0, TAU)
		var distance := rng.randf_range(350, 800)
		var height := rng.randf_range(50, 200)
		var cone := CylinderMesh.new()
		cone.top_radius = rng.randf_range(4, 20)
		cone.bottom_radius = rng.randf_range(60, 140)
		cone.height = height
		cone.radial_segments = 5
		Geo.mesh_node(self, cone, Vector3(105 + cos(angle) * distance, height / 2 - 30, sin(angle) * distance), island)
	# Infield launch-test hangars and tower.
	for z in [-50, 5, 60]:
		Geo.box(self, Vector3(33, 13, 27), Vector3(115, 0.5, z), dark)
		Geo.box(self, Vector3(33.2, 0.3, 27.2), Vector3(115, 7.2, z), cyan)
		for x in [104, 115, 126]:
			Geo.box(self, Vector3(7, 6, 0.1), Vector3(x, -1, z + 13.6), Geo.material(Color("6a8387"), 0.3))
	Geo.box(self, Vector3(7, 37, 7), Vector3(65, 11.5, 20), dark)
	Geo.box(self, Vector3(15, 6, 14), Vector3(65, 32, 20), Geo.material(Color("3e7683"), 0.65))
	label_3d("FLIGHT SYSTEMS\nTEST FACILITY  /  01", Vector3(90, 12, 5), 0, 100, 0.035)

func build_course() -> void:
	for i in range(41):
		route.append(Vector3(0, 0, 100 - i * 5))
	for i in range(1, 61):
		var angle := PI + PI * i / 60.0
		route.append(Vector3(105 + 105 * cos(angle), 0, -100 + 105 * sin(angle)))
	for i in range(1, 41):
		route.append(Vector3(210, 0, -100 + i * 5))
	for i in range(1, 61):
		var angle := PI * i / 60.0
		route.append(Vector3(105 + 105 * cos(angle), 0, 100 + 105 * sin(angle)))
	var asphalt := Geo.material(Color("303d44"))
	var shoulder := Geo.material(Color("82928e"))
	for i in route.size():
		var a := route[i]
		var b := route[(i + 1) % route.size()]
		if a.distance_to(b) < 0.01:
			continue
		var center := (a + b) / 2
		var length := a.distance_to(b)
		var basis := Basis.looking_at((b - a).normalized())
		var yaw := basis.get_euler().y
		var gap := center.x > 209 and center.z > -20 and center.z < 5
		if not gap:
			Geo.solid(self, Vector3(19.5, 0.7, length + 0.15), center - Vector3.UP * 0.50, shoulder, yaw)
			Geo.box(self, Vector3(18, 0.03, length + 0.16), center - Vector3.UP * 0.135, asphalt).rotation.y = yaw
			for side in [-1, 1]:
				var edge: Vector3 = center + basis.x * side * 8.65
				Geo.box(self, Vector3(0.15, 0.035, length + 0.1), edge - Vector3.UP * 0.11, cyan).rotation.y = yaw
				Geo.solid(self, Vector3(0.3, 0.8, length + 0.1), center + basis.x * side * 9.4 + Vector3.UP * 0.2, dark, yaw)
			if i % 2 == 0:
				Geo.box(self, Vector3(0.16, 0.035, length * 0.55), center - Vector3.UP * 0.10, shoulder).rotation.y = yaw
			if i % 12 == 0:
				Geo.box(self, Vector3(1.4, 8, 1.4), center - Vector3.UP * 4.85, dark)
		if i % 10 == 0:
			for side in [-1, 1]:
				Geo.box(self, Vector3(0.12, 4.5, 0.12), center + basis.x * side * 10.1 + Vector3.UP * 2, dark)
				Geo.box(self, Vector3(0.25, 0.15, 1.3), center + basis.x * side * 10.1 + Vector3.UP * 4.3, cyan).rotation.y = yaw
	# First obstacle: full-width solid barrier. Early, readable flight lesson.
	Geo.solid(self, Vector3(18, 1.25, 1.6), Vector3(0, 0.48, 16), orange)
	for x in range(-8, 9, 2):
		Geo.box(self, Vector3(0.65, 0.86, 0.025), Vector3(x, 0.5, 16.82), dark).rotation.z = -0.5
	for z in [49, 44, 39]:
		Geo.box(self, Vector3(17, 0.035, 0.28), Vector3(0, -0.10, z), lime)
	sign_over_road("01  /  LIFT-OFF\nSPACE · 短按喷射越过路障", Vector3(0, 6.2, 52), 0)
	sign_over_road("02  /  BROKEN BRIDGE\n前方断桥 25m · 提前喷射", Vector3(210, 6.2, -53), PI)
	for z in [-49, -44, -39]:
		Geo.box(self, Vector3(17, 0.035, 0.28), Vector3(210, -0.10, z), lime)
	for z in [-20.1, 5.1]:
		Geo.box(self, Vector3(18, 0.18, 0.28), Vector3(210, -0.05, z), orange)
	# Optional aerial line cuts the apex of a southern bend between the same gates.
	var shortcut := Geo.solid(self, Vector3(5.0, 0.25, 12), Vector3(196, 0.3, 154), lime, 2.10)
	shortcut.rotation.x = 0.12
	label_3d("AIR LINE ↗\n可选飞跃切弯", Vector3(196, 4, 147), PI, 60, 0.018)
	for t in [0.25, 0.5, 0.75]:
		var p := Vector3(192, 5.5, 157).lerp(Vector3(110, 5.5, 205), t)
		var ring := TorusMesh.new()
		ring.inner_radius = 2.5
		ring.outer_radius = 2.65
		var hoop := Geo.mesh_node(self, ring, p, lime)
		hoop.rotation_degrees = Vector3(90, -60, 0)
	# Eight gates in route order; start/finish must be crossed last.
	for index in [0, 26, 48, 70, 92, 126, 149, 173]:
		var next: int = (index + 1) % route.size()
		gates.append(Transform3D(Basis.looking_at((route[next] - route[index]).normalized()), route[index]))
	for i in gates.size():
		build_gate(i)
	for x in range(-8, 9):
		for z in range(2):
			Geo.box(self, Vector3(1, 0.04, 1), Vector3(x, -0.08, 100 + z), Geo.material(Color("e7eee3") if (x + z) % 2 == 0 else Color("152d39")))

func label_3d(text: String, pos: Vector3, yaw: float, font_size: int = 64, pixel: float = 0.015) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel
	label.position = pos
	label.rotation.y = yaw
	label.modulate = Color("dceeee")
	label.outline_size = 8
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	label.font = font
	add_child(label)
	return label

func sign_over_road(text: String, pos: Vector3, yaw: float) -> void:
	var panel := Geo.box(self, Vector3(16, 2.7, 0.25), pos, dark)
	panel.rotation.y = yaw
	label_3d(text, pos + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.15), yaw, 70, 0.017)

func build_gate(index: int) -> void:
	var pose := gates[index]
	var marker := Node3D.new()
	marker.transform = pose
	add_child(marker)
	for x in [-9.0, 9.0]:
		Geo.box(marker, Vector3(0.25, 5.5, 0.25), Vector3(x, 2.6, 0), dark)
		Geo.box(marker, Vector3(0.15, 4.0, 0.15), Vector3(x, 2.8, 0.2), cyan)
	gate_lights.append(Geo.box(marker, Vector3(18.25, 0.14, 0.3), Vector3(0, 5.4, 0), cyan))
	label_3d("START / FINISH" if index == 0 else "CP  %02d" % index, pose.origin + Vector3.UP * 6.1, pose.basis.get_euler().y, 48, 0.012)
	var area := Area3D.new()
	area.transform = pose
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(19, 65, 1.0)
	collider.shape = shape
	collider.position.y = 30
	area.add_child(collider)
	add_child(area)
	area.body_entered.connect(_gate_entered.bind(index))

func _gate_entered(body: Node3D, index: int) -> void:
	if body != car or countdown > 0.0:
		return
	if race.pass_gate(index, car.linear_velocity.dot(-gates[index].basis.z) > 0.5):
		recovery_pose = gates[index]
		recovery_pose.origin += -recovery_pose.basis.z * 5 + Vector3.UP * 1.0
		if race.finished:
			if best_time <= 0 or race.elapsed < best_time:
				best_time = race.elapsed
				var save := ConfigFile.new()
				save.set_value("race", "best", best_time)
				save.save("user://flycar.cfg")
			banner.text = "LAP COMPLETE\n%s   /   BEST %s\n复位 %d 次 · Enter 再来一圈" % [format_time(race.elapsed), format_time(best_time), race.recoveries]
		else:
			banner.text = "CHECKPOINT %02d" % index
			message_time = 1.4

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	var left := panel(root, Vector2(30, 26), Vector2(340, 108))
	ui_label(left, "F L Y C A R   /   P H Y S I C S   L A B", Vector2(18, 12), 13, Color("b5ec67"))
	ui_label(left, "ROADSTER", Vector2(16, 32), 34)
	ui_label(left, "01 / 海岸试验环线     ·     SINGLE LAP", Vector2(18, 80), 13, Color("9cb6bd"))
	var top := panel(root, Vector2(-350, 26), Vector2(320, 108), true)
	hud_time = ui_label(top, "00:00.000", Vector2(18, 10), 31)
	hud_gate = ui_label(top, "CHECKPOINT  01 / 08", Vector2(20, 58), 14, Color("b5ec67"))
	ui_label(top, "PHYSICAL SUSPENSION / COLD GAS", Vector2(20, 83), 11, Color("9cb6bd"))
	var map_panel := panel(root, Vector2(-210, 153), Vector2(180, 232), true)
	ui_label(map_panel, "CIRCUIT / 1.06 KM", Vector2(15, 10), 11, Color("9cb6bd"))
	map = Map.new()
	map.position = Vector2(8, 21)
	map.size = Vector2(170, 195)
	map.points = route
	map.vehicle = car
	map.gates = gates
	map_panel.add_child(map)
	var bottom := panel(root, Vector2(30, -174), Vector2(360, 144), false, true)
	hud_speed = ui_label(bottom, "000", Vector2(17, 3), 51)
	ui_label(bottom, "KM/H", Vector2(145, 40), 14, Color("9cb6bd"))
	ui_label(bottom, "THRUSTER PRESSURE", Vector2(20, 77), 11, Color("9cb6bd"))
	hud_fuel = ProgressBar.new()
	hud_fuel.position = Vector2(20, 94)
	hud_fuel.size = Vector2(320, 7)
	hud_fuel.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b5ec67")
	hud_fuel.add_theme_stylebox_override("fill", fill)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color("28434b")
	hud_fuel.add_theme_stylebox_override("background", track_style)
	hud_fuel.size = Vector2(320, 7)
	bottom.add_child(hud_fuel)
	hud_status = ui_label(bottom, "", Vector2(20, 125), 11, Color("9cb6bd"))
	var controls := panel(root, Vector2(-450, -118), Vector2(420, 88), true, true)
	ui_label(controls, "W / S  驱动 / 刹车    A / D  转向    Shift  手刹", Vector2(16, 11), 12)
	ui_label(controls, "SPACE  短暂喷射    ↑↓←→  空中姿态", Vector2(16, 35), 12, Color("b5ec67"))
	ui_label(controls, "R  检查点复位    ENTER  重开    ESC  暂停", Vector2(16, 59), 12, Color("9cb6bd"))
	banner = ui_label(root, "", Vector2.ZERO, 36)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -390
	banner.offset_top = -100
	banner.offset_right = 390
	banner.offset_bottom = 60
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_shadow_color", Color("0a1821"))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 2)
	hud_hint = ui_label(root, "", Vector2.ZERO, 15, Color("e0f3ec"))
	hud_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_hint.offset_left = -350
	hud_hint.offset_top = -57
	hud_hint.offset_right = 350
	hud_hint.offset_bottom = -22
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint.add_theme_color_override("font_outline_color", Color("10212c"))
	hud_hint.add_theme_constant_override("outline_size", 5)

func panel(parent: Control, pos: Vector2, dimensions: Vector2, right: bool = false, bottom: bool = false) -> Panel:
	var node := Panel.new()
	parent.add_child(node)
	if right:
		node.anchor_left = 1
		node.anchor_right = 1
	if bottom:
		node.anchor_top = 1
		node.anchor_bottom = 1
	node.offset_left = pos.x
	node.offset_top = pos.y
	node.offset_right = pos.x + dimensions.x
	node.offset_bottom = pos.y + dimensions.y
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.105, 0.88)
	style.border_color = Color(0.4, 0.7, 0.75, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	node.add_theme_stylebox_override("panel", style)
	return node

func ui_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color = Color("edf5ef")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func format_time(seconds: float) -> String:
	var ms := int(seconds * 1000)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

func recover() -> void:
	car.reset_to(recovery_pose)
	if race.finished:
		return
	race.recoveries += 1
	race.elapsed += 3.0
	banner.text = "RECOVERY  +3.0s"
	message_time = 1.4

func restart_race() -> void:
	get_tree().paused = false
	race.restart()
	recovery_pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 85))
	car.reset_to(recovery_pose)
	car.fuel = 1.0
	car.freeze = false
	countdown = 3.0
	message_time = 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		banner.text = "PAUSED\nESC 继续" if get_tree().paused else ""
	if event.is_action_pressed("restart"):
		restart_race()
	if event.is_action_pressed("recover") and not get_tree().paused and countdown <= 0:
		recover()

func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - dt)
		# Let a requested restart pose enter the physics state before freezing.
		if not car.pending_reset:
			car.freeze = true
		banner.text = "%d\n准备起跑 · W 加速 / Space 喷射" % ceili(countdown)
		if countdown <= 0:
			car.freeze = false
			banner.text = "GO"
			message_time = 0.8
	else:
		if not race.finished:
			race.elapsed += dt
		if car.position.y < -8:
			recover()
		if message_time > 0:
			message_time -= dt
			if message_time <= 0 and not race.finished:
				banner.text = ""

func _process(dt: float) -> void:
	if get_tree().paused:
		return
	var forward := -car.global_basis.z
	forward.y = 0
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var desired := car.position - forward * 10.5 + Vector3.UP * 4.1
	camera.position = camera.position.lerp(desired, 1.0 - exp(-dt * 5))
	camera.look_at(car.position + Vector3.UP * 0.6 + forward * 4.5)
	camera.fov = lerpf(camera.fov, 68 + clampf(car.linear_velocity.length() * 0.17, 0, 12), 1 - exp(-dt * 3))
	hud_speed.text = "%03d" % roundi(car.linear_velocity.length() * 3.6)
	hud_time.text = format_time(race.elapsed)
	hud_gate.text = "FINISHED / BEST %s" % format_time(best_time) if race.finished else "CHECKPOINT  %02d / 08" % (8 if race.next_gate == 0 else race.next_gate)
	hud_fuel.value = car.fuel * 100
	hud_status.text = "%s   /   CONTACT %d/4   /   %d%%" % ["JET ACTIVE" if car.burning else ("RECHARGING" if car.contacts >= 3 and car.fuel < 0.99 else "READY" if car.fuel > 0.15 else "LOW PRESSURE"), car.contacts, roundi(car.fuel * 100)]
	map.next_gate = race.next_gate
	map.queue_redraw()
	for i in gate_lights.size():
		gate_lights[i].material_override = lime if i == race.next_gate else cyan
	if countdown > 0:
		hud_hint.text = "W / S 驱动 / 刹车 · A / D 转向 · 喷射越障需把握车速和起飞时机"
	elif car.global_basis.y.dot(Vector3.UP) < 0.2 and car.linear_velocity.length() < 3:
		hud_hint.text = "车辆侧翻 · 按 R 返回检查点（+3秒）"
	elif car.position.x < 12 and car.position.z > 12 and car.position.z < 65:
		hud_hint.text = "前方路障 · 越接近障碍越需要及时起飞 · 短按 Space 约 0.4 秒"
	elif car.position.x > 200 and car.position.z > -75 and car.position.z < 6:
		hud_hint.text = "断桥 25m · 保持车速，提前喷射 · 空中松开 Space 保留余量"
	elif car.contacts == 0:
		hud_hint.text = "AIRBORNE · ↑↓ 调整俯仰 / ←→ 调整侧倾 · 落地后回充"
	else:
		hud_hint.text = "真实悬挂 / 轮胎抓地 / 车身受力    ·    喷射储量 1.2s，落地后回充"
