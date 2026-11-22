extends Node2D
## Interaction lab. The rectangles and geometric actors are test assets only.

@export var player_frames: SpriteFrames
@export_enum("Four directions:4", "Eight directions:8") var player_direction_count: int = 8
@export var player_foot_anchor: Vector2 = Vector2(32, 60)

var navigation_grid: NavigationGrid
var player: PlayerController
var entities: Node2D
var interaction: InteractionController
var hover_label: Label
var status_label: Label
var inventory_label: Label
var state_label: Label
var progress_bar: ProgressBar
var history_label: Label
var gate_button: Button
var debug_enabled: bool = true
var _history: PackedStringArray = []
var _gate_closed: bool = true
var _gate_shape: CollisionShape2D
var _gate_rect := Rect2(1060, 510, 14, 158)
var _walls: Array[Rect2] = [Rect2(590, 274, 118, 172), Rect2(1060, 510, 180, 14), Rect2(1226, 510, 14, 158), Rect2(1060, 654, 180, 14)]


func _ready() -> void:
	_setup_input_map()
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	navigation_grid = NavigationGrid.new()
	navigation_grid.name = "NavigationGrid"
	add_child(navigation_grid)
	navigation_grid.configure(Vector2i(40, 23), Vector2(32, 32), Vector2.ZERO)
	for rect in _walls:
		_add_wall(rect)
	for boundary in [Rect2(-32, -32, 1344, 32), Rect2(-32, 720, 1344, 32), Rect2(-32, 0, 32, 720), Rect2(1280, 0, 32, 720)]:
		_add_wall(boundary)
	_gate_shape = _add_wall(_gate_rect)
	_build_player()
	_populate_targets()
	var picker := WorldPicker.new()
	picker.name = "WorldPicker"
	add_child(picker)
	interaction = InteractionController.new()
	interaction.name = "InteractionController"
	interaction.setup(player, picker)
	add_child(interaction)
	_build_hud()
	interaction.hover_changed.connect(_on_hover_changed)
	interaction.status_changed.connect(_on_status_changed)
	player.action_queue.status_changed.connect(_on_status_changed)
	player.action_queue.action_committed.connect(_on_commit)
	player.navigation_failed.connect(_on_status_changed)
	player.inventory_changed.connect(_update_inventory)
	player.equipment_changed.connect(func(_item: StringName) -> void: _update_inventory())
	_update_inventory()
	queue_redraw()


func _populate_targets() -> void:
	_add_target(&"chest", "补给箱", Vector2(430, 225), Color("b17b45"), 24, 3)
	_add_target(&"tree", "枯树", Vector2(790, 220), Color("66805d"), 28, 3)
	_add_target(&"pickup", "废金属", Vector2(860, 485), Color("7dabb0"), 15, 1)
	_add_target(&"zombie", "感染者", Vector2(1040, 350), Color("9c6d72"), 23, 3)
	_add_target(&"chest", "封闭区补给箱", Vector2(1150, 590), Color("b17b45"), 22, 3)


func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(state_label):
		state_label.text = "动作状态  " + player.action_queue.debug_state()
		progress_bar.value = player.animation_driver.get_progress() * 100.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 736), Color("1d292e"))
	for x in range(0, 1281, 32):
		draw_line(Vector2(x, 0), Vector2(x, 736), Color("24343b"), 1.0)
	for y in range(0, 737, 32):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("24343b"), 1.0)
	for rect in _walls:
		_draw_wall(rect)
	if _gate_closed:
		_draw_wall(_gate_rect)
	else:
		draw_rect(_gate_rect, Color(0.3, 0.8, 0.65, 0.12))
	if debug_enabled and is_instance_valid(player):
		var points := player.path_preview()
		if points.size() >= 2:
			draw_polyline(points, Color(0.4, 0.85, 0.75, 0.65), 2.0)
			for point in points:
				draw_circle(point, 3.0, Color("80dac7"))
		var intent := player.action_queue.current_intent
		if intent != null and is_instance_valid(intent.target):
			draw_arc(intent.target.global_position, float(intent.action_data.get("range", 52)), 0, TAU, 48, Color(0.9, 0.75, 0.35, 0.6), 1.5)


func _draw_wall(rect: Rect2) -> void:
	draw_rect(rect, Color("45565e"))
	draw_rect(rect.grow(-3), Color("33444d"))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("809295"), 3.0)


func _build_player() -> void:
	player = PlayerController.new()
	player.name = "Player"
	player.navigation_grid = navigation_grid
	player.position = Vector2(220, 360)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	player.add_child(collision)
	var visual := ActorVisualAdapter.new()
	visual.name = "Visual"
	visual.sprite_frames = player_frames
	visual.direction_count = player_direction_count
	visual.foot_anchor = player_foot_anchor
	player.add_child(visual)
	entities.add_child(player)


