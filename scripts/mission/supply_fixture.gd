class_name SupplyFixture
extends Interactable

const BRIDGE_COST := {&"wood": 3, &"scrap": 2}
const DELIVERY_COST := {&"medical_kit": 1}

var bridge: SupplyFixture
var field_search: FieldSearch


func get_available_actions(actor: PlayerController, _held_item_id: StringName) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not interaction_enabled or is_consumed or is_queued_for_deletion():
		return actions
	var id := &"inspect"
	var label := "查看"
	if not is_open:
		match object_kind:
			&"wreck":
				id = &"survey_site"
				label = "接近并搜寻"
			&"bridge":
				label = "查看修桥材料"
				if actor.has_items(BRIDGE_COST):
					id = &"repair_bridge"
					label = "修复栈桥"
			&"medical_cache":
				label = "查看进仓路线"
				if is_instance_valid(bridge) and bridge.is_open:
					id = &"take_kit"
					label = "领取急救包"
			&"infirmary":
				label = "查看交接单"
				if actor.has_items(DELIVERY_COST):
					id = &"deliver_kit"
					label = "交付急救包"
	actions.append(_action(id, label, 85, interaction_range, 1.1 if id == &"repair_bridge" else 0.48))
	return actions


func execute_action(action_id: StringName, actor: PlayerController) -> Dictionary:
	if not is_instance_valid(actor) or not interaction_enabled or is_queued_for_deletion():
		return {"success": false, "message": "交接点暂不可用。"}
	if action_id == &"inspect":
		return {"success": true, "message": _description()}
	if is_open or ActionResolver.resolve_id(actor, self, action_id).is_empty():
		return {"success": false, "message": "材料或交接条件已变化。"}
	if action_id == &"survey_site":
		if not field_search.use():
			return {"success": false, "message": "搜寻还需 %d 秒，稍后按 Q 或再次点击废车。" % field_search.seconds_left()}
		return {"success": true, "message": "车后发现了废金属。点击拾取。" if is_open else "试着从车尾搜寻。"}
	# Inventory signals are synchronous. Latch the fixture before publishing a mutation.
	is_open = true
	var message: String
	match action_id:
		&"repair_bridge":
			actor.spend_items(BRIDGE_COST, _publish_change)
			message = "栈桥修好了。过桥到应急仓领取急救包。"
		&"take_kit":
			actor.add_item(&"medical_kit", 1)
			_publish_change()
			message = "急救包已装好。带回西侧值班室。"
		&"deliver_kit":
			actor.spend_items(DELIVERY_COST, _publish_change)
			message = "值班员签收了急救包。今晚的药品齐了。"
	return {"success": true, "message": message}


func _publish_change() -> void:
	set_hovered(false)
	state_changed.emit()


func _description() -> String:
	match object_kind:
		&"wreck":
			return "车后散落的物资已找到。"
		&"bridge":
			return "栈桥可通行。" if is_open else "缺口需要木材 ×3、废金属 ×2。"
		&"medical_cache":
			return "箱内物资已领完。" if is_open else "西侧栈桥修通后可以进仓。"
	return "药品已签收。" if is_open else "交接单：去东南应急仓，把急救包带回这里。"
