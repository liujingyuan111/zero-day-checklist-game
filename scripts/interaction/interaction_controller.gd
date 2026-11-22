class_name InteractionController
extends Node

signal hover_changed(message: String)
signal status_changed(message: String)

var actor: PlayerController
var world_picker: WorldPicker
var hovered_target: Interactable
var _last_hover_message: String = ""
var _hover_refresh: float = 0.0


func setup(p_actor: PlayerController, p_world_picker: WorldPicker) -> void:
	actor = p_actor
	world_picker = p_world_picker


func _physics_process(delta: float) -> void:
	_hover_refresh += delta
	if _hover_refresh >= 0.08:
		_hover_refresh = 0.0
		_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(world_picker):
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_primary_click()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			actor.action_queue.cancel_action("右键取消")
			actor.stop_path()
			status_changed.emit("已取消当前动作和移动。")
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				actor.equip_item(&"axe")
				status_changed.emit("已装备斧头。")
				_update_hover()
				get_viewport().set_input_as_handled()
			KEY_2:
				actor.equip_item(&"")
				status_changed.emit("已切换空手；砍伐需要斧头。")
				_update_hover()
				get_viewport().set_input_as_handled()


func _handle_primary_click() -> void:
	var mouse_position := actor.get_global_mouse_position()
	var target := world_picker.pick_target(mouse_position)
	if is_instance_valid(target):
		var action := ActionResolver.resolve(actor, target)
		if action.is_empty():
			status_changed.emit("这个目标当前没有可用动作。")
			return
		actor.action_queue.request_action(target, action)
		return
	actor.action_queue.cancel_action("移动指令")
	if actor.move_to_position(mouse_position):
		status_changed.emit("正在前往点击位置。")
	else:
		status_changed.emit("位置不可达或距离墙体太近。")


func _update_hover() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(world_picker):
		return
	var next_target: Interactable = null
	var ui := get_viewport().gui_get_hovered_control()
	if ui == null or ui.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		next_target = world_picker.pick_target(actor.get_global_mouse_position())
	if next_target != hovered_target:
		if is_instance_valid(hovered_target):
			hovered_target.set_hovered(false)
		hovered_target = next_target
	var message := ""
	if is_instance_valid(hovered_target) and not hovered_target.is_queued_for_deletion():
		hovered_target.set_hovered(true)
		var action := ActionResolver.resolve(actor, hovered_target)
		var label := String(action.get("label", "暂无动作"))
		message = "%s  ·  %s" % [hovered_target.object_label, label]
		if hovered_target.object_kind == &"tree" and actor.equipped_item_id != &"axe":
			message += "（按 1 装备斧头）"
		if hovered_target.object_kind in [&"tree", &"zombie"]:
			message += "  ·  耐久 %d" % hovered_target.object_hp
	if message != _last_hover_message:
		_last_hover_message = message
		hover_changed.emit(message)
