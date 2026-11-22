extends "res://scripts/main.gd"

const TEAL := Color("#86d8bd")
const AMBER := Color("#eab879")
const PAPER := Color("#e6e5d8")
const MUTED := Color("#acbdb7")
const ITEM_NAMES := {&"water":"水", &"bandage":"绷带", &"canned_food":"罐头", &"wood":"木材", &"scrap":"废金属", &"core_shard":"核心碎片", &"medical_kit":"急救包"}

var field_search: FieldSearch
var wreck: SupplyFixture
var bridge: SupplyFixture
var depot: SupplyFixture
var infirmary: SupplyFixture
var salvage: Interactable
var goal_title: Label
var goal_detail: Label
var chapter: Label
var search_label: Label
var _last_second := -1


func _ready() -> void:
	_walls.append(Rect2(0, 0, 1280, 118))
	_walls.append(Rect2(0, 650, 1280, 70))
	_walls.append(Rect2(1060, 510, 14, 42))
	_walls.append(Rect2(1060, 622, 14, 46))
	_gate_rect = Rect2(1060, 552, 14, 70)
	_walls.append(Rect2(76, 208, 142, 88))
	_walls.append(Rect2(441, 377, 80, 32))
	super._ready()
	_on_status_changed("值班室缺药。点击废车去找金属，再去北侧砍树。")
	_refresh_goal()


func _populate_targets() -> void:
	infirmary = SupplyFixture.new()
	_add_target(&"infirmary", "值班室交接台", Vector2(161, 316), Color("#568e7a"), 23, 1, infirmary)
	_symbol(infirmary, "＋")
	_add_target(&"chest", "街边补给箱", Vector2(341, 225), Color("#a47c56"), 22, 3)
	var tree := _add_target(&"tree", "枯树", Vector2(786, 257), Color("#8e8465"), 27, 3)
	var infected := _add_target(&"zombie", "感染者", Vector2(929, 332), Color("#a27075"), 23, 3)
	var trunk: Polygon2D = tree.get_node("Visual")
	trunk.polygon = PackedVector2Array([Vector2(-9,17),Vector2(-4,2),Vector2(-5,-7),Vector2(-21,-16),Vector2(-24,-29),Vector2(-19,-22),Vector2(-17,-19),Vector2(-5,-14),Vector2(-8,-31),Vector2(-4,-42),Vector2(0,-31),Vector2(2,-16),Vector2(12,-23),Vector2(18,-35),Vector2(17,-20),Vector2(4,-7),Vector2(4,5),Vector2(12,17)])
	_detail(infected, Rect2(-9,-20,18,12), Color("#847870"))
	_detail(infected, Rect2(1,-15,5,2), Color("#dab79a"))
	_detail(infected, Rect2(-15,-1,11,5), Color("#b28980"))
	_detail(infected, Rect2(3,1,14,5), Color("#b28980"))
	salvage = _add_target(&"pickup", "废金属", Vector2(500, 429), Color("#bcad79"), 16, 1)
	bridge = SupplyFixture.new()
	_add_target(&"bridge", "栈桥维修点", Vector2(996, 584), Color("#af844f"), 22, 1, bridge)
	_symbol(bridge, "≡")
	bridge.state_changed.connect(_bridge_changed)
	depot = SupplyFixture.new()
	depot.bridge = bridge
	_add_target(&"medical_cache", "急救物资箱", Vector2(1154, 594), Color("#a47763"), 22, 1, depot)
	_symbol(depot, "＋")
	field_search = FieldSearch.new()
	field_search.actor = player
	field_search.targets = entities
	add_child(field_search)
	wreck = SupplyFixture.new()
	wreck.field_search = field_search
	wreck.interaction_range = 34.0
	# The clickable car body and the clear working position at its rear differ.
	wreck.configure(&"wreck", "废车", Vector2(480, 434), AMBER, 1.0)
	wreck.get_node("Visual").hide()
	wreck.get_node("Shadow").hide()
	var car_shape := RectangleShape2D.new()
	car_shape.size = Vector2(82, 36)
	var car_collider: CollisionShape2D = wreck.get_node("CollisionShape2D")
	car_collider.shape = car_shape
	car_collider.position = Vector2(1, -41)
	entities.add_child(wreck)
	field_search.conceal(salvage)
	field_search.scanned.connect(_on_scan)