func _add_target(kind: StringName, label: String, world_position: Vector2, color: Color, radius: float, hp: int, custom_target: Interactable = null) -> Interactable:
	var target := custom_target if custom_target != null else Interactable.new()
	target.name = String(kind).capitalize()
	target.configure(kind, label, world_position, color, radius)
	target.object_hp = hp
	if kind == &"pickup":
		target.loot_item_id = &"scrap"
		target.loot_quantity = 2
	entities.add_child(target)
	var caption := Label.new()
	caption.text = label
	caption.position = Vector2(-70, radius + 10)
	caption.size = Vector2(140, 24)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("a9bac0"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(caption)
	return target


func _add_wall(rect: Rect2) -> CollisionShape2D:
	navigation_grid.set_solid_rect_world(rect, true)
	var wall := StaticBody2D.new()
	wall.position = rect.get_center()
	wall.collision_layer = 1
	wall.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	wall.add_child(collision)
	entities.add_child(wall)
	return collision


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(494, 170)
	panel.custom_minimum_size = Vector2(494, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111e26")
	style.border_color = Color("3b6669")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var title := Label.new()
	title.text = "ZERO DAY / INTERACTION LAB  0.2"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("7ed8c2"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "交互验证场 · F1 返回补给任务"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("9cafb8"))
	column.add_child(subtitle)
	hover_label = Label.new()
	hover_label.text = "指向一个目标，查看可用动作。"
	hover_label.add_theme_font_size_override("font_size", 15)
	column.add_child(hover_label)
	status_label = Label.new()
	status_label.text = "准备就绪。点击目标会自动接近。"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(460, 28)
	status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(status_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 13)
	column.add_child(state_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 5)
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_bar)

	var tools_panel := VBoxContainer.new()
	tools_panel.position = Vector2(20, 465)
	tools_panel.size = Vector2(400, 180)
	layer.add_child(tools_panel)
	var instructions := Label.new()
	instructions.text = "WASD 移动 / 左键交互 / 右键取消\n1 斧头 · 2 空手 · R 重置\nF2 路径显示 · F3 移动目标 · F4 删除目标"
	instructions.add_theme_font_size_override("font_size", 15)
	instructions.add_theme_color_override("font_color", Color("a9bac0"))
	instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools_panel.add_child(instructions)
	var repeat_toggle := CheckButton.new()
	repeat_toggle.text = "连续砍伐 / 攻击"
	repeat_toggle.button_pressed = true
	repeat_toggle.focus_mode = Control.FOCUS_NONE
	repeat_toggle.toggled.connect(func(enabled: bool) -> void: player.action_queue.repeat_enabled = enabled)
	tools_panel.add_child(repeat_toggle)
	gate_button = Button.new()
	gate_button.text = "F6  打开右下测试区入口"
	gate_button.focus_mode = Control.FOCUS_NONE
	gate_button.pressed.connect(_toggle_gate)
	tools_panel.add_child(gate_button)
	var reset := Button.new()
	reset.text = "R  重置测试场"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset_scene)
	tools_panel.add_child(reset)

	inventory_label = Label.new()
	inventory_label.position = Vector2(20, 682)
	inventory_label.size = Vector2(1240, 28)
	inventory_label.add_theme_font_size_override("font_size", 14)
	inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(inventory_label)
	history_label = Label.new()
	history_label.position = Vector2(850, 20)
	history_label.size = Vector2(410, 140)
	history_label.add_theme_font_size_override("font_size", 14)
	history_label.add_theme_color_override("font_color", Color("99b9b7"))
	history_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(history_label)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F1:
			get_tree().change_scene_to_file.call_deferred("res://scenes/supply_run.tscn")
		KEY_R:
			_reset_scene()
		KEY_F2:
			debug_enabled = not debug_enabled
		KEY_F3:
			_move_test_target()
		KEY_F4:
			var target := _test_target()
			if is_instance_valid(target):
				target.queue_free()
				_on_status_changed("测试：目标已删除，待执行动作应停止。")
		KEY_F6:
			_toggle_gate()
		_:
			return
	get_viewport().set_input_as_handled()


func _test_target() -> Interactable:
	if player.action_queue.current_intent != null and is_instance_valid(player.action_queue.current_intent.target):
		return player.action_queue.current_intent.target
	return interaction.hovered_target if is_instance_valid(interaction.hovered_target) else null


func _move_test_target() -> void:
	var target := _test_target()
	if not is_instance_valid(target):
		_on_status_changed("先点击或指向一个目标，再按 F3。")
		return
	for offset in [Vector2(96, -64), Vector2(-96, 64), Vector2(0, 96)]:
		var candidate: Vector2 = target.position + offset
		if navigation_grid.is_walkable_world(candidate):
			target.position = candidate
			_on_status_changed("测试：目标已移动，接近路线应更新。")
			return


func _set_gate_closed(closed: bool) -> void:
	_gate_closed = closed
	_gate_shape.set_deferred("disabled", not _gate_closed)
	navigation_grid.set_solid_rect_world(_gate_rect, _gate_closed)
	queue_redraw()


func _toggle_gate() -> void:
	_set_gate_closed(not _gate_closed)
	gate_button.text = "F6  打开右下测试区入口" if _gate_closed else "F6  关闭右下测试区入口"
	_on_status_changed("测试入口已关闭。" if _gate_closed else "测试入口已打开，可以接近右下补给箱。")
	queue_redraw()


func _reset_scene() -> void:
	player.action_queue.cancel_action("重置")
	get_tree().reload_current_scene.call_deferred()


func _on_hover_changed(message: String) -> void:
	hover_label.text = message if not message.is_empty() else "指向一个目标，查看可用动作。"


func _on_status_changed(message: String) -> void:
	status_label.text = message


func _on_commit(token: int, action_id: StringName, result: Dictionary) -> void:
	_history.append("#%d %s  %s" % [token, String(action_id), String(result.get("message", ""))])
	while _history.size() > 5:
		_history.remove_at(0)
	history_label.text = "实际结算记录\n" + "\n".join(_history)
	_update_inventory()


func _update_inventory() -> void:
	inventory_label.text = "装备：%s   |   %s" % ["斧头" if player.equipped_item_id == &"axe" else "空手", player.inventory_summary()]


func _setup_input_map() -> void:
	for pair in [["move_left", KEY_A], ["move_left", KEY_LEFT], ["move_right", KEY_D], ["move_right", KEY_RIGHT], ["move_up", KEY_W], ["move_up", KEY_UP], ["move_down", KEY_S], ["move_down", KEY_DOWN]]:
		var action: StringName = StringName(pair[0])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(pair[1])
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
