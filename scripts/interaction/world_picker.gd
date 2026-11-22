class_name WorldPicker
extends Node2D

@export_flags_2d_physics var target_collision_mask: int = 2


func pick_target(world_position: Vector2) -> Interactable:
	if not world_position.is_finite():
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = target_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(query, 64)
	var best: Interactable = null
	for hit in hits:
		var candidate: Interactable = hit.get("collider") as Interactable
		if not _can_pick(candidate):
			continue
		if best == null or _comes_before(candidate, best):
			best = candidate
	return best


func _can_pick(candidate: Interactable) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	if not candidate.is_visible_in_tree() or not candidate.input_pickable:
		return false
	# Optional fields let future targets opt out without coupling picking to art.
	for property in candidate.get_property_list():
		var key: StringName = StringName(property["name"])
		if key == &"interaction_enabled" and not bool(candidate.get(key)):
			return false
		if key == &"is_consumed" and bool(candidate.get(key)):
			return false
	return true


func _comes_before(candidate: Interactable, current: Interactable) -> bool:
	var candidate_priority := _priority(candidate)
	var current_priority := _priority(current)
	if candidate_priority != current_priority:
		return candidate_priority > current_priority
	if candidate.z_index != current.z_index:
		return candidate.z_index > current.z_index
	if not is_equal_approx(candidate.global_position.y, current.global_position.y):
		return candidate.global_position.y > current.global_position.y
	# Query ordering is unspecified; node path makes overlapping selection stable.
	return String(candidate.get_path()) < String(current.get_path())


func _priority(candidate: Interactable) -> int:
	for property in candidate.get_property_list():
		if StringName(property["name"]) == &"pick_priority":
			return int(candidate.get(&"pick_priority"))
	return 0
