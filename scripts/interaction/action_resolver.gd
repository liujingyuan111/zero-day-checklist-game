class_name ActionResolver
extends RefCounted


static func resolve(actor: PlayerController, target: Interactable) -> Dictionary:
	if not _valid_target(actor, target):
		return {}
	var candidates := target.get_available_actions(actor, actor.equipped_item_id)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("priority", 0))
		var pb := int(b.get("priority", 0))
		return pa > pb if pa != pb else String(a.get("id", "")) < String(b.get("id", ""))
	)
	return candidates[0].duplicate(true)


static func resolve_id(actor: PlayerController, target: Interactable, action_id: StringName) -> Dictionary:
	if not _valid_target(actor, target):
		return {}
	for action in target.get_available_actions(actor, actor.equipped_item_id):
		if StringName(action.get("id", &"")) == action_id:
			return action.duplicate(true)
	return {}


static func _valid_target(actor: PlayerController, target: Interactable) -> bool:
	return is_instance_valid(actor) and is_instance_valid(target) and not target.is_queued_for_deletion() and target.interaction_enabled and not target.is_consumed
