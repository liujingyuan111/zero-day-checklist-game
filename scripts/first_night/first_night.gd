extends "res://scripts/main.gd"

const PAPER := Color("#f1ead7")
const DIM := Color("#b7c5ba")
const GOLD := Color("#ebbc78")
const MINT := Color("#8bdbcb")
const BG := Color("#18292d")
const TITLES := {&"shelter":"西侧据点", &"booth":"街口值班亭", &"pump":"旧泵房"}
const PLACES := {&"shelter":Vector2(203,414), &"booth":Vector2(557,312), &"pump":Vector2(1012,391)}
const DESCRIPTIONS := {&"blanket":"路上少淋 15 点雨，回屋再降 25 点潮湿。", &"bar":"能打开泵房锁柜，多带两份生火用的燃料。", &"drink":"夜间按 H 吃一罐，饥饿降低 30 点。"}

var run := NightRun.new()
var street: NightStreet
var sites := {}
var shopping: Panel
var report: Panel
var budget_label: Label
var counts := {}
var shop_note: Label
var phase_text: Label
var mission_text: Label
const VITAL_LABELS := ["生命", "饥饿", "潮湿", "SAN"]
const VITAL_COLORS := [Color("#bd786c"), Color("#d8ae71"), Color("#81b9c9"), Color("#a397c1")]
const VITAL_HINTS := ["生命降到 0 时倒下。", "饥饿越低越好。过夜达到 80 时扣生命。", "潮湿越低越好。过夜达到 65 时扣生命。", "SAN 越高越好。过夜降到 25 或更低时扣生命。"]
var vital_values: Array[Label] = []
var vital_bars: Array[ColorRect] = []
var sense_button: Button
var drink_button: Button
var report_text: Label
var night_controls: Control
var effect_player: AudioStreamPlayer
var legacy_button: Button


