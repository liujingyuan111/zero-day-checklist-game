class_name FirstNightSite
extends Interactable

var run: NightRun


func get_available_actions(_actor: PlayerController, _item: StringName) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not interaction_enabled or run.phase != NightRun.Phase.NIGHT:
		return options
	var action_id := &"inspect"
	var label := "查看"
	if object_kind == &"shelter":
		action_id = &"end_night"
		label = "回屋过夜" if not run.route.is_empty() else "留守过夜"
	elif run.route.is_empty():
		action_id = &"scavenge"
		label = "前往搜刮"
	options.append(_action(action_id, label, 80, interaction_range, 0.65))
	return options


func execute_action(action_id: StringName, actor: PlayerController) -> Dictionary:
	if ActionResolver.resolve_id(actor,self,action_id).is_empty():
		return {"success":false, "message":"本次行动已结束。"}
	match action_id:
		&"scavenge":
			if run.search(object_kind):
				is_open = true
				return {"success":true,"message":"带回燃料 ×%d。点击西侧据点门口过夜。" % run.fuel}
		&"end_night":
			if run.settle():
				return {"success":true,"message":"第一夜已结算。"}
		&"inspect":
			return {"success":true,"message":"天亮前只够搜一处。返回据点过夜。"}
	return {"success":false,"message":"行动条件已变化。"}
