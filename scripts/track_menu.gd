extends CanvasLayer
signal selected(index: int)
signal cancelled
const Preview = preload("res://scripts/minimap.gd")
const Catalog = preload("res://scripts/track_catalog.gd")
var is_open := false
var root_control: Control
var cancel_button: Button

func build(tracks: Array) -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root_control.theme = theme
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.06, 0.97)
	root_control.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root_control.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	text_label(stack, "FLYCAR   /   CHINA SERIES", 15, Color("b5ec67"))
	text_label(stack, "选择你的下一条赛道", 38)
	text_label(stack, "参考真实布局 · 高架飞行改编版    /    三条路线，三种节奏", 16, Color("9cb6bd"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1180, 440)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	scroll.add_child(cards)
	for i in tracks.size():
		var data: Dictionary = tracks[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(370, 400)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("122633")
		style.border_color = Color(data.color)
		style.border_width_top = 3
		style.set_corner_radius_all(10)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", style)
		cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		text_label(content, "CHINA  /  %02d" % (i + 1), 12, Color(data.color))
		text_label(content, data.name, 24)
		text_label(content, data.subtitle, 14, Color("b0c2c7"))
		var preview := Preview.new()
		preview.custom_minimum_size = Vector2(330, 200)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.points = Catalog.sample(data)
		preview.route_color = Color(data.color)
		content.add_child(preview)
		text_label(content, "飞行改编 %.2f km  /  原赛道 %.3f km" % [Catalog.length_of(preview.points) / 1000, data.reference_km], 12, Color("93aeb8"))
		var button := Button.new()
		button.text = "进入赛道  →"
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 18)
		content.add_child(button)
		button.pressed.connect(func(): selected.emit(i))
	text_label(stack, "WASD 驾驶   /   SPACE 短喷越障   /   M 切换地图   /   落海沉没 · 落地碎裂", 14, Color("9cb6bd"))
	cancel_button = Button.new()
	cancel_button.text = "返回比赛  [Esc]"
	cancel_button.custom_minimum_size.y = 38
	stack.add_child(cancel_button)
	cancel_button.pressed.connect(func(): cancelled.emit())
	root_control.visible = false

func text_label(parent: Node, text: String, size: int, color: Color = Color("e6f1eb")) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func open(allow_cancel: bool) -> void:
	is_open = true
	root_control.visible = true
	cancel_button.visible = allow_cancel

func close() -> void:
	is_open = false
	root_control.visible = false