func _ready() -> void:
	_walls = [Rect2(96,305,180,86),Rect2(503,225,108,66),Rect2(926,285,187,84),
		Rect2(654,320,116,88),Rect2(332,337,56,24),Rect2(767,405,56,24),
		Rect2(1142,279,56,24),Rect2(0,0,1280,104),Rect2(0,633,1280,87)]
	_gate_rect = Rect2(0,0,1,1)
	super._ready()
	player.position = Vector2(274,422)
	player.get_node("Visual").hide()
	_enable_world(false)
	# The logic plane and the orthographic camera share the same ground coordinates.
	var vp := SubViewport.new()
	vp.size = Vector2i(1280,720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	street = NightStreet.new()
	vp.add_child(street)
	var window := TextureRect.new()
	window.texture = vp.get_texture()
	window.size = Vector2(1280,720)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.z_index = -20
	add_child(window)
	effect_player = AudioStreamPlayer.new()
	effect_player.volume_db = -13
	add_child(effect_player)
	_refresh()


func _populate_targets() -> void:
	for key in PLACES:
		var site := FirstNightSite.new()
		site.run = run
		_add_target(key,TITLES[key],PLACES[key],MINT,28,1,site)
		# Door facade and ground marker share a reachable work point outside the building.
		var facade := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(51,63)
		facade.shape = shape
		facade.position = Vector2(0,-31)
		site.add_child(facade)
		site.get_node("Visual").hide()
		site.get_node("Shadow").hide()
		for child in site.get_children():
			if child is Label:
				child.position.y = 11
				child.add_theme_color_override("font_color",PAPER)
				child.add_theme_color_override("font_outline_color",BG)
				child.add_theme_constant_override("outline_size",4)
		sites[key] = site


func _enable_world(enabled: bool) -> void:
	interaction.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	player.set_physics_process(enabled)
	if not enabled:
		player.stop_path()
	for site: FirstNightSite in sites.values():
		site.interaction_enabled = enabled
		site.visible = enabled


func _process(delta: float) -> void:
	if is_instance_valid(street):
		street.sync(player,delta)


func _draw() -> void:
	if run.phase == NightRun.Phase.NIGHT:
		for key in PLACES:
			var at: Vector2 = PLACES[key]
			var tint := MINT if key == &"shelter" or (run.used_sense and key == &"pump") else GOLD
			draw_circle(at,6,tint)
			draw_arc(at,12,0,TAU,28,tint,1.5)
		if is_instance_valid(player):
			var path := player.path_preview()
			if path.size()>1:
				draw_polyline(path,Color(0.82,0.92,0.80,0.45),1.5)


func _style(fill: Color, border := Color("#536961")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	return style


func _panel(parent: Node, rect: Rect2, fill: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",_style(fill))
	parent.add_child(panel)
	return panel


func _label(parent: Node, at: Vector2, extent: Vector2, words: String, size_pt: int, tint: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size_pt)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)
	return label


func _button(parent: Node, rect: Rect2, words: String, callback: Callable, accent := false) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = words
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size",16)
	btn.add_theme_stylebox_override("normal",_style(Color("#395b53") if accent else Color("#283d40")))
	btn.add_theme_stylebox_override("hover",_style(Color("#45625e"),MINT))
	btn.add_theme_stylebox_override("pressed",_style(Color("#576c61"),GOLD))
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var header := _panel(hud,Rect2(0,0,1280,91),BG)
	phase_text = _label(header,Vector2(24,9),Vector2(230,25),"",14,MINT)
	_label(header,Vector2(24,33),Vector2(250,46),"零日清单",31,PAPER)
	mission_text = _label(header,Vector2(232,15),Vector2(588,58),"",19,PAPER)
	for i in VITAL_LABELS.size():
		var x := 818 + 114 * i
		_label(header, Vector2(x, 8), Vector2(54, 25), VITAL_LABELS[i], 15, DIM)
		var value := _label(header, Vector2(x, 31), Vector2(90, 29), "", 22, PAPER)
		vital_values.append(value)
		var track := ColorRect.new()
		track.position = Vector2(x, 66)
		track.size = Vector2(91, 5)
		track.color = Color("#3b4f51")
		header.add_child(track)
		var bar := ColorRect.new()
		bar.color = VITAL_COLORS[i]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(bar)
		vital_bars.append(bar)
		var hint := Control.new()
		hint.position = Vector2(x, 5)
		hint.size = Vector2(101, 73)
		hint.tooltip_text = VITAL_HINTS[i]
		header.add_child(hint)
	var footer := _panel(hud,Rect2(0,633,1280,87),BG)
	status_label = _label(footer,Vector2(23,7),Vector2(870,37),"",17,PAPER)
	hover_label = _label(footer,Vector2(23,49),Vector2(850,30),"",14,DIM)
	night_controls = Control.new()
	night_controls.position = Vector2(890,9)
	night_controls.size = Vector2(372,62)
	night_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(night_controls)
	sense_button = _button(night_controls,Rect2(0,0,188,42),"Q 空间感知",_sense,true)
	drink_button = _button(night_controls,Rect2(201,0,168,42),"H 吃罐装粥",_drink)
	legacy_button = _button(footer,Rect2(1028,22,225,40),"试玩 v0.3 夜班急件",_legacy)
	shopping = _panel(hud,Rect2(316,115,648,495),BG)
	_label(shopping,Vector2(27,17),Vector2(390,30),"灾变预警   /   最后一班补给车",15,MINT)
	_label(shopping,Vector2(27,51),Vector2(360,57),"出发前买什么？",32,PAPER)
	budget_label = _label(shopping,Vector2(466,59),Vector2(170,40),"",20,GOLD)
	_label(shopping,Vector2(28,111),Vector2(602,34),"今晚只有一次外出机会。运输券不能留到灾后使用。",16,DIM)
	var y := 157
	for item in NightRun.PRICES:
		_label(shopping,Vector2(28,y),Vector2(370,30),"%s     %d 券" % [NightRun.NAMES[item],NightRun.PRICES[item]],20,PAPER)
		_label(shopping,Vector2(29,y+32),Vector2(438,28),DESCRIPTIONS[item],14,DIM)
		_button(shopping,Rect2(467,y+5,40,40),"−",_refund.bind(item))
		counts[item] = _label(shopping,Vector2(525,y+7),Vector2(43,36),"0",18,PAPER)
		_button(shopping,Rect2(573,y+5,45,40),"＋",_buy.bind(item))
		y += 75
	shop_note = _label(shopping,Vector2(28,389),Vector2(595,31),"饥饿、潮湿越低越好。生命、SAN 越高越好。",15,GOLD)
	_button(shopping,Rect2(28,431,590,43),"确认物资，进入第一夜",_begin,true)
	report = _panel(hud,Rect2(310,127,660,465),BG)
	_label(report,Vector2(28,22),Vector2(500,24),"第一夜   /   值守记录",15,MINT)
	report_text = _label(report,Vector2(29,60),Vector2(610,315),"",17,PAPER)
	report_text.add_theme_constant_override("line_spacing",5)
	_button(report,Rect2(29,388,603,48),"再来一夜，重新采购",_reset_scene,true)
	report.hide()


func _buy(item: StringName) -> void:
	shop_note.text = run.buy(item)
	_refresh()


func _refund(item: StringName) -> void:
	run.refund(item)
	shop_note.text = "饥饿、潮湿越低越好。生命、SAN 越高越好。"
	_refresh()


func _begin() -> void:
	if run.phase != NightRun.Phase.SHOP:
		return
	run.begin_night()
	street.night()
	_enable_world(true)
	status_label.text = "雨还在下。街亭有遮挡，去泵房得穿过积水，也可以直接回屋。"
	_ping(preload("res://art/first_night/switch.wav"))
	_refresh()


func _sense() -> void:
	if not run.sense():
		return
	street.reveal()
	FieldEffect.spawn(self,player.position,165,0.7,MINT)
	FieldEffect.spawn(self,PLACES[&"pump"],35,1.6,MINT,true)
	status_label.text = "感知回声：街亭有 1 份燃料。泵房有 3 份，其中 2 份锁在柜内。"
	_ping(preload("res://art/first_night/echo.mp3"))
	_refresh()


func _drink() -> void:
	if run.drink():
		status_label.text = run.ledger[-1]
		_ping(preload("res://art/first_night/switch.wav"))
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(shopping):
		return
	shopping.visible = run.phase == NightRun.Phase.SHOP
	night_controls.visible = run.phase == NightRun.Phase.NIGHT
	legacy_button.visible = run.phase == NightRun.Phase.SHOP
	report.visible = run.phase == NightRun.Phase.REPORT
	budget_label.text = "余额   %d / %d 券" % [run.money,NightRun.BUDGET]
	for key in counts:
		counts[key].text = str(run.purchases[key])
	var values: Array[int] = [run.health, run.hunger, run.wetness, run.sanity]
	for i in values.size():
		vital_values[i].text = str(values[i])
		vital_bars[i].size = Vector2(91.0 * values[i] / 100.0, 5)
	match run.phase:
		NightRun.Phase.SHOP:
			phase_text.text = "D − 7    /    灾变预警"
			mission_text.text = "广播预警。你带着伤，赶上了最后一班补给车。"
			status_label.text = "守夜时饥饿 ≥80、潮湿 ≥65、SAN ≤25，每项扣 20 生命。"
		NightRun.Phase.NIGHT:
			phase_text.text = "D 0    /    雨夜停电"
			if run.route.is_empty():
				mission_text.text = "搜刮一处：街亭近，泵房远。也可留守。" if not run.used_sense else "回声已显：街亭 1 燃料，泵房 1 ＋ 锁柜 2。"
			else:
				mission_text.text = "回西侧据点过夜。燃料 ×%d，可烘去 %d 点潮湿。" % [run.fuel,run.fuel*20]
			sense_button.disabled = run.used_sense or not run.route.is_empty()
			sense_button.text = "感知已使用" if run.used_sense else "Q 感知  ·  SAN −20"
			drink_button.disabled = run.drinks_left <= 0
			drink_button.text = "H 吃粥  ·  余 %d" % run.drinks_left
		NightRun.Phase.REPORT:
			phase_text.text = "D + 1    /    天亮"
			mission_text.text = "首夜结束"
			var outcome := "撑到了天亮" if run.health > 0 else "没能撑过第一夜"
			report_text.text = "%s　｜　剩余生命 %d\n%s　·　%s\n采购　%s\n\n%s" % [outcome, run.health, NightRun.ROUTES[run.route], "感知 1 次" if run.used_sense else "跳过感知", run.manifest(), "\n".join(run.ledger)]
	queue_redraw()


func _on_commit(_token: int, action_id: StringName, _result: Dictionary) -> void:
	_ping(preload("res://art/first_night/switch.wav"))
	if action_id == &"end_night":
		_enable_world(false)
	_refresh()


func _on_hover_changed(message: String) -> void:
	hover_label.text = message if not message.is_empty() else "WASD 移动    左键交互    右键取消"


func _update_inventory() -> void:
	pass # Supplies for the first-night comparison belong to the run manifest.


func _ping(stream: AudioStream) -> void:
	if is_instance_valid(effect_player) and DisplayServer.get_name() != "headless":
		effect_player.stream = stream
		effect_player.play()


func _legacy() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/supply_run.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Q: _sense()
		KEY_H: _drink()
		KEY_R: _reset_scene()
		_: return
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if run.phase == NightRun.Phase.NIGHT:
		queue_redraw()