func _detail(target: Interactable, rect: Rect2, tint: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	polygon.color = tint
	polygon.use_parent_material = true
	target.get_node("Visual").add_child(polygon)


func _symbol(target: Node2D, mark: String) -> void:
	var icon := Label.new()
	icon.text = mark
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.position = Vector2(-22, -22)
	icon.size = Vector2(44, 44)
	icon.add_theme_font_size_override("font_size", 26)
	icon.add_theme_color_override("font_color", Color("#fff0d4"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(icon)


func _bridge_changed() -> void:
	_set_gate_closed(false)
	$FieldMap.crossing_open = true
	$FieldMap.queue_redraw()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	_strip(hud, Rect2(0, 0, 1280, 117))
	_strip(hud, Rect2(0, 650, 1280, 70))
	_label(hud, Vector2(26, 10), Vector2(230, 20), "零 日 清 单     /     外 勤 记 录", 14, TEAL)
	_label(hud, Vector2(24, 34), Vector2(270, 54), "夜班急件", 34, PAPER)
	chapter = _label(hud, Vector2(28, 88), Vector2(270, 22), "", 13, MUTED)
	_strip(hud, Rect2(303, 20, 2, 78), Color("#526661"))
	goal_title = _label(hud, Vector2(326, 18), Vector2(572, 46), "", 24, AMBER)
	goal_detail = _label(hud, Vector2(326, 66), Vector2(580, 40), "", 16, PAPER)
	search_label = _label(hud, Vector2(938, 22), Vector2(323, 36), "", 19, TEAL)
	_label(hud, Vector2(938, 68), Vector2(324, 25), "WASD 移动    左键交互    右键取消", 14, MUTED)
	status_label = _label(hud, Vector2(24, 654), Vector2(700, 30), "", 17, PAPER)
	inventory_label = _label(hud, Vector2(24, 685), Vector2(740, 27), "", 14, MUTED)
	hover_label = _label(hud, Vector2(766, 655), Vector2(495, 30), "", 16, AMBER)
	_label(hud, Vector2(766, 688), Vector2(506, 25), "1 斧头    2 空手    R 重开    F1 测试场  F8 首夜", 14, MUTED)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(0, 646)
	progress_bar.size = Vector2(1280, 4)
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	progress_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(progress_bar)


func _strip(parent: Node, rect: Rect2, color := Color("#172529")) -> void:
	var strip := ColorRect.new()
	strip.position = rect.position
	strip.size = rect.size
	strip.color = color
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(strip)


func _label(parent: Node, at: Vector2, extent: Vector2, words: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.text = words
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	var remaining := field_search.seconds_left()
	if remaining != _last_second:
		_last_second = remaining
		search_label.text = "Q   现场搜寻    ·    就绪" if remaining == 0 else "Q   现场搜寻    ·    %d 秒" % remaining
	progress_bar.value = player.animation_driver.get_progress() * 100.0


func _draw() -> void:
	pass # The mission map is a separately replaceable display layer.


func _on_hover_changed(message: String) -> void:
	hover_label.text = message if not message.is_empty() else "指向目标可查看交互"


func _on_scan(origin: Vector2, marks: Array[Vector2], discoveries: int) -> void:
	FieldEffect.spawn(entities, origin, FieldSearch.RADIUS, 0.65, TEAL)
	for mark in marks:
		FieldEffect.spawn(entities, mark, 29.0, 1.6, AMBER, true)
	if discoveries > 0:
		wreck.is_open = true
		_on_status_changed("车后发现了废金属。点击拾取。")
	elif marks.size() > 0:
		_on_status_changed("已标记附近 %d 处交互点。" % marks.size())
	else:
		_on_status_changed("这里没有发现。靠近目标区域后再次搜寻。")
	_refresh_goal()


func _on_commit(_token: int, action_id: StringName, result: Dictionary) -> void:
	if action_id != &"inspect":
		FieldEffect.spawn(entities, result["world_position"], 31, 0.36, AMBER if action_id in [&"chop", &"attack"] else TEAL)
	_refresh_goal()


func _update_inventory() -> void:
	var items := PackedStringArray()
	for key in ITEM_NAMES:
		var amount := int(player.inventory.get(key, 0))
		if amount > 0:
			items.append("%s ×%d" % [ITEM_NAMES[key], amount])
	inventory_label.text = "%s    /    %s" % ["斧头" if player.equipped_item_id == &"axe" else "空手", "   ".join(items)]
	_refresh_goal()


func _refresh_goal() -> void:
	if not is_instance_valid(goal_title):
		return
	var stage := 1
	if infirmary.is_open:
		stage = 4
		goal_title.text = "值班员已签收"
		goal_detail.text = "急救包已送达。药品清点完毕，本次出勤完成。"
	elif depot.is_open:
		stage = 3
		goal_title.text = "把急救包送回值班室"
		goal_detail.text = "原路向西，点击值班室门前的绿色交接台。"
	elif bridge.is_open:
		stage = 2
		goal_title.text = "进东岸应急仓取药"
		goal_detail.text = "栈桥已通。点击桥对面的急救物资箱。"
	else:
		var wood := int(player.inventory.get(&"wood", 0))
		var scrap := int(player.inventory.get(&"scrap", 0))
		var hint := "点击废车，或在车后按 Q。"
		if scrap >= 2 and wood < 3:
			hint = "装备斧头，点击北侧枯树。"
		elif wood >= 3 and scrap >= 2:
			hint = "点击东南角的栈桥维修点。"
		elif is_instance_valid(salvage) and salvage.visible:
			hint = "点击车后的废金属。"
		goal_title.text = "备料，修通东岸栈桥"
		goal_detail.text = "木材 %d/3    废金属 %d/2    ·    %s" % [mini(wood,3), mini(scrap,2), hint]
	chapter.text = "补给行动    /    " + ("已签收" if stage == 4 else "第 %d / 3 段" % stage)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Q:
			if not field_search.use():
				_on_status_changed("搜寻冷却中，还需 %d 秒。" % field_search.seconds_left())
		KEY_R:
			_reset_scene()
		KEY_F8:
			get_tree().change_scene_to_file.call_deferred("res://scenes/first_night.tscn")
		KEY_F1:
			get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		_:
			return
	get_viewport().set_input_as_handled()
