extends Node3D

const Geo = preload("res://scripts/geometry.gd")
const Car = preload("res://scripts/car.gd")
const Race = preload("res://scripts/race_state.gd")
const Map = preload("res://scripts/minimap.gd")
const Catalog = preload("res://scripts/track_catalog.gd")
const Course = preload("res://scripts/course.gd")
const Menu = preload("res://scripts/track_menu.gd")
const Blast = preload("res://scripts/explosion.gd")
var car: RigidBody3D
var camera: Camera3D
var course: Node3D
var menu: CanvasLayer
var tracks: Array = []
var active_index := -1
var has_started := false
var menu_was_paused := false
var race = Race.new(8)
var route: Array[Vector3] = []
var gates: Array[Transform3D] = []
var countdown := 3.0
var recovery_pose := Transform3D.IDENTITY
var hud_speed: Label
var hud_time: Label
var hud_gate: Label
var hud_status: Label
var hud_fuel: ProgressBar
var hud_hint: Label
var hud_course: Label
var hud_map_title: Label
var banner: Label
var map: Control
var message_time := 0.0
var best_time := 0.0
var best_times: Dictionary = {}
var death_remaining := 0.0
var explosion: Node3D
var record_path := "user://flycar.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Car.configure_inputs()
	if not InputMap.has_action("maps"):
		InputMap.add_action("maps")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_M
		InputMap.action_add_event("maps", key)
	tracks = Catalog.load_tracks()
	build_environment()
	car = Car.new()
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(car)
	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 4000
	add_child(camera)
	build_hud()
	menu = Menu.new()
	add_child(menu)
	menu.build(tracks)
	menu.selected.connect(switch_track)
	menu.cancelled.connect(close_maps)
	var save := ConfigFile.new()
	if save.load(record_path) == OK:
		for data in tracks:
			best_times[data.id] = float(save.get_value("tracks", data.id, 0.0))
	if tracks.is_empty():
		banner.text = "未找到有效地图数据 / tracks/*.json"
		car.freeze = true
		return
	switch_track(0)
	has_started = false
	open_maps()

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("254453")
	sky_material.sky_horizon_color = Color("b4c9c9")
	sky_material.ground_bottom_color = Color("193340")
	sky_material.ground_horizon_color = Color("b4c9c9")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8d4dd")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.00035
	environment.fog_light_color = Color("9dbab9")
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.light_color = Color("ffe1b9")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	add_child(sun)
	Geo.box(self, Vector3(6000, 1, 6000), Vector3(0, -1, 0), Geo.material(Color("254b55"), 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	for i in 40:
		var angle := TAU * i / 40
		var distance := rng.randf_range(1600, 2400)
		var height := rng.randf_range(80, 260)
		var mountain := CylinderMesh.new()
		mountain.bottom_radius = rng.randf_range(110, 240)
		mountain.top_radius = 8
		mountain.height = height
		mountain.radial_segments = 5
		Geo.mesh_node(self, mountain, Vector3(cos(angle) * distance, height / 2 - 12, sin(angle) * distance), Geo.material(Color("4e6e68")))

func switch_track(index: int) -> void:
	if index < 0 or index >= tracks.size():
		return
	get_tree().paused = false
	clear_explosion()
	if is_instance_valid(course):
		remove_child(course)
		course.queue_free()
	course = Course.new()
	add_child(course)
	course.build(tracks[index])
	course.gate_entered.connect(_gate_entered)
	active_index = index
	has_started = true
	route = course.route
	gates = course.gates
	race = Race.new(gates.size())
	best_time = float(best_times.get(tracks[index].id, 0.0))
	recovery_pose = course.spawn
	car.reset_to(recovery_pose)
	car.fuel = 1.0
	car.visible = true
	car.freeze = false
	countdown = 3.0
	message_time = 0
	menu.close()
	map.points = route
	map.gates = gates
	map.route_color = Color(tracks[index].color)
	hud_course.text = tracks[index].name + " · 飞行改编版"
	hud_map_title.text = "CIRCUIT / %.2f KM" % (course.length / 1000)
	var forward := -recovery_pose.basis.z
	camera.position = recovery_pose.origin - forward * 10.5 + Vector3.UP * 4.1
	camera.look_at(recovery_pose.origin + forward * 4)

func open_maps() -> void:
	if menu.is_open:
		return
	menu_was_paused = get_tree().paused
	get_tree().paused = true
	menu.open(has_started)

func close_maps() -> void:
	if not has_started:
		return
	menu.close()
	get_tree().paused = menu_was_paused

func clear_explosion() -> void:
	death_remaining = 0.0
	if is_instance_valid(explosion):
		explosion.queue_free()
	explosion = null

func begin_explosion() -> void:
	if death_remaining > 0 or countdown > 0:
		return
	death_remaining = 1.6
	car.freeze = true
	car.visible = false
	explosion = Blast.new()
	add_child(explosion)
	explosion.global_position = car.global_position
	banner.text = "VEHICLE DESTROYED\n车辆爆炸 · 即将返回检查点"

func _gate_entered(body: Node3D, index: int) -> void:
	if body != car or countdown > 0 or death_remaining > 0:
		return
	if race.pass_gate(index, car.linear_velocity.dot(-gates[index].basis.z) > 0.5):
		recovery_pose = course.pose_at(course.length * index / gates.size() + 7.0)
		recovery_pose.origin += Vector3.UP * 0.9
		if race.finished:
			save_record(race.elapsed)
			show_result()
		else:
			banner.text = "CHECKPOINT %02d" % index
			message_time = 1.4

func save_record(seconds: float) -> void:
	if best_time <= 0 or seconds < best_time:
		best_time = seconds
		best_times[tracks[active_index].id] = seconds
		var save := ConfigFile.new()
		save.load(record_path)
		for id in best_times:
			save.set_value("tracks", id, best_times[id])
		save.save(record_path)

func show_result() -> void:
	banner.text = "LAP COMPLETE\n%s  /  BEST %s\n复位 %d 次 · Enter 重开 / M 换图" % [format_time(race.elapsed), format_time(best_time), race.recoveries]

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
	hud_course = ui_label(left, "", Vector2(18, 80), 13, Color("9cb6bd"))
	var top := panel(root, Vector2(-350, 26), Vector2(320, 108), true)
	hud_time = ui_label(top, "00:00.000", Vector2(18, 10), 31)
	hud_gate = ui_label(top, "CHECKPOINT  01 / 08", Vector2(20, 58), 14, Color("b5ec67"))
	ui_label(top, "PHYSICAL SUSPENSION / COLD GAS", Vector2(20, 83), 11, Color("9cb6bd"))
	var map_panel := panel(root, Vector2(-210, 153), Vector2(180, 232), true)
	hud_map_title = ui_label(map_panel, "", Vector2(15, 10), 11, Color("9cb6bd"))
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
	ui_label(controls, "R 复位   ENTER 重开   M 地图   ESC 暂停", Vector2(16, 59), 12, Color("9cb6bd"))
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
	return "%02d:%02d.%03d" % [int(ms / 60000.0), int(ms / 1000.0) % 60, ms % 1000]

func recover() -> void:
	if death_remaining > 0:
		return
	car.visible = true
	car.freeze = false
	car.reset_to(recovery_pose)
	if race.finished:
		show_result()
		return
	race.recoveries += 1
	race.elapsed += 3
	banner.text = "RECOVERY  +3.0s"
	message_time = 1.4

func restart_race() -> void:
	if active_index < 0:
		return
	clear_explosion()
	get_tree().paused = false
	menu.close()
	race.restart()
	recovery_pose = course.spawn
	car.reset_to(recovery_pose)
	car.fuel = 1.0
	car.visible = true
	car.freeze = false
	countdown = 3.0
	message_time = 0

func _unhandled_input(event: InputEvent) -> void:
	if menu.is_open:
		if event.is_action_pressed("pause") or event.is_action_pressed("maps"):
			close_maps()
		return
	if event.is_action_pressed("maps"):
		open_maps()
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		if get_tree().paused:
			banner.text = "PAUSED\nESC 继续 / M 选择地图"
		elif death_remaining > 0:
			banner.text = "VEHICLE DESTROYED\n车辆爆炸 · 即将返回检查点"
		elif race.finished:
			show_result()
		else:
			banner.text = ""
	if event.is_action_pressed("restart"):
		restart_race()
	if event.is_action_pressed("recover") and not get_tree().paused and countdown <= 0:
		recover()

func _physics_process(dt: float) -> void:
	if get_tree().paused or active_index < 0 or car.pending_reset:
		return
	if death_remaining > 0:
		if not race.finished:
			race.elapsed += dt
		death_remaining = maxf(0, death_remaining - dt)
		if death_remaining <= 0:
			clear_explosion()
			recover()
		return
	if countdown > 0:
		countdown = maxf(0, countdown - dt)
		if not car.pending_reset:
			car.freeze = true
		banner.text = "%d\n%s" % [ceili(countdown), tracks[active_index].name]
		if countdown <= 0:
			car.freeze = false
			banner.text = "GO"
			message_time = 0.8
	else:
		if not race.finished:
			race.elapsed += dt
		if car.position.y < course.road_height_at(car.position) - 8:
			begin_explosion()
		if message_time > 0:
			message_time -= dt
			if message_time <= 0 and not race.finished and death_remaining <= 0:
				banner.text = ""

func _process(dt: float) -> void:
	if get_tree().paused or active_index < 0:
		return
	var forward := -car.global_basis.z
	forward.y = 0
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	if not car.pending_reset and death_remaining <= 0:
		var desired := car.position - forward * 10.5 + Vector3.UP * 4.1
		camera.position = camera.position.lerp(desired, 1 - exp(-dt * 5))
		camera.look_at(car.position + Vector3.UP * 0.6 + forward * 4.5)
		camera.fov = lerpf(camera.fov, 68 + clampf(car.linear_velocity.length() * 0.17, 0, 12), 1 - exp(-dt * 3))
	hud_speed.text = "%03d" % roundi(car.linear_velocity.length() * 3.6)
	hud_time.text = format_time(race.elapsed)
	hud_gate.text = "BEST %s" % format_time(best_time) if race.finished else "CHECKPOINT  %02d / %02d" % [gates.size() if race.next_gate == 0 else race.next_gate, gates.size()]
	hud_fuel.value = car.fuel * 100
	hud_status.text = "%s / CONTACT %d/4 / %d%%" % ["JET ACTIVE" if car.burning else "READY" if car.fuel > 0.15 else "LOW PRESSURE", car.contacts, roundi(car.fuel * 100)]
	map.next_gate = race.next_gate
	map.queue_redraw()
	for i in course.gate_lights.size():
		course.gate_lights[i].material_override = course.selected if i == race.next_gate else course.accent
	if death_remaining > 0:
		hud_hint.text = "车辆已损毁 · 正在返回检查点 · 追加 3 秒罚时"
	elif countdown > 0:
		hud_hint.text = "WASD 驾驶 · Space 短喷 · M 切换地图 · 记得在 Godot 窗口顶部选择“输入”"
	elif car.global_basis.y.dot(Vector3.UP) < 0.2 and car.linear_velocity.length() < 3:
		hud_hint.text = "车辆侧翻 · 按 R 返回检查点（+3秒）"
	elif car.position.distance_to(course.barrier_pose.origin) < 55:
		hud_hint.text = "前方实体路障 · 保持车速，短按 Space 约 0.4–0.5 秒"
	elif car.position.distance_to(course.gap_pose.origin) < 70:
		hud_hint.text = "前方 25m 断桥 · 提前短喷约 0.6–0.7 秒 · 注意落点"
	elif car.contacts == 0:
		hud_hint.text = "AIRBORNE · ↑↓ 俯仰 / ←→ 侧倾 · 掉到赛道下方会爆炸"
	else:
		hud_hint.text = "真实悬挂 / 短时喷射    ·    M 地图菜单    ·    请留意前方绿色起飞提示"
